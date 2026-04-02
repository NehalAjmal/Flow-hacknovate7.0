from pydantic import BaseModel

class CalendarEvent(BaseModel):
    title: str
    start_time: str         # ISO format datetime string
    minutes_until: int      # How many minutes from now this event starts
    duration_minutes: int   # How long the event lasts

class CalendarContext(BaseModel):
    has_upcoming_events: bool
    warning_level: str      # "none" | "caution" | "warning" | "block"
    next_event: CalendarEvent | None
    events: list[CalendarEvent]
    recommendation: str     # Human-readable advice for the session start screen