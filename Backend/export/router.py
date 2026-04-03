from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
import asyncio

from .schemas import FocusDNARequest
from .service import generate_weekly_insight, draw_focus_dna_card

router = APIRouter()

@router.post("/focus-dna")
async def export_focus_dna(payload: FocusDNARequest):
    """
    Generate the weekly Focus DNA card as a downloadable PNG.
    Flutter receives raw image bytes and handles the save/share dialog.
    """
    try:
        # Step 1: Get the Gemini-generated weekly insight (async API call)
        insight = await generate_weekly_insight(payload)
 
        # Step 2: Draw the card using Pillow (CPU work, runs in a thread
        # so it doesn't block the async event loop)
        png_bytes = await asyncio.to_thread(draw_focus_dna_card, payload, insight)
 
        # Step 3: Return the PNG as a raw binary response.
        # Flutter's http package receives these bytes and can save or share them.
        return Response(
            content=png_bytes,
            media_type="image/png",
            headers={
                "Content-Disposition": f'attachment; filename="flow_dna_{payload.user_name.replace(" ", "_")}.png"'
            }
        )
 
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate Focus DNA card: {str(e)}"
        )
 