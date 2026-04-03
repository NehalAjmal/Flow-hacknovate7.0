"""
FLOW — Demo Data Seeder
Team Error 011 | Hacknovate 7.0

Run this AFTER setup.py to populate the database with realistic demo data.
This makes the demo look lived-in from the first login.

Usage:
    python demo/seed_data.py
"""

import sys
import os
import json
import random
import bcrypt
from datetime import datetime, timedelta, timezone

# Make sure Backend/ is on the path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import find_dotenv, load_dotenv
load_dotenv(find_dotenv())

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from config import settings

from db_models.base import Base
from db_models.user import User
from db_models.team import Team
from db_models.session import Session as FlowSession

engine = create_engine(settings.database_url.replace("+aiomysql", "+pymysql"))
SessionLocal = sessionmaker(bind=engine)


# ── Demo users ─────────────────────────────────────────────────────────────────

DEMO_USERS = [
    {
        "full_name":  "Amaan Khan",
        "email":      "demo@flow.app",
        "password":   "demo1234",
        "age":        21,
        "sex":        "male",
        "role":       "employee",
    },
    {
        "full_name":  "Nehal Ajmal",
        "email":      "nehal@flow.app",
        "password":   "demo1234",
        "age":        21,
        "sex":        "male",
        "role":       "employee",
    },
    {
        "full_name":  "Admin User",
        "email":      "admin@flow.app",
        "password":   "admin1234",
        "age":        30,
        "sex":        "prefer_not_to_say",
        "role":       "admin",
    },
]


# ── Realistic session data generator ──────────────────────────────────────────

TASKS = [
    ("Debugging JWT auth middleware", "heavy"),
    ("Building session signal endpoint", "heavy"),
    ("Reviewing PR for Flutter login screen", "moderate"),
    ("Writing unit tests for decision engine", "moderate"),
    ("Documenting API endpoints", "light"),
    ("Fixing calendar OAuth token refresh", "heavy"),
    ("Designing Focus DNA card layout", "moderate"),
    ("Setting up MySQL schema migrations", "moderate"),
    ("Optimizing signal ingestion latency", "heavy"),
    ("Code review — pattern learner module", "moderate"),
]

STATES_SEQUENCE = [
    "deep_work", "deep_work", "deep_work", "stuck",
    "deep_work", "deep_work", "fatigue", "deep_work",
]


def make_signal_log(duration_min: int) -> list:
    """Generate a realistic 30s tick signal log for a session."""
    ticks = duration_min * 2  # 2 ticks per minute
    log = []
    state_idx = 0
    base_time = datetime.now(timezone.utc) - timedelta(minutes=duration_min)

    for i in range(ticks):
        # Advance state every ~10 ticks
        if i > 0 and i % 10 == 0:
            state_idx = min(state_idx + 1, len(STATES_SEQUENCE) - 1)

        state = STATES_SEQUENCE[state_idx]

        # Generate realistic signals based on state
        if state == "deep_work":
            keystrokes = random.randint(20, 45)
            switches   = random.randint(2, 6)
            idle       = random.randint(0, 15)
            score      = random.uniform(72, 92)
        elif state == "stuck":
            keystrokes = random.randint(2, 8)
            switches   = random.randint(0, 2)
            idle       = random.randint(10, 40)
            score      = random.uniform(30, 45)
        elif state == "fatigue":
            keystrokes = random.randint(4, 12)
            switches   = random.randint(1, 4)
            idle       = random.randint(20, 60)
            score      = random.uniform(40, 60)
        else:
            keystrokes = 0
            switches   = random.randint(0, 1)
            idle       = random.randint(60, 120)
            score      = random.uniform(15, 30)

        tick_time = base_time + timedelta(seconds=i * 30)
        log.append({
            "ts":         tick_time.isoformat(),
            "keystrokes": keystrokes,
            "switches":   switches,
            "idle":       idle,
            "window":     "VS Code" if state in ("deep_work", "stuck") else "Chrome",
            "state":      state,
            "score":      round(score, 1),
        })

    return log


def make_replay_events(signal_log: list) -> list:
    """Condense signal log into Flutter replay timeline events."""
    events = []
    prev_state = None

    for entry in signal_log:
        if entry["state"] != prev_state:
            events.append({
                "ts":    entry["ts"],
                "state": entry["state"],
                "score": entry["score"],
            })
            prev_state = entry["state"]

    return events


