from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

from db_models.base import get_db
from db_models.user import User
from db_models.team import Team
from config import settings

from auth.schemas import (
    RegisterRequest, LoginRequest,
    RegisterResponse, LoginResponse,
    GoogleAuthRequest,
)
from auth.utils import get_password_hash, verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ── Helper ─────────────────────────────────────────────────────────────────────

def _resolve_team(db: Session, account_type: str, company_code: Optional[str] = None):
    if account_type in ("company_employee", "admin"):
        if not company_code:
            raise HTTPException(
                status_code=400,
                detail="company_code is required for this account type",
            )
        team = db.query(Team).filter(Team.company_code == company_code).first()
        if not team:
            raise HTTPException(status_code=404, detail="Invalid company code")
        role = "employee" if account_type == "company_employee" else "admin"
        return role, team.id
    return "solo", None


# ── /register ──────────────────────────────────────────────────────────────────

@router.post(
    "/register",
    response_model=RegisterResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_user(payload: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email is already registered")

    role, team_id = _resolve_team(db, payload.account_type, payload.company_code)

    new_user = User(
        full_name=payload.full_name,
        email=payload.email,
        password_hash=get_password_hash(payload.password),
        age=payload.age,
        sex=payload.sex,
        role=role,
        team_id=team_id,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    token = create_access_token(data={"sub": new_user.id, "role": new_user.role})

    return RegisterResponse(
        user_id=new_user.id,
        token=token,
        role=new_user.role,
        team_id=new_user.team_id,
        redirect_to="/dashboard",
    )


# ── /login ─────────────────────────────────────────────────────────────────────

@router.post(
    "/login",
    response_model=LoginResponse,
    status_code=status.HTTP_200_OK,
)
def login_user(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email).first()

    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    token = create_access_token(data={"sub": user.id, "role": user.role})

    return LoginResponse(
        user_id=user.id,
        token=token,
        role=user.role,
        team_id=user.team_id,
        redirect_to="/dashboard",
    )



@router.post(
    "/google",
    response_model=RegisterResponse,
    status_code=status.HTTP_200_OK,
)
def google_auth(payload: GoogleAuthRequest, db: Session = Depends(get_db)):
    try:
        id_info = id_token.verify_oauth2_token(
            payload.token,
            google_requests.Request(),
            settings.google_client_id,
        )
        email     = id_info["email"]
        full_name = id_info.get("name", "")
    except (ValueError, KeyError):
        raise HTTPException(status_code=401, detail="Invalid Google token")

    user = db.query(User).filter(User.email == email).first()

    if user:
        pass

    else:
        if not payload.password:
            raise HTTPException(
                status_code=400,
                detail="Password is required when registering via Google",
            )

        role, team_id = _resolve_team(
            db,
            payload.account_type or "solo",
            payload.company_code,
        )

        user = User(
            full_name=full_name,
            email=email,
            password_hash=get_password_hash(payload.password),
            role=role,
            team_id=team_id,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token(data={"sub": user.id, "role": user.role})

    return RegisterResponse(
        user_id=user.id,
        token=token,
        role=user.role,
        team_id=user.team_id,
        redirect_to="/dashboard",
    )