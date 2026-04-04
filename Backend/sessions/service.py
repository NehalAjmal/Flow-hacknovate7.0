from typing import Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session as DBSession

from db_models.user import User
from db_models.session import Session
from llm.cache import get_intervention

# 🔥 ML ENGINE IMPORTS
from engine.decision import DecisionEngine,compute_trough_pressure
from engine.deviation import DeviationEngine
from engine.ultradian import UltradianEngine
from engine.biometric import BiometricEngine
from learning.engine import PatternLearner

# 🔥 FATIGUE SERVICE
from ml_models.fatigue_model import fatigue_service

decision_engine = DecisionEngine()
deviation_engine = DeviationEngine()
ultradian_engine = UltradianEngine()
biometric_engine = BiometricEngine()
pattern_learner = PatternLearner()

_live_sessions: dict = {}

PASSIVE_APPS = {
    "youtube", "netflix", "twitter", "instagram", "facebook",
    "reddit", "tiktok", "twitch", "spotify", "discord"
}


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


# ── START SESSION ─────────────────────────────────────────

def start_session(db: DBSession, user_id: str, task: str):
    session = Session(
        user_id=user_id,
        task_description=task,
        start_time=datetime.now(timezone.utc),
        signal_log=[],
    )

    db.add(session)
    db.commit()
    db.refresh(session)

    # 🔥 START ULTRADIAN CLOCK
    ultradian_engine.start()
    try:
        fatigue = fatigue_service.get_state().get("fatigue_score", 0.0)
    except:
        fatigue = 0.0

    _live_sessions[session.id] = {
        "state": "deep_work",
        "focus_score": 75.0,
        "minutes_in_state": 0,
        "session_start": datetime.now(timezone.utc),
        "intervention": None,
    }

    return session


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
    if not live:
        return {"error": "session not found"}

    # ── DB SESSION ───────────────────────────
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        return {"error": "db session not found"}

    # ── TIME CALCULATION ─────────────────────
    session_minutes = int(
        (datetime.now(timezone.utc) - live["session_start"]).total_seconds() / 60
    )

    kpm = keystroke_count * 2

    # 🔥 TROUGH CALCULATION
    signal_len = len(session.signal_log or [])
    current_minute = signal_len * (5 / 60)
    trough_minute = 45  # fallback until patterns stored

    try:
        # ── ML SIGNALS ─────────────────────────
        deviation = deviation_engine.compute(kpm, window_switches, idle_seconds)
        ultradian = ultradian_engine.compute()
        biometric = biometric_engine.compute()
        fatigue = fatigue_service.get_state().get("fatigue_score", 0.0)

        # 🔥 TROUGH PRESSURE
        trough_pressure = compute_trough_pressure(current_minute, trough_minute)

        # ── DECISION ENGINE ────────────────────
        decision = decision_engine.compute(
            fatigue=fatigue,
            deviation=deviation,
            ultradian=ultradian,
            biometric=biometric,
            trough_pressure=trough_pressure
        )

        new_state = decision["state"]
        new_score = decision["focus_score"] * 100

    except Exception as e:
        print("⚠️ fallback:", e)

        new_state = classify_state(kpm, window_switches, idle_seconds, active_window, session_minutes)
        new_score = compute_focus_score(kpm, window_switches, idle_seconds, session_minutes, new_state)

        deviation = ultradian = biometric = fatigue = 0.0

    # ── STATE TRACKING ───────────────────────
    if new_state == live["state"]:
        live["minutes_in_state"] += 0.5
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

    # 🔥 PREDICTIVE INTERVENTION
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

    session.signal_log = log[-100:]
    db.commit()

    return live

# ── GET STATUS ─────────────────────────

def get_session_status(session_id: str):
    live = _live_sessions.get(session_id, {})

    fatigue = fatigue_service.get_state()

    return {
        "state": live.get("state", "deep_work"),
        "focus_score": round(live.get("focus_score", 75), 1),
        "signals": {
            "behavioral": min(1.0, live.get("keystrokes_per_min", 0) / 40),
            "ultradian": ultradian_engine.compute(),
            "biometric": fatigue.get("fatigue_score", 0.0),
            "ear": min(1.0, fatigue.get("ear", 0.0) * 3),
        }
    }

def _prepare_learning_data(signal_log):
    """
    Convert DB signal_log → PatternLearner format
    """

    data = []

    for entry in signal_log:
        data.append({
            "timestamp": entry.get("ts"),

            "input": {
                "keystrokes": entry.get("keystrokes", 0),
                "switches": entry.get("switches", 0),
                "idle": entry.get("idle", 0),
            },

            "output": {
                "fatigue": entry.get("fatigue", 0.0),
                "deviation": entry.get("deviation", 0.0)
            }
        })

    return data

# ── END SESSION ─────────────────────────

def end_session(db: DBSession, session_id: str):
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        return {"error": "not found"}

    session.end_time = datetime.now(timezone.utc)

    log = session.signal_log or []
    scores = [entry.get("score", 75) for entry in log]

    session.focus_score = int(sum(scores) / len(scores)) if scores else 75

    db.commit()
    _live_sessions.pop(session_id, None)

    print("\n📊 ===== LEARNING DEBUG =====")

    print("Total log entries:", len(log))

    learning_data = _prepare_learning_data(log)

    if learning_data:
        print("Sample input:", learning_data[0])

    patterns = pattern_learner.update(learning_data)

    print("Generated patterns:", patterns)

    print("===== END DEBUG =====\n")

# ── PATTERN LEARNING ─────────────────────

    learning_data = _prepare_learning_data(log)

    patterns = pattern_learner.update(learning_data)
    user = db.query(User).filter(User.id == session.user_id).first()
    if user:
        user.pattern_model = patterns
    db.commit()

    return {
        "session_id": session_id,
        "focus_score": session.focus_score,
        "events": log[:20],
        "patterns": patterns
    }