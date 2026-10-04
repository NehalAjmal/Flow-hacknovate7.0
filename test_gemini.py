import asyncio
from Backend.llm.client import get_gemini_client, get_model_name
from Backend.llm.prompts import stuck_prompt

async def test_stuck():
    prompt = stuck_prompt(
        task_declared="Debugging JWT auth",
        difficulty="hard",
        stuck_duration_minutes=25,
        active_window="VS Code",
        session_duration_minutes=45
    )
    client = get_gemini_client()
    model = get_model_name()
    print("Model:", model)
    res = client.models.generate_content(model=model, contents=prompt)
    print("Response:", res.text)

asyncio.run(test_stuck())
