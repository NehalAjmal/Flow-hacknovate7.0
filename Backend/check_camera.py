"""
Permission checker for FLOW (camera + keystrokes).

Run this from YOUR terminal (Terminal.app / iTerm) — not from an IDE task runner:

    source venv/bin/activate
    python Backend/check_camera.py

1. Camera: the first run makes macOS show the camera dialog attributed to your
   terminal app. Click OK — frames confirm the eye-fatigue pipeline will work.
2. Keystrokes: the script then listens for 8 seconds — type something!
   A nonzero count means Input Monitoring / Accessibility is granted.
"""

import sys
import time


def check_camera() -> bool:
    try:
        import cv2
    except Exception as e:
        print(f"OpenCV is not available: {e}")
        print("Reinstall with:  pip install --force-reinstall opencv-contrib-python")
        return False

    print("── CAMERA ─────────────────────────────────────────────")
    print("Requesting camera access...")
    print("-> A macOS dialog should appear. Click 'OK' to allow.\n")

    cap = cv2.VideoCapture(0)

    granted = False
    for _ in range(60):  # wait up to 60s for the user to answer the dialog
        if cap.isOpened():
            granted = True
            break
        time.sleep(1)

    if not granted:
        print("RESULT: camera still blocked after 60s.")
        print("If your terminal is not listed in Settings > Privacy & Security > Camera,")
        print("try:  tccutil reset Camera   (then run this script again)\n")
        return False

    ok = False
    for _ in range(10):
        ret, frame = cap.read()
        if ret:
            print(f"RESULT: camera works - frame captured {frame.shape}")
            ok = True
            break
        time.sleep(0.3)
    cap.release()

    if not ok:
        print("RESULT: authorized but no frames yet - try again in a few seconds.")
    return ok


def check_keystrokes() -> bool:
    print("\n── KEYSTROKES ─────────────────────────────────────────")
    print("Listening for 8 seconds - TYPE SOMETHING NOW...")
    try:
        from pynput import keyboard

        count = 0

        def on_press(_key):
            nonlocal count
            count += 1

        listener = keyboard.Listener(on_press=on_press)
        listener.start()
        time.sleep(8)
        listener.stop()

        if count > 0:
            print(f"RESULT: keystroke capture works - {count} keys detected")
            return True
        print("RESULT: 0 keys detected - Input Monitoring / Accessibility")
        print("is not granted for this terminal app yet.")
        print("System Settings > Privacy & Security > Input Monitoring -> add your terminal.")
        return False
    except Exception as e:
        print(f"RESULT: keystroke listener failed: {e}")
        return False


if __name__ == "__main__":
    camera_ok = check_camera()
    keys_ok = check_keystrokes()
    print("\n═══════════════════════════════════════════════════════")
    print(f"camera: {'OK' if camera_ok else 'BLOCKED'}   keystrokes: {'OK' if keys_ok else 'BLOCKED'}")
    if camera_ok and keys_ok:
        print("\nAll permissions granted. Start FLOW with ./run_all.sh and enjoy real tracking.")
    sys.exit(0 if (camera_ok and keys_ok) else 1)

