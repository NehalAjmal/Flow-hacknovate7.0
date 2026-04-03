import time
import math


class UltradianEngine:
    def __init__(self, cycle_minutes: int = 90):
        """
        cycle_minutes: typical ultradian cycle (default 90 min)
        """
        self.cycle_seconds = cycle_minutes * 60
        self.start_time = None

    # ─────────────────────────────────────────────
    # START SESSION
    # ─────────────────────────────────────────────

    def start(self):
        self.start_time = time.time()

    # ─────────────────────────────────────────────
    # MAIN COMPUTE FUNCTION
    # ─────────────────────────────────────────────

    def compute(self) -> float:
        """
        Returns ultradian score (0–1)
        """

        if self.start_time is None:
            return 1.0  # default peak

        elapsed = time.time() - self.start_time

        # normalize within cycle
        phase = (elapsed % self.cycle_seconds) / self.cycle_seconds

        # cosine curve (smooth drop + rise)
        score = 0.5 * (1 + math.cos(2 * math.pi * phase))

        # invert so:
        # start = high, middle = low, reset = high
        score = 1 - score

        return round(score, 3)

    # ─────────────────────────────────────────────
    # OPTIONAL: GET RAW INFO
    # ─────────────────────────────────────────────

    def get_elapsed_minutes(self) -> float:
        if self.start_time is None:
            return 0.0
        return (time.time() - self.start_time) / 60.0