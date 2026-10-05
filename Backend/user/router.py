from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession
from datetime import datetime, timezone, timedelta

from db_models.base import get_db
from auth.dependencies import get_current_user
from db_models.user import User
from db_models.session import Session
from .schemas import DashboardMetrics, PatternsResponse, ChartPoint

router = APIRouter()

@router.get("/dashboard", response_model=DashboardMetrics)
def get_dashboard(
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    # naive UTC — matches what MySQL returns and what the SQL filters expect
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    start_of_yesterday = start_of_today - timedelta(days=1)

    # 1. Fetch Today's Sessions
    todays_sessions = db.query(Session).filter(
        Session.user_id == current_user.id,
        Session.start_time >= start_of_today
    ).all()

    sessions_count = len(todays_sessions)
    total_duration = sum([(s.actual_duration_min or 0) for s in todays_sessions])

    # 2. Focus Score Math — honest zeros for accounts with no sessions today
    if sessions_count > 0:
        scores = [s.focus_score for s in todays_sessions if s.focus_score]
        today_score = int(sum(scores) / len(scores)) if scores else 0
    else:
        today_score = 0  # no invented baseline — the UI shows an empty state

    # Fetch Yesterday to calculate the Delta (+/- vs yesterday)
    yesterdays_sessions = db.query(Session).filter(
        Session.user_id == current_user.id,
        Session.start_time >= start_of_yesterday,
        Session.start_time < start_of_today
    ).all()

    if yesterdays_sessions:
        y_scores = [s.focus_score for s in yesterdays_sessions if s.focus_score]
        yesterday_score = int(sum(y_scores) / len(y_scores)) if y_scores else today_score
    else:
        yesterday_score = today_score # Zero delta if no past data

    delta = today_score - yesterday_score

    # 3. Rhythm Position (Using user's ML learned ultradian cycle)
    pattern = current_user.pattern_model or {}
    params = pattern.get("parameters", {})
    # learner exports ultradian_cycle_minutes; seeded demo data uses ultradian_period
    cycle_length = int(params.get("ultradian_cycle_minutes") or params.get("ultradian_period") or 90)

    # Calculate how deep into their current cycle they are based on today's work
    if todays_sessions:
        last_session = todays_sessions[-1]
        rhythm_pos = (last_session.actual_duration_min or 0) % cycle_length
    else:
        rhythm_pos = 0

    # 4. History flag — any completed session ever (drives the empty/onboarding UI)
    has_history = db.query(Session).filter(
        Session.user_id == current_user.id,
        Session.end_time != None
    ).count() > 0

    minutes_until_trough = max(0, cycle_length - rhythm_pos) if has_history else 0

    # 5. Dynamic Greeting
    hour = now.hour
    first_name = current_user.full_name.split()[0]
    if hour < 12:
        greeting = f"Good morning, {first_name}"
    elif hour < 17:
        greeting = f"Good afternoon, {first_name}"
    else:
        greeting = f"Good evening, {first_name}"

    return DashboardMetrics(
        focus_score_today=today_score,
        focus_score_delta=delta,
        sessions_today=sessions_count,
        total_duration_minutes=total_duration,
        rhythm_position_minutes=rhythm_pos,
        minutes_until_trough=minutes_until_trough,
        has_history=has_history,
        greeting_message=greeting
    )

@router.get("/patterns", response_model=PatternsResponse)
def get_patterns(
    current_user: User = Depends(get_current_user),
    db: DBSession = Depends(get_db)
):
    # 1. Get learned patterns from ML (or defaults)
    pattern = current_user.pattern_model or {}
    params = pattern.get("parameters", {})
    has_pattern_data = bool(params)
    # learner exports ultradian_cycle_minutes; seeded demo data uses ultradian_period
    cycle_minutes = int(params.get("ultradian_cycle_minutes") or params.get("ultradian_period") or 90)

    # Peak hours derived ONLY from learned data — never invented.
    # The fatigue_focus_profile maps hour -> focus (0-1, higher = better).
    profile = params.get("fatigue_focus_profile") or {}
    if profile:
        top = sorted(profile.items(), key=lambda kv: kv[1], reverse=True)[:2]
        peak_hours = sorted(int(h) for h, _ in top)
    else:
        peak_hours = []

    # 2. Fetch real sessions
    sessions = db.query(Session).filter(Session.user_id == current_user.id).all()

    # 3. Daily activity for the last 28 days (oldest first) — sessions completed per day
    today = datetime.now(timezone.utc).replace(tzinfo=None).replace(hour=0, minute=0, second=0, microsecond=0)
    daily_activity = [0] * 28
    for s in sessions:
        if s.start_time and s.end_time:
            day_index = 27 - (today - s.start_time.replace(tzinfo=None).replace(
                hour=0, minute=0, second=0, microsecond=0)).days
            if 0 <= day_index < 28:
                daily_activity[day_index] += 1

    # Compute weekly trends
    days_map = {0:"Mon", 1:"Tue", 2:"Wed", 3:"Thu", 4:"Fri", 5:"Sat", 6:"Sun"}
    points_dict = {d: [] for d in days_map.values()}

    # Only compute from the last 7 days to avoid flatlining the entire map historically
    # naive UTC — MySQL returns naive datetimes and aware/naive comparison raises
    week_ago = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=7)

    for s in sessions:
        if s.start_time and s.start_time >= week_ago and s.focus_score:
            dt = s.start_time
            day_str = days_map[dt.weekday()]
            points_dict[day_str].append(s.focus_score)

    weekly_trends = []
    for day_str in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]:
        scores = points_dict[day_str]
        avg = int(sum(scores)/len(scores)) if scores else 0
        weekly_trends.append(ChartPoint(label=day_str, value=avg))

    # Compute hourly quality
    hourly_dict = {h: [] for h in range(9, 18)}
    for s in sessions:
        if s.start_time and s.focus_score:
            h = s.start_time.hour
            if h in hourly_dict:
                hourly_dict[h].append(s.focus_score)

    hourly_quality = []
    for h in sorted(hourly_dict.keys()):
        scores = hourly_dict[h]
        if scores:
            avg = int(sum(scores)/len(scores))
            ampm = "AM" if h < 12 else "PM"
            lbl_h = h if h <= 12 else h - 12
            hourly_quality.append(ChartPoint(label=f"{lbl_h} {ampm}", value=avg))

    return PatternsResponse(
        ultradian_cycle_minutes=cycle_minutes,
        peak_focus_hours=peak_hours,
        has_pattern_data=has_pattern_data,
        daily_activity=daily_activity,
        weekly_trends=weekly_trends,
        hourly_quality=hourly_quality
    )