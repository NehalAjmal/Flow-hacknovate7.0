import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Float, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from db_models.base import Base


class BiometricReading(Base):
    __tablename__ = "biometric_readings"

    id:         Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id:    Mapped[str] = mapped_column(String(36), ForeignKey("users.id"),                          nullable=False, index=True)
    session_id: Mapped[str] = mapped_column(String(36), ForeignKey("sessions.id", ondelete="CASCADE"),   nullable=False, index=True)

    heart_rate_bpm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    hrv_sdnn:       Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    ear_value:      Mapped[Optional[float]] = mapped_column(Float, nullable=True)   # Eye Aspect Ratio 0-1

    source:     Mapped[Optional[str]]   = mapped_column(String(50), nullable=True)  # apple_watch | webcam_rppg — was String(20), too short
    confidence: Mapped[Optional[float]] = mapped_column(Float,      nullable=True)  # 0-1 signal confidence

    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    # Relationships
    user:    Mapped["User"]    = relationship("User",    back_populates="biometric_readings")
    session: Mapped["Session"] = relationship("Session", back_populates="biometric_readings")

    def __repr__(self) -> str:
        return f"<BiometricReading session={self.session_id[:8]} hr={self.heart_rate_bpm} source={self.source}>"