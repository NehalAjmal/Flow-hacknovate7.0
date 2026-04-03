import time
from collections import deque

from engine.ear import normalize_ear, is_eye_closed


class FatigueEngine:
    def __init__(self):
        # baseline calibration
        self.baseline_ear = None
        self.calibration_buffer = []
        self.calibration_frames = 50

        # fatigue tracking
        self.fatigue_score = 0.0
        self.closed_frames = 0

        # microsleep tracking
        self.microsleep_events = deque(maxlen=10)

        # timing
        self.last_update = time.time()

    # ─────────────────────────────────────────────
    # MAIN UPDATE FUNCTION
    # ─────────────────────────────────────────────

    def update(self, ear: float) -> dict:
        """
        Update fatigue state using EAR input

        Returns:
            {
                "fatigue_score": float,
                "fatigue_state": str
            }
        """

        now = time.time()
        dt = now - self.last_update
        self.last_update = now

        # ── CALIBRATION PHASE ─────────────────────
        if self.baseline_ear is None:
            self.calibration_buffer.append(ear)

            if len(self.calibration_buffer) >= self.calibration_frames:
                self.baseline_ear = sum(self.calibration_buffer) / len(self.calibration_buffer)

            return {
                "fatigue_score": 0.0,
                "fatigue_state": "calibrating"
            }

        # ── NORMALIZATION ─────────────────────────
        ear_ratio = normalize_ear(ear, self.baseline_ear)

        # ── EYE CLOSURE DETECTION ─────────────────
        if is_eye_closed(ear_ratio):
            self.closed_frames += 1
        else:
            # blink / closure event
            if self.closed_frames > 15:
                self.fatigue_score += 0.1
                self.microsleep_events.append(now)

            self.closed_frames = 0

        # ── FATIGUE ACCUMULATION ─────────────────
        if self.closed_frames > 20:
            self.fatigue_score += 0.02

        # ── DECAY (recovery) ─────────────────────
        self.fatigue_score *= 0.98

        # clamp
        self.fatigue_score = min(max(self.fatigue_score, 0.0), 1.0)

        # ── STATE CLASSIFICATION ─────────────────
        fatigue_state = self._get_state()

        return {
            "fatigue_score": round(self.fatigue_score, 3),
            "fatigue_state": fatigue_state
        }

    # ─────────────────────────────────────────────
    # STATE LOGIC
    # ─────────────────────────────────────────────

    def _get_state(self) -> str:
        if self.fatigue_score < 0.3:
            return "normal"
        elif self.fatigue_score < 0.6:
            return "fatigued"
        else:
            return "critical"

    # ─────────────────────────────────────────────
    # OPTIONAL: expose extra metrics
    # ─────────────────────────────────────────────

    def get_metrics(self) -> dict:
        return {
            "baseline_ear": self.baseline_ear,
            "recent_microsleeps": len(self.microsleep_events),
            "fatigue_score": self.fatigue_score
        }