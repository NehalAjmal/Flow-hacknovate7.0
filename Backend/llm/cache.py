# llm/cache.py
# FIX: Python 3.9 needs List[str] not list[str]

import json
import random
from typing import List
from pathlib import Path

_INTERVENTIONS_PATH = Path(__file__).parent.parent / "interventions.json"

with open(_INTERVENTIONS_PATH, "r") as f:
    _CACHE = json.load(f)


def get_intervention(state: str) -> dict:
    if state not in _CACHE:
        return {
            "title": "Check in with yourself",
            "message": "FLOW noticed a change in your patterns. Take a moment to assess.",
            "action_label": None,
            "duration_seconds": None
        }
    entry = _CACHE[state]
    return {
        "title": entry["title"],
        "message": random.choice(entry["messages"]),
        "action_label": entry["action_label"],
        "duration_seconds": entry["duration_seconds"]
    }


def get_all_states() -> List[str]:
    return list(_CACHE.keys())