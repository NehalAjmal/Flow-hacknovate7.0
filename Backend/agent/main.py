import time
import threading
import requests
from datetime import datetime

from tracker import KeystrokeTracker, WindowTracker


# 🔥 CONFIG
SESSION_ID = "abc123"   # ← replace this
BACKEND_URL = "http://localhost:8000/ingest_signal"

SEND_INTERVAL = 5  # seconds


# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────

keyboard_tracker = KeystrokeTracker()
window_tracker = WindowTracker()


# ─────────────────────────────────────────────
# WINDOW TRACKING THREAD (IMPORTANT FIX)
# ─────────────────────────────────────────────

def track_windows():
    while True:
        window_tracker.update()
        time.sleep(0.5)  # check 2 times per second


# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────

def run():
    print("🚀 Real-time Agent Started\n")

    # start trackers
    keyboard_tracker.start()

    # start window tracking thread
    threading.Thread(target=track_windows, daemon=True).start()

    while True:
        time.sleep(SEND_INTERVAL)

        try:
            # ── COLLECT DATA ─────────────────────

            keystrokes = keyboard_tracker.get_and_reset()
            switches = window_tracker.get_and_reset()

            active_window = window_tracker.last_window or "Unknown"

            # idle detection (simple)
            idle_seconds = 0 if keystrokes > 0 else SEND_INTERVAL

            payload = {
                "session_id": SESSION_ID,
                "keystroke_count": keystrokes,
                "window_switches": switches,
                "idle_seconds": idle_seconds,
                "mouse_distance_px": 0,
                "active_window": active_window,
                "timestamp": datetime.now().isoformat()
            }

            print("📡 Sending:", payload)

            # ── SEND ────────────────────────────

            res = requests.post(BACKEND_URL, json=payload)

            if res.status_code == 200:
                data = res.json()
                print(f"✅ State: {data.get('state')} | Score: {data.get('focus_score')}")
            else:
                print("⚠️ Backend error:", res.status_code)

        except Exception as e:
            print("❌ Error:", e)


if __name__ == "__main__":
    run()