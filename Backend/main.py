from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from auth.dependencies import get_current_user
from db_models.user import User
from auth.router import router as auth_router

app = FastAPI(title="FLOW API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth_router)

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