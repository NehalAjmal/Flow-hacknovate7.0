from pydantic import BaseModel

class StuckRequest(BaseModel):
    session_id: str
    task_declared: str          # What the user said they were working on
    difficulty: str             # "light" | "moderate" | "heavy"
    stuck_duration_minutes: int # How many minutes they've been looping
    active_window: str          # What app/window they're currently in
    session_duration_minutes: int  # Total session time so far
 
class StuckSuggestion(BaseModel):
    strategy: str       # Short name for the strategy e.g. "Rubber Duck Debugging"
    explanation: str    # Why this strategy fits their specific situation
    first_step: str     # The single concrete next action to take right now
 
class StuckResponse(BaseModel):
    suggestions: list[StuckSuggestion]
    encouragement: str  # One warm, human sentence to end on
    session_id: str