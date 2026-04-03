import numpy as np
from datetime import datetime, timedelta


class ForecastEngine:
    def __init__(self):
        pass

    # ─────────────────────────────────────────────
    # MAIN FUNCTION
    # ─────────────────────────────────────────────

    def forecast(self, patterns: dict) -> dict:
        """
        Generate 3-hour capacity forecast
        """

        now = datetime.utcnow()

        fatigue_profile = patterns.get("parameters", {}).get("fatigue_focus_profile", {})
        cycle = patterns.get("parameters", {}).get("ultradian_cycle_minutes", 90)

        results = []

        for minute in range(0, 181, 30):  # every 30 min
            t = now + timedelta(minutes=minute)

            # ── TIME-BASED FATIGUE ─────────────────
            hour = str(t.hour)
            fatigue_factor = fatigue_profile.get(hour, 0.5)

            # ── ULTRADIAN EFFECT ──────────────────
            phase = (minute % cycle) / cycle
            ultradian = 0.5 * (1 + np.cos(2 * np.pi * phase))
            ultradian = 1 - ultradian  # invert

            # ── COMBINE ───────────────────────────
            capacity = (
                0.6 * fatigue_factor +
                0.4 * ultradian
            )

            capacity = float(np.clip(capacity, 0.0, 1.0))

            results.append({
                "minute": minute,
                "capacity": round(capacity, 3)
            })

        return {
            "generated_at": now.isoformat(),
            "forecast": results
        }