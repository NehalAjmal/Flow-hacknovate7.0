# API contract notes for the backend team

The frontend is built against the team's *Product Readiness* doc, §5 (`/api/v1`). Where the doc left something unspecified, the frontend picked the shape below. **Implement these shapes, or tell the frontend owner which ones to change.** Each item lists the Dart file that parses it.

Rules the client already relies on:
- Every path is under `/api/v1`. Auth is `Authorization: Bearer <access_token>`.
- Errors: `{ "error": { "code": "...", "message": "..." } }`. FastAPI's `{ "detail": ... }` is tolerated as a fallback for now.
- Timestamps: ISO 8601 with a timezone (UTC preferred).
- Unknown fields are ignored. Missing optional fields get safe defaults. New SSE event types are ignored, not fatal.

## Error codes the UI branches on (`lib/api/api_error.dart`)

| code | HTTP | Where |
|---|---|---|
| `invalid_credentials` | 401 | login |
| `mfa_invalid` | 401 | `/auth/mfa/verify` |
| `session_expired` | 401 | any call after a refresh fails |
| `llm_consent_required` | 403 | `/session/{id}/stuck` |
| `rate_limited` | 429 | any |
| `not_found` | 404 | any |

## 1. Auth (`models/auth.dart`)

**Gap in the doc:** `/auth/mfa/verify` is listed as role *Admin*, but at that step the admin has no token yet. The client therefore does this:

- `POST /auth/login` → `{access_token, refresh_token, role, team_id, consent_missing[], mfa_required:false}`, **or** `{mfa_required:true, mfa_token, role, team_id}`.
- `POST /auth/mfa/verify` (**public**) body `{mfa_token, code}` → `{access_token, refresh_token}`.
- `POST /auth/refresh` (**public**) body `{refresh_token}` → `{access_token, refresh_token?}`. A new refresh token is stored if one is returned (rotation).
- `GET /auth/me` → `{user_id, name, email, role, team_id, email_verified, settings_version}`.
- `POST /auth/register` body `{name, email, password, account_type: solo|employee, invite_token?}` → `{user_id, role, team_id, needs_email_verification}`. Registration does **not** sign the user in; they verify their email, then log in.
- Invite links: the client opens `/register?invite=<token>`. The deep-link format is still undecided (see Open questions).

## 2. Consent, settings, pause (`models/consent.dart`, `models/settings.dart`)

- `GET /consent` → `{policy_version, scopes: {behavior|camera|calendar|llm|team_aggregate: {granted, version, timestamp}}}`. A grant made under an older `version` than `policy_version` counts as **not granted**.
- `PUT /consent/{scope}` body `{granted, policy_version}` → the updated entry `{granted, version, timestamp}`.
- `behavior` is the only required scope. Without it the app routes the user to `/consent`.
- `GET/PUT /settings` → `{delivery_mode: advisory|explained|lock, break_length_sec, quiet_hours: {start:"HH:mm", end:"HH:mm"}|null, camera_enabled, calendar_enabled, llm_enabled, snooze_options:[minutes]}`. PUT is partial and returns the **full** settings.
- **Server must enforce:** `camera_enabled`, `calendar_enabled` and `llm_enabled` cannot be true without the matching consent. The client enforces it too, but the client cannot be trusted.
- `POST /pause` body `{minutes}` or `{until_end_of_day:true}` → `{paused, until}`. `DELETE /pause` → 204.

## 3. Session (`models/session.dart`)

- `POST /session/start` body `{task_text?, demand, planned_minutes, share_task_with_llm}` → `{session_id, started_at}`. The client fills the rest from its request.
- `GET /session/active` → **404** when no session is running. Otherwise `{session_id, started_at, planned_minutes, demand, task_text, state, pending_intervention: <id>|{id}|null, paused, paused_seconds}`.
  - **Added beyond the doc:** `started_at`, `planned_minutes`, `demand`, `task_text`, `paused`, `paused_seconds`. The timer is computed from `started_at - paused_seconds`, so it survives app restarts. The old app's timer counted from app launch.
- `state` values: `steady | approaching_break | break_due | paused`.
- **Stream:** `GET /session/stream?session_id=…` as **SSE** (`text/event-stream`). Each `data:` line is JSON with a `type`:
  - `state`: the §5.11 payload plus a `state` field
  - `intervention`: `{intervention_id, delivery_mode}`
  - `break_due`: `{suggested_break_sec}`
  - `session_ended`: `{session_id}`

  If the stream errors or closes, the client polls `GET /session/status?session_id=` every 8 s and retries the stream periodically.
