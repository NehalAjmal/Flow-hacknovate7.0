import google.generativeai as genai
from config import settings

genai.configure(api_key=settings.gemini_api_key)

def get_gemini_model():
    return genai.GenerativeModel('settings.gemini_model')