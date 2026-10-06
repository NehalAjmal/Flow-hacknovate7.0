from typing import Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session as DBSession

from db_models.user import User
from db_models.session import Session
from db_models.biometric import BiometricReading
from llm.cache import get_intervention

#  ML ENGINE IMPORTS
from engine.decision import DecisionEngine, compute_trough_pressure
from engine.deviation import DeviationEngine
from engine.ultradian import UltradianEngine
from engine.biometric import BiometricEngine
import subprocess
import os
import sys
from learning.engine import PatternLearner

#  FATIGUE SERVICE
from ml_models.fatigue_model import fatigue_service

pattern_learner = PatternLearner()

_live_sessions: dict = {}

# The agent sends a tick every 30s; the log covers ~5h before capping.
AGENT_TICK_MINUTES = 0.5
SIGNAL_LOG_CAP = 600

PASSIVE_APPS = {
    "youtube", "netflix", "twitter", "instagram", "facebook",
    "reddit", "tiktok", "twitch", "spotify", "discord"
}

DEFAULT_TROUGH_MINUTE = 45
DEFAULT_ULTRADIAN_CYCLE = 90


# ── FALLBACK LOGIC (DO NOT REMOVE) ─────────────────────────

def classify_state(kpm, switches, idle, window, minutes):
    if any(p in window.lower() for p in PASSIVE_APPS):
        return "passive"
    if minutes >= 90 and kpm < 10:
        return "fatigue"
    if switches <= 2 and kpm < 8:
        return "stuck"
    return "deep_work"


def compute_focus_score(kpm, switches, idle, minutes, state):
    if state == "passive":
        return max(0.0, 30.0 - (idle / 10))
    if state == "fatigue":
        return max(10.0, 60.0 - (minutes - 90) * 0.5)
    if state == "stuck":
        return 35.0
    return min(100.0, kpm * 1.2 + 20)


# ── HELPERS ────────────────────────────────────────────────

def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _as_aware_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """MySQL returns naive datetimes; treat stored values as UTC."""
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _new_engines() -> dict:
    """Fresh engine set per session — no state leaks across users/sessions."""
    return {
        "decision": DecisionEngine(),
        "deviation": DeviationEngine(),
        "ultradian": UltradianEngine(),
        "biometric": BiometricEngine(),
    }


def _learned_params(db: DBSession, user_id: str) -> dict:
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.pattern_model:
        return {}
    return user.pattern_model.get("parameters", {}) or {}


def _latest_hr_hrv(db: DBSession, session_id: str):
    """Latest real heart-rate signal for this session: DB readings first
    (Apple Watch / rPPG ingest), then the live webcam rPPG estimate."""
    row = (
        db.query(BiometricReading)
        .filter(BiometricReading.session_id == session_id)
        .order_by(BiometricReading.recorded_at.desc())
        .first()
    )
    if row and row.heart_rate_bpm and row.hrv_sdnn:
        return float(row.heart_rate_bpm), float(row.hrv_sdnn)

    # live webcam rPPG (same process) — HR only, gated by confidence
    state = fatigue_service.get_state()
    hr = state.get("heart_rate_bpm")
    if hr and state.get("hr_confidence", 0.0) >= 0.15:
        return float(hr), None
    return None


# ── START SESSION ─────────────────────────────────────────

def start_session(
    db: DBSession,
    user_id: str,
    task_description: str,
    declared_difficulty: str,
    planned_duration_min: int,
):
    session = Session(
        user_id=user_id,
        task_description=task_description,
        declared_difficulty=declared_difficulty,
        planned_duration_min=planned_duration_min,
        start_time=_utcnow(),
        signal_log=[],
    )

    db.add(session)
    db.commit()
    db.refresh(session)

    params = _learned_params(db, user_id)
    cycle_minutes = int(params.get("ultradian_cycle_minutes") or params.get("ultradian_period") or DEFAULT_ULTRADIAN_CYCLE)

    #  PER-SESSION ENGINES (ultradian clock starts now)
    engines = _new_engines()
    engines["ultradian"] = UltradianEngine(cycle_minutes=cycle_minutes)
    engines["ultradian"].start()

    #  START FATIGUE TRACKING (CAMERA OPENS HERE)
    try:
        fatigue_service.start()
    except Exception as e:
        print("fatigue start failed:", e)

    #  START KEYBOARD/MOUSE LOCAL AGENT
    agent_process = None
    try:
        agent_script = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "agent", "main.py"))
        agent_process = subprocess.Popen([sys.executable, agent_script, session.id])
    except Exception as e:
        print("Agent start failed:", e)

    _live_sessions[session.id] = {
        "state": "deep_work",
        "focus_score": 75.0,
        "minutes_in_state": 0,
        "session_start": _utcnow(),
        "intervention": None,
        "agent_process": agent_process,
        "engines": engines,
        "user_id": user_id,
        "trough_minute": int(params.get("trough_minute") or DEFAULT_TROUGH_MINUTE),
    }

    return session


