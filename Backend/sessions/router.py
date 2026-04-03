# sessions/router.py
# All /session/* endpoints.
# The /stuck endpoint (Gemini AI) was already here.
# This adds: start, signal, status, respond, end

import json
from typing import Optional
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session as DBSession
from pydantic import BaseModel
from typing import List

from db_models.base import get_db
from auth.dependencies import get_current_user
from db_models.user import User
from llm.client import get_gemini_client, get_model_name
from llm.prompts import stuck_prompt
from .schemas import StuckRequest, StuckResponse, StuckSuggestion
from . import service

router = APIRouter()


# ── Schemas for new endpoints ──────────────────────────────────────────────────

class SessionStartRequest(BaseModel):
    task_description: str
    declared_difficulty: str   # light | moderate | heavy
    planned_duration_min: int


class SessionStartResponse(BaseModel):
    session_id: str
    message: str


class SignalRequest(BaseModel):
    session_id: str
    keystroke_count: int
    window_switches: int
    idle_seconds: int
    mouse_distance_px: int
    active_window: str
    timestamp: str


class InterventionResponse(BaseModel):
    session_id: str
    response: str   # accepted | dismissed | stuck


class SessionEndRequest(BaseModel):
    session_id: str
    self_rated_quality: Optional[int] = None  # 1-5


# ── Endpoints ──────────────────────────────────────────────────────────────────

@router.post("/start", response_model=SessionStartResponse)
def start_session(
    payload: SessionStartRequest,
    db: DBSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    User clicks 'Begin Focus'. Creates a session record and starts tracking.
    """
    session = service.start_session(
        db=db,
        user_id=current_user.id,
        task_description=payload.task_description,
        declared_difficulty=payload.declared_difficulty,
        planned_duration_min=payload.planned_duration_min,
    )
    return SessionStartResponse(
        session_id=session.id,
        message="Session started. Agent should begin sending signals."
    )


@router.post("/signal")
def receive_signal(
    payload: SignalRequest,
    db: DBSession = Depends(get_db),
):
    """
    Python agent calls this every 30 seconds with behavioral data.
    No auth required — agent runs locally and we trust it.
    Updates live state and decides if intervention is needed.
    """
    live = service.ingest_signal(
        db=db,
        session_id=payload.session_id,
        keystroke_count=payload.keystroke_count,
        window_switches=payload.window_switches,
        idle_seconds=payload.idle_seconds,
        mouse_distance_px=payload.mouse_distance_px,
        active_window=payload.active_window,
        timestamp=payload.timestamp,
    )
    return {
        "status": "ok",
        "state": live["state"],
        "focus_score": round(live["focus_score"], 1),
        "should_intervene": live["intervention"] is not None,
    }


@router.get("/status")
def get_status(
    session_id: str,
    current_user: User = Depends(get_current_user),
):
    """
    Flutter polls this every 8 seconds during an active session.
    Returns full state for the active session UI.
    """
    status = service.get_session_status(session_id)
    return status


@router.post("/respond")
def respond_to_intervention(
    payload: InterventionResponse,
    db: DBSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    User clicks accept/dismiss/stuck on an intervention card.
    """
    result = service.handle_intervention_response(
        db=db,
        session_id=payload.session_id,
        response=payload.response,
    )
    return result


@router.post("/end")
def end_session(
    payload: SessionEndRequest,
    db: DBSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    User ends the session. Returns replay and stats for session-end screen.
    """
    result = service.end_session(
        db=db,
        session_id=payload.session_id,
        self_rated_quality=payload.self_rated_quality,
    )
    return result


@router.get("/pre-check")
def pre_check(
    current_user: User = Depends(get_current_user),
):
    """
    Called when session start screen loads.
    Returns smart recommendations based on user's pattern model.
    """
    pattern = current_user.pattern_model or {}
    params  = pattern.get("parameters", {})

    # Pull peak hours from learned pattern model
    focus_profile = params.get("fatigue_focus_profile", {})
    if focus_profile:
        best_hour = max(focus_profile, key=lambda h: focus_profile[h])
        recommendation = f"Your data suggests {best_hour}:00 is your peak focus hour today."
    else:
        recommendation = "Complete a few sessions so FLOW can learn your peak hours."

    return {
        "recommendation": recommendation,
        "suggested_duration_min": int(params.get("ultradian_period", 50)),
        "warnings": [],   # calendar warnings added here once calendar_google is connected
    }


# ── Stuck endpoint (Gemini AI) — was already here ─────────────────────────────

@router.post("/stuck", response_model=StuckResponse)
async def get_stuck_suggestions(payload: StuckRequest):
    """
    Called when user clicks 'I'm stuck — help me break this down'.
    Makes a live Gemini API call with full session context.
    """
    prompt = stuck_prompt(
        task_declared=payload.task_declared,
        difficulty=payload.difficulty,
        stuck_duration_minutes=payload.stuck_duration_minutes,
        active_window=payload.active_window,
        session_duration_minutes=payload.session_duration_minutes
    )

    try:
        client = get_gemini_client()
        response = await client.aio.models.generate_content(
            model=get_model_name(),
            contents=prompt
        )
        raw_text = response.text.strip()
        if raw_text.startswith("```"):
            raw_text = raw_text.split("```")[1]
            if raw_text.startswith("json"):
                raw_text = raw_text[4:]
            raw_text = raw_text.strip()

        data = json.loads(raw_text)
        return StuckResponse(
            suggestions=[StuckSuggestion(**s) for s in data["suggestions"]],
            encouragement=data["encouragement"],
            session_id=payload.session_id
        )

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="AI response could not be parsed.")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"AI service temporarily unavailable: {str(e)}")