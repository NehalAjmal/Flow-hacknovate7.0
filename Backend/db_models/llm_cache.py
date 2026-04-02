import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, Text, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from db_models.base import Base


class LLMCache(Base):
    """
    Keyed by a deterministic hash of the prompt context.
    No FK to users — responses are context-keyed and reusable across users.
    expires_at = NULL means pre-baked demo response, never expires.
    """
    __tablename__ = "llm_cache"

    id:            Mapped[str]           = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    cache_key:     Mapped[str]           = mapped_column(String(255), nullable=False, unique=True)
    prompt_type:   Mapped[str]           = mapped_column(String(30),  nullable=False)  # intervention | stuck | focus_dna | forecast_insight
    prompt_text:   Mapped[str]           = mapped_column(Text, nullable=False)
    response_text: Mapped[str]           = mapped_column(Text, nullable=False)
    expires_at:    Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    hit_count:     Mapped[int]           = mapped_column(Integer, nullable=False, default=0)
    created_at:    Mapped[datetime]      = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())

    def __repr__(self) -> str:
        return f"<LLMCache key={self.cache_key[:16]} type={self.prompt_type} hits={self.hit_count}>"