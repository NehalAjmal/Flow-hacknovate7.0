from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # MySQL connection string
    database_url: str

    # JWT signing key
    jwt_secret_key: str

    # Gemini API
    gemini_api_key: str
    gemini_model: str = "gemini-2.5-flash"

    # Google OAuth — Web client ID from Google Cloud Console
    google_client_id: str

    # Token expiry
    access_token_expire_minutes: int = 30

    class Config:
        env_file = ".env"


settings = Settings()