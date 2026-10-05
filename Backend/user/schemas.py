from pydantic import BaseModel
from typing import List

class DashboardMetrics(BaseModel):
    focus_score_today: int
    focus_score_delta: int
    sessions_today: int
    total_duration_minutes: int
    rhythm_position_minutes: int
    minutes_until_trough: int
    has_history: bool = False      # user has at least one completed session ever
    greeting_message: str

class ChartPoint(BaseModel):
    label: str
    value: int

class PatternsResponse(BaseModel):
    ultradian_cycle_minutes: int
    peak_focus_hours: List[int]
    has_pattern_data: bool = False
    daily_activity: List[int] = []   # 28 values, sessions completed per day (oldest first)
    weekly_trends: List[ChartPoint]
    hourly_quality: List[ChartPoint]