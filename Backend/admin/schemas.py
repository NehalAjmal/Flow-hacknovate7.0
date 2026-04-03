# admin/schemas.py

from pydantic import BaseModel
from typing import List, Optional


class AdminStatCard(BaseModel):
    label: str
    value: str
    sub: Optional[str] = None


class BurnoutFlag(BaseModel):
    employee_id: str
    display_name: str
    risk_level: str       # "medium" | "high"
    sessions_this_week: int
    avg_focus_score: int


class TrendPoint(BaseModel):
    day: str              # "Mon", "Tue", etc.
    avg_score: int


class AdminDashboardResponse(BaseModel):
    total_employees: int
    active_right_now: int
    avg_focus_score: int
    burnout_flags_count: int
    best_meeting_window: str
    trend_7_days: List[TrendPoint]
    burnout_flags: List[BurnoutFlag]
    state_distribution: dict   # {"deep_work": 4, "stuck": 1, "fatigue": 2, "passive": 1}