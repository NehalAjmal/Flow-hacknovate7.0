import cv2
import numpy as np
import time
import threading
import os
import json
from datetime import datetime

import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

from ml_models.rppg import PulseEstimator, forehead_roi_mean


class FatigueService:
    def __init__(self):
        self.running = False
        self.thread = None
        self.detector = None

        self.cap = None  #  camera handle

        self.state = {
            "fatigue_score": 0.0,
            "fatigue_state": "normal",
            "ear": 0.0,
            "heart_rate_bpm": None,
            "hr_confidence": 0.0
        }

        # rPPG heart-rate estimation from the same camera frames
        self.pulse = PulseEstimator()

        # state snapshot written for cross-process consumers (biometric router fallback)
        self._state_path = os.path.join(os.path.dirname(__file__), "fatigue.json")
        self._last_state_write = 0.0

        # eye landmarks
        self.LEFT_EYE = [33, 160, 158, 133, 153, 144]
        self.RIGHT_EYE = [362, 385, 387, 263, 373, 380]

        # calibration
        self.baseline_ear = None
        self.ear_history = []
        self.calibration_frames = 50

        self.closed_frames = 0
        self.fatigue_score = 0.0

    # ─────────────────────────────
    # INIT DETECTOR
    # ─────────────────────────────
    def _init_detector(self):
        if self.detector is not None:
            return

        MODEL_PATH = os.path.join(
            os.path.dirname(__file__),
            "face_landmarker.task"
        )

        if not os.path.exists(MODEL_PATH):
            raise FileNotFoundError(
                f" Model not found at {MODEL_PATH}\n"
                f"Download and place in ml_models/"
            )

        base_options = python.BaseOptions(
            model_asset_path=MODEL_PATH
        )

        options = vision.FaceLandmarkerOptions(
            base_options=base_options,
            output_face_blendshapes=False,
            output_facial_transformation_matrixes=False,
            num_faces=1
        )

        self.detector = vision.FaceLandmarker.create_from_options(options)
        print(" MediaPipe initialized")

    # ─────────────────────────────
    # START
    # ─────────────────────────────
    def start(self):
        if self.running:
            return

        print(" Starting fatigue service...")

        self._init_detector()

        # reset state
        self.baseline_ear = None
        self.ear_history = []
        self.closed_frames = 0
        self.fatigue_score = 0.0
        self.pulse = PulseEstimator()

        self.running = True

        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

        print(" Fatigue service started")

    # ─────────────────────────────
    # STOP ( IMPORTANT FIX)
    # ─────────────────────────────
    def stop(self):
        if not self.running:
            return

        print(" Stopping fatigue service...")

        self.running = False

        if self.thread:
            self.thread.join(timeout=2)

        if self.cap:
            self.cap.release()
            self.cap = None

        # reset live state + drop the snapshot so consumers never see stale data
        self.state = {
            "fatigue_score": 0.0, "fatigue_state": "normal", "ear": 0.0,
            "heart_rate_bpm": None, "hr_confidence": 0.0,
        }
        try:
            os.remove(self._state_path)
        except OSError:
            pass

        print(" Fatigue service stopped")

    # ─────────────────────────────
    # GET STATE
    # ─────────────────────────────
    def get_state(self):
        return self.state

    # ─────────────────────────────
    # MAIN LOOP
    # ─────────────────────────────
    def _run(self):
        self.cap = cv2.VideoCapture(0)

        if not self.cap.isOpened():
            print(" Camera failed to open")
            return

        print(" Camera opened")

        while self.running:
            ret, frame = self.cap.read()
            if not ret:
                continue

            frame = cv2.flip(frame, 1)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            mp_image = mp.Image(
                image_format=mp.ImageFormat.SRGB,
                data=rgb
            )

            result = self.detector.detect(mp_image)

            if result.face_landmarks:
                face = result.face_landmarks[0]
                h, w, _ = frame.shape

                left_eye = self._get_points(face, self.LEFT_EYE, w, h)
                right_eye = self._get_points(face, self.RIGHT_EYE, w, h)

                ear = (self._compute_ear(left_eye) +
                       self._compute_ear(right_eye)) / 2.0

                self.state["ear"] = ear

                # rPPG: forehead green-channel sample for this frame
                xs = [p[0] for p in self._get_points(face, [1, 33, 263, 152, 10], w, h)]
                ys = [p[1] for p in self._get_points(face, [1, 33, 263, 152, 10], w, h)]
                face_box = (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))
                green = forehead_roi_mean(frame, face_box)
                if green == green:  # not NaN
                    self.pulse.add_sample(green)
                self.pulse.estimate()
                if self.pulse.bpm is not None:
                    self.state["heart_rate_bpm"] = round(self.pulse.bpm, 1)
                    self.state["hr_confidence"] = round(self.pulse.confidence, 2)

                # ── CALIBRATION ──
                if self.baseline_ear is None:
                    self.ear_history.append(ear)
                    if len(self.ear_history) > self.calibration_frames:
                        self.baseline_ear = np.mean(self.ear_history)
                        print(" Calibration complete")
                    continue

                ear_ratio = ear / self.baseline_ear

                # ── FATIGUE LOGIC ──
                if ear_ratio < 0.75:
                    self.closed_frames += 1
                else:
                    if self.closed_frames > 15:
                        self.fatigue_score += 0.1
                    self.closed_frames = 0

                if self.closed_frames > 20:
                    self.fatigue_score += 0.02

                # decay
                self.fatigue_score *= 0.98
                self.fatigue_score = min(self.fatigue_score, 1.0)

                # state
                if self.fatigue_score < 0.3:
                    fatigue_state = "normal"
                elif self.fatigue_score < 0.6:
                    fatigue_state = "fatigued"
                else:
                    fatigue_state = "critical"

                self.state.update({
                    "fatigue_score": round(self.fatigue_score, 3),
                    "fatigue_state": fatigue_state
                })

            # persist a snapshot ~1x/sec for cross-process consumers
            now = time.time()
            if now - self._last_state_write > 1.0:
                self._last_state_write = now
                try:
                    with open(self._state_path, "w") as f:
                        json.dump({
                            "ear": self.state.get("ear", 0.0),
                            "fatigue_score": self.state.get("fatigue_score", 0.0),
                            "fatigue_state": self.state.get("fatigue_state", "normal"),
                            "heart_rate_bpm": self.state.get("heart_rate_bpm"),
                            "hr_confidence": self.state.get("hr_confidence", 0.0),
                            "updated_at": datetime.now().isoformat(),
                        }, f)
                except Exception:
                    pass  # snapshot is best-effort only

            time.sleep(0.03)

        # cleanup
        if self.cap:
            self.cap.release()
            self.cap = None

        print(" Camera released")

    # ─────────────────────────────
    # HELPERS
    # ─────────────────────────────
    def _compute_ear(self, eye):
        A = np.linalg.norm(eye[1] - eye[5])
        B = np.linalg.norm(eye[2] - eye[4])
        C = np.linalg.norm(eye[0] - eye[3])
        return (A + B) / (2.0 * C)

    def _get_points(self, face, indices, w, h):
        return np.array([
            [int(face[i].x * w), int(face[i].y * h)]
            for i in indices
        ])


#  SINGLETON INSTANCE
fatigue_service = FatigueService()