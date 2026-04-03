from pydantic import BaseModel
from typing import List

class EmployeeStatus(BaseModel):
    id: str
    display_name: str
    current_status: str  # "In Flow", "Break", "Offline"
    focus_score: int
    burnout_risk: str    # "Low", "Medium", "High"

class TeamSummaryResponse(BaseModel):
    team_name: str
    average_focus_score: int
    active_sessions_count: int
    total_employees: int
    employees: List[EmployeeStatus]