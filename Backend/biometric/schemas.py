# biometric/schemas.py

from pydantic import BaseModel
from typing import Optional


class BiometricIngestRequest(BaseModel):
    session_id: str
    user_id: Optional[str] = None    # optional — server can pull from JWT
    heart_rate_bpm: Optional[float] = None
    hrv_sdnn: Optional[float] = None
    ear_value: Optional[float] = None     # Eye Aspect Ratio from ML friend's engine
    source: Optional[str] = "webcam"     # apple_watch | webcam_rppg | ml_model
    confidence: Optional[float] = None   # 0.0 - 1.0


class BiometricIngestResponse(BaseModel):
    status: str
    reading_id: str
    fatigue_signal: float    # 0.0 - 1.0, computed from the ingested values


class LatestBiometricResponse(BaseModel):
    heart_rate_bpm: Optional[float]
    hrv_sdnn: Optional[float]
    ear_value: Optional[float]
    fatigue_signal: float
    source: Optional[str]