from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from auth.dependencies import get_current_user
from db_models.user import User
from auth.router import router as auth_router

from sessions.router import router as session_router
from calendar_app.router import router as calendar_router
from export.router import router as export_router

app = FastAPI(title="FLOW API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth_router)

app.include_router(session_router, prefix="/session", tags=["Session"])
app.include_router(calendar_router, prefix="/calendar", tags=["Calendar"])
app.include_router(export_router, prefix="/export", tags=["Export"])

@app.get("/")
def root():
    return {"status": "FLOW backend running"}

@app.get("/api/ping")
def ping():
    return {"message": "pong"}

@app.get("/dashboard")
def view_dashboard(current_user: User = Depends(get_current_user)):
    return {
        "message": f"Welcome to Flow, {current_user.full_name}!",
        "role": current_user.role,
        "team_id": current_user.team_id
    }