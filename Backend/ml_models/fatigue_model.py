# import cv2
# import mediapipe as mp
# import numpy as np
# import time
# import threading


# class FatigueService:
#     def __init__(self):
#         self.running = False
#         self.thread = None

#         # shared state
#         self.state = {
#             "fatigue_score": 0.0,
#             "fatigue_state": "normal",
#             "ear": 0.0
#         }

#         # mediapipe
#         self.mp_face_mesh = mp.solutions.face_mesh
#         self.face_mesh = self.mp_face_mesh.FaceMesh()

#         # eye landmarks
#         self.LEFT_EYE = [33, 160, 158, 133, 153, 144]
#         self.RIGHT_EYE = [362, 385, 387, 263, 373, 380]

#         # calibration
#         self.baseline_ear = None
#         self.ear_history = []
#         self.calibration_frames = 50

#         # fatigue logic
#         self.closed_frames = 0
#         self.fatigue_score = 0.0

#     # ─────────────────────────────────────────────
#     # PUBLIC METHODS
#     # ─────────────────────────────────────────────

#     def start(self):
#         if self.running:
#             return

#         self.running = True
#         self.thread = threading.Thread(target=self._run, daemon=True)
#         self.thread.start()
#         print("✅ Fatigue service started")

#     def get_state(self):
#         return self.state

#     # ─────────────────────────────────────────────
#     # CORE LOOP
#     # ─────────────────────────────────────────────

#     def _run(self):
#         cap = cv2.VideoCapture(0)

#         while self.running:
#             ret, frame = cap.read()
#             if not ret:
#                 continue

#             frame = cv2.flip(frame, 1)
#             rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
#             results = self.face_mesh.process(rgb)

#             if results.multi_face_landmarks:
#                 face = results.multi_face_landmarks[0]
#                 h, w, _ = frame.shape

#                 left_eye = self._get_points(face, self.LEFT_EYE, w, h)
#                 right_eye = self._get_points(face, self.RIGHT_EYE, w, h)

#                 ear = (self._compute_ear(left_eye) +
#                        self._compute_ear(right_eye)) / 2.0

#                 self.state["ear"] = ear

#                 # ── CALIBRATION ─────────────────
#                 if self.baseline_ear is None:
#                     self.ear_history.append(ear)
#                     if len(self.ear_history) > self.calibration_frames:
#                         self.baseline_ear = np.mean(self.ear_history)
#                     continue

#                 ear_ratio = ear / self.baseline_ear

#                 # ── EYE CLOSURE ─────────────────
#                 if ear_ratio < 0.75:
#                     self.closed_frames += 1
#                 else:
#                     if self.closed_frames > 15:
#                         self.fatigue_score += 0.1
#                     self.closed_frames = 0

#                 if self.closed_frames > 20:
#                     self.fatigue_score += 0.02

#                 # decay
#                 self.fatigue_score *= 0.98
#                 self.fatigue_score = min(self.fatigue_score, 1.0)

#                 # ── STATE ───────────────────────
#                 if self.fatigue_score < 0.3:
#                     fatigue_state = "normal"
#                 elif self.fatigue_score < 0.6:
#                     fatigue_state = "fatigued"
#                 else:
#                     fatigue_state = "critical"

#                 # update shared state
#                 self.state.update({
#                     "fatigue_score": round(self.fatigue_score, 3),
#                     "fatigue_state": fatigue_state
#                 })

#             time.sleep(0.03)  # ~30 FPS

#         cap.release()

#     # ─────────────────────────────────────────────
#     # HELPERS
#     # ─────────────────────────────────────────────

#     def _compute_ear(self, eye):
#         A = np.linalg.norm(eye[1] - eye[5])
#         B = np.linalg.norm(eye[2] - eye[4])
#         C = np.linalg.norm(eye[0] - eye[3])
#         return (A + B) / (2.0 * C)

#     def _get_points(self, face, indices, w, h):
#         return np.array([
#             [int(face.landmark[i].x * w), int(face.landmark[i].y * h)]
#             for i in indices
#         ])


# # 🔥 SINGLETON INSTANCE
# fatigue_service = FatigueService()