# sessions/service.py
#
# Core session business logic. This file owns:
#   - Starting a session (creating DB record)
#   - Receiving 30-second behavioral signals from the Python agent
#   - Computing the current cognitive state (rule-based classifier)
#   - Returning live status to Flutter (polled every 8s)
#   - Handling intervention responses
#   - Ending a session
#
# The state classification here is intentionally rule-based so it works
# even if engine/ files are empty. It mirrors the logic the ML friend
# will eventually plug in through the engine layer.

from typing import Optional, List
from datetime import datetime, timezone
from sqlalchemy.orm import Session as DBSession

from db_models.session import Session
from db_models.user import User
from llm.cache import get_intervention


# ── In-memory session state ────────────────────────────────────────────────────
# Stores live signal data between the 30s agent ticks and the 8s Flutter polls.
# Key = session_id, Value = dict of latest computed signals.
# This is fine for a hackathon — in production you'd use Redis.

_live_sessions: dict = {}


# ── State classification thresholds ───────────────────────────────────────────

FATIGUE_SESSION_MIN     = 90    # minutes before fatigue is possible
FATIGUE_KEYSTROKE_MAX   = 10    # keystrokes/min below this → fatigue signal
STUCK_WINDOW_SWITCHES   = 2     # very low switching → stuck on same thing
STUCK_KEYSTROKE_MAX     = 8     # barely typing
PASSIVE_APPS = {
    "youtube", "netflix", "twitter", "instagram", "facebook",
    "reddit", "tiktok", "twitch", "spotify", "discord"
}


def classify_state(
    keystrokes_per_min: float,
    window_switches: int,
    idle_seconds: int,
    active_window: str,
    session_minutes: int,
) -> str:
    """
    Classify the user's current cognitive state from behavioral signals.
    Returns one of: deep_work | stuck | fatigue | passive
    """
    app_lower = active_window.lower()

    # Passive: on social/entertainment apps
    if any(p in app_lower for p in PASSIVE_APPS):
        return "passive"

    # Fatigue: long session + very low keystroke rate
    if session_minutes >= FATIGUE_SESSION_MIN and keystrokes_per_min < FATIGUE_KEYSTROKE_MAX:
        return "fatigue"

    # Stuck: very low switching + very low typing (grinding on same problem)
    if window_switches <= STUCK_WINDOW_SWITCHES and keystrokes_per_min < STUCK_KEYSTROKE_MAX:
        return "stuck"

    # Default: deep work
    return "deep_work"


def compute_focus_score(
    keystrokes_per_min: float,
    window_switches: int,
    idle_seconds: int,
    session_minutes: int,
    state: str,
) -> float:
    """
    Compute a 0-100 focus score from behavioral signals.
    Higher = more focused and cognitively healthy.
    """
    if state == "passive":
        return max(0.0, 30.0 - (idle_seconds / 10))

    if state == "fatigue":
        fatigue_penalty = min(40, (session_minutes - FATIGUE_SESSION_MIN) * 0.5)
        return max(10.0, 60.0 - fatigue_penalty)

    if state == "stuck":
        return 35.0

    # deep_work: reward consistent typing, penalize idle
    keystroke_score = min(50, keystrokes_per_min * 1.2)
    idle_penalty    = min(20, idle_seconds / 30)
    switch_bonus    = min(10, window_switches * 2) if window_switches < 8 else 0
    return min(100.0, keystroke_score + switch_bonus - idle_penalty + 20)


def should_intervene(state: str, minutes_in_state: int) -> bool:
    """
    Decide whether to fire an intervention based on current state and
    how long the user has been in it.
    """
    thresholds = {
        "fatigue":  5,    # intervene after 5 min of fatigue
        "stuck":    20,   # intervene after 20 min stuck
        "passive":  10,   # intervene after 10 min passive
        "deep_work": 999, # never interrupt deep work
    }
    return minutes_in_state >= thresholds.get(state, 999)