def _rehydrate_live(db: DBSession, session: Session) -> dict:
    """
    Rebuild an in-memory live entry from the DB row.
    Needed after a server restart (or uvicorn --reload) while a session runs —
    otherwise every agent tick fails and the session is orphaned.
    """
    params = _learned_params(db, session.user_id)
    cycle_minutes = int(params.get("ultradian_cycle_minutes") or params.get("ultradian_period") or DEFAULT_ULTRADIAN_CYCLE)

    engines = _new_engines()
    start = _as_aware_utc(session.start_time) or _utcnow()
    # Resume the ultradian clock from the real start time
    engines["ultradian"] = UltradianEngine(cycle_minutes=cycle_minutes)
    engines["ultradian"].start_time = start.timestamp()

    live = {
        "state": "deep_work",
        "focus_score": 75.0,
        "minutes_in_state": 0,
        "session_start": start,
        "intervention": None,
        "agent_process": None,
        "engines": engines,
        "user_id": session.user_id,
        "trough_minute": int(params.get("trough_minute") or DEFAULT_TROUGH_MINUTE),
        "rehydrated": True,
    }
    _live_sessions[session.id] = live
    return live


# ── INGEST SIGNAL (MAIN LOGIC) ─────────────────────────

def ingest_signal(
    db,
    session_id,
    keystroke_count,
    window_switches,
    idle_seconds,
    mouse_distance_px,
    active_window,
    timestamp,
):
    live = _live_sessions.get(session_id)

    # ── DB SESSION ───────────────────────────
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        return None  # truly unknown session → router returns 404

    if session.end_time is not None:
        # Session already ended — ignore stale agent ticks (agent exits on 404)
        return None

    if not live:
        # Server restarted mid-session: rebuild state instead of erroring out
        live = _rehydrate_live(db, session)
        print(f" rehydrated live session {session_id[:8]} from DB")

    # ── TIME CALCULATION ─────────────────────
    session_minutes = int(
        (_utcnow() - live["session_start"]).total_seconds() / 60
    )

    kpm = keystroke_count * 2

    #  TROUGH CALCULATION — real elapsed minutes vs the user's learned trough
    current_minute = session_minutes
    trough_minute = live["trough_minute"]

    try:
        # ── ML SIGNALS ─────────────────────────
        engines = live["engines"]
        deviation = engines["deviation"].compute(kpm, window_switches, idle_seconds)
        ultradian = engines["ultradian"].compute()

        fatigue = fatigue_service.get_state().get("fatigue_score", 0.0)

        # Biometric: real HR (watch or webcam rPPG) when available, otherwise webcam fatigue as proxy
        hr_hrv = _latest_hr_hrv(db, session_id)
        if hr_hrv:
            biometric = engines["biometric"].compute(hr=hr_hrv[0], hrv=hr_hrv[1])
        else:
            biometric = round(max(0.0, 1.0 - fatigue), 3)

        #  TROUGH PRESSURE
        trough_pressure = compute_trough_pressure(current_minute, trough_minute)

        # ── DECISION ENGINE ────────────────────
        decision = engines["decision"].compute(
            fatigue=fatigue,
            deviation=deviation,
            ultradian=ultradian,
            biometric=biometric,
            trough_pressure=trough_pressure
        )

        new_state = decision["state"]
        new_score = decision["focus_score"] * 100

    except Exception as e:
        print(" fallback:", e)

        new_state = classify_state(kpm, window_switches, idle_seconds, active_window, session_minutes)
        new_score = compute_focus_score(kpm, window_switches, idle_seconds, session_minutes, new_state)

        deviation = ultradian = biometric = fatigue = 0.0

    # ── STATE TRACKING ───────────────────────
    if new_state == live["state"]:
        live["minutes_in_state"] += AGENT_TICK_MINUTES
    else:
        live["minutes_in_state"] = 0
        live["intervention"] = None

    live.update({
        "state": new_state,
        "focus_score": new_score,
        "keystrokes_per_min": kpm,
        "window_switches": window_switches,
        "idle_seconds": idle_seconds,
        "active_window": active_window,
    })

    #  PREDICTIVE INTERVENTION
    if trough_pressure > 0.8 and not live["intervention"]:
        live["intervention"] = {
            "title": "Upcoming focus dip",
            "message": "You're nearing a natural dip in focus. Consider taking a break.",
            "action_label": "Take Break"
        }

    elif live["minutes_in_state"] > 5 and not live["intervention"]:
        live["intervention"] = get_intervention(new_state)

    # ── DB LOG ───────────────────────────────
    log = session.signal_log or []

    log.append({
        "ts": timestamp,
        "keystrokes": keystroke_count,
        "switches": window_switches,
        "idle": idle_seconds,
        "window": active_window,
        "state": new_state,
        "score": round(new_score, 1),

        "fatigue": fatigue,
        "deviation": deviation,
        "ultradian": ultradian,
        "biometric": biometric
    })

    session.signal_log = log[-SIGNAL_LOG_CAP:]
    db.commit()

    return live


