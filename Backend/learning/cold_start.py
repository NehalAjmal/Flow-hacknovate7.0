from datetime import datetime


class ColdStartEngine:
    def __init__(self):
        pass

    # ─────────────────────────────────────────────
    # MAIN FUNCTION
    # ─────────────────────────────────────────────

    def get_defaults(self, age: int = None, sex: str = None) -> dict:
        """
        Generate default parameters for new users
        """

        fatigue_profile = self._default_fatigue_profile(age)

        return {
            "schema_version": "cold_start_v1",
            "generated_at": datetime.utcnow().isoformat(),
            "parameters": {
                "fatigue_focus_profile": fatigue_profile,
                "ultradian_cycle_minutes": self._default_cycle(age),
                "baseline_keystrokes_per_min": self._default_kpm(age),
                "baseline_window_switches": 3.0
            }
        }

    # ─────────────────────────────────────────────
    # DEFAULT FATIGUE PROFILE
    # ─────────────────────────────────────────────

    def _default_fatigue_profile(self, age):
        """
        Returns hour → focus capability (0–1)
        """

        profile = {}

        for hour in range(24):
            if 6 <= hour <= 11:
                val = 0.8  # morning peak
            elif 12 <= hour <= 15:
                val = 0.6  # post-lunch dip
            elif 16 <= hour <= 20:
                val = 0.7  # evening recovery
            else:
                val = 0.4  # night / low energy

            # slight adjustment for age
            if age:
                if age > 40:
                    val *= 0.9
                elif age < 20:
                    val *= 1.05

            profile[str(hour)] = round(min(val, 1.0), 3)

        return profile

    # ─────────────────────────────────────────────
    # DEFAULT ULTRADIAN CYCLE
    # ─────────────────────────────────────────────

    def _default_cycle(self, age):
        if age:
            if age > 40:
                return 75
            elif age < 20:
                return 100
        return 90

    # ─────────────────────────────────────────────
    # DEFAULT KEYSTROKE BASELINE
    # ─────────────────────────────────────────────

    def _default_kpm(self, age):
        if age:
            if age < 20:
                return 30
            elif age > 40:
                return 20
        return 25