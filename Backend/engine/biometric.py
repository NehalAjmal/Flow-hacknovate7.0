import numpy as np


class BiometricEngine:
    def __init__(self):
        # baselines (can be learned later)
        self.baseline_hr = 70        # bpm
        self.baseline_hrv = 50       # ms

        self.history = []

    # ─────────────────────────────────────────────
    # MAIN COMPUTE FUNCTION
    # ─────────────────────────────────────────────

    def compute(self, hr: float = None, hrv: float = None) -> float:
        """
        Compute biometric score (0–1) from whichever components are available.
        If no data provided → return neutral score.
        """
        if hr is None and hrv is None:
            return 0.5  # neutral fallback

        components = []

        # ── HR component (higher HR = more stress)
        if hr is not None:
            hr_ratio = hr / self.baseline_hr
            components.append(max(0.0, 1.0 - (hr_ratio - 1.0)))

        # ── HRV component (higher HRV = better)
        if hrv is not None:
            hrv_ratio = hrv / self.baseline_hrv
            components.append(min(hrv_ratio, 1.0))

        biometric = sum(components) / len(components)

        biometric = float(np.clip(biometric, 0.0, 1.0))

        # ── smoothing
        self.history.append(biometric)
        if len(self.history) > 10:
            self.history.pop(0)

        smoothed = float(np.mean(self.history))

        return round(smoothed, 3)

    # ─────────────────────────────────────────────
    # OPTIONAL: UPDATE BASELINES
    # ─────────────────────────────────────────────

    def update_baseline(self, hr: float, hrv: float):
        """
        Slowly adapt baseline to user
        """
        self.baseline_hr = 0.9 * self.baseline_hr + 0.1 * hr
        self.baseline_hrv = 0.9 * self.baseline_hrv + 0.1 * hrv