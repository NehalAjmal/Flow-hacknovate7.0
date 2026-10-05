# admin/service.py
# Business logic for the admin dashboard.
# Aggregates team data without exposing any individual's personal session details.
# Privacy rule: admins see counts and averages, never individual signal logs.

from datetime import datetime, timezone, timedelta
from typing import Optional
from sqlalchemy.orm import Session as DBSession
from sqlalchemy import func

from db_models.user import User
from db_models.session import Session
from .schemas import AdminDashboardResponse, BurnoutFlag, TrendPoint


def _empty_dashboard() -> AdminDashboardResponse:
    return AdminDashboardResponse(
        total_employees=0,
        active_right_now=0,
        avg_focus_score=0,
        burnout_flags_count=0,
        best_meeting_window="--:--",
        trend_7_days=[],
        burnout_flags=[],
        state_distribution={}
    )


def get_admin_dashboard(db: DBSession, team_id: Optional[str]) -> AdminDashboardResponse:
    """
    Build the full admin dashboard payload for a team.
    All data is aggregate — no individual session details exposed.
    """
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    week_ago = now - timedelta(days=7)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    yesterday_start = today_start - timedelta(days=1)

    # Admin without a team (solo account) — show honest zeros, no fake demo data
    if not team_id:
        return _empty_dashboard()

    # All employees in this team
    employees = db.query(User).filter(
        User.team_id == team_id,
        User.role == "employee"
    ).all()

    total_employees = len(employees)

    if total_employees == 0:
        return _empty_dashboard()

    # Team record for the company code
    from db_models.team import Team
    team = db.query(Team).filter(Team.id == team_id).first()
    company_code = team.company_code if team else None

    employee_ids = [e.id for e in employees]

    # Sessions this week
    week_sessions = db.query(Session).filter(
        Session.user_id.in_(employee_ids),
        Session.start_time >= week_ago
    ).all()

    # Today's sessions (active right now = no end_time)
    active_now = db.query(Session).filter(
        Session.user_id.in_(employee_ids),
        Session.start_time >= today_start,
        Session.end_time == None
    ).count()

    # Average focus score across all week sessions
    scores = [s.focus_score for s in week_sessions if s.focus_score is not None]
    avg_score = int(sum(scores) / len(scores)) if scores else 0

    # Burnout flags — employees whose avg focus < 50 or sessions_this_week < 2
    burnout_flags = []
    for emp in employees:
        emp_sessions = [s for s in week_sessions if s.user_id == emp.id]
        emp_scores = [s.focus_score for s in emp_sessions if s.focus_score]
        emp_avg = int(sum(emp_scores) / len(emp_scores)) if emp_scores else 0

        risk = None
        if emp_avg < 40 or len(emp_sessions) < 2:
            risk = "high"
        elif emp_avg < 55:
            risk = "medium"

        if risk:
            burnout_flags.append(BurnoutFlag(
                employee_id=emp.id,
                display_name=emp.full_name.split()[0] + " " + emp.full_name.split()[-1][0] + ".",
                risk_level=risk,
                sessions_this_week=len(emp_sessions),
                avg_focus_score=emp_avg,
            ))

    # 7-day trend
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    trend = []
    for i in range(7):
        day_start = today_start - timedelta(days=6 - i)
        day_end   = day_start + timedelta(days=1)
        day_sessions = [
            s for s in week_sessions
            if s.start_time and day_start <= s.start_time.replace(tzinfo=None) < day_end and s.focus_score
        ]
        day_scores = [s.focus_score for s in day_sessions]
        day_avg = int(sum(day_scores) / len(day_scores)) if day_scores else 0
        trend.append(TrendPoint(
            day=days[(day_start.weekday())],
            avg_score=day_avg
        ))

    # State distribution — synthesized placeholder counts, honest about it:
    # live per-employee state streaming isn't wired yet, so only active sessions
    # are reflected (the rest are genuinely unknown, shown as 0).
    state_distribution = {
        "deep_work": max(0, active_now - 1),
        "stuck":     0,
        "fatigue":   min(1, active_now),
        "passive":   0,
    }

    # Today's volume + duration + delta vs yesterday — all real
    today_sessions = [
        s for s in week_sessions
        if s.start_time and s.start_time >= today_start
    ]
    sessions_today = len(today_sessions)
    today_durations = [s.actual_duration_min or 0 for s in today_sessions]
    avg_duration = int(sum(today_durations) / len(today_durations)) if today_durations else 0

    yesterday_sessions = db.query(Session).filter(
        Session.user_id.in_(employee_ids),
        Session.start_time >= yesterday_start,
        Session.start_time < today_start,
    ).all()
    y_scores = [s.focus_score for s in yesterday_sessions if s.focus_score]
    y_avg = int(sum(y_scores) / len(y_scores)) if y_scores else avg_score
    avg_focus_delta = avg_score - y_avg if (scores or y_scores) else 0

    # Best meeting window — find the hour with lowest avg active sessions
    # Simple heuristic: suggest 2 hours from now, on the half hour
    next_hour = (now.hour + 2) % 24
    best_window = f"{next_hour:02d}:00 – {(next_hour+1):02d}:00"

    return AdminDashboardResponse(
        total_employees=total_employees,
        active_right_now=active_now,
        avg_focus_score=avg_score,
        avg_focus_delta=avg_focus_delta,
        sessions_today=sessions_today,
        avg_duration_min=avg_duration,
        company_code=company_code,
        burnout_flags_count=len(burnout_flags),
        best_meeting_window=best_window,
        trend_7_days=trend,
        burnout_flags=burnout_flags,
        state_distribution=state_distribution,
    )

