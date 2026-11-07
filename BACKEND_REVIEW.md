# FLOW Backend Review

Reviewed at commit HEAD of `main` (shallow clone). Scope: everything under `Backend/`. Severity: 🔴 broken or exploitable, 🟠 breaks in real use, 🟡 misleading or low impact.

---

## 🔴 1. Signal log never persists past the first tick

**Where:** `Backend/sessions/service.py`, `ingest_signal`

```python
log = session.signal_log or []
log.append({...})
session.signal_log = log[-SIGNAL_LOG_CAP:]
db.commit()
```

`append` mutates the list SQLAlchemy is already tracking. On flush, the old value and the new value compare equal, so no `UPDATE` is sent. The first tick only persists because `[]` is falsy, so `or []` creates a new list.

**Verified** with SQLAlchemy 2.0.48 and the same pattern: after 3 ticks the DB held only the first entry.

**Consequences**
- `session.focus_score` at `/end` is the average of one tick.
- `PatternLearner` learns from one data point. Trough minute and cycle length are noise.
- Session-end `events` is empty or a single entry.

**Fix (pick one)**
- `signal_log = mapped_column(MutableList.as_mutable(JSON))`
- `session.signal_log = [*(session.signal_log or []), entry][-SIGNAL_LOG_CAP:]`
- `flag_modified(session, "signal_log")` after the append

**Better:** a `signal_ticks` table. Rewriting a growing JSON blob on every tick costs O(n²) in total writes.

---

## 🔴 2. `PatternLearner` is one global object shared by all users

**Where:** `Backend/sessions/service.py` (`pattern_learner = PatternLearner()` at module level), `Backend/learning/engine.py`

- `hourly_fatigue`, `keystroke_history`, `session_lengths` and `trough_history` collect data from every user.
- `end_session` writes that mixed result into the current user's `pattern_model`.
- All of it is lost on restart.

"Learns your personal rhythm" is false as implemented.

**Fix:** make `update()` a pure function over the user's own stored sessions (or their previous `pattern_model` plus the new session). No module-level state.

---

## 🔴 3. Ultradian curve is inverted

**Where:** `Backend/engine/ultradian.py`, `compute`

```python
score = 0.5 * (1 + math.cos(2 * math.pi * phase))
score = 1 - score
```

At phase 0 this gives 0, and at the cycle midpoint it gives 1. The comment says "start = high, middle = low". Every session starts with the ultradian term at 0, and the score peaks at the point where the dip is predicted.

**Fix:** drop the `1 - score` line.

---

## 🔴 4. `deep_work` is nearly unreachable; fatigue is double-counted

**Where:** `Backend/engine/decision.py`, `Backend/sessions/service.py` (`ingest_signal`)

- `deep_work` requires a score above 75. With ultradian at 0 (issue 3) the maximum is 80, which needs zero deviation and zero fatigue.
- Deviation is smoothed over 10 ticks, so one bad tick drags the score down for 5 minutes.
- When there's no heart-rate data, `biometric = 1 - fatigue`, so fatigue enters the score twice (0.3 + 0.1 weight).
- The team doc (§4.2) wants weights normalized over the *available* signals and per-signal contributions returned. The current engine does neither.

---

## 🔴 5. Security

| Issue | Where | Impact |
|---|---|---|
| Self-registration as **admin** with only a company code | `auth/router.py` `_resolve_team`, `auth/schemas.py` | Every employee knows the code, so anyone can become admin. |
| `/session/signal` has no auth | `sessions/router.py` `receive_signal` | Anyone with a session ID can inject ticks. CORS is `*`. |
| `/session/stuck` has no auth | `sessions/router.py` `get_stuck_suggestions` | Unlimited Gemini calls on your key. |
| No ownership check on `/session/status`, `/respond`, `/end` | `sessions/router.py` | Any logged-in user can read or end anyone's session (IDOR). |
| Google OAuth token + `client_secret` sent as a GET query parameter | `calendar_app/router.py` | Credentials land in access and proxy logs. |
| Agent JWT is never provided | `service.start_session` passes only `session.id`; `.agent_token` is never written | The agent works only because `/signal` is unauthenticated. |
| No rate limiting on `/auth/login` | `auth/router.py` | Unlimited password guessing. |
| `allow_origins=["*"]` | `main.py` | Combined with bearer tokens in `SharedPreferences`, any page can call the API if it gets a token. |

---

## 🔴 6. JWT expires after 30 minutes with no refresh

**Where:** `config.py` (`access_token_expire_minutes = 30`); there is no `/auth/refresh`

Focus sessions run 50–90 minutes. Mid-session, `/status` and `/end` return 401. If `/end` never runs, the agent subprocess keeps running, the camera stays on and the session never closes.

