# sessions/schemas.py
# FIX: Python 3.9 needs List[X] instead of list[X]

from typing import List
from pydantic import BaseModel


class StuckRequest(BaseModel):
    session_id: str
    task_declared: str
    difficulty: str
    stuck_duration_minutes: int
    active_window: str
    session_duration_minutes: int


class StuckSuggestion(BaseModel):
    strategy: str
    explanation: str
    first_step: str


class StuckResponse(BaseModel):
    suggestions: List[StuckSuggestion]
    encouragement: str
    session_id: str