- `POST /session/{id}/end` → `{summary: {session_id, started_at, ended_at, focus_minutes, planned_minutes, demand, task_text, breaks_suggested, breaks_taken}, replay_ready}`.
- `GET /sessions?page=&from=&to=` → `{items:[summary…], page, has_more}`.
- `GET /session/{id}/replay` → `{events:[{minute, kind, text}], what_flow_learned:[string]}`.
- `POST /session/{id}/stuck` → `{breakdown:[], questions:[], next_step, cached}`. 403 `llm_consent_required` if the `llm` scope isn't granted.
- `POST /session/{id}/resumption` body `{break_id, seconds_to_first_edit}`.

## 4. Interventions & breaks (`models/intervention.dart`)

- `GET /intervention/{id}` → `{id, type, message, delivery_mode, suggested_break_sec, short_reason}`.
- `GET /intervention/{id}/explain?detail=short|full` → exactly the §5.11 payload. `contribution` must be `value × weight / Σweights_available`. The UI shows `contribution / combined_score` as "% of the score".
- `POST /intervention/{id}/respond` body `{response: accepted|snoozed|dismissed, snooze_minutes?}`.
- `POST /intervention/{id}/override` body `{reason: incident|deploy|pairing|other}`.
- `POST /intervention/{id}/report` body `{reason, free_text?}`. **Proposed reasons:** `wrong_time | in_meeting | too_frequent | not_needed | other`.
- `POST /breaks/start` → `{break_id}`. `POST /breaks/{id}/end` body `{actual_minutes}` → `{restoration_score?}`.
- `GET /breaks?session_id=` → `{suggested, taken, breaks:[{break_id, started_at, ended_at, intervention_id, actual_minutes, restoration_score}]}`.
- `POST /ratings` body `{session_id, kind: focus|fatigue|post_break_focus, value: 1..5, context_id?}`.
- **Server should not emit interventions while a break is active.** The mock does this.

## 5. Insights (`models/insights.dart`)

- `GET /user/dashboard` → `{today:{sessions, focus_minutes, breaks_taken}, current_state, quick_start:{demand, minutes, task_text}|null, forecast|null}`.
- `GET /user/patterns` → `{sessions_completed, sessions_needed, peak_hours, personal_period_min, break_effectiveness}`. Each learned value is wrapped as `{value, sample_size, confidence: low|medium|high}`, per doc §6.1 "honest numbers". While `sessions_needed > 0` the UI shows "still learning (n of m)".
- `GET /forecast` → `{available, sessions_needed, windows:[{start, end, kind: focus|break|meeting, note}], confidence, basis}`.
- `POST /calendar/connect` → `{auth_url}`. `GET /calendar/context` → `{connected, events:[{title, start, end}]}`.
- `POST /export/focus-dna` → `image/png` body.

### Added for the Day Score (`models/day.dart`)

- `GET /user/day?date=YYYY-MM-DD` returns:
  ```json
  {"date": "...",
   "sessions": [{"session_id", "start", "end", "demand", "state": "done|active|forecast|scheduled", "task_text"}],
   "breaks": [{"at", "mark": "taken|suggested|snoozed"}],
   "nudges": [{"at", "outcome": "taken|snoozed|dismissed|ignored|pending"}],
   "meetings": [{"start", "end", "title"}],
   "pressure": [{"t", "v"}],
   "forecast": [{"t", "v"}],
   "forecast_band": [{"t", "lo", "hi"}],
   "forecast_confidence": "low|medium|high",
   "usual_band": [{"t", "lo", "hi"}],
   "usual_days": 12,
   "totals": {"focus_minutes", "usual_focus_minutes", "breaks_taken", "breaks_suggested", "breaks_skipped"}}
  ```
- **Pressure is normalised so `1.0` = the nudge line** for that user at that time. The client draws the nudge line at 1.0 and never needs the raw threshold.
- `pressure` covers the past only (≤ now); `forecast` starts at now.
- Samples every 5 min are enough; the client interpolates linearly.
- For the active session, `end` is its *planned* end.
- `usual_band` is p25–p75 of the user's own past days at the same time of day. Send `usual_days: 0` until there are enough days, and the band is hidden.
- Session widths, gaps and heights are drawn from these times and `demand`, so they must be real values, never padded.
- `GET /user/month?month=YYYY-MM` returns `{days: [{date, focus_minutes}]}`, which feeds the month terrain. Days with no data are omitted.

## 6. Privacy (`models/privacy.dart`)

- `GET /me/data-summary` → `{categories:[{name, description, item_count, retention_days}]}`.
- `POST /me/data-export` → `{id, status: pending|ready|failed}`. `GET /me/data-export/{id}` → the same plus `download_url`.
- `DELETE /me` → 204. The client then logs out.

## 7. Team & admin (`models/team.dart`)

