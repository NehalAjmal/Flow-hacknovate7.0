import numpy as np
from collections import defaultdict
from datetime import datetime


class PatternLearner:
    def __init__(self):
        self.hourly_fatigue = defaultdict(list)
        self.keystroke_history = []
        self.switch_history = []
        self.session_lengths = []
        self.trough_history = []

    # ─────────────────────────────────────────────
    # MAIN UPDATE FUNCTION
    # ─────────────────────────────────────────────

    def update(self, session_data: list) -> dict:

        if not session_data:
            return self._empty_model()

        timestamps = []
        fatigue_vals = []
        keystrokes = []
        switches = []

        for point in session_data:
            timestamps.append(point.get("timestamp"))
            fatigue_vals.append(point.get("output", {}).get("fatigue", 0.0))

            inp = point.get("input", {})
            keystrokes.append(inp.get("keystroke_count", 0))   # ✅ FIXED
            switches.append(inp.get("window_switches", 0))     # ✅ FIXED

        # ── SESSION LENGTH ───────────────────────
        self.session_lengths.append(len(session_data))

        # ── HOURLY FATIGUE PROFILE ───────────────
        for t, f in zip(timestamps, fatigue_vals):
            try:
                hour = datetime.fromisoformat(t).hour
            except:
                hour = datetime.utcnow().hour

            self.hourly_fatigue[hour].append(f)

        # ── BASELINES ────────────────────────────
        avg_kpm = float(np.mean(keystrokes)) if keystrokes else 0
        avg_switch = float(np.mean(switches)) if switches else 0

        self.keystroke_history.append(avg_kpm)
        self.switch_history.append(avg_switch)

        # 🔥 COMPUTE TROUGH FOR THIS SESSION
        through = self._compute_trough_minute(session_data)
        self.trough_history.append(through)

        return self._export_model()

    # ─────────────────────────────────────────────
    # EXPORT MODEL
    # ─────────────────────────────────────────────

    def _export_model(self) -> dict:

        # fatigue profile
        avg = {
            h: np.mean(v)
            for h, v in self.hourly_fatigue.items()
            if len(v) >= 3
        }

        if avg:
            mn, mx = min(avg.values()), max(avg.values())
            fatigue_profile = {
                str(h): round(1 - (v - mn) / (mx - mn + 1e-8), 3)
                for h, v in avg.items()
            }
        else:
            fatigue_profile = {}

        # ultradian cycle
        if len(self.session_lengths) >= 3:
            cycle = int(np.median(self.session_lengths))
        else:
            cycle = 50

        # baselines
        baseline_kpm = float(np.mean(self.keystroke_history)) if self.keystroke_history else 0
        baseline_switch = float(np.mean(self.switch_history)) if self.switch_history else 0

        # 🔥 FINAL TROUGH (learned over sessions)
        through_minute = int(np.median(self.trough_history)) if self.trough_history else 45

        return {
            "schema_version": "learning_v2",
            "parameters": {
                "fatigue_focus_profile": fatigue_profile,
                "ultradian_cycle_minutes": cycle,
                "baseline_keystrokes_per_min": round(baseline_kpm, 2),
                "baseline_window_switches": round(baseline_switch, 2),
                "through_minute": through_minute   # ✅ ADDED
            }
        }

    # ─────────────────────────────────────────────
    # TROUGH CALCULATION
    # ─────────────────────────────────────────────

    def _compute_trough_minute(self, log):

        if not log:
            return 45

        scores = []

        for i, point in enumerate(log):
            inp = point.get("input", {})

            score = (
                inp.get("keystroke_count", 0)
                - inp.get("window_switches", 0) * 2
                - inp.get("idle_seconds", 0) * 0.5
            )

            scores.append((i, score))

        trough_idx = min(scores, key=lambda x: x[1])[0]

        return trough_idx * 5  # assuming 5s interval → convert later if needed

    # ─────────────────────────────────────────────
    # EMPTY MODEL
    # ─────────────────────────────────────────────

    def _empty_model(self):
        return {
            "schema_version": "empty",
            "parameters": {}
        }