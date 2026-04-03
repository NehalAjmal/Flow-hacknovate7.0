# llm/client.py
# Uses the NEW google.genai package (not the deprecated google.generativeai).
# sessions/router.py calls client.aio.models.generate_content(...)
# so the client must be a google.genai.Client instance.

from google import genai
from config import settings

# Single shared client — initialized once at startup
_client = genai.Client(api_key=settings.gemini_api_key)


def get_gemini_client() -> genai.Client:
    """Returns the shared google.genai Client instance."""
    return _client


def get_model_name() -> str:
    """Returns the configured Gemini model name from .env."""
    return settings.gemini_model