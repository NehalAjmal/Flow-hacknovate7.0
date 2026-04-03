class DecisionEngine:

    def compute(self, fatigue, deviation, ultradian, biometric, trough_pressure=0.0):
        """
        Combine signals → final state + score
        """

        # normalize inputs (assume 0–1 scale)
        fatigue = min(max(fatigue, 0), 1)
        deviation = min(max(deviation, 0), 1)
        ultradian = min(max(ultradian, 0), 1)
        biometric = min(max(biometric, 0), 1)

        # ── BASE SCORE ─────────────────────────
        base_score = (
            0.4 * (1 - deviation) +
            0.3 * (1 - fatigue) +
            0.2 * ultradian +
            0.1 * biometric
        ) * 100

        # 🔥 APPLY TROUGH PENALTY
        base_score -= trough_pressure * 20

        base_score = max(0, min(100, base_score))

        # ── STATE CLASSIFICATION ───────────────
        if base_score > 75:
            state = "deep_work"
        elif base_score > 50:
            state = "neutral"
        elif base_score > 30:
            state = "distracted"
        else:
            state = "fatigue"

        return {
            "state": state,
            "focus_score": base_score / 100
        }


# 🔥 HELPER FUNCTION
def compute_trough_pressure(current_minute, trough_minute):
    if trough_minute <= 0:
        return 0.0

    distance = trough_minute - current_minute

    if distance > 20:
        return 0.0
    elif distance > 10:
        return 0.3
    elif distance > 5:
        return 0.6
    elif distance > 0:
        return 0.9
    else:
        return 1.0