# export/router.py

from collections import defaultdict
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession

from db_models.base import get_db
from db_models.session import Session as SessionModel
from db_models.user import User
from auth.dependencies import get_current_user
from .schemas import FocusDNARequest, FocusDNAResponse
from .service import generate_focus_dna

router = APIRouter()

DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


@router.post("/focus-dna", response_model=FocusDNAResponse)
async def export_focus_dna(
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """
    Returns the Focus DNA data payload for the weekly card.

    The weekly stats are computed server-side from the user's session
    history — the client only needs a valid token and an empty body.

    No image generation happens here — that's Flutter's job.
    """
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    week_ago = now - timedelta(days=7)

    week_sessions = [
        s for s in db.query(SessionModel)
        .filter(SessionModel.user_id == current_user.id)
        .all()
        if s.start_time and s.start_time >= week_ago and s.focus_score
    ]

    total_sessions = len(week_sessions)

    if week_sessions:
        scores = [s.focus_score for s in week_sessions if s.focus_score]
        weekly_focus_score = sum(scores) / len(scores)
        avg_quality = weekly_focus_score  # sessions are engine-scored 0-100

        day_scores = defaultdict(list)
        hour_scores = defaultdict(list)
        for s in week_sessions:
            day_scores[s.start_time.weekday()].append(s.focus_score)
            hour_scores[s.start_time.hour].append(s.focus_score)
        best_day = DAYS[max(day_scores, key=lambda d: sum(day_scores[d]) / len(day_scores[d]))]
        peak_hours = sorted(
            sorted(hour_scores, key=lambda h: sum(hour_scores[h]) / len(hour_scores[h]), reverse=True)[:2]
        )
    else:
        weekly_focus_score = 0.0
        avg_quality = 0.0
        best_day = "—"
        peak_hours = [9]

    # Learned cycle length when available, else the 90-min default
    pattern = current_user.pattern_model or {}
    params = pattern.get("parameters", {}) or {}
    cycle_minutes = int(params.get("ultradian_cycle_minutes") or params.get("ultradian_period") or 90)

    payload = FocusDNARequest(
        user_name=current_user.full_name,
        peak_hours=peak_hours,
        cycle_length_minutes=cycle_minutes,
        weekly_focus_score=weekly_focus_score,
        best_focus_day=best_day,
        total_sessions_this_week=total_sessions,
        avg_session_quality=avg_quality,
    )

    return await generate_focus_dna(payload)
