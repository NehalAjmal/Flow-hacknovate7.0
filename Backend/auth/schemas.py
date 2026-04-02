from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional


class RegisterRequest(BaseModel):
    full_name:    str
    email:        EmailStr
    password:     str
    age:          Optional[int]  = None
    sex:          Optional[str]  = None
    account_type: str            = "solo"   # solo | company_employee | admin
    company_code: Optional[str]  = None

    @field_validator("account_type")
    @classmethod
    def validate_account_type(cls, v: str) -> str:
        allowed = {"solo", "company_employee", "admin"}
        if v not in allowed:
            raise ValueError(f"account_type must be one of {allowed}")
        return v


class LoginRequest(BaseModel):
    email:    EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    token:        str
    password:     str                    # user sets their own password even when signing up via Google
    account_type: Optional[str] = "solo"
    company_code: Optional[str] = None


class RegisterResponse(BaseModel):
    user_id:     str          # UUID string
    token:       str
    role:        str
    team_id:     Optional[str] = None
    redirect_to: str


# LoginResponse reuses the same shape
LoginResponse = RegisterResponse