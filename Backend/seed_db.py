import uuid
import random
import json
from datetime import datetime, timedelta, timezone

from db_models.base import SessionLocal
from db_models.user import User
from db_models.session import Session
from db_models.team import Team 

def seed_database():
    db = SessionLocal()
    try:
        print("🧹 Cleaning old demo data...")
        db.query(Session).delete()
        db.query(User).filter(User.email.like("%@flow.com")).delete()
        db.query(Team).filter(Team.id == "team_error_011").delete()
        db.commit()

        print("🌱 Creating Demo Team...")
        # FIX: Added 'admin_key' to satisfy the database constraint
        demo_team = Team(
            id="team_error_011",
            name="Team Error 011",
            company_code="HACK7",
            admin_key="FLOW-DEMO-2026" # This fixes the 'Column admin_key cannot be null' error
        )
        db.add(demo_team)
        db.commit() 

        print("👤 Creating Users...")
        admin_user = User(
            id=str(uuid.uuid4()),
            email="admin@flow.com",
            full_name="Nehal Ajmal (Lead)",
            password_hash="hashed_dummy_password", 
            role="admin",
            team_id="team_error_011",
            # We pass the dict directly; SQLAlchemy handles the JSON column
            pattern_model={"parameters": {"ultradian_period": 90}},
            burnout_flagged=False
        )
        db.add(admin_user)

        employees = []
        for i in range(1, 4):
            emp = User(
                id=str(uuid.uuid4()),
                email=f"employee{i}@flow.com",
                full_name=f"Demo Employee {i}",
                password_hash="hashed_dummy_password",
                role="employee",
                team_id="team_error_011",
                pattern_model={"parameters": {"ultradian_period": random.choice([75, 90, 110])}},
                burnout_flagged=False
            )
            employees.append(emp)
            db.add(emp)

        db.commit()

        print("📊 Generating Session History...")
        now = datetime.now(timezone.utc)
        all_users = [admin_user] + employees
        
        for user in all_users:
            for _ in range(random.randint(5, 8)):
                days_ago = random.randint(0, 3)
                start_hour = random.randint(8, 16)
                start_time = now - timedelta(days=days_ago)
                start_time = start_time.replace(hour=start_hour, minute=0, second=0)
                
                duration = random.randint(45, 120)
                end_time = start_time + timedelta(minutes=duration)
                
                session = Session(
                    id=str(uuid.uuid4()),
                    user_id=user.id,
                    start_time=start_time,
                    end_time=end_time,
                    actual_duration_min=duration,
                    focus_score=random.randint(40, 95)
                )
                db.add(session)
                
            # Create ONE LIVE session for the demo
            if user.role == "employee" and random.choice([True, False]):
                live_session = Session(
                    id=str(uuid.uuid4()),
                    user_id=user.id,
                    start_time=now - timedelta(minutes=20),
                    end_time=None,
                    focus_score=None
                )
                db.add(live_session)

        db.commit()
        print("✅ Database successfully populated!")
        print("👉 Login: admin@flow.com | Pass: hashed_dummy_password")

    except Exception as e:
        print(f"❌ Error seeding database: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_database()