# export/service.py
# The Focus DNA export service.
#
# IMPORTANT — WHY NO IMAGE GENERATION HERE:
# The backend's job is data. Flutter's job is UI.
# Generating a PNG on the Python backend using Pillow is wrong because:
# 1. Fonts look terrible without a proper rendering engine
# 2. Flutter already has a beautiful, native card widget designed for this
# 3. The backend would need to bundle fonts, handle DPI, etc. — all Flutter's domain
# 4. It's just bad architecture — backends serve data, frontends render it
#
# So this service returns a clean JSON payload with all the data Flutter needs
# to render the Focus DNA card and let the user screenshot/share it natively.
# Flutter's share_plus package handles the actual file export.

from llm.client import get_gemini_client, get_model_name
from llm.prompts import focus_dna_insight_prompt
from .schemas import FocusDNARequest, FocusDNAResponse


async def generate_focus_dna(data: FocusDNARequest) -> FocusDNAResponse:
    """
    Generate the Focus DNA data payload.
    Calls Gemini for a personalized weekly insight.
    Returns structured data — Flutter renders the card.
    """

    # Build the Gemini prompt using the prompts module
    prompt = focus_dna_insight_prompt(
        user_name=data.user_name,
        peak_hours=data.peak_hours,
        cycle_length_minutes=data.cycle_length_minutes,
        weekly_focus_score=data.weekly_focus_score,
        best_focus_day=data.best_focus_day,
        total_sessions=data.total_sessions_this_week,
        avg_quality=data.avg_session_quality
    )

    # Call Gemini for the personalized insight
    try:
        client = get_gemini_client()
        response = await client.aio.models.generate_content(
            model=get_model_name(),
            contents=prompt
        )
        insight = response.text.strip().strip('"').strip("'")
    except Exception:
        # If Gemini fails, use a data-driven fallback so the card still works
        insight = f"Your peak window is {data.peak_hours[0]}:00 — protect that hour next week."

    # Format peak hours as readable strings e.g. ["9:00", "10:00", "14:00"]
    peak_hours_formatted = [f"{h}:00" for h in data.peak_hours]

    return FocusDNAResponse(
        user_name=data.user_name,
        peak_hours_formatted=peak_hours_formatted,
        cycle_length_minutes=data.cycle_length_minutes,
        weekly_focus_score=round(data.weekly_focus_score, 1),
        best_focus_day=data.best_focus_day,
        total_sessions_this_week=data.total_sessions_this_week,
        avg_session_quality=round(data.avg_session_quality, 1),
        gemini_insight=insight,
        # Flutter uses this subtitle on the card
        card_subtitle=f"Week summary  •  {data.total_sessions_this_week} sessions completed"
    )