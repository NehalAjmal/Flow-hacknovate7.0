# export/schemas.py

from pydantic import BaseModel


class FocusDNARequest(BaseModel):
    user_name: str
    peak_hours: list[int]             # e.g. [9, 10, 14] — hours in 24hr format
    cycle_length_minutes: int         # personal ultradian period e.g. 87
    weekly_focus_score: float         # 0.0 to 100.0
    best_focus_day: str               # e.g. "Tuesday"
    total_sessions_this_week: int
    avg_session_quality: float        # 0.0 to 5.0


class FocusDNAResponse(BaseModel):
    user_name: str
    peak_hours_formatted: list[str]   # ["9:00", "10:00", "14:00"]
    cycle_length_minutes: int
    weekly_focus_score: float
    best_focus_day: str
    total_sessions_this_week: int
    avg_session_quality: float
    gemini_insight: str               # The personalized AI-generated sentence
    card_subtitle: str                # Subtitle line for the Flutter card widget