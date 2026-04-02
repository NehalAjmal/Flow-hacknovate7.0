import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Boolean, DateTime, ForeignKey, JSON, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from db_models.base import Base


class User(Base):
    __tablename__ = "users"

    id:            Mapped[str]           = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    full_name:     Mapped[str]           = mapped_column(String(255), nullable=False)
    email:         Mapped[str]           = mapped_column(String(320), nullable=False, unique=True, index=True)
    password_hash: Mapped[str]           = mapped_column(String(255), nullable=False)
    age:           Mapped[Optional[int]] = mapped_column(Integer,    nullable=True)
    sex:           Mapped[Optional[str]] = mapped_column(String(20), nullable=True)   # male | female | prefer_not_to_say
    role:          Mapped[str]           = mapped_column(String(20), nullable=False, default="solo")  # solo | employee | admin
    team_id:       Mapped[Optional[str]] = mapped_column(String(36), ForeignKey("teams.id"), nullable=True)

    # Written by the learning engine after every session — nullable until first session completes
    pattern_model:   Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    burnout_flagged: Mapped[bool]     = mapped_column(Boolean,  nullable=False, default=False)
    created_at:      Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    # Relationships
    team:               Mapped[Optional["Team"]]         = relationship("Team",             back_populates="users")
    sessions:           Mapped[list["Session"]]          = relationship("Session",          back_populates="user", cascade="all, delete-orphan")
    biometric_readings: Mapped[list["BiometricReading"]] = relationship("BiometricReading", back_populates="user", cascade="all, delete-orphan")
    calendar_cache:     Mapped[list["CalendarCache"]]    = relationship("CalendarCache",    back_populates="user", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<User {self.email} role={self.role}>"