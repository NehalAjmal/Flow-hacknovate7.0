from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession

from db_models.base import get_db
from db_models.user import User
from db_models.session import Session
from .schemas import TeamSummaryResponse, EmployeeStatus
from auth.dependencies import get_current_user, require_admin

router = APIRouter()

@router.get("/summary", response_model=TeamSummaryResponse)
def get_team_summary(
    current_user: User = Depends(require_admin),
    db: DBSession = Depends(get_db)
):
    team_id = current_user.team_id
    
    # 1. Fetch all users in this team
    team_members = db.query(User).filter(User.team_id == team_id).all() if team_id else []

    # 2. HACKATHON MAGIC: Demo Data for Solo users testing the UI
    if len(team_members) <= 1:
        demo_employees = [
            EmployeeStatus(id="emp_1", display_name="Employee 1", current_status="In Flow", focus_score=88, burnout_risk="Low"),
            EmployeeStatus(id="emp_2", display_name="Employee 2", current_status="Offline", focus_score=72, burnout_risk="Medium"),
            EmployeeStatus(id="emp_3", display_name="Employee 3", current_status="In Flow", focus_score=45, burnout_risk="High")
        ]
        return TeamSummaryResponse(
            team_name="Engineering Pod Alpha",
            average_focus_score=68,
            active_sessions_count=2,
            total_employees=3,
            employees=demo_employees
        )

    # 3. REAL LOGIC: Process actual team members
    employees_data = []
    total_score = 0
    active_count = 0

    for i, member in enumerate(team_members):
        display_name = f"Employee {i+1}" # Privacy filter
        
        # Grab their most recent session
        last_session = db.query(Session).filter(Session.user_id == member.id).order_by(Session.start_time.desc()).first()
        
        status = "Offline"
        score = 75
        risk = "Low"

        if last_session:
            score = last_session.focus_score or 75
            if last_session.end_time is None:
                status = "In Flow"
                active_count += 1
            
            # Simple ML Burnout logic
            if score < 50:
                risk = "High"
            elif score < 70:
                risk = "Medium"

        total_score += score
        employees_data.append(EmployeeStatus(
            id=str(member.id),
            display_name=display_name,
            current_status=status,
            focus_score=score,
            burnout_risk=risk
        ))

    avg_score = int(total_score / len(team_members)) if team_members else 0

    return TeamSummaryResponse(
        team_name=f"Team {team_id}",
        average_focus_score=avg_score,
        active_sessions_count=active_count,
        total_employees=len(team_members),
        employees=employees_data
    )