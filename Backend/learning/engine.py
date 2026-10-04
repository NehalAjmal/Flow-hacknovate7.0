import numpy as np
from collections import defaultdict
from datetime import datetime


# The activity agent sends a tick every 30s — used when timestamps are missing.
TICK_MINUTES = 0.5


def _parse_ts(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except (ValueError, TypeError):
        return None


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
            timestamps.append(_parse_ts(point.get("timestamp")))
            fatigue_vals.append(point.get("output", {}).get("fatigue", 0.0))

            inp = point.get("input", {})
            keystrokes.append(inp.get("keystroke_count", 0))
            switches.append(inp.get("window_switches", 0))

        # ── SESSION LENGTH (real minutes, not entry counts) ──
        self.session_lengths.append(self._session_duration_minutes(timestamps))

        # ── HOURLY FATIGUE PROFILE ───────────────
        for t, f in zip(timestamps, fatigue_vals):
            hour = t.hour if t else datetime.utcnow().hour
            self.hourly_fatigue[hour].append(f)

        # ── BASELINES ────────────────────────────
        avg_kpm = float(np.mean(keystrokes)) if keystrokes else 0
        avg_switch = float(np.mean(switches)) if switches else 0

        self.keystroke_history.append(avg_kpm)
        self.switch_history.append(avg_switch)

        # 🔥 COMPUTE TROUGH FOR THIS SESSION
        trough = self._compute_trough_minute(session_data, timestamps)
        self.trough_history.append(trough)

        return self._export_model()

    # ─────────────────────────────────────────────
    # SESSION DURATION
    # ─────────────────────────────────────────────

    def _session_duration_minutes(self, parsed_timestamps) -> float:
        valid = [t for t in parsed_timestamps if t is not None]
        if len(valid) >= 2:
            span = (max(valid) - min(valid)).total_seconds() / 60.0
            if span > 0:
                # Add one tick so the last entry is counted
                return round(span + TICK_MINUTES, 1)
        return round(len(parsed_timestamps) * TICK_MINUTES, 1)

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

        # ultradian cycle — median session length in MINUTES (defaults to 90 until learned)
        if len(self.session_lengths) >= 3:
            cycle = max(25, int(np.median(self.session_lengths)))
        else:
            cycle = 90

        # baselines
        baseline_kpm = float(np.mean(self.keystroke_history)) if self.keystroke_history else 0
        baseline_switch = float(np.mean(self.switch_history)) if self.switch_history else 0

        # 🔥 FINAL TROUGH (learned over sessions)
        trough_minute = int(np.median(self.trough_history)) if self.trough_history else 45

        return {
            "schema_version": "learning_v2",
            "parameters": {
                "fatigue_focus_profile": fatigue_profile,
                "ultradian_cycle_minutes": cycle,
                "baseline_keystrokes_per_min": round(baseline_kpm, 2),
                "baseline_window_switches": round(baseline_switch, 2),
                "trough_minute": trough_minute
            }
        }

    # ─────────────────────────────────────────────
    # TROUGH CALCULATION
    # ─────────────────────────────────────────────

    def _compute_trough_minute(self, log, parsed_timestamps=None):

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

        # Convert the entry index to minutes using real tick spacing when possible
        if parsed_timestamps:
            valid = [t for t in parsed_timestamps if t is not None]
            if len(valid) >= 2 and trough_idx < len(parsed_timestamps):
                ticks = parsed_timestamps[: trough_idx + 1]
                valid_ticks = [t for t in ticks if t is not None]
                if len(valid_ticks) >= 2:
                    return int(round((valid_ticks[-1] - valid_ticks[0]).total_seconds() / 60.0))

        return int(round(trough_idx * TICK_MINUTES))

    # ─────────────────────────────────────────────
    # EMPTY MODEL
    # ─────────────────────────────────────────────

    def _empty_model(self):
        return {
            "schema_version": "empty",
            "parameters": {}
        }