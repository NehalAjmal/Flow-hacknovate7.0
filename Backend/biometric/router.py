# biometric/router.py
#
# Receives biometric readings from two sources:
#   1. The ML friend's fatigue engine (EAR values from webcam)
#   2. Apple Watch / rPPG (heart rate, HRV)
#
# Also reads from fatigue.json which the ML friend's main.py writes to,
# so even if they don't call this endpoint, we can still pull their data.

import uuid
import json
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from db_models.base import get_db
from db_models.biometric import BiometricReading
from auth.dependencies import get_current_user
from db_models.user import User
from .schemas import BiometricIngestRequest, BiometricIngestResponse, LatestBiometricResponse

router = APIRouter()

# Path to the fatigue.json file the ML friend's engine writes
_FATIGUE_JSON = Path(__file__).parent.parent / "ml_models" / "fatigue.json"


def _compute_fatigue_signal(
    ear: Optional[float],
    hr: Optional[float],
    hrv: Optional[float],
) -> float:
    """
    Combine EAR, HR, HRV into a single 0-1 fatigue signal.
    Higher = more fatigued.
    Mirrors the logic in engine/biometric.py but works standalone.
    """
    score = 0.0
    count = 0

    if ear is not None:
        # EAR < 0.2 = very closed eyes = high fatigue
        ear_fatigue = max(0.0, min(1.0, 1.0 - (ear / 0.35)))
        score += ear_fatigue
        count += 1

    if hr is not None:
        # Elevated HR (above 90) = fatigue signal
        hr_fatigue = max(0.0, min(1.0, (hr - 60) / 40))
        score += hr_fatigue
        count += 1

    if hrv is not None:
        # Low HRV = fatigue (inverse relationship)
        hrv_fatigue = max(0.0, min(1.0, 1.0 - (hrv / 80)))
        score += hrv_fatigue
        count += 1

    return round(score / count, 3) if count > 0 else 0.5


def _read_fatigue_json() -> Optional[dict]:
    """
    Read the latest entry from the ML friend's fatigue.json output.
    Returns None if file doesn't exist yet.
    """
    if not _FATIGUE_JSON.exists():
        return None
    try:
        with open(_FATIGUE_JSON) as f:
            data = json.load(f)
        if isinstance(data, list) and data:
            return data[-1]  # most recent entry
        return None
    except Exception:
        return None


@router.post("/ingest", response_model=BiometricIngestResponse)
def ingest_biometric(
    payload: BiometricIngestRequest,
    db: DBSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Receive a biometric reading from Apple Watch, rPPG, or the ML engine.
    Stores it in the DB and returns the computed fatigue signal.
    """
    fatigue_signal = _compute_fatigue_signal(
        ear=payload.ear_value,
        hr=payload.heart_rate_bpm,
        hrv=payload.hrv_sdnn,
    )

    reading = BiometricReading(
        user_id=current_user.id,
        session_id=payload.session_id,
        heart_rate_bpm=payload.heart_rate_bpm,
        hrv_sdnn=payload.hrv_sdnn,
        ear_value=payload.ear_value,
        source=payload.source,
        confidence=payload.confidence,
    )
    db.add(reading)
    db.commit()
    db.refresh(reading)

    return BiometricIngestResponse(
        status="ok",
        reading_id=reading.id,
        fatigue_signal=fatigue_signal,
    )


@router.get("/latest", response_model=LatestBiometricResponse)
def get_latest_biometric(
    session_id: str,
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """
    Returns the most recent biometric reading for a session.
    First checks the DB, then falls back to reading fatigue.json directly
    from the ML friend's engine output.
    """
    # Try DB first
    reading = (
        db.query(BiometricReading)
        .filter(
            BiometricReading.session_id == session_id,
            BiometricReading.user_id == current_user.id,
        )
        .order_by(BiometricReading.recorded_at.desc())
        .first()
    )

    if reading:
        fatigue_signal = _compute_fatigue_signal(
            ear=reading.ear_value,
            hr=reading.heart_rate_bpm,
            hrv=reading.hrv_sdnn,
        )
        return LatestBiometricResponse(
            heart_rate_bpm=reading.heart_rate_bpm,
            hrv_sdnn=reading.hrv_sdnn,
            ear_value=reading.ear_value,
            fatigue_signal=fatigue_signal,
            source=reading.source,
        )

    # Fallback: read fatigue.json from ML friend's engine
    fatigue_data = _read_fatigue_json()
    if fatigue_data:
        ear = fatigue_data.get("ear_value") or fatigue_data.get("ear")
        fatigue_score = fatigue_data.get("fatigue_score", 0.5)
        return LatestBiometricResponse(
            heart_rate_bpm=None,
            hrv_sdnn=None,
            ear_value=ear,
            fatigue_signal=fatigue_score,
            source="ml_model",
        )

    # No data at all — return neutral defaults
    return LatestBiometricResponse(
        heart_rate_bpm=None,
        hrv_sdnn=None,
        ear_value=None,
        fatigue_signal=0.5,
        source=None,
    )