def make_pattern_model(sessions: list) -> dict:
    """Build a realistic learned pattern model from demo sessions."""
    return {
        "schema_version": "F8_v2_fatigue_only",
        "last_updated":   datetime.utcnow().isoformat(),
        "parameters": {
            "fatigue_focus_profile": {
                "9":  0.92, "10": 0.95, "11": 0.88,
                "14": 0.72, "15": 0.65, "16": 0.78,
                "20": 0.45, "21": 0.38,
            },
            "ultradian_period":     52,
            "difficulty_bias":      {"1": 0.3, "3": -0.1, "5": -0.5},
            "intervention_threshold": 0.62,
            "resting_hr_baseline":  68.0,
            "hrv_baseline":         52.0,
        }
    }


# ── Main seeder ────────────────────────────────────────────────────────────────

def seed():
    db = SessionLocal()

    print("\n🌱 FLOW — Demo Data Seeder\n")

    # 1. Get or create the ERR011 team
    team = db.query(Team).filter(Team.company_code == "ERR011").first()
    if not team:
        admin_key_hash = bcrypt.hashpw(b"000000", bcrypt.gensalt()).decode("utf-8")
        team = Team(
            name="Error 011 Demo Corp",
            company_code="ERR011",
            admin_key=admin_key_hash,
        )
        db.add(team)
        db.commit()
        db.refresh(team)
        print("  ✓ Created team ERR011")
    else:
        print("  ✓ Team ERR011 already exists")

    # 2. Create demo users
    created_users = []
    for u in DEMO_USERS:
        existing = db.query(User).filter(User.email == u["email"]).first()
        if existing:
            print(f"  ✓ User {u['email']} already exists — skipping")
            created_users.append(existing)
            continue

        pw_hash = bcrypt.hashpw(u["password"].encode(), bcrypt.gensalt()).decode()
        user = User(
            full_name=u["full_name"],
            email=u["email"],
            password_hash=pw_hash,
            age=u["age"],
            sex=u["sex"],
            role=u["role"],
            team_id=team.id if u["role"] != "admin" else None,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        created_users.append(user)
        print(f"  ✓ Created user: {u['email']} / {u['password']}")

    # 3. Seed sessions for the first demo user (Amaan)
    demo_user = created_users[0]

    existing_sessions = db.query(FlowSession).filter(
        FlowSession.user_id == demo_user.id
    ).count()

    if existing_sessions >= 5:
        print(f"  ✓ Demo user already has {existing_sessions} sessions — skipping session seed")
    else:
        print(f"\n  Seeding sessions for {demo_user.full_name}...")
        seeded_sessions = []

        for i, (task, difficulty) in enumerate(random.sample(TASKS, 7)):
            # Spread sessions across last 5 days
            days_ago      = random.randint(0, 4)
            hour          = random.choice([9, 10, 11, 14, 15, 16, 20])
            start_time    = (
                datetime.now(timezone.utc)
                - timedelta(days=days_ago)
            ).replace(hour=hour, minute=random.randint(0, 30), second=0)

            duration_min  = random.randint(35, 75)
            end_time      = start_time + timedelta(minutes=duration_min)

            signal_log    = make_signal_log(duration_min)
            replay_events = make_replay_events(signal_log)

            scores = [e["score"] for e in signal_log]
            avg_score = int(sum(scores) / len(scores)) if scores else 72

            accepted      = random.randint(1, 3)
            total_int     = accepted + random.randint(0, 2)

            session = FlowSession(
                user_id=demo_user.id,
                task_description=task,
                declared_difficulty=difficulty,
                planned_duration_min=60,
                actual_duration_min=duration_min,
                start_time=start_time,
                end_time=end_time,
                focus_score=avg_score,
                self_rated_quality=random.randint(3, 5),
                interventions_total=total_int,
                interventions_accepted=accepted,
                signal_log=signal_log,
                replay_events=replay_events,
            )
            db.add(session)
            seeded_sessions.append(session)

        db.commit()
        print(f"  ✓ Seeded {len(seeded_sessions)} sessions")

        # 4. Update pattern model on demo user
        pattern = make_pattern_model(seeded_sessions)
        demo_user.pattern_model = pattern
        db.commit()
        print("  ✓ Updated pattern model for demo user")

    db.close()

    print("\n✅ Demo data ready!\n")
    print("  Login credentials:")
    print("  ─────────────────────────────────────")
    print("  Solo/Employee:  demo@flow.app   / demo1234")
    print("  Employee 2:     nehal@flow.app  / demo1234")
    print("  Admin:          admin@flow.app  / admin1234")
    print("  Company code:   ERR011")
    print("  Admin key:      000000")
    print("  ─────────────────────────────────────\n")


if __name__ == "__main__":
    seed()