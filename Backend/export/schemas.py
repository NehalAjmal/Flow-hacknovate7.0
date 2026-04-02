from pydantic import BaseModel

class FocusDNARequest(BaseModel):
    user_name: str
    peak_hours: list[int]
    cycle_length_minutes: int
    weekly_focus_score: float
    best_focus_day: str
    total_sessions_this_week: int
    avg_session_quality: float