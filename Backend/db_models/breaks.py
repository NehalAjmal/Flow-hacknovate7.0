import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Float, Boolean, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from db_models.base import Base


class Break(Base):
    __tablename__ = "breaks"

    id:         Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id: Mapped[str] = mapped_column(String(36), ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)

    suggested_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    taken:        Mapped[bool]               = mapped_column(Boolean, nullable=False, default=False)
    taken_at:     Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_actual_min: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Layer A — behavioural state before the break
    switches_before:   Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    keystrokes_before: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Layer B — behavioural state after the break (for restoration score)
    switches_after:   Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    keystrokes_after: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    restoration_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)  # 0-1

    # Relationships
    session: Mapped["Session"] = relationship("Session", back_populates="breaks")

    def __repr__(self) -> str:
        return f"<Break session={self.session_id[:8]} taken={self.taken} restoration={self.restoration_score}>"