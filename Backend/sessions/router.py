from fastapi import APIRouter, HTTPException
import google.generativeai as genai
import json
from llm.client import get_gemini_model
from config import settings
from .schemas import StuckRequest, StuckResponse, StuckSuggestion

router = APIRouter()

@router.post("/stuck", response_model=StuckResponse)
async def get_stuck_suggestions(payload: StuckRequest):
    """
    Called when a user clicks 'I'm stuck — help me break this down'.
    Makes a live Gemini API call with full session context.
    Returns 3 specific strategies tailored to their exact situation.
    """
 
    # Build a rich, context-aware prompt.
    # The more specific the context we give Gemini, the more useful the output.
    # Notice we're telling Gemini to respond in JSON — this makes parsing reliable.
    prompt = f"""
You are FLOW, an AI cognitive assistant helping a developer who is stuck.
 
Here is their exact situation:
- Task they declared: "{payload.task_declared}"
- Difficulty level they set: {payload.difficulty}
- Time spent stuck on this specific problem: {payload.stuck_duration_minutes} minutes
- Active application/window: {payload.active_window}
- Total session duration so far: {payload.session_duration_minutes} minutes
 
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
 
    try:
        # Initialize the Gemini model.
        # gemini-1.5-flash is fast (important for UX) and generous on free tier.
        model = genai.GenerativeModel(settings.gemini_model)
 
        # This is the actual API call. The `await` here is important —
        # instead of freezing FastAPI while waiting for Google to respond
        # (which could take 1-3 seconds), FastAPI can handle other requests
        # during that wait. generate_content_async is the async version.
        response = await model.generate_content_async(prompt)
 
        # Extract the text from Gemini's response
        raw_text = response.text.strip()
 
        # Sometimes Gemini wraps JSON in markdown code fences like ```json ... ```
        # Strip those out if present so json.loads doesn't choke
        if raw_text.startswith("```"):
            raw_text = raw_text.split("```")[1]
            if raw_text.startswith("json"):
                raw_text = raw_text[4:]
            raw_text = raw_text.strip()
 
        # Parse the JSON string into a Python dictionary
        data = json.loads(raw_text)
 
        # Build and return the response object.
        # Pydantic validates the structure before sending it to Flutter.
        return StuckResponse(
            suggestions=[StuckSuggestion(**s) for s in data["suggestions"]],
            encouragement=data["encouragement"],
            session_id=payload.session_id
        )
 
    except json.JSONDecodeError:
        # If Gemini returned something we can't parse, return a safe fallback
        # rather than crashing. During a demo, a graceful fallback > a 500 error.
        raise HTTPException(
            status_code=500,
            detail="AI response could not be parsed. Please try again."
        )
    except Exception as e:
        # Catch all other errors (network issues, API quota, etc.)
        raise HTTPException(
            status_code=503,
            detail=f"AI service temporarily unavailable: {str(e)}"
        )
 