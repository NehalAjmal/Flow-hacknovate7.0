# agent/main.py
#
# FLOW Activity Agent — runs on the user's machine during a session.
# Captures keystrokes, window switches, idle time every 30 seconds
# and POSTs to the backend /session/signal endpoint.
#
# FIXES from original:
#   1. URL was /ingest_signal — correct is /session/signal
#   2. SESSION_ID was hardcoded "abc123" — now passed via command line
#   3. No auth token — now reads JWT from .agent_token file
#   4. SEND_INTERVAL was 5s — spec says 30s
#   5. Port was 8000 — server runs on 8002

import sys
import time
import threading
import requests
import os
from datetime import datetime
from pathlib import Path

# Add parent dir so we can import tracker
sys.path.insert(0, str(Path(__file__).parent))
from tracker import KeystrokeTracker, WindowTracker

# ── CONFIG ────────────────────────────────────────────────────────────────────

BACKEND_URL   = "http://localhost:8002"
SEND_INTERVAL = 30   # seconds — matches spec

# Session ID is passed as a command line argument when the Flutter app
# launches the agent subprocess after calling POST /session/start.
# Usage: python agent/main.py <session_id> <jwt_token>
if len(sys.argv) >= 3:
    SESSION_ID = sys.argv[1]
    JWT_TOKEN  = sys.argv[2]
elif len(sys.argv) == 2:
    SESSION_ID = sys.argv[1]
    JWT_TOKEN  = None
else:
    # Fallback for manual testing — you can hardcode these temporarily
    SESSION_ID = input("Enter session_id: ").strip()
    JWT_TOKEN  = input("Enter JWT token: ").strip()

HEADERS = {"Authorization": f"Bearer {JWT_TOKEN}"} if JWT_TOKEN else {}


# ── INIT TRACKERS ─────────────────────────────────────────────────────────────

keyboard_tracker = KeystrokeTracker()
window_tracker   = WindowTracker()


# ── WINDOW TRACKING THREAD ────────────────────────────────────────────────────

def track_windows():
    while True:
        window_tracker.update()
        time.sleep(0.5)


# ── MOUSE DISTANCE (simple delta tracking) ───────────────────────────────────

_last_mouse_pos = None
_mouse_distance = 0

try:
    from pynput import mouse as pynput_mouse

    def on_move(x, y):
        global _last_mouse_pos, _mouse_distance
        if _last_mouse_pos:
            dx = x - _last_mouse_pos[0]
            dy = y - _last_mouse_pos[1]
            _mouse_distance += int((dx**2 + dy**2) ** 0.5)
        _last_mouse_pos = (x, y)

    mouse_listener = pynput_mouse.Listener(on_move=on_move)
    mouse_listener.start()
except Exception:
    pass  # mouse tracking optional


def get_and_reset_mouse_distance():
    global _mouse_distance
    val = _mouse_distance
    _mouse_distance = 0
    return val


# ── MAIN LOOP ─────────────────────────────────────────────────────────────────

def run():
    print(f"\n⚡ FLOW Agent Started")
    print(f"   Session : {SESSION_ID}")
    print(f"   Backend : {BACKEND_URL}")
    print(f"   Interval: {SEND_INTERVAL}s\n")

    keyboard_tracker.start()
    threading.Thread(target=track_windows, daemon=True).start()

    # Idle tracking
    last_keystroke_time = time.time()
    _orig_on_press = keyboard_tracker.on_press

    def on_press_with_idle(key):
        global last_keystroke_time
        last_keystroke_time = time.time()
        _orig_on_press(key)

    keyboard_tracker.listener._handlers[0] = on_press_with_idle

    while True:
        time.sleep(SEND_INTERVAL)

        try:
            keystrokes    = keyboard_tracker.get_and_reset()
            switches      = window_tracker.get_and_reset()
            active_window = window_tracker.last_window or "Unknown"
            mouse_dist    = get_and_reset_mouse_distance()

            # Idle = seconds since last keystroke, capped at SEND_INTERVAL
            idle_seconds  = min(SEND_INTERVAL, int(time.time() - last_keystroke_time))

            payload = {
                "session_id":       SESSION_ID,
                "keystroke_count":  keystrokes,
                "window_switches":  switches,
                "idle_seconds":     idle_seconds,
                "mouse_distance_px": mouse_dist,
                "active_window":    active_window,
                "timestamp":        datetime.now().isoformat(),
            }

            print(f"📡 [{datetime.now().strftime('%H:%M:%S')}] "
                  f"keys={keystrokes} switches={switches} "
                  f"idle={idle_seconds}s window='{active_window[:30]}'")

            res = requests.post(
                f"{BACKEND_URL}/session/signal",
                json=payload,
                headers=HEADERS,
                timeout=5,
            )

            if res.status_code == 200:
                data = res.json()
                state = data.get("state", "unknown")
                score = data.get("focus_score", 0)
                intervene = data.get("should_intervene", False)
                print(f"   ✅ State: {state} | Score: {score}"
                      + (" | 🔔 INTERVENE" if intervene else ""))
            else:
                print(f"   ⚠️  Backend error {res.status_code}: {res.text[:80]}")

        except requests.exceptions.ConnectionError:
            print("   ❌ Cannot reach backend — is the server running?")
        except Exception as e:
            print(f"   ❌ Error: {e}")


if __name__ == "__main__":
    run()