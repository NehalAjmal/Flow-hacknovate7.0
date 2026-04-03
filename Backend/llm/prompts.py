# llm/prompts.py
# All Gemini prompt templates live here.
# They are functions that take data and return a formatted prompt string.
# This keeps all AI prompt logic in one place — easy to tune and test.

def stuck_prompt(task_declared: str, difficulty: str,
                 stuck_duration_minutes: int, active_window: str,
                 session_duration_minutes: int) -> str:
    """
    Build the prompt for the 'I'm stuck' feature.
    Takes the session context as arguments and returns a formatted string.

    BUG FIX: The original file used a top-level f-string referencing `payload`
    which doesn't exist at module level — it would crash on import.
    Prompts must be functions that receive data as parameters.
    """
    return f"""
You are FLOW, an AI cognitive assistant helping a developer who is stuck.

Here is their exact situation:
- Task they declared: "{task_declared}"
- Difficulty level they set: {difficulty}
- Time spent stuck on this specific problem: {stuck_duration_minutes} minutes
- Active application/window: {active_window}
- Total session duration so far: {session_duration_minutes} minutes

Your job is to give them 3 concrete, specific strategies to get unstuck.
These must be tailored to their declared task — not generic advice.
Do NOT give advice like "take a break" or "search online" — those are obvious.
Focus on cognitive reframing, problem decomposition, and debugging strategies.

Respond ONLY with valid JSON in this exact format — no other text, no markdown:
{{
  "suggestions": [
    {{
      "strategy": "short strategy name",
      "explanation": "one sentence explaining why this fits their specific situation",
      "first_step": "the single concrete action to take in the next 2 minutes"
    }},
    {{
      "strategy": "short strategy name",
      "explanation": "one sentence explaining why this fits their specific situation",
      "first_step": "the single concrete action to take in the next 2 minutes"
    }},
    {{
      "strategy": "short strategy name",
      "explanation": "one sentence explaining why this fits their specific situation",
      "first_step": "the single concrete action to take in the next 2 minutes"
    }}
  ],
  "encouragement": "one warm human sentence acknowledging the frustration and expressing genuine belief they will get through this"
}}
"""


def focus_dna_insight_prompt(user_name: str, peak_hours: list,
                              cycle_length_minutes: int,
                              weekly_focus_score: float,
                              best_focus_day: str,
                              total_sessions: int,
                              avg_quality: float) -> str:
    """
    Build the prompt for generating a personalized weekly insight
    for the Focus DNA card.
    """
    peak_hours_str = ", ".join([f"{h}:00" for h in peak_hours])

    return f"""
You are FLOW, an AI cognitive performance assistant.
A user just completed their week. Here is their actual data:

- Name: {user_name}
- Peak focus hours this week: {peak_hours_str}
- Personal ultradian cycle (their natural focus rhythm): {cycle_length_minutes} minutes
- Weekly focus score: {weekly_focus_score:.1f} / 100
- Best focus day: {best_focus_day}
- Total sessions completed: {total_sessions}
- Average session quality rating: {avg_quality:.1f} / 5.0

Write ONE insight sentence (max 20 words) that is:
1. Specific to THEIR data — reference actual numbers or patterns
2. Actionable — tells them something they can do differently next week
3. Warm but direct — not generic motivational fluff

Respond with ONLY the insight sentence. No labels, no quotes, no explanation.
"""