import numpy as np


class DeviationEngine:
    def __init__(self):
        # optional rolling baseline
        self.history = []

    # ─────────────────────────────────────────────
    # MAIN FUNCTION
    # ─────────────────────────────────────────────

    def compute(self, keystrokes: int, switches: int, idle_seconds: int) -> float:
        """
        Compute deviation score (0 = focused, 1 = distracted)
        """

        # ── NORMALIZATION ─────────────────────────

        # keystrokes: higher = good → invert
        keystroke_score = 1.0 - min(keystrokes / 40.0, 1.0)

        # switches: higher = bad
        switch_score = min(switches / 10.0, 1.0)

        # idle: higher = bad
        idle_score = min(idle_seconds / 120.0, 1.0)

        # ── WEIGHTED COMBINATION ─────────────────

        deviation = (
            0.4 * keystroke_score +
            0.3 * switch_score +
            0.3 * idle_score
        )

        deviation = float(np.clip(deviation, 0.0, 1.0))

        # ── OPTIONAL: smooth over time ───────────

        self.history.append(deviation)
        if len(self.history) > 10:
            self.history.pop(0)

        smoothed = float(np.mean(self.history))

        return round(smoothed, 3)