"""
FLOW — Database Setup Script
Team Error 011 | Hacknovate 7.0

Run once after cloning:
    python setup_db.py
"""

import sys
import re
import bcrypt
import os
from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("✗ DATABASE_URL not found in .env")
    print("  → Copy .env.example to .env and fill in your MySQL password")
    sys.exit(1)


def get_db_name(url: str) -> str:
    match = re.search(r"/([^/?]+)(\?|$)", url)
    if not match:
        raise ValueError(f"Could not parse database name from URL: {url}")
    return match.group(1)


def get_root_url(url: str, db_name: str) -> str:
    return url.replace(f"/{db_name}", "/")


def create_database(url: str, db_name: str):
    from sqlalchemy import create_engine, text
    root_url = get_root_url(url, db_name)
    engine = create_engine(root_url)
    with engine.connect() as conn:
        conn.execute(text(
            f"CREATE DATABASE IF NOT EXISTS `{db_name}` "
            f"CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
        ))
        conn.commit()
    engine.dispose()
    print(f"  ✓ Database `{db_name}` ready")


def create_tables():
    from sqlalchemy import create_engine
    from db_models.base import Base
    import db_models.user            # noqa
    import db_models.team            # noqa
    import db_models.session         # noqa
    import db_models.biometric       # noqa
    import db_models.breaks          # noqa
    import db_models.calendar_cache  # noqa
    import db_models.llm_cache       # noqa

    engine = create_engine(DATABASE_URL)
    Base.metadata.create_all(bind=engine)
    engine.dispose()
    print("  ✓ All tables created (or already exist)")


def seed_demo_team():
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from db_models.team import Team

    engine = create_engine(DATABASE_URL)
    SessionLocal = sessionmaker(bind=engine)
    db = SessionLocal()

    try:
        existing = db.query(Team).filter(Team.company_code == "ERR011").first()
        if existing:
            print("  ✓ Demo team ERR011 already exists — skipping seed")
            return

        admin_key_hash = bcrypt.hashpw(b"000000", bcrypt.gensalt()).decode("utf-8")
        demo_team = Team(
            name="Error 011 Demo Corp",
            company_code="ERR011",
            admin_key=admin_key_hash,
        )
        db.add(demo_team)
        db.commit()
        print("  ✓ Demo team ERR011 seeded (admin key: 000000)")
    finally:
        db.close()
        engine.dispose()


def main():
    print("\n🚀 FLOW — Database Setup\n")

    db_name = get_db_name(DATABASE_URL)

    print(f"[1/3] Creating database `{db_name}`...")
    try:
        create_database(DATABASE_URL, db_name)
    except Exception as e:
        print(f"  ✗ Failed: {e}")
        print("  → Check your DATABASE_URL in .env and make sure MySQL is running")
        sys.exit(1)

    print("[2/3] Creating tables...")
    try:
        create_tables()
    except Exception as e:
        print(f"  ✗ Failed: {e}")
        sys.exit(1)

    print("[3/3] Seeding demo data...")
    try:
        seed_demo_team()
    except Exception as e:
        print(f"  ✗ Failed: {e}")
        sys.exit(1)

    print("\n✅ Setup complete! Run the server with:\n")
    print("   uvicorn main:app --reload\n")


if __name__ == "__main__":
    main()