# llm/client.py
# FIX: google.generativeai is deprecated and dead.
# The new package is google.genai — different import, slightly different API.

import google.generativeai as genai
from config import settings

# Initialize the client once at module load
genai.configure(api_key=settings.gemini_api_key)


def get_gemini_client():
    """Returns the shared Gemini client."""
    return genai


def get_model_name():
    """Returns the configured model name."""
    return settings.gemini_model


def get_gemini_model():
    """Returns the configured Gemini model."""
    return genai.GenerativeModel(get_model_name())