# config.py
# This file reads all our secret values from the .env file.
# Think of it as the single source of truth for all configuration.
# Every other file imports from here instead of reading .env directly.

from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Gemini API key from Google AI Studio
    gemini_api_key: str

    # Secret key used to sign JWT tokens (from your .env)
    secret_key: str

    # MySQL connection string
    database_url: str

    # Gemini model to use — gemini-1.5-flash is fast and free-tier friendly
    gemini_model: str = "gemini-1.5-flash"

    # How long a JWT token stays valid (in minutes)
    access_token_expire_minutes: int = 60 * 24  # 24 hours

    class Config:
        # This tells pydantic to look for a .env file automatically
        env_file = ".env"

# Create a single instance that the whole app shares.
# Any file can do: from config import settings
settings = Settings()