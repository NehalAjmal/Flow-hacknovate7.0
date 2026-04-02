def compute_warning_level(minutes_until: int) -> str:
    """
    Given how many minutes until the next event, return a warning level.
    The session start screen uses this to color-code the warning card.
 
    none     — No meeting in the next 3 hours. Start anything.
    caution  — Meeting in 60-90 min. Long sessions not recommended.
    warning  — Meeting in 30-60 min. Only short sessions.
    block    — Meeting in under 30 min. Don't start a deep work session at all.
    """
    if minutes_until > 90:
        return "none"
    elif minutes_until > 60:
        return "caution"
    elif minutes_until > 30:
        return "warning"
    else:
        return "block"
 
 
def build_recommendation(warning_level: str, minutes_until: int | None) -> str:
    """
    Build a human-readable recommendation string based on the warning level.
    This is what the Flutter session start screen shows inside the warning card.
    """
    recommendations = {
        "none": "Your calendar is clear for the next 3 hours. Any session length is safe.",
        "caution": f"You have a meeting in about {minutes_until} minutes. Consider a session under 45 minutes to leave buffer time.",
        "warning": f"Meeting in {minutes_until} minutes. A short 20-25 minute session is the maximum recommended.",
        "block": f"Meeting starting in {minutes_until} minutes. Starting a deep focus session now will interrupt your flow at the worst time. Prepare for your meeting instead."
    }
    return recommendations.get(warning_level, "Calendar check inconclusive.")
 