**Every** team/admin endpoint uses one wrapper: `{group_size, suppressed, reason, metrics}`. If `suppressed` is missing, the client treats the response as **suppressed**. If `suppressed` is true, the client discards `metrics` even when the server sends it.

| Endpoint | `metrics` shape |
|---|---|
| `/team/summary` | `{average_focus, trend:[{date, value}]}` |
| `/admin/summary` | `{active_count, avg_focus_trend:[…], session_volume}` |
| `/admin/trend` | `{days_7:[…], days_30:[…]}` |
| `/admin/insights` | `{peak_hours:[int], typical_recovery_min}` |
| `/admin/strain` | `{level: low\|moderate\|high, note}` |
| `/admin/meeting-window` | `{start, end}` |

- `/admin/privacy-status` → `{group_size, suppressed, can_see:[string], cannot_see:[string]}`.
- `POST /admin/invites` body `{valid_for_hours}` → `{id, created_at, expires_at, used, url}`. `url` is returned **only on create**. `GET /admin/invites` → `{items:[…]}` without `url`.
- `GET /admin/audit-log` → `{items:[{action, at, actor}]}`.

## 8. Meta (`models/meta.dart`)

- `GET /flags` → `{flags:{name: bool|string}}`. A failure here never breaks the app (empty flags are used). The `lock_mode` flag hides the lock option.
- `POST /feedback` body `{kind: feedback|bug|feature, message, diagnostics?}`.
- `GET /changelog` (public) → `{items:[{version, date, items:[string]}]}`.

## 9. Local agent protocol (team B) — `api/real/real_agent.dart`

**Proposal**, since the doc does not define it: JSON over WebSocket at `ws://127.0.0.1:8765`, localhost only.

- App → agent: `{"type":"get_status"}`, `{"type":"pair","code":"123456"}`, `{"type":"set_camera","on":true}`, `{"type":"watch_resumption","break_id":"…"}`
- Agent → app:
  - `{"type":"status","paired":true,"behavior_on":true,"camera_on":false,"app_category":"editor","version":"1.0"}`
  - `{"type":"signals","keys_per_min":42,"switches_per_5min":3,"idle_sec":4,"eye_score":null}`
  - `{"type":"resumption","break_id":"…","seconds_to_first_edit":38}`
- `app_category` ∈ `editor | terminal | browser | chat | docs | meeting | other`. **No window titles over this socket either.**
- Pairing must stop other local processes from talking to the agent. A plain localhost socket is reachable by any local program, including any web page the user opens. The agent should require the pairing secret on every connection and check the `Origin` header.

## Open questions

1. **SSE auth on web builds:** browsers' `EventSource` can't send an `Authorization` header. The desktop build is fine. If a web build matters, use a short-lived stream token in the query string.
2. **Calendar OAuth redirect back into a desktop app:** use a loopback redirect (`http://127.0.0.1:<port>`) or a custom URL scheme. This needs `url_launcher` and a listener, and it isn't designed yet.
3. **Invite link format:** `https://…/register?invite=` (web) vs a `flow://` scheme registered by the desktop installer.
4. **`/session/status`** uses `?session_id=` while every other session route uses `/session/{id}/…`. Pick one.
5. The doc says **Claude** for the stuck assistant; the current backend uses Gemini. The frontend doesn't care, but the consent copy says "an AI model". Name the provider in the privacy text once decided.

## Schedules (routines): assumed, frontend ready

The frontend calls these; the backend needs to add them (`ApiArea.schedules`, mock by default).

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/user/schedules` | — | `{ "schedules": [Schedule] }` |
| POST | `/user/schedules` | Schedule (no id) | Schedule (with id) |
| PUT | `/user/schedules/{id}` | Schedule | Schedule |
| DELETE | `/user/schedules/{id}` | — | 204 |

`Schedule` (times are the user's local time, weekdays 1 = Mon … 7 = Sun):

```json
{ "id": "sch_1", "name": "Weekly review", "start": "17:40", "end": "18:20",
  "weekdays": [1,2,3,4,5], "demand": "light", "enabled": true }
```

- `GET /user/day` should include each occurrence for that date as a session with `"state": "scheduled"`, `"id"` = the schedule id, and `"task_text"` = its name.
- Starting a scheduled session is client-side: at the start time (or up to 2 minutes late) the app shows "starts in 10 s · Start now · Skip", then calls the normal `POST /session/start` with the schedule's name, demand and length. No extra endpoint is needed.

## Calendar connect (browser hand-off)

1. `POST /calendar/connect` returns the Google consent URL.
2. The app opens it in the system browser, then polls `GET /calendar/context` every 3 s for up to 2 min until `connected: true`.
3. The OAuth redirect must therefore land on the **backend** (which stores the token), not on the app.
