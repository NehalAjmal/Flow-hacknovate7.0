# export/schemas.py
# FIX: Python 3.9 needs List[int] not list[int]

from typing import List
from pydantic import BaseModel


class FocusDNARequest(BaseModel):
    user_name: str
    peak_hours: List[int]
    cycle_length_minutes: int
    weekly_focus_score: float
    best_focus_day: str
    total_sessions_this_week: int
    avg_session_quality: float


class FocusDNAResponse(BaseModel):
    user_name: str
    peak_hours_formatted: List[str]
    cycle_length_minutes: int
    weekly_focus_score: float
    best_focus_day: str
    total_sessions_this_week: int
    avg_session_quality: float
    gemini_insight: str
    card_subtitle: str