---

## 🟠 7. Architecture: server process owns the keylogger and camera

**Where:** `sessions/service.py` (`subprocess.Popen` for the agent, `fatigue_service.start()`), `ml_models/fatigue_model.py` (process-wide singleton)

This only works when the backend runs on the user's own machine, for one user. Teams, admins and company codes assume a shared server. On a shared server:
- The agent and camera run on the server, not on the employee's machine.
- Two concurrent sessions share one camera.
- The first user to end their session calls `fatigue_service.stop()` and stops the other user's tracking.

Also:
- `_live_sessions` is an in-memory dict, so there can be only one worker.
- After a restart, a rehydrated session has `agent_process=None`, so the running agent is orphaned (it can never be terminated by `/end`).

The team doc (§5.10) already moves to a paired local agent. That is the right fix.

---

## 🟠 8. Install and run breakage

- `googleapiclient` is imported at module load (`calendar_app/router.py`) but `google-api-python-client` is not in `requirements.txt`. A clean install crashes on startup.
- `google-auth` is only installed indirectly through `google-genai`. Pin it.
- README says port 8000 and a venv in `Backend/`. `run_all.sh` and the agent use port 8002 and a venv at the repo root.
- `schema.sql` and the SQLAlchemy models have no migration tool keeping them in sync (no Alembic).
- `bcrypt` 5.x raises `ValueError` on passwords over 72 bytes, which returns a 500 on `/auth/register`.
- `README` tells Windows users `python setup.py install`; check what `Backend/setup.py` actually does before keeping that step.

---

## 🟡 9. Fake or misleading data returned by the API

| Where | What |
|---|---|
| `team/router.py` | Returns hardcoded "Engineering Pod Alpha" demo employees whenever the team has ≤1 member. |
| `admin/service.py` | `best_meeting_window` is "now + 2 hours". |
| `admin/service.py` | `state_distribution` is synthesized from the active count. |
| `admin/service.py` | Burnout risk "high" when an employee has < 2 sessions, so non-users are flagged as burning out. |
| `admin/service.py` | `display_name` uses real first name + last initial, which contradicts the "aggregate only" comment at the top of the file. |
| `admin/router.py` `/send-break-alert` | Returns success and a count but sends nothing. Team doc §4.3 removes it. |
| `user/router.py` `/dashboard` | `todays_sessions[-1]` without `ORDER BY`, so "last session" is arbitrary. |
| `user/router.py` `/dashboard` | `rhythm_position = actual_duration % cycle` of a finished session has no meaning. |
| `sessions/service.py` `classify_state` | `discord` and `spotify` count as "passive", so anyone working with music on is flagged. |
| `sessions/router.py` `/pre-check` | `warnings` is always `[]`. |

---

## 🟡 10. Scientific claims

- **rPPG** (`ml_models/rppg.py`): real signal processing, but green-channel only (no POS/CHROM), no skin segmentation, confidence gate 0.12–0.15. The "within ~5 BPM" docstring claim is optimistic. Team doc §2.3 drops rPPG and HR anyway.
- **"HR > 60 = fatigue"** (`biometric/router.py`): elevated HR indicates arousal or stress, not fatigue. `_compute_fatigue_signal` and `BiometricEngine` use different, inconsistent baselines.
- **Trough minute** = index of the tick with the lowest keystroke score. Calling that an ultradian trough is a stretch even once issue 1 is fixed.

---

## 🟡 11. Smaller code issues

- `sessions/router.py` `/stuck` parses Gemini output by splitting on ```` ``` ````. Use `response_mime_type="application/json"` with a schema.
- `/stuck` catches all exceptions and returns the raw exception text to the client.
- `end_session` returns `{"error": "not found"}` with HTTP 200 instead of a 404.
- `handle_intervention_response` never updates `interventions_total` / `interventions_accepted`, so those columns are always 0.
- `agent/main.py` falls back to session ID `demo_123` when started without arguments.
- `KeystrokeTracker.count` is incremented from the pynput thread without a lock (low risk in CPython, but inconsistent with the mouse code, which does lock).

---

## What is solid

- rPPG pipeline structure: resampling, detrending, FFT band-limiting, jump rejection.
- Per-OS window tracking that degrades without crashing.
- Session rehydration after restart (aside from the orphaned agent).
- Naive vs aware datetime handling is mostly consistent.

---

## Mapping to the team readiness doc

Most of these are already scheduled in the team's Product Readiness doc. Issues **1, 2, 3, 6 (refresh)**, the **missing dependency (8)** and the **IDOR / unauthenticated endpoints (5)** are not explicitly listed there and should be added to Phase 1 for owner A.
