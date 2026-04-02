import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Text, DateTime, ForeignKey, JSON, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from db_models.base import Base


class Session(Base):
    __tablename__ = "sessions"

    id:      Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    task_description:     Mapped[Optional[str]] = mapped_column(Text,        nullable=True)  # TEXT not String(512)
    declared_difficulty:  Mapped[Optional[str]] = mapped_column(String(50),  nullable=True)  # matches schema VARCHAR(50)
    planned_duration_min: Mapped[Optional[int]] = mapped_column(Integer,     nullable=True)
    actual_duration_min:  Mapped[Optional[int]] = mapped_column(Integer,     nullable=True)

    start_time: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    end_time:   Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    focus_score:        Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    self_rated_quality: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    interventions_total:    Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    interventions_accepted: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    # JSON instead of JSONB — MySQL compatible
    signal_log:      Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)   # raw 30s agent ticks
    replay_events:   Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)   # Flutter replay stream
    learned_updates: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)   # learning engine diff

    # Relationships
    user:               Mapped["User"]               = relationship("User",             back_populates="sessions")
    biometric_readings: Mapped[list["BiometricReading"]] = relationship("BiometricReading", back_populates="session", cascade="all, delete-orphan")
    breaks:             Mapped[list["Break"]]        = relationship("Break",            back_populates="session", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Session {self.id[:8]} user={self.user_id[:8]} score={self.focus_score}>"