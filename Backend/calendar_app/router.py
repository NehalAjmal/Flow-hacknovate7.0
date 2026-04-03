from fastapi import APIRouter
from .service import compute_warning_level, build_recommendation
from .schemas import CalendarContext

router = APIRouter()

@router.get("/context", response_model=CalendarContext)
async def get_calendar_context(
    # In the real implementation, the user's Google OAuth token would come
    # from the database (stored when they connected Google Calendar at signup).
    # For now, we accept it as a header so the frontend can pass it directly.
    # Your friend doing the auth/SQL part will store these tokens in MySQL.
    google_token: str = None
):
    """
    Fetch the user's Google Calendar events for the next 3 hours.
    Called on session start screen load to warn about upcoming meetings.
    Returns structured calendar context including warning level and recommendation.
    """
 
    # If no Google token is provided, return a safe "no data" response.
    # This handles users who haven't connected Google Calendar yet.
    if not google_token:
        return CalendarContext(
            has_upcoming_events=False,
            warning_level="none",
            next_event=None,
            events=[],
            recommendation="Connect Google Calendar in settings to get meeting-aware session recommendations."
        )
 
    try:
        # Build Google Calendar API credentials from the stored token.
        # In production, the token dict comes from your MySQL users table
        # where your friend stored it during the OAuth2 flow.
        token_data = json.loads(google_token)
        credentials = Credentials(
            token=token_data.get("access_token"),
            refresh_token=token_data.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=token_data.get("client_id"),
            client_secret=token_data.get("client_secret"),
        )
 
        # Build the Google Calendar API client.
        # This is a synchronous call but it's just building a local object,
        # not making a network request — no await needed here.
        service = build("calendar", "v3", credentials=credentials)
 
        # Define our time window: now → now + 3 hours
        now = datetime.now(timezone.utc)
        three_hours_later = now + timedelta(hours=3)
 
        # Fetch events from the primary calendar within our window.
        # This IS a network call. We run it in a thread pool using
        # asyncio.to_thread because the Google client library is synchronous
        # (it doesn't support await natively). This keeps FastAPI non-blocking.
        import asyncio
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
 
        # Parse each Google Calendar event into our clean CalendarEvent model
        parsed_events = []
        for event in raw_events:
            # Google Calendar events can be all-day (date only) or timed (dateTime).
            # We only care about timed events — all-day events don't block focus time.
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
 
        # Determine the overall warning level based on the soonest event
        if parsed_events:
            next_event = parsed_events[0]  # already sorted by start time
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
 
    except Exception as e:
        # If calendar fetch fails for any reason (expired token, network issue),
        # return a graceful degraded response rather than crashing.
        # A failed calendar check should never prevent a user from starting a session.
        return CalendarContext(
            has_upcoming_events=False,
            warning_level="none",
            next_event=None,
            events=[],
            recommendation=f"Calendar temporarily unavailable. Proceeding without meeting context."
        )
 