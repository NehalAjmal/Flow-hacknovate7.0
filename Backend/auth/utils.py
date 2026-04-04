import jwt
import bcrypt
from datetime import datetime, timedelta, timezone
from typing import Optional
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())

from config import settings

SECRET_KEY = settings.jwt_secret_key
ALGORITHM  = "HS256"


def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"), 
            hashed_password.encode("utf-8")
        )
    except ValueError:
        # Catch the "Invalid salt" crash if the DB contains a plain text password.
        
        # HACKATHON BYPASS: If you are manually typing passwords into your DB 
        # to test the demo, uncomment the line below to just allow plain-text matches:
        # return plain_password == hashed_password 
        
        return False


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta if expires_delta else timedelta(minutes=settings.access_token_expire_minutes)
    )
    to_encode["exp"] = expire
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)