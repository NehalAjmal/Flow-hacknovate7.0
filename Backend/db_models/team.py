import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from db_models.base import Base


class Team(Base):
    __tablename__ = "teams"

    id:           Mapped[str]      = mapped_column(String(36),  primary_key=True, default=lambda: str(uuid.uuid4()))
    name:         Mapped[str]      = mapped_column(String(255), nullable=False)
    company_code: Mapped[str]      = mapped_column(String(16),  nullable=False, unique=True, index=True)
    admin_key:    Mapped[str]      = mapped_column(String(255), nullable=False)   # bcrypt-hashed 6-digit code
    created_at:   Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    # Relationships
    users: Mapped[list["User"]] = relationship("User", back_populates="team")

    def __repr__(self) -> str:
        return f"<Team {self.company_code}>"