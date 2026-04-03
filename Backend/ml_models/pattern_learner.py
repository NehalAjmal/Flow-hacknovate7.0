import numpy as np
from collections import defaultdict
from datetime import datetime
import pymysql
import os
from urllib.parse import urlparse
from dotenv import load_dotenv
import json
import random

# -----------------------------
# ENV + DB
# -----------------------------
load_dotenv()

def get_db():
    url = urlparse(os.getenv("DATABASE_URL"))

    return pymysql.connect(
        host=url.hostname,
        user=url.username,
        password=url.password,
        database=url.path.lstrip("/"),
        port=url.port or 3306,
        cursorclass=pymysql.cursors.DictCursor
    )


def get_sessions(conn, user_id):
    with conn.cursor() as c:
        c.execute("SELECT * FROM sessions WHERE user_id=%s", (user_id,))
        return c.fetchall()


def get_biometrics(conn, user_id, session_id):
    with conn.cursor() as c:
        c.execute(
            "SELECT * FROM biometric_readings WHERE user_id=%s AND session_id=%s",
            (user_id, session_id)
        )
        return c.fetchall()


def save_model(conn, user_id, model):
    with conn.cursor() as c:
        c.execute(
            "UPDATE users SET pattern_model=%s WHERE id=%s",
            (json.dumps(model), user_id)
        )
    conn.commit()


