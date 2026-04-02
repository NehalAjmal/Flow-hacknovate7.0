import cv2
import mediapipe as mp
import numpy as np
from collections import deque
import time
import threading
import sys
import json

# ---------------- LOAD CONFIG ---------------- #
with open("config.json") as f:
    config = json.load(f)

# ---------------- BEEP ---------------- #
def beep():
    if sys.platform == "win32":
        import winsound
        winsound.Beep(1000, 300)
    else:
        print('\a')

last_beep_time = 0

# ---------------- INIT ---------------- #
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh()

LEFT_EYE = [33, 160, 158, 133, 153, 144]
RIGHT_EYE = [362, 385, 387, 263, 373, 380]

MOUTH = [13, 14]
NOSE = 1
CHIN = 152
FOREHEAD = 10

def compute_EAR(eye):
    A = np.linalg.norm(eye[1] - eye[5])
    B = np.linalg.norm(eye[2] - eye[4])
    C = np.linalg.norm(eye[0] - eye[3])
    return (A + B) / (2.0 * C)

def get_points(face, indices, w, h):
    return np.array([
        [int(face.landmark[i].x * w), int(face.landmark[i].y * h)]
        for i in indices
    ])

# ---------------- CAMERA ---------------- #
cap = cv2.VideoCapture(0)

# ---------------- CALIBRATION ---------------- #
baseline_ear = None
ear_history = []
calibration_frames = 100

# ---------------- STATE ---------------- #
closed_frames = 0
fatigue_score = 0.0
ear_smooth = 1.0

microsleep_log = deque()
head_down_frames = 0
critical_timer = 0

event_timer = {}

def show_event(name, duration=2):
    event_timer[name] = time.time() + duration

# -------- LOGGING -------- #
log_data = []
last_save_time = time.time()

# ---------------- LOOP ---------------- #
while True:
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = face_mesh.process(rgb)

    event = None
    yawning = False
    head_down = False
    microsleep_count = 0
    microsleep_level = "none"
    fatigue_state = "normal"

    if results.multi_face_landmarks:
        face = results.multi_face_landmarks[0]
        h, w, _ = frame.shape

        # -------- EYES -------- #
        left_eye = get_points(face, LEFT_EYE, w, h)
        right_eye = get_points(face, RIGHT_EYE, w, h)
        ear = (compute_EAR(left_eye) + compute_EAR(right_eye)) / 2.0

        # -------- CALIBRATION -------- #
        if baseline_ear is None:
            ear_history.append(ear)
            if len(ear_history) > calibration_frames:
                baseline_ear = np.mean(ear_history)
            cv2.putText(frame, "Calibrating...", (30, 50),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0,255,255), 2)
            cv2.imshow("Fatigue Engine", frame)
            continue

        ear_ratio = ear / baseline_ear

        # -------- TEMPORAL LOGIC -------- #
        if ear_ratio < config["ear_threshold"]:
            closed_frames += 1
        else:
            if config["blink_min"] < closed_frames < config["blink_max"]:
                event = "BLINK"
            elif config["fatigue_min"] <= closed_frames < config["microsleep_frames"]:
                event = "FATIGUE"
            elif closed_frames >= config["microsleep_frames"]:
                event = "MICROSLEEP"
                microsleep_log.append(time.time())
                show_event("MICROSLEEP!", 3)
            closed_frames = 0

        # -------- YAWNING -------- #
        mouth_top = face.landmark[MOUTH[0]]
        mouth_bottom = face.landmark[MOUTH[1]]
        yawning = abs(mouth_top.y - mouth_bottom.y) > 0.04
        if yawning:
            show_event("YAWNING", 2)

        # -------- HEAD DOWN -------- #
        forehead_y = face.landmark[FOREHEAD].y
        chin_y = face.landmark[CHIN].y
        nose_y = face.landmark[NOSE].y

        face_height = abs(forehead_y - chin_y)
        if face_height > 0.1:
            relative = (chin_y - nose_y) / face_height
            if relative < 0.25:
                head_down_frames += 1
            else:
                head_down_frames = 0

            head_down = head_down_frames > config["head_down_frames"]
            if head_down:
                show_event("HEAD DOWN", 2)

        # -------- MICROSLEEP WINDOW -------- #
        now = time.time()
        microsleep_log = deque([t for t in microsleep_log if now - t < config["microsleep_window_sec"]])
        microsleep_count = len(microsleep_log)

        if microsleep_count >= config["critical_microsleeps"]:
            microsleep_level = "critical"
        elif microsleep_count >= config["high_microsleeps"]:
            microsleep_level = "high"
        elif microsleep_count >= config["low_microsleeps"]:
            microsleep_level = "low"

        # -------- FATIGUE SCORE -------- #
        fatigue_score *= 0.95

        if event == "FATIGUE":
            fatigue_score += 0.05
        if event == "MICROSLEEP":
            fatigue_score += 0.2
        if yawning:
            fatigue_score += 0.02
        if head_down:
            fatigue_score += 0.03

        if microsleep_level == "low":
            fatigue_score += 0.05
        elif microsleep_level == "high":
            fatigue_score += 0.1

        if microsleep_level == "critical" and critical_timer == 0:
            fatigue_score = 1.0
            critical_timer = 60
            show_event("STOP WORK!", 4)

        if critical_timer > 0:
            critical_timer -= 1

        fatigue_score = min(fatigue_score, 1.0)

        # -------- FATIGUE STATE -------- #
        if fatigue_score > 0.7:
            fatigue_state = "fatigued"
            show_event("TAKE A BREAK", 3)

        if microsleep_level == "high":
            fatigue_state = "danger"
            show_event("WARNING!", 3)

        if microsleep_level == "critical":
            fatigue_state = "critical"

        # -------- SOUND -------- #
        if fatigue_state in ["danger", "critical"]:
            if time.time() - last_beep_time > 2:
                threading.Thread(target=beep).start()
                last_beep_time = time.time()

        # -------- LOG -------- #
        output = {
            "timestamp": time.time(),
            "fatigue_score": round(fatigue_score, 3),
            "fatigue_state": fatigue_state,
            "microsleep_level": microsleep_level,
            "microsleeps_last_60s": microsleep_count,
            "yawning": yawning,
            "head_down": head_down,
            "event": event
        }

        log_data.append(output)

        if time.time() - last_save_time > 5:
            with open("fatigue_log.json", "w") as f:
                json.dump(log_data, f, indent=4)
            last_save_time = time.time()

    # -------- ALWAYS SHOW SCORE -------- #
    cv2.putText(frame, f"Fatigue: {fatigue_score:.2f}", (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0,255,255), 2)

    # -------- EVENTS -------- #
    current_time = time.time()
    y = 100

    for name, expiry in list(event_timer.items()):
        if current_time < expiry:
            color = (0,255,255)
            if "STOP" in name or "WARNING" in name or "MICROSLEEP" in name:
                color = (0,0,255)

            cv2.putText(frame, name, (50, y),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)
            y += 60
        else:
            del event_timer[name]

    cv2.imshow("Fatigue Engine", frame)

    if cv2.waitKey(1) & 0xFF in [27, ord('q')]:
        break

cap.release()
cv2.destroyAllWindows()