# ── Session start ──────────────────────────────────────────────────────────────

def start_session(
    db: DBSession,
    user_id: str,
    task_description: str,
    declared_difficulty: str,
    planned_duration_min: int,
) -> Session:
    """
    Create a new session record and initialize live state tracking.
    """
    session = Session(
        user_id=user_id,
        task_description=task_description,
        declared_difficulty=declared_difficulty,
        planned_duration_min=planned_duration_min,
        start_time=datetime.now(timezone.utc),
        signal_log=[],
        replay_events=[],
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # Initialize live state for this session
    _live_sessions[session.id] = {
        "state":             "deep_work",
        "focus_score":       75.0,
        "minutes_in_state":  0,
        "last_signal_at":    datetime.now(timezone.utc),
        "intervention":      None,   # filled when we decide to intervene
        "keystrokes_per_min": 0,
        "window_switches":   0,
        "idle_seconds":      0,
        "active_window":     task_description[:40],
        "session_start":     datetime.now(timezone.utc),
    }

    return session


# ── Signal ingestion ───────────────────────────────────────────────────────────

def ingest_signal(
    db: DBSession,
    session_id: str,
    keystroke_count: int,
    window_switches: int,
    idle_seconds: int,
    mouse_distance_px: int,
    active_window: str,
    timestamp: str,
) -> dict:
    """
    Receive a 30-second behavioral tick from the Python agent.
    Classify state, compute score, decide on intervention.
    Returns the updated live state dict.
    """
    live = _live_sessions.get(session_id)
    if not live:
        # Session not in memory (server restarted) — reconstruct minimal state
        live = {
            "state": "deep_work", "focus_score": 75.0,
            "minutes_in_state": 0,
            "last_signal_at": datetime.now(timezone.utc),
            "intervention": None,
            "session_start": datetime.now(timezone.utc),
        }
        _live_sessions[session_id] = live

    # Compute session duration
    session_minutes = int(
        (datetime.now(timezone.utc) - live["session_start"]).total_seconds() / 60
    )

    # Keystrokes per minute over the 30s window
    keystrokes_per_min = keystroke_count * 2  # 30s → per minute

    # Classify state
    new_state = classify_state(
        keystrokes_per_min=keystrokes_per_min,
        window_switches=window_switches,
        idle_seconds=idle_seconds,
        active_window=active_window,
        session_minutes=session_minutes,
    )

    # Track how long in current state
    if new_state == live["state"]:
        live["minutes_in_state"] += 0.5  # 30s tick
    else:
        live["minutes_in_state"] = 0     # reset on state change
        live["intervention"] = None      # clear old intervention on state change

    live["state"]             = new_state
    live["focus_score"]       = compute_focus_score(
        keystrokes_per_min, window_switches, idle_seconds, session_minutes, new_state
    )
    live["keystrokes_per_min"] = keystrokes_per_min
    live["window_switches"]    = window_switches
    live["idle_seconds"]       = idle_seconds
    live["active_window"]      = active_window
    live["last_signal_at"]     = datetime.now(timezone.utc)

    # Decide intervention
    if should_intervene(new_state, live["minutes_in_state"]) and not live["intervention"]:
        live["intervention"] = get_intervention(new_state)

    # Append to session signal_log in DB (keep last 100 ticks)
    session = db.query(Session).filter(Session.id == session_id).first()
    if session:
        log = session.signal_log or []
        log.append({
            "ts": timestamp,
            "keystrokes": keystroke_count,
            "switches": window_switches,
            "idle": idle_seconds,
            "window": active_window,
            "state": new_state,
            "score": round(live["focus_score"], 1),
        })
        session.signal_log = log[-100:]  # keep last 100
        db.commit()

    return live


# ── Status (Flutter polls this every 8s) ───────────────────────────────────────

def get_session_status(session_id: str) -> dict:
    """
    Return current live state for Flutter to render.
    If no live state exists (server restart), return safe defaults.
    """
    live = _live_sessions.get(session_id, {})

    intervention = live.get("intervention")
    score = round(live.get("focus_score", 75.0), 1)
    state = live.get("state", "deep_work")

    # Signal breakdown (0-1 scale for the signal strength bars in Flutter)
    kpm = live.get("keystrokes_per_min", 20)
    behavioral_signal = min(1.0, kpm / 40)     # 40 kpm = full bar
    idle = live.get("idle_seconds", 0)
    ultradian_signal  = max(0.0, 1.0 - (idle / 120))  # 2min idle = empty
    biometric_signal  = 0.7   # placeholder until biometric friend integrates
    ear_signal        = 0.8   # placeholder until ML friend integrates

    return {
        "should_intervene":    intervention is not None,
        "combined_score":      score / 100,
        "threshold":           0.65,
        "state":               state,
        "focus_score":         score,
        "signals": {
            "ultradian":  round(ultradian_signal, 2),
            "behavioral": round(behavioral_signal, 2),
            "biometric":  biometric_signal,
            "ear":        ear_signal,
        },
        "primary_driver":       state,
        "intervention_type":    intervention["title"] if intervention else None,
        "intervention_message": intervention["message"] if intervention else None,
        "intervention_action":  intervention["action_label"] if intervention else None,
    }


# ── Intervention response ──────────────────────────────────────────────────────

def handle_intervention_response(
    db: DBSession,
    session_id: str,
    response: str,  # "accepted" | "dismissed" | "stuck"
) -> dict:
    """
    User responded to an intervention. Clear it and log the response.
    """
    live = _live_sessions.get(session_id, {})
    live["intervention"] = None  # clear so it doesn't keep showing
    live["minutes_in_state"] = 0  # reset so we don't immediately re-trigger

    # Log acceptance rate to DB
    session = db.query(Session).filter(Session.id == session_id).first()
    if session:
        session.interventions_total = (session.interventions_total or 0) + 1
        if response == "accepted":
            session.interventions_accepted = (session.interventions_accepted or 0) + 1
        db.commit()

    return {"status": "ok", "response_recorded": response}


# ── Session end ────────────────────────────────────────────────────────────────

def end_session(
    db: DBSession,
    session_id: str,
    self_rated_quality: Optional[int] = None,
) -> dict:
    """
    Close the session, compute final stats, build replay timeline.
    """
    session = db.query(Session).filter(Session.id == session_id).first()
    if not session:
        return {"error": "Session not found"}

    live = _live_sessions.get(session_id, {})

    session.end_time = datetime.now(timezone.utc)
    session.self_rated_quality = self_rated_quality

    # Compute actual duration
    if session.start_time:
        delta = session.end_time - session.start_time
        session.actual_duration_min = int(delta.total_seconds() / 60)

    # Compute final focus score from signal log
    log = session.signal_log or []
    if log:
        scores = [entry.get("score", 75) for entry in log]
        session.focus_score = int(sum(scores) / len(scores))
    else:
        session.focus_score = int(live.get("focus_score", 75))

    # Build replay events for Flutter session-end timeline
    replay = []
    for entry in log:
        replay.append({
            "ts":     entry.get("ts"),
            "state":  entry.get("state"),
            "score":  entry.get("score"),
            "window": entry.get("window", ""),
        })
    session.replay_events = replay

    db.commit()

    # Clean up live state
    _live_sessions.pop(session_id, None)

    return {
        "session_id":           session_id,
        "duration_minutes":     session.actual_duration_min,
        "focus_score":          session.focus_score,
        "interventions_total":  session.interventions_total,
        "interventions_accepted": session.interventions_accepted,
        "replay_events":        replay[:20],  # first 20 for Flutter
        "what_flow_learned":    "Pattern model will update after 3 sessions.",
    }