def handle_intervention_response(db: DBSession, session_id: str, response: str):
    live = _live_sessions.get(session_id)
    if live:
        if response in ["dismissed", "accepted"]:
            live["intervention"] = None
    return {"status": "ok", "response": response}

# ── GET STATUS ─────────────────────────

def get_session_status(db: DBSession, session_id: str):
    """
    Returns live status for a session.
    Returns None when the session doesn't exist (router → 404).
    """
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        return None

    live = _live_sessions.get(session_id)
    fatigue = fatigue_service.get_state()

    def _minutes_to_trough() -> Optional[int]:
        """Minutes until the session's learned trough, or None when unknown."""
        if not live:
            return None
        start = _as_aware_utc(session.start_time) or live["session_start"]
        elapsed = int((_utcnow() - start).total_seconds() / 60)
        return max(0, live["trough_minute"] - elapsed)

    if not live:
        # Session exists but has no in-memory state (e.g. started before a restart):
        # report DB-derived basics instead of inventing a fake healthy session.
        log = session.signal_log or []
        return {
            "state": log[-1]["state"] if log else "deep_work",
            "focus_score": round(log[-1]["score"], 1) if log else 0.0,
            "signals": {
                "behavioral": 0.0,
                "ultradian": 0.5,
                "biometric": fatigue.get("fatigue_score", 0.0),
                "ear": min(1.0, fatigue.get("ear", 0.0) * 3),
            },
            "intervention": None,
            "minutes_to_trough": None,
        }

    engines = live.get("engines") or {}

    return {
        "state": live.get("state", "deep_work"),
        "focus_score": round(live.get("focus_score", 75), 1),
        "signals": {
            "behavioral": min(1.0, live.get("keystrokes_per_min", 0) / 40),
            "ultradian": engines["ultradian"].compute() if engines else 0.5,
            "biometric": fatigue.get("fatigue_score", 0.0),
            "ear": min(1.0, fatigue.get("ear", 0.0) * 3),
        },
        "heart_rate_bpm": fatigue.get("heart_rate_bpm"),
        "intervention": live.get("intervention"),
        "minutes_to_trough": _minutes_to_trough(),
    }

def _prepare_learning_data(signal_log):
    """
    Convert DB signal_log → PatternLearner format.
    Keys must match what learning/engine.py reads:
    keystroke_count / window_switches / idle_seconds.
    """

    data = []

    for entry in signal_log:
        data.append({
            "timestamp": entry.get("ts"),

            "input": {
                "keystroke_count": entry.get("keystrokes", 0),
                "window_switches": entry.get("switches", 0),
                "idle_seconds": entry.get("idle", 0),
            },

            "output": {
                "fatigue": entry.get("fatigue", 0.0),
                "deviation": entry.get("deviation", 0.0)
            }
        })

    return data

# ── END SESSION ─────────────────────────

def end_session(
    db: DBSession,
    session_id: str,
    self_rated_quality: Optional[int] = None,
):
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        return {"error": "not found"}

    session.end_time = _utcnow()
    session.self_rated_quality = self_rated_quality

    log = session.signal_log or []
    scores = [entry.get("score", 75) for entry in log]

    session.focus_score = int(sum(scores) / len(scores)) if scores else 75

    if session.actual_duration_min is None and session.start_time:
        start = _as_aware_utc(session.start_time)
        session.actual_duration_min = max(0, int((session.end_time - start).total_seconds() / 60))

    db.commit()

    live_data = _live_sessions.pop(session_id, None)
    if live_data and live_data.get("agent_process"):
        try:
            live_data["agent_process"].terminate()
            print("Stopped tracking agent.")
        except Exception:
            pass

    # Stop fatigue camera too since session ended
    try:
        fatigue_service.stop()
    except Exception:
        pass

    # ── PATTERN LEARNING (single pass) ─────────
    learning_data = _prepare_learning_data(log)
    patterns = pattern_learner.update(learning_data)

    user = db.query(User).filter(User.id == session.user_id).first()
    if user:
        user.pattern_model = patterns
    db.commit()

    print(f" learned patterns for session {session_id[:8]}: "
          f"trough={patterns.get('parameters', {}).get('trough_minute')} min, "
          f"cycle={patterns.get('parameters', {}).get('ultradian_cycle_minutes')} min")

    return {
        "session_id": session_id,
        "focus_score": session.focus_score,
        "actual_duration_min": session.actual_duration_min,
        "events": log[:20],
        "patterns": patterns
    }
