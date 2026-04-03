# admin/router.py

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from db_models.base import get_db
from db_models.user import User
from auth.dependencies import require_admin
from .schemas import AdminDashboardResponse
from .service import get_admin_dashboard

router = APIRouter()


@router.get("/dashboard", response_model=AdminDashboardResponse)
def admin_dashboard(
    current_user: User = Depends(require_admin),
    db: DBSession = Depends(get_db),
):
    """
    Full admin dashboard payload. Requires admin JWT.
    Returns team aggregate data — no individual session details.
    """
    if not current_user.team_id:
        # Admin has no team — return demo data so screen isn't blank
        from .service import _demo_dashboard
        return _demo_dashboard()

    return get_admin_dashboard(db=db, team_id=current_user.team_id)


@router.post("/send-break-alert")
def send_break_alert(current_user: User = Depends(require_admin)):
    """
    Notify all active employees to take a break.
    In production this would push a notification via WebSocket.
    For demo: returns success immediately.
    """
    return {
        "status": "ok",
        "message": "Break alert sent to all active employees.",
        "notified_count": 5,  # demo value
    }


@router.post("/invite-employee")
def invite_employee(
    current_user: User = Depends(require_admin),
    db: DBSession = Depends(get_db),
):
    """
    Returns the company code for the admin to share with employees.
    """
    from db_models.team import Team
    team = db.query(Team).filter(Team.id == current_user.team_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    return {
        "company_code": team.company_code,
        "message": f"Share code '{team.company_code}' with employees during registration.",
    }