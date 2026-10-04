# agent/main.py
#
# FLOW Activity Agent — runs on the user's machine during a session.
# Captures keystrokes, window switches, idle time every 30 seconds
# and POSTs to the backend /session/signal endpoint.

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

# Pointing exactly to your local server for the demo
BACKEND_URL   = "http://127.0.0.1:8002"
SEND_INTERVAL = 30   # seconds — matches spec

# Safe Session ID and JWT handling
SESSION_ID = "demo_session_001"
JWT_TOKEN = None

if len(sys.argv) >= 2:
    SESSION_ID = sys.argv[1]
    # Safely read from file if it exists, otherwise check command line
    token_file = Path(".agent_token")
    if token_file.exists():
        JWT_TOKEN = token_file.read_text().strip()
    elif len(sys.argv) >= 3:
        JWT_TOKEN = sys.argv[2]
else:
    # Quick fallback for easy local testing
    SESSION_ID = input("Enter session_id (or press Enter to use default 'demo_123'): ").strip() or "demo_123"

HEADERS = {"Authorization": f"Bearer {JWT_TOKEN}"} if JWT_TOKEN else {}


# ── INIT TRACKERS ─────────────────────────────────────────────────────────────

keyboard_tracker = KeystrokeTracker()
window_tracker   = WindowTracker()


# ── WINDOW TRACKING THREAD ────────────────────────────────────────────────────

def track_windows():
    while True:
        window_tracker.update()
        time.sleep(0.5)


# ── MOUSE DISTANCE (Thread Safe) ──────────────────────────────────────────────

_last_mouse_pos = None
_mouse_distance = 0
_mouse_lock = threading.Lock() # Added lock to prevent race conditions

try:
    from pynput import mouse as pynput_mouse

    def on_move(x, y):
        global _last_mouse_pos, _mouse_distance
        if _last_mouse_pos:
            dx = x - _last_mouse_pos[0]
            dy = y - _last_mouse_pos[1]
            with _mouse_lock:
                _mouse_distance += int((dx**2 + dy**2) ** 0.5)
        _last_mouse_pos = (x, y)

    mouse_listener = pynput_mouse.Listener(on_move=on_move)
    mouse_listener.start()
except Exception:
    print("⚠️ Mouse tracking unavailable (pynput missing). Continuing without it.")
    pass 


def get_and_reset_mouse_distance():
    global _mouse_distance
    with _mouse_lock:
        val = _mouse_distance
        _mouse_distance = 0
    return val


# ── MAIN LOOP ─────────────────────────────────────────────────────────────────

def run():
    print(f"\n⚡ FLOW Agent Started (Local Mode)")
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

    try:
        # Note: Depending on pynput version, this internal array might differ
        keyboard_tracker.listener._handlers[0] = on_press_with_idle
    except AttributeError:
        pass # Failsafe if pynput internals change

    try:
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
                print("   ❌ Cannot reach backend — is the local server running on port 8002?")
            except Exception as e:
                print(f"   ❌ Error: {e}")

    except KeyboardInterrupt:
        print("\n🛑 FLOW Agent shutting down gracefully... Good luck with the Demo!")
        sys.exit(0)

if __name__ == "__main__":
    run()