# -----------------------------
# DEMO DATA GENERATOR
# -----------------------------
def generate_demo_data(conn, user_id="user_1"):
    from datetime import datetime, timedelta
    import random

    def fatigue_curve(hour):
        """
        Returns base fatigue (0–1) based on time of day
        """
        if 6 <= hour <= 10:      # morning peak
            return random.uniform(0.2, 0.4)
        elif 11 <= hour <= 15:   # afternoon slump
            return random.uniform(0.6, 0.85)
        elif 16 <= hour <= 19:   # recovery
            return random.uniform(0.4, 0.6)
        else:                    # night fatigue
            return random.uniform(0.7, 0.95)

    with conn.cursor() as c:

        # ensure user exists
        c.execute("""
            INSERT IGNORE INTO users (id, full_name, email, password_hash)
            VALUES (%s, %s, %s, %s)
        """, (user_id, "Demo User", "demo@test.com", "hash"))

        base_time = datetime.now()

        for i in range(60):  # more sessions = better learning
            session_id = f"s{i}"

            # spread sessions across last 2 days
            offset_hours = random.randint(0, 36)
            session_time = base_time - timedelta(hours=offset_hours)

            hour = session_time.hour
            fatigue = fatigue_curve(hour)

            # convert fatigue → biometrics (inverse relationships)
            hr = 65 + fatigue * 25      # higher fatigue → higher HR
            hrv = 60 - fatigue * 30     # higher fatigue → lower HRV
            ear = 0.35 - fatigue * 0.15 # higher fatigue → lower EAR

            # realistic focus score
            focus_score = int(5 - fatigue * 4)
            focus_score = max(1, min(5, focus_score))

            c.execute("""
                INSERT IGNORE INTO sessions (
                    id, user_id, declared_difficulty,
                    actual_duration_min, start_time,
                    focus_score, self_rated_quality,
                    interventions_total, interventions_accepted
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                session_id,
                user_id,
                random.choice(["easy", "medium", "hard"]),
                random.randint(30, 60),
                session_time,
                focus_score,
                focus_score,
                random.randint(0, 5),
                random.randint(0, 5)
            ))

            # biometrics (5 readings per session)
            for _ in range(5):
                c.execute("""
                    INSERT INTO biometric_readings (
                        id, user_id, session_id,
                        heart_rate_bpm, hrv_sdnn, ear_value
                    )
                    VALUES (UUID(), %s, %s, %s, %s, %s)
                """, (
                    user_id,
                    session_id,
                    random.uniform(hr - 3, hr + 3),
                    random.uniform(hrv - 5, hrv + 5),
                    random.uniform(ear - 0.02, ear + 0.02)
                ))

    conn.commit()
    print("Demo data generated")


# -----------------------------
# CORE LOGIC
# -----------------------------
def clamp(x):
    return max(0.0, min(1.0, x))


def compute_fatigue(biometrics):
    if not biometrics:
        return None

    hr_vals = [b["heart_rate_bpm"] for b in biometrics if b.get("heart_rate_bpm")]
    hrv_vals = [b["hrv_sdnn"] for b in biometrics if b.get("hrv_sdnn")]
    ear_vals = [b["ear_value"] for b in biometrics if b.get("ear_value")]

    if not hr_vals or not hrv_vals:
        return None

    hr = np.mean(hr_vals)
    hrv = np.mean(hrv_vals)
    ear = np.mean(ear_vals) if ear_vals else 0.3

    fatigue = 0.4*((hr-60)/40) + 0.4*(1-hrv/100) + 0.2*(1-ear)
    return clamp(fatigue)


def map_difficulty(d):
    return {"easy": 1, "medium": 3, "hard": 5}.get(str(d).lower(), 3)


class PatternLearner:
    def __init__(self):
        self.hourly = defaultdict(list)
        self.difficulty_bias = defaultdict(list)
        self.interventions = {"accepted": 0, "total": 0}
        self.hr = []
        self.hrv = []
        self.durations = []

    def update(self, session, biometrics):
        start_time = session.get("start_time")
        if not start_time:
            return

        hour = start_time.hour

        fatigue = compute_fatigue(biometrics)
        if fatigue is not None:
            self.hourly[hour].append(fatigue)

        if session.get("actual_duration_min"):
            self.durations.append(session["actual_duration_min"])

        difficulty = map_difficulty(session.get("declared_difficulty"))
        focus = session.get("focus_score", difficulty)
        self.difficulty_bias[difficulty].append(focus - difficulty)

        self.interventions["total"] += session.get("interventions_total", 0)
        self.interventions["accepted"] += session.get("interventions_accepted", 0)

        for b in biometrics:
            if b.get("heart_rate_bpm"):
                self.hr.append(b["heart_rate_bpm"])
            if b.get("hrv_sdnn"):
                self.hrv.append(b["hrv_sdnn"])

    def export(self):
        avg = {h: np.mean(v) for h, v in self.hourly.items() if len(v) >= 3}

        if not avg:
            focus_profile = {}
        else:
            mn, mx = min(avg.values()), max(avg.values())
            focus_profile = {
                str(h): round(1-(v-mn)/(mx-mn+1e-8), 3)
                for h, v in avg.items()
            }

        return {
            "schema_version": "F8_v2_fatigue_only",
            "last_updated": datetime.utcnow().isoformat(),
            "parameters": {
                "fatigue_focus_profile": focus_profile,
                "ultradian_period": float(np.median(self.durations)) if len(self.durations) >= 5 else 50,
                "difficulty_bias": {
                    str(k): float(np.mean(v))
                    for k, v in self.difficulty_bias.items() if len(v) >= 5
                },
                "intervention_threshold": 0.6,
                "resting_hr_baseline": float(np.mean(self.hr)) if self.hr else 70,
                "hrv_baseline": float(np.mean(self.hrv)) if self.hrv else 50
            }
        }


# -----------------------------
# MAIN
# -----------------------------
def run(user_id):
    conn = get_db()
    learner = PatternLearner()

    print(" Resetting old data...")
    with conn.cursor() as c:
        c.execute("DELETE FROM biometric_readings WHERE user_id=%s", (user_id,))
        c.execute("DELETE FROM sessions WHERE user_id=%s", (user_id,))
    conn.commit()

    print(" Generating demo data...")
    generate_demo_data(conn, user_id)

    sessions = get_sessions(conn, user_id)

    for s in sessions:
        biometrics = get_biometrics(conn, user_id, s["id"])
        learner.update(s, biometrics)

    model = learner.export()
    save_model(conn, user_id, model)

    print("\n✅ MODEL GENERATED:\n")
    print(json.dumps(model, indent=4))


if __name__ == "__main__":
    run("user_1")