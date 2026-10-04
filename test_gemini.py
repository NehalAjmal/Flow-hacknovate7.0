"""Gemini smoke test — run from the repo root:  python test_gemini.py"""
import sys
from pathlib import Path

# Backend modules do `from config import settings`, so Backend/ must be on sys.path.
sys.path.insert(0, str(Path(__file__).parent / "Backend"))

from llm.client import get_gemini_client, get_model_name
from llm.prompts import stuck_prompt


def test_stuck():
    prompt = stuck_prompt(
        task_declared="Debugging JWT auth",
        difficulty="hard",
        stuck_duration_minutes=25,
        active_window="VS Code",
        session_duration_minutes=45,
    )
    client = get_gemini_client()
    model = get_model_name()
    print("Model:", model)
    res = client.models.generate_content(model=model, contents=prompt)
    print("Response:", res.text)


if __name__ == "__main__":
    test_stuck()
