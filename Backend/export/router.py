# export/router.py

from fastapi import APIRouter, HTTPException
from .schemas import FocusDNARequest, FocusDNAResponse
from .service import generate_focus_dna

router = APIRouter()


@router.post("/focus-dna", response_model=FocusDNAResponse)
async def export_focus_dna(payload: FocusDNARequest):
    """
    Returns the Focus DNA data payload for the weekly card.

    Flutter receives this JSON and renders the card natively.
    The user can then screenshot or use Flutter's share_plus to export it.

    No image generation happens here — that's Flutter's job.
    """
    try:
        result = await generate_focus_dna(payload)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate Focus DNA: {str(e)}"
        )