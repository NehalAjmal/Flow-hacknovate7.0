# calendar_app/service.py
# FIX: Python 3.9 doesn't support `int | None` syntax.
# Must use Optional[int] from typing module instead.

from typing import Optional


def compute_warning_level(minutes_until: int) -> str:
    if minutes_until > 90:
        return "none"
    elif minutes_until > 60:
        return "caution"
    elif minutes_until > 30:
        return "warning"
    else:
        return "block"


def build_recommendation(warning_level: str, minutes_until: Optional[int]) -> str:
    recommendations = {
        "none": "Your calendar is clear for the next 3 hours. Any session length is safe.",
        "caution": f"You have a meeting in about {minutes_until} minutes. Consider a session under 45 minutes to leave buffer time.",
        "warning": f"Meeting in {minutes_until} minutes. A short 20-25 minute session is the maximum recommended.",
        "block": f"Meeting starting in {minutes_until} minutes. Starting a deep focus session now will interrupt your flow at the worst time. Prepare for your meeting instead."
    }
    return recommendations.get(warning_level, "Calendar check inconclusive.")