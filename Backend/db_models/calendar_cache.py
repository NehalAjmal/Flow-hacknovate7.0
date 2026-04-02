import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Boolean, DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from db_models.base import Base


class CalendarCache(Base):
    __tablename__ = "calendar_cache"

    id:         Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id:    Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    event_id:   Mapped[str] = mapped_column(String(255), nullable=False)  # Google Calendar event ID

    title:      Mapped[Optional[str]]  = mapped_column(String(512), nullable=True)
    starts_at:  Mapped[datetime]       = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at:    Mapped[datetime]       = mapped_column(DateTime(timezone=True), nullable=False)
    is_blocking:Mapped[bool]           = mapped_column(Boolean, nullable=False, default=False)

    fetched_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "event_id", name="uq_calendar_user_event"),
    )

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="calendar_cache")

    def __repr__(self) -> str:
        return f"<CalendarCache user={self.user_id[:8]} event={self.event_id[:12]}>"