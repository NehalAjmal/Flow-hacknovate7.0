"""
Camera permission checker for FLOW.

Run this from YOUR terminal (Terminal.app / iTerm) — not from an IDE task runner:

    source venv/bin/activate
    python Backend/check_camera.py

The first run makes macOS show the camera permission dialog attributed to
your terminal app. Click OK, then this script confirms frames are flowing.
Once granted, the backend's fatigue service (same terminal) gets camera access too.
"""

import sys
import time


def main() -> int:
    try:
        import cv2
    except Exception as e:
        print(f"OpenCV is not available: {e}")
        print("Reinstall with:  pip install --force-reinstall opencv-contrib-python")
        return 1

    print("Requesting camera access...")
    print("-> A macOS dialog should appear now. Click 'OK' to allow.")
    print("-> If nothing appears, check System Settings > Privacy & Security > Camera")
    print("   and enable your terminal app there.\n")

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
        print("try:  tccutil reset Camera   (then run this script again)")
        return 1

    ok = False
    for _ in range(10):
        ret, frame = cap.read()
        if ret:
            print(f"RESULT: camera works - frame captured {frame.shape}")
            ok = True
            break
        time.sleep(0.3)
    cap.release()

    if ok:
        print("\nAll good. Start a FLOW session and the eye-fatigue pipeline will use the camera.")
        return 0
    print("RESULT: authorized but no frames yet - try again in a few seconds.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
