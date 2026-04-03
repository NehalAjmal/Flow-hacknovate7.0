from pydantic_settings import BaseSettings
from dotenv import find_dotenv


class Settings(BaseSettings):
    database_url: str
    jwt_secret_key: str
    gemini_api_key: str
    gemini_model: str = "gemini-2.5-flash"
    google_client_id: str
    access_token_expire_minutes: int = 30

    class Config:
        env_file = find_dotenv()


settings = Settings()