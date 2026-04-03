# sessions/router.py
# FIX: Updated for new google.genai API

import json
from fastapi import APIRouter, HTTPException
from llm.client import get_gemini_client, get_model_name
from llm.prompts import stuck_prompt
from .schemas import StuckRequest, StuckResponse, StuckSuggestion

router = APIRouter()


@router.post("/stuck", response_model=StuckResponse)
async def get_stuck_suggestions(payload: StuckRequest):
    """
    Called when user clicks 'I'm stuck'.
    Calls Gemini with full session context, returns 3 specific strategies.
    """
    prompt = stuck_prompt(
        task_declared=payload.task_declared,
        difficulty=payload.difficulty,
        stuck_duration_minutes=payload.stuck_duration_minutes,
        active_window=payload.active_window,
        session_duration_minutes=payload.session_duration_minutes
    )

    try:
        client = get_gemini_client()

        # New google.genai async API
        response = await client.aio.models.generate_content(
            model=get_model_name(),
            contents=prompt
        )

        raw_text = response.text.strip()

        # Strip markdown code fences if Gemini wraps the JSON
        if raw_text.startswith("```"):
            raw_text = raw_text.split("```")[1]
            if raw_text.startswith("json"):
                raw_text = raw_text[4:]
            raw_text = raw_text.strip()

        data = json.loads(raw_text)

        return StuckResponse(
            suggestions=[StuckSuggestion(**s) for s in data["suggestions"]],
            encouragement=data["encouragement"],
            session_id=payload.session_id
        )

    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="AI response could not be parsed. Please try again.")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"AI service temporarily unavailable: {str(e)}")