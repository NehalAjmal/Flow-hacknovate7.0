from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="FLOW API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(session_router, prefix="/session", tags=["Session"])
app.include_router(calendar_router, prefix="/calendar", tags=["Calendar"])
app.include_router(export_router, prefix="/export", tags=["Export"])

@app.get("/")
def root():
    return {"status": "FLOW backend running"}

@app.get("/api/ping")
def ping():
    return {"message": "pong"}