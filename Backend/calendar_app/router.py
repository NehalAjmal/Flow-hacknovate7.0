# calendar_app/router.py
# BUG FIX: The original file was missing all its imports.
# json, Credentials, build, datetime, timedelta, timezone, asyncio
# were all used but never imported — would crash immediately on startup.

import json
import asyncio
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from .service import compute_warning_level, build_recommendation
from .schemas import CalendarContext, CalendarEvent

router = APIRouter()


@router.get("/context", response_model=CalendarContext)
async def get_calendar_context(google_token: str = None):
    """
    Fetch the user's Google Calendar events for the next 3 hours.
    Called on session start screen load to warn about upcoming meetings.
    Returns structured calendar context including warning level and recommendation.
    """

    if not google_token:
        return CalendarContext(
            has_upcoming_events=False,
            warning_level="none",
            next_event=None,
            events=[],
            recommendation="Connect Google Calendar in settings to get meeting-aware session recommendations."
        )

    try:
        token_data = json.loads(google_token)
        credentials = Credentials(
            token=token_data.get("access_token"),
            refresh_token=token_data.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=token_data.get("client_id"),
            client_secret=token_data.get("client_secret"),
        )

        service = build("calendar", "v3", credentials=credentials)

        now = datetime.now(timezone.utc)
        three_hours_later = now + timedelta(hours=3)

        # Google's client library is synchronous — asyncio.to_thread lets us
        # run it without blocking the FastAPI event loop
        events_result = await asyncio.to_thread(
            service.events().list(
                calendarId="primary",
                timeMin=now.isoformat(),
                timeMax=three_hours_later.isoformat(),
                maxResults=10,
                singleEvents=True,
                orderBy="startTime"
            ).execute
        )

        raw_events = events_result.get("items", [])
        parsed_events = []

        for event in raw_events:
            start_str = event["start"].get("dateTime")
            end_str = event["end"].get("dateTime")
            if not start_str or not end_str:
                continue  # skip all-day events

            start_dt = datetime.fromisoformat(start_str)
            end_dt = datetime.fromisoformat(end_str)
            minutes_until = int((start_dt - now).total_seconds() / 60)
            duration_minutes = int((end_dt - start_dt).total_seconds() / 60)

            parsed_events.append(CalendarEvent(
                title=event.get("summary", "Untitled Event"),
                start_time=start_str,
                minutes_until=max(0, minutes_until),
                duration_minutes=duration_minutes
            ))

        if parsed_events:
            next_event = parsed_events[0]
            warning_level = compute_warning_level(next_event.minutes_until)
            recommendation = build_recommendation(warning_level, next_event.minutes_until)
        else:
            next_event = None
            warning_level = "none"
            recommendation = "No meetings in the next 3 hours. Any session length is safe."

        return CalendarContext(
            has_upcoming_events=len(parsed_events) > 0,
            warning_level=warning_level,
            next_event=next_event,
            events=parsed_events,
            recommendation=recommendation
        )

    except Exception:
        return CalendarContext(
            has_upcoming_events=False,
            warning_level="none",
            next_event=None,
            events=[],
            recommendation="Calendar temporarily unavailable. Proceeding without meeting context."
        )