# calendar_app/schemas.py
# FIX: Python 3.9 needs Optional[X] instead of X | None

from typing import Optional, List
from pydantic import BaseModel


class CalendarEvent(BaseModel):
    title: str
    start_time: str
    minutes_until: int
    duration_minutes: int


class CalendarContext(BaseModel):
    has_upcoming_events: bool
    warning_level: str
    next_event: Optional[CalendarEvent]
    events: List[CalendarEvent]
    recommendation: str