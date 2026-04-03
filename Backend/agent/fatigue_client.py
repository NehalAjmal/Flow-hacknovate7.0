from ml_models.fatigue_model import fatigue_service

class FatigueClient:
    def get(self):
        state = fatigue_service.get_state()
        return {
            "fatigue": state.get("fatigue_score", 0.0)
        }