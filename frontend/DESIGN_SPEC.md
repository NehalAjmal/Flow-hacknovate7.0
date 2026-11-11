# Flow design spec, v0.4 (draft for review)

The colour palette is **decided** (§16). The logo is **parked**. Elsewhere, colours are referred to by **role** (neutral / dark neutral / accent / amber), and §16 maps each role to its values.

---

## 0. Rules

| # | Rule | In practice |
|---|---|---|
| A (1) | **Less UI that does more** | Every control earns its place; it may do several jobs, **each visibly** (label, icon or hover hint). |
| 2 | **Apple-style physics** | Springs carry velocity on retarget · rubber band `c·x·d/(d+c·x)` (mouse drag 0.4 · notched wheel 0.5 · hi-res wheel 0.17 · small trackpad 0.715 · large trackpad 0.17) · **macOS-style scrolling everywhere, on both OSes**. |
| B | **Never looks empty; nothing moved to fill space** | Each screen answers 2–3 real questions; empty states are composed. |
| C | **Hairline principles, 3D and colour-filled** | Data as objects that answer the pointer. |
| D | **Mix 2D and 3D where it feels natural** | 3D when it's an **amount**, something you **handle**, or a **physical state change**. 2D for precise reading, rotating controls and tiny or dense things. Depth scales with size; one light direction app-wide. |
| E | **Slim everything** | 1–1.5 px hairlines · 1.5 px outline icons · light tabular numerals · letter-spaced small-caps labels · one filled button per view. |
| D7 | **Shortcuts are never primary** | Every action has a visible control; shortcuts shown in tooltips, the tray menu and Settings. |
| P | **Placement** | **Display on top → one read-out line → one control deck directly below**, controls grouped by job and touching. Never in the header, never scattered. |
| L | **The line is the ground** | No plinths or trays. 3D rises from a hairline. **Line = not yet · solid = happened.** |
| H | **Hairline rules kept** | Hover targets use the rest pose (no flicker) · effects spread outward from the cause · reach clamped · designed rest pose · correct depth order · no words *inside* objects · redraw only while something changes. |
| ✓ | **Honesty** | Parallel projection only · exact values in the read-out · learned values show sample size + confidence · no health or accuracy claims. |
| ◐ | **Accent discipline** | Accent = **"now / active" only**: NOW line, active session block, dial dot, progress dashes. Selected things (nav pill, lit pillar, segmented, Start button) use **dark neutral**. Amber = approaching break / break due. Never red for a person's state. |

---

## 1. Motion system

| Token | Use | Spec |
|---|---|---|
| **FOLLOW** | Tracking the pointer while dragging | spring 0.15 s · ζ 0.85 |
| **SNAP** | Detents, presses, releases, choices | spring 0.5 s · ζ 0.85 |
| **SETTLE** | Shape or position changes, shared-element moves | spring 0.5 s · ζ 1.0 (no overshoot) |
| **FADE** | Text swaps only | 150 ms |
| **STAGGER** | Groups reacting | 30–40 ms per step, **outward from the cause** |
| **CLOCK** | Countdown, NOW line, progress dashes, "ink drying" (the block crossing NOW fills; a finished block's colour drifts from accent to stone over ~10 min) | moves with real time, never a spring |
| **LINE-DRAW** | SVG/path drawn length | for "arriving / not yet" only |

- **Every animation must say what caused it, where it came from, or where it went** (Rule A).
- **Banned:** count-up numbers · shakes · pulsing/blinking · confetti · idle loops · marching ants · parallax · decorative page fades · replaying "rise" on every visit (rise only when data is new).
- **Reduced motion:** jump to the end state; the CLOCK still runs.
- **Refusal:** a refused action rubber-bands back + a hint fades in. No shake.

---

## 2. Shared components

**Control language** (a modernised tactile kit):
- **Pressables:** tiny front-on solids with a **2 px lip**. Hover lifts 1 px (SNAP), press sinks 2 px (FOLLOW), release (SNAP). No drop shadows.
- **Depth = function:** *recessed* holds a value (fields, tracks, the wheel well); *raised* acts.
- **One knob shape everywhere:** a raised disc with a dimple (slider thumbs, range knobs, the dial dot, the wheel marker).
- **Toggles:** a 28×16 pill. **Radio/check:** dots pressed in when chosen.
- **Scrollbars:** a macOS-style overlay, recessed track + raised pill, fading in and out.

**The dial (2D, dashed ring, BlockIt style):**
- Ticks every 5 min; longer every 15; longest every 60. A ✦ tick marks the suggestion.
- 0→value dashes filled (dark neutral), the rest faint. Accent dot.
- **Animations:**
  - draw-in staggered from 0
  - dashes near the dot grow/darken with falloff while turning (FOLLOW)
  - each 5-min step pops the dash under the dot (SNAP; Mac trackpad haptic)
  - fill changes spread from the dot (SETTLE)
  - rubber band at 15 / 180 min
  - **in a session the dashed ring is the progress ring** (dashes fill with the CLOCK)
  - **in a break the dashes drain**

**The drum wheel (3D-lite, vertical or horizontal):**
- Ridges bunch and fade at the edges; a fixed marker.
- **Step ends built in:** hovering the top/bottom third shows a chevron; a click steps once.
- Drag/trackpad: FOLLOW → friction → snap to the projected detent. Notched mouse wheel: one step per notch.
- Rubber band at the ends.

**Other components:**
- **3-snap slider · two-knob range slider:** the range track is a **mini spine** (24 h, your usual focus + meetings).
- **Filled-dot rating** (5 dots).
- **State chip:** text + icon (the icon line-morphs on change). Hover = why.
- **Sensing chips.**
- **Read-out line:** centred, letter-spaced small caps, FADE on change.

**The spine (the one time component), in three sizes:**
- **Full:** Home Score, session summary.
- **Mid:** Insights day cards, Team typical day.
- **Mini:** history rows, widget details (last 60 min), range-slider tracks, the break gap.

**Graph readings standard:**
- direct labels (no legends where avoidable) · units always · bars from zero · shared scales for compared charts
- a 3D scale reference ("tallest = 4 h 10 m")
- the exact value in the read-out; **a crosshair moved by the mouse or arrow keys**
- sample size + confidence on learned values
- **"view as table"** for screen readers

**Isometric/oblique engine** (Hairline ideas ported, MIT, © 2026 Lucas Marques): projection · rounded prisms · terrain · riffle · stacked block. Redraws only while something moves.

---

## 3. Shell: sidebar, header, window modes

**Sidebar:**
- A floating rail, **12 px from the left/top/bottom edges**, **56 px wide**, radius 16, hairline border.
- The item group is **vertically centred**: Home · Insights · Team* · Admin*.
- Bottom group: Settings · Privacy · Feedback · avatar (account · help · sign out).
- Icons 20 px / 1.5 px stroke, 40 px targets.
- Active = a dark-neutral pill that **slides between items** (SETTLE). Hover = a tooltip with the label + shortcut.
- A **live session dashed ring** appears in the rail during a session (hidden on Home); click → the widget.
- Content starts 24 px right of the rail.

**Header (every main screen):**
- Left: greeting · date.
- Right: **"Flow on ▾" chip** (global pause: 1 h / today / resume; status and control in one) + sensing chips.
- The agent banner (when not paired) sits as a slim line under the header.

**Window modes** (one window; tray icon always present):

| Mode | When |
|---|---|
| **Full** | Always available |
| **Mini widget** | **Only during a session** (running / paused / break / nudge pending). Auto on session start (Settings toggle). No session → no Shrink button, the shortcut does nothing, close → tray. |
| **Expanded card** | Nudge / details / break, growing out of the widget |
| **Lock** | Opt-in delivery mode only |
| **Hidden** | Tray only. The session continues, nudges → OS notifications |

- Session ends while mini → the window grows into the summary.
- Closing the window keeps Flow in the tray; Quit is in the tray menu.
- The tray icon + taskbar progress show steady / approaching / break / paused.

**Switch choreography (shared element = the deck's session group ⇄ the widget):**
- **Full → mini:**
  1. the ghost block fills (SETTLE)
  2. the window goes transparent at its current bounds
  3. the session group flies to the corner while the rest fades (SETTLE + FADE)
  4. the native window snaps to the widget bounds once aligned
- **Mini → full:** the reverse; the rest of Home draws in, spreading out from the deck.
- Interrupting it reverses from the current speed.
- **Windows risk:** frame toggling may flicker → must be prototyped. Fallback: a FADE crossfade + a direct resize.

**Widget (320×88, 2D):** `[dashed ring] 32:10 · Steady [⏸] [⌄] [⤢]`
- Click the time = pause/resume. The amber dot = a pending nudge (scales in once, never pulses).
- **Drag** = native move (FOLLOW). **Release** = SNAP to the nearest corner with a rubber band at screen edges. Position remembered **per monitor**; a missing monitor → primary.
- Scheduled start: the widget enters from its corner with "Starting in 10 s · Skip".

**Nudge choreography (mini):**
1. The tray/taskbar turn amber.
2. The window snaps to card bounds (transparent, anchored).
3. The chip icon line-morphs to "Break due"; the dashes near now turn amber.
4. The card grows upward (SETTLE); contents stagger outward from the corner: message → reason → buttons.

- No focus steal, no sound. **After 60 s** it collapses and the amber dot scales in.
- **Take a break:** the card **becomes the break** (dashes drain, the spine gap opens) → "I'm back" → 2 rating rows → shrinks into the widget.
- **Snooze:** the menu SNAPs out → collapse + "snoozed 10 m" fades for 2 s.
- **Dismiss:** collapse.
- **Why?:** the card grows further; contribution bars rise from their baseline.
- The pointer entering mid-collapse re-expands it with its current velocity.
- **Full mode:** the nudge expands the deck's session group **in place** (the height is reserved, so nothing shifts). An unfocused full window also sends an OS notification.

**Lock:** the widget's ring grows into a full-screen ring + spine. **Slide to override** (FOLLOW, rubber band; ≥ 90% confirms) → reason picker.

---

## 4. Signed out: Welcome · Sign in · Register · 2-step · Forgot/Reset · Verify

- **Left ~42%:** the Flow blocks **rising from a line** (3D), at a composed rest.
- **Right:** the slim form, max 360 px, vertically centred.
- **Error:** the next block stays outlined (no shake).
- **Success:** the outlines fill left→right (STAGGER + SETTLE), then the line + blocks **move into place as guide step 1**.
- **Register:** Solo / Invited (the invite prefilled from the link).
- **2-step:** six digit boxes, paste fills them, auto-submits.
- **Forgot:** always the same message.
- Field focus: the recess deepens 1 px (SNAP).

## 5. Welcome guide (6 steps, ~2 min)

A centred column, max 560 px. Progress = 6 dots that press in. Back / Next / Skip setup. Steps slide horizontally (SETTLE); the direction encodes forward/back.

| Step | Visual | Control |
|---|---|---|
| 1 What Flow does | a mini spine, blocks rising | Next |
| 2 What it senses + consent | sensing chip icons line-draw in as each is granted | per-scope switches (behavior required, not skippable) |
| 3 Connect the agent | a connection line draws between app and agent; **the plug snaps in only on real pairing** | 6-digit code · "Do this later" |
| 4 Nudge style (+ macOS notification permission) | a live preview card morphs per option | 3 option tiles |
| 5 Practice nudge | the **real** window shrinks to the **real** widget; a practice nudge grows | Snooze / Why? |
| 6 Start | the Home dial | "Start your first session" / "Explore first" |

Replayable from Settings › Help. One-time in-context tips afterwards (widget controls, Why?, still learning, close → tray).

## 6. Home

```
│12│ 56 │24│ greeting · date ............................ [Flow on ▾] ◦sensing chips │
│px│rail│px│ (agent banner if not paired)                                           │
│  │    │  │ DISPLAY: Day Score (forecast inside, right of NOW ~60%)                │
│  │    │  │        THURSDAY 7 · 3 H 20 MIN · NEXT MEETING 5:00   (read-out)        │
│  │    │  │ ┌ Look back ~40% ──────────┐ ┌ Start ~60% ──────────────────────────┐ │
│  │    │  │ │ wheel ▕flush▏ day terrain │ │ 25·50·90  task  demand  DIAL [Start] │ │
```

**Display: the Day Score** (full spine):
- **Auto-fit axis:** from 30 min before the first session to 30 min after the last *planned* one, **minimum 6 h**. Hour labels every hour, half-hour ticks. When the day changes length, the axis SETTLEs to the new range.
- **Block geometry is data, never decoration:**
  - **width = real duration**
  - **gap = the real break** (5–15 min reads as a tight cluster; a long gap is honest information, e.g. lunch)
  - **height = declared demand** (3 levels)
  - **depth 4 px**, so a day reads as a ribbon rising from the line, not as crates

| Track | Drawn as |
|---|---|
| Sessions | **3D blocks rising from the axis**: past = warm stone shaded by demand · **the active block = wet accent ink** · finished blocks **dry** from accent to stone over a few minutes · future = cool line-work · scheduled = dashed |
| Pressure | see below |
| Breaks | ● taken / ○ suggested / ◐ snoozed, each with a **dotted drop-line** to the curve showing the dip it caused |
| Meetings | pills (nudges held during them) |

**Pressure track** (it tells the story, not one solid fill):
- A filled area with a **crisp top-edge stroke**.
- A faint **"usual day" band** behind it (p25–p75 of your own days, with "usual (n days)" in the read-out).
- A **50% guide** (dotted) and the **nudge line** (amber, dashed, labelled).
- **Approach zone:** the part of the area within the top 20% below the nudge line is tinted amber, so "getting close" shows before a nudge.
- **Nudge markers:** ▼ amber where the line was crossed, plus the outcome ("nudge 10:42 · break taken", "snoozed", "dismissed").
- **Session-start hairlines** tie each block to its part of the curve.
- **NOW:** a dot on the curve + "74% · line in ~12m".
- **Forecast:** a dashed cool line + a **confidence band**.
- Hover: the crosshair card ("1:30 · Spec writing · light · pressure 34% · usual 38%").

- **Margin:** day totals per track, with a **delta vs your usual** ("3h20 · +20m vs usual", "4/5 · 1 skipped") + mini bars.
- **Forecast right of NOW:**
  - redraws outward from NOW on update
  - **"ink drying":** the block crossing NOW fills with the CLOCK
  - a scheduled session's dashes close, then it fills when it starts
- The NOW line draws down once on load.

| Pointer on the Score | Result |
|---|---|
| hover | crosshair across all tracks + values in the read-out (arrow keys too) |
| click a past block | that session's summary |
| drag **starting at NOW** | ghost block = start now (same as the dial) |
| drag elsewhere in the future | create a scheduled session |

**Control deck:**
- **Look back:** the vertical wheel **flush** against the **day terrain**. That's a hairline isometric floor grid with **pillars rising from day cells**; empty cells = no data or still learning; the scale reads "tallest = …". Rolling the wheel lights the pillar (SNAP, neighbours staggered) and slides the Score (SETTLE). A pillar click jumps there. Hover = a field falloff.
- **Start:**
  - presets 25 · 50 · 90 (the dial turns to them, SETTLE)
  - task (optional)
  - demand (3-snap)
  - "share with AI" (only with consent)
  - **the dial** (it starts at the suggestion)
  - **Start · ends 4:40** (dark neutral, the one filled button)

  Turning the dial grows the **ghost block** directly above on the Score. A centre-click = start with the defaults.
- **During a session**, the Start group becomes: dashed progress ring · ends at · **+15** · Pause · End (same width, nothing jumps).

## 7. Session summary

- **Display:** the session's 3D blocks rising from its own axis. On entry, the **progress ring unrolls into this line** (SETTLE).
- **Read-out:** focused / planned · breaks taken / suggested · time back after the break.
- **2D under it:** pressure on the same axis with nudge markers.
- "What Flow learned" (1–3 lines with sample size).
- **Deck:** 5-dot rating · Done.
- Stats fade in; no count-ups.

## 8. Insights (Patterns + History + Focus DNA)

- **Display:** the week's 7 day cards (mid spines, 3D) **standing on a floor line**. Day name + total sit **under** each card. Hover = it stands up (SNAP), neighbours part (STAGGER); click = it expands into the full Score (SETTLE).
- **Read-out:** "WEEK 45 · 14 H 10 MIN · 9 BREAKS".
- **Deck:** `[ Day | Week | Month ]` flush with the **wheel** (steps the period; the cards slide in its direction).
- **Below, in one column:**
  - **peak hours:** 3D bars rising from a 24 h line
  - **cycle curve** (2D: minutes into a session × relative focus; your peak marked; 90-min assumption dashed; n + confidence)
  - **break before/after** (2D paired dots, 1–5, median)
  - **year heatmap** (2D)
  - **history:** rows with shallow 3D mini spines + start–end + duration
  - **Focus DNA:** preview + Save PNG
- Period changes morph old values to new (SETTLE).
- **Learning state:** outlined cards + empty grid cells + "unlocks after N".

## 9. Settings (2D; one centred column, max 720 px; an in-page index)

1. **Nudges:**
   - delivery tiles whose mini preview **plays one nudge** when chosen
   - sensitivity slider (Fewer ↔ More)
   - snooze chips
2. **Breaks:** a horizontal drum wheel for length (2–15) · post-break rating on/off.
3. **Schedules:** each = a range slider on a 24 h mini spine + weekday pills + demand. They appear on Home as dashed blocks.
4. **Quiet hours:** the same component. Quiet hours = no nudges; scheduled sessions may still run.
5. **Sensors:** camera · calendar (connect/disconnect) · AI. Without consent, the switch rubber-bands back + "Allow in Privacy".
6. **Agent:** status · pair · version.
7. **Window:** auto-mini · widget corner · close = tray · global shortcut (opt-in, clash warning).
8. **Account:** name · email · password · resend verification · **admin 2-step setup** (QR + recovery codes).
9. **Help:** shortcuts · replay guide · tips on/off · contact.

## 10. Privacy

- Consent list (switch + plain text + last changed). Withdrawing turns the feature off.
- **What's stored:** one **3D stacked block** (a layer per category, labelled via leader lines, with the count) + retention.
- **Export:** a progress pill fills with real progress.
- **Delete account:** type DELETE.

## 11. Team · Admin

- **Team** (employees and admins):
  - **≥ 5 people:** the team terrain (hairline floor grid, aggregate pillars; hover reads `Tue 10:00 · avg 0.71 · 8 people`) + the team typical-day mid spine + trend (2D, last value labelled at the line end).
  - **< 5 people:** **the empty grid** + "Team data appears when at least 5 people share (now 3)". No numbers, no animation.
- **Admin:**
  - The privacy panel first (can / cannot see + group size).
  - The team terrain.
  - Trend 7/30.
  - Workload as a filled band (not a gauge).
  - The meeting window as a highlighted span on the team spine.
  - Invites (the link shown once; the row grows in; revoke collapses it).
  - Activity log.

## 12. Feedback

Kind (segmented) · message · include diagnostics (expandable "what's included") · Send · What's new.

## 13. System states

- **Loading:** outlines line-draw, then fill as data arrives (STAGGER from the first loaded).
- **Offline / polling:** a slim chip (the connection line shows a gap).
- **Errors:** an inline line + Retry; no modal error pages.

---

## 14. Where 3D is used

| 3D (amounts / physical) | 3D-lite (handled) | 2D |
|---|---|---|
| Session blocks · day terrain · week cards · team terrain · auth/guide blocks · peak-hours bars · history mini spines (shallow) · privacy stacked block | buttons · chips · presets · knobs · rating dots · toggles · drum wheel | dial · ring · widget · pressure / cycle / break / trend charts · year heatmap · text · icons · workload band |

## 15. Window and layout limits

Minimum window 960×640. Below ~1100 px wide, the deck's two groups stack vertically, but the order is still display → read-out → deck.

---

## 16. Colour: "Stone & Verdigris, ink drying" (decided)

**The idea** (colour carries meaning, Rule A):
- **Temperature is time.** The past is warm stone, the future is cool verdigris line-work, and the accent marks **NOW**, where the two meet.
- **The present is wet ink.** The active session is accent-coloured; finished blocks **dry** from cool accent to warm stone over a few minutes, so recency stays visible.
- Pushed slightly toward neon (more saturated, still not full neon).

**Hues: 4.** Neutral (warm stone) · accent (verdigris) · amber (break soon/due) · problem (system only). Every other shade is derived; 3D faces are computed (top +22% lightness, side −18%, grounding edge −35%).

| Role | Light | Dark | Used for |
|---|---|---|---|
| bg | `#EEECE6` | `#161816` | window background |
| raised | `#F7F6F2` | `#1F221F` | rail, chips, pressables |
| recess | `#E2DFD7` | `#0F110F` | fields, tracks, wheel well |
| hairline | `#CFCBC1` | `#313531` | rules, grids, borders |
| text 1 / 2 / 3 | `#1F201D` / `#585A54` / `#7D7E77` | `#E9ECE6` / `#A2A79E` / `#6F746C` | text levels |
| selected (dark neutral) | `#262724` | `#E4E8E0` | active nav pill, lit pillar, segmented, Start button |
| past · light / moderate / heavy demand | `#D3C8B4` / `#B09F84` / `#7D6C55` | `#3D362C` / `#5E5243` / `#8C7B62` | finished session blocks, terrain ramp |
| **accent** (NOW / active) | `#0B8A70` | `#3FE0B8` | NOW line, active block, dial dot, progress dashes, the NOW value |
| accent tint | `#CFEFE6` | `#123A31` | ghost block, focus rings |
| accent deep | `#06604E` | `#8AF0D6` | pressed / hover on accent |
| future (cool line) | `#33AE93` | `#2FC29F` | forecast blocks, forecast line, its confidence band (12% opacity) |
| **amber** (break soon / due) | `#B06E00` | `#FFB733` | nudge line, approach zone (35%), nudge markers, pending dot, tray/taskbar state |
| amber tint | `#F6E2BC` | `#3A2A0E` | the "Break due" chip background |
| **problem** (system only) | `#9A4436` | `#DB7E69` | offline, failed save, invalid field. **Never a person's state.** |

**Measured contrast vs background:**
- Accent: 3.6:1 (light) / 10.7:1 (dark).
- Amber: 3.5:1 / 10.3:1.
- Text 1: 13.9:1 / 15.0:1. Text 3: 3.5:1 / 3.7:1.
- Every non-text mark is ≥ 3:1. **Body text never uses the accent or amber in light mode** (both are under 4.5:1); use text 1/2 for words, with colour on the dot or line beside them.

**Rules:**
- **The accent is never orange or yellow** (amber means "break due").
- **No gradients, glows or neon blur**; "toward neon" means saturation only.
- **Selected ≠ accent:** selection is dark neutral, so the accent always means *now*.
- The default theme follows the OS.

**Reference mocks:** `flow-palette-merged-v2.svg` (light + dark, with the full pressure track).

## 17. Type, wordmark, launch (decided)

**Type: three voices, never mixed in one line**

| Voice | Face | Used for | Rule |
|---|---|---|---|
| Instrument | OffBit 101 (+Bold) | wordmark, big numbers, timers, headlines | 20 px and up only; ticking values use fixed digit cells (no tabular figures in the face) |
| Not yet | OffBit Dot | scheduled times, countdown before a start | same skeleton as 101 (rule L in type) |
| Controls | Sono (static instances) / SonoMono | buttons, labels, read-outs, chart labels | caps labels keep "Flow" as Flow |
| Flow's notes | Cutive | nudges, insights, guide, summaries | set 1 px under UI size |

The product name is always **Flow** (capital F only), including inside caps labels.

**Wordmark:** "Flow" in OffBit 101 Bold, drawn from outlines (generated from the font). One accent element: the **o**.

**Launch (cold start, ~2.3 s, any click or key skips):**
1. Each letter's outline draws in as slow stone dashes (the spine's "not yet" line), staggered.
2. The letters fill bottom → top like liquid; the surface ripples in proportion to the fill spring's velocity, so it calms as it settles. The o fills in the accent.
3. A circle opens from the o and grows over the screen (critically damped spring), revealing the live app beneath; a 1 px stone ring marks the front.
- The splash uses the opposite ground to the app: a dark splash with paper letters for a light app, a stone splash with ink letters for a dark app.
- The reveal waits for sign-in to resolve; meanwhile a dashed line runs under the mark.
- Reduced motion: the still mark, then a 150 ms fade.

**Score (Home) honesty rules:**
- Blocks are the main element (max ~27% of height, 96 px).
- The pressure area is coloured by height: < 50% light stone, 50–80% mid stone, 80–100% amber tint, over the line amber. Monotone smoothing (no invented peaks).
- Percentages appear on hover only; the present shows "line in ~N m" when a projection exists.
- The full-day forecast (and forecast blocks) is drawn only when `forecast_confidence` is high. Otherwise, during a live session, a short projection extends the last 15 min trend for up to 20 min and stops at the line.
- The usual band needs ≥ 10 days; before that the track says "learning your usual rhythm · day N of 10".

## 18. Signed-out screens (built)

- Left 42%: wordmark, a Cutive line, and a line with four stone blocks plus the **next** block as a dashed outline. Busy → the next block fills to ~70% (SETTLE); error → it drains back and stays an outline (no shake); success → it fills.
- Right: slim form, max 360 px. Hint-as-label recessed fields, full-width primary, underlined quiet links. Errors are one inline line.
- 2-step: six recessed digit boxes over one real field (typing, paste and OS one-time-code autofill work); a complete code submits itself.
- Under 820 px wide: the stage collapses to the wordmark above the form.

## 19. Round 5 decisions (built)

- **Every 3D block rises** from its line on arrival, with SETTLE (closed form `Motion.settleAt`) staggered 35–80 ms by position: Score blocks, month terrain, sign-in stage, session summary, loading blocks. Again only when the data or day changes, never on every visit.
- **Block solidity:** depth = 13% of max height (5–13 px), front face lit from above (gradient), a catch-light on the top edge, a crease on the side edge, a hairline gap between neighbours.
- **Loading (spec §13 made concrete):** faint blocks on a line rise, then breathe ±9% out of phase on a 2.4 s period. Reduced motion: still. Replaces every spinner (`AsyncSection` default).
- **Usual:** one dashed median line labelled "your usual" (after ≥ 10 days), no band fill.
- **Type step:** the whole app runs at +10% on top of the OS text size (`FlowTextScaler`).
- **Home deck:** the Start controls keep a fixed slim width so the dial sits near the middle of the deck; controls give way first when the window narrows.
- **Welcome guide** (`/consent` for new users, `/guide` to replay) built: spring-driven horizontal steps, the consent step blocks Next and Skip until behavior sensing is granted, agent pairing with a dashed→solid connection line, nudge-style tiles with a live preview, a practice nudge (Why? bars rise), and the first-session dial. The real window → widget shrink in step 5 waits for the window work (task #4).
- **Session screens** built: the full active view (the dial ring is the session; timer fitted to the face), a full-screen break (dashes drain in amber; lock mode = slide to override with rubber band, confirm ≥ 90%), welcome-back rating dots, and a summary whose display is the session's own axis (focus blocks with 10-min seams, breaks as gaps, nudge ▼ and approach ticks).
- **Nudge card** is one shared view (`NudgeCardView`): an OffBit head with an amber dot, the message in Cutive, Why? expanding in place with contribution bars, "More detail" for the full table.

## 20. Colour: subtle washes (built; ultramarine and slate tried and rejected)

There is no loud second accent. Colour is atmosphere: several soft hues, each a faint wash of the ground with a thin edge, each tied to a meaning.

| Tone | Wash | Where |
|---|---|---|
| brand | deeper warm stone | the sign-in stage, guide step 1 |
| planned | mist, a grey-green (`#6F8580` line-work, wash `#E3E7E4`) | the Home Start group, guide consent and agent steps, dashed planned blocks |
| now | sage (verdigris tint, 55% toward the ground) | the active session display, the Home session group, the guide start step |
| rest | sand (amber tint, 45% toward the ground) | the break screen ground, the guide nudge steps |
| past | stone (light stone, 62% toward the ground) | the Home look-back, the session summary axis |

- The strong accents stay small: verdigris marks NOW, amber marks a break.
- Links and the feature-note rings use ink, not colour.
- Headlines are OffBit Bold.

**Explaining functionality:**
- `FeatureNote`: a numbered ring, a short title, one or two lines in Cutive.
- Welcome: the stone field shows a sample nudge and three notes.
- Guide: notes under steps 1 and 5.
- Home: a "How to read this" toggle shows numbered captions.

## 21. Fill the screen (rule 1, applied from round 7 on)

No page may sit half-empty. Each screen fits the viewport, and its elements size from the space they get (the dial, chart heights, heatmap cells, card heights), not from fixed numbers.

- **Focus session:** the sage ground fills the page below the header.
  - Left: the dial, sized from the window (220–460 px).
  - Right: the state chip, this session's pressure on the session's own axis (with "your usual" for these minutes once there are ≥ 10 days, and the live pressure as the NOW dot), live signal bars, three large stats (focused so far · nudges · breaks taken), then the controls.
- **Insights** (built; `/patterns` and `/history`):
  - a week stepper in the header
  - seven day cards standing on a floor line; each card is fitted to the hours that week actually used; hover stands a card up and its neighbours part; the chosen card is outlined
  - the chosen day's full Score on a stone wash
  - peak hours as 3D bars over 24 h, from this week's real sessions, with the learned peaks marked ▲
  - your focus cycle (a model curve labelled with n and confidence, 90′ assumption dashed) next to "breaks that helped" (big %)
  - the last 12 months as a full-width heatmap, cells sized from the width
  - recent sessions with shallow 3D mini spines, next to Focus DNA with a three-point legend

## 22. Motion: every element moves (built)

**The day blocks arrive like the wordmark.**
- Where a block *is a day*, it uses the logo's motion: a dashed outline first ("not yet"), then a bottom → top liquid fill ("happened") whose surface sloshes and calms as its spring settles.
  - Home's Look back terrain: isometric pillars (`paintPillarOutline` + `paintPillar(ripple:)`), staggered outward from the selected day.
  - Insights week cards: front-on blocks via `lib/ui/blocks.dart`.
- Every other 3D block (the Score, peak bars, summary, sign-in stage, history) rises from its line with SETTLE.

**Launch gate:** first-appearance animations wait until the launch reveal starts (`LaunchGate`, `Motion.enter`); otherwise they would play, unseen, under the overlay.

**Insights interactions:**

| Element | Motion | Hover |
|---|---|---|
| Week cards | the selection outline slides between cards (SNAP, carries velocity) | stands a card up |
| Peak bars | rise | lifts the bar 4 px and reads "10:00 · 280 min" |
| Cycle curve | line-draws in from the left; the area fades in after | crosshair reads "62′ in · focus 94% of your peak" |
| Heatmap | cells grow outward from today | outlines the cell with a dark date tooltip |
| Break bar | fills | — |
| History rows | stagger in (`Appear`: fade + 8 px rise, 35 ms steps) | — |
| Focus DNA | image fades in; legend staggers | — |

## 23. Settings (built)

The page fills the screen instead of a 720 px column.

**Left: a sticky, full-height index.**
- Each row is a section name with its current value underneath (Quiet · 5 min · Off · behavior only); the active row has a raised face and an ink bar.
- At the bottom, "in one line": the whole setup as one Cutive sentence.

**Right: one wash per section.** Each section has a title, Flow's one-line explanation, and controls next to a live preview.

| Section | Controls | Preview |
|---|---|---|
| **Nudges** (sand) | delivery tiles; snooze chips (pick 1–3) | the real nudge card or the lock screen for that mode |
| **Breaks** (sand) | a horizontal drum wheel, 2–15 min, with a big numeral; saved 450 ms after the wheel settles | the break dial at that length |
| **Quiet hours** (mist) | a toggle and a range slider whose track runs noon → noon (`TimeRangeSlider.origin`) so a night is one piece; debounced save | notes on schedules (task #7) and window behaviour (task #4), which have no API yet |
| **Sensors** (stone) | camera, calendar (+ connect/disconnect), AI; without consent the toggle springs back and shows "Needs consent first · Allow in Privacy →" | "sensed right now" chips |
| **Agent** (sage when connected, mist when not) | status, inline 6-digit pairing | live counts from this computer |
| **Account** (stone) | name, email (verified), role; Change password sends a reset link; Sign out | the admin 2-step setup note (waits on an API) |
| **Help** (mist) | replay the welcome guide | the shortcuts list |

**Not built (no API field):** nudge sensitivity and the post-break rating toggle.

## 24. Privacy, Feedback, system states (built)

**Privacy**
- **What's stored:** one 3D stack, a layer per category, with layer height ∝ log(items) so a big category doesn't flatten the rest.
  - Layers drop onto each other from the floor (SETTLE, staggered).
  - Leader lines carry name, count and retention outside the object; hovering slides a layer out and reads its description.
- **Consents:** each with plain text and "changed <date>"; withdrawing behavior asks first.
- **Export:** a pill whose dashed line runs while the server prepares it and fills only when it is really ready (the API reports no percentage, so none is invented).
- **Delete:** an inline "type DELETE" field; the button wakes only on the exact word, then signs out.

**Feedback**
- Fills the page: kind chips, a message box that grows to the bottom, diagnostics with an expandable "what's included" (and what is never sent), Send with an inline "Sent. Thank you."
- What's new and "what helps us most" sit beside it.

**System states**
- **Errors:** one inline line (problem-colour dot + message + underlined Retry), never a modal.
- **Connection chip:** offline is a line with a gap; polling is a dashed line.
- **404:** the day's line with the next block left as an outline, then "Nothing here" and one way back.
- **Loading:** LoadingBlocks everywhere (§19).

## 25. Team · Admin (built)

**Data honesty:** the API gives per-day team averages, not an hour × day grid, so the "team terrain" is the team's week: seven aggregate day pillars on a hairline floor. They fill like every day block (outline → liquid). Hover reads "Wed · avg 70 · 8 people". Any value below 5 people is never shown.

**Team**
- Fills the page: the week on the left, sized from the window.
- Right: the average focus (big), the trend (line-draws in, last value labelled at the line end, hover reads a day), and two notes: "only averages", "you can leave".

**Below 5 people (Team and Admin):** the empty floor grid and one sentence. No numbers, no animation.

**Admin**
- **Top row:** the privacy panel first (✓ can see / ✕ cannot see, plus group size), next to the team's week with "N in a session now · M sessions this week".
- **Middle row:** average focus with a 7/30-day toggle, next to workload as a filled band (low · moderate · high, "not a health measure") and the best meeting window as a highlighted span on an 8–20 line, with the team's focus peaks ▲ and the typical recovery time.
- **Bottom row:** invites (the new link appears inline once, with Copy/Done; rows grow in; Revoke), next to the admin activity log.

Old placeholder files removed: `admin_screens.dart`, `insight_screens.dart`. `/export` now opens Insights (Focus DNA lives there).

## 26. Window modes (built)

Built per §3 as a **pop-out**: the window hides, becomes a frameless pill in its corner, and reappears; the content springs in (88% → 100%, slight overshoot). Esc, the open button or the tray's "Show Flow" bring the full app back. If the OS refuses the shape, Flow stays in its window.

- **Widget:** `[ring] 1:09:55 · STEADY [⏸] [⤢]`. Drag anywhere to move (native); it snaps to the nearest corner and remembers it. Click the time to pause; an amber dot scales in once for a waiting nudge and opens the card.
- **Card:** the waiting nudge (the live `InterventionCard`), or, without one, the session itself (time, progress, Pause / Take a break / End).
- **Settings › Window:** pop out into the widget when a session starts; closing keeps Flow in the tray; widget corner (picked on a small screen).
- **Home's session group:** gains a "Pop out" button (desktop only, only while a session runs).
- **Tray icons:** idle (dashed ring) · steady (green core) · approaching (amber ring) · break due (amber full) · paused (bars).
- **Notification rule:** in widget/card mode the card is the nudge, so no OS notification. Notify only when the window is hidden or the full app is unfocused.
- **Invite landing:** `/invite?token=` shows "You're invited" with four notes (your admin sees your time · never what you work on · nothing until you agree · you can leave), then opens Create account with the token filled in.

## 27. Schedules, calendar hand-off, Focus DNA save (built)

- **Settings › Schedules (mist):** one row per routine.
  - Each row: name, on/off, a 24 h range slider, weekday pills (M T W T F S S), demand (light/moderate/heavy) and Remove. "Add a schedule" sits underneath.
  - Preview: "your week", seven day lines with each routine as a dashed planned block.
- **Home:** drag across the future part of the Score to plan a routine on that weekday, with an Undo snackbar.
- **Scheduled blocks** come from real schedules (dashed, mist).
- **On time:** a slim banner at the top, "Weekly review starts in 9 s · Start now · Skip". It starts by itself after 10 s, only when no session runs and Flow isn't paused, and offers each routine once per day. On desktop with auto-widget on, the session then moves into the widget.
- **Calendar connect:** opens Google in the browser; the row reads "Finish signing in in your browser… Flow is waiting" with Cancel, and turns connected by itself.
- **Focus DNA → Save PNG:** a save dialog on desktop, a download on web.

## 28. Admin: People (built)

The admin (only the admin) can look at each person; teammates still see averages only. People are told at the invite and again when creating the account, and "Share with my team" in Privacy is the off switch.

- **Team admin** gains a **People** button. Its panel lists what the admin can and cannot see, per person included.
- **People (`/admin/people`):** one row per person. Display: the week as seven blocks on a scale shared by everyone, with a tick for the team's average that day; days to come are a dashed base (line = not yet). Read-out: focus, sessions, breaks taken of suggested, break pressure (words + three bars; amber only when high). Controls last: sort by focus / break pressure / name. Rows grow to fill the page; a green dot marks who is in a session now. A row opens the person.
- **Person (`/admin/people/:id`):** the week as seven day lanes on a shared clock (sessions shaded by demand, a filled amber dot = break taken, a ring = snoozed or dismissed); focus this week against the team average; how break suggestions were answered as one bar; 30 days of focus with 14 days of break pressure drawn over it.
- **Always on screen:** one line saying what this is and what it never includes. Never task text, window titles, apps, typing or camera data: the models have no such fields.
- **On the record:** opening a person writes "Opened a person's page" to the admin activity log.

## 29. Page switches and loading (built)

- Data outlives its page by 5 minutes, and live changes refresh in place, so going back is instant and nothing blinks.
- The loader (the o as a jelly cup: pours, sloshes, jiggles, drains) appears only when a load takes longer than 250 ms.
- One page transition everywhere: 180 ms fade with a 6 px rise. Entrances play on a page's first visit only.
- Dev panel › Simulate: mock latency, "Forget cached pages", "Send a nudge now".

## 30. Nudges: three ways to arrive (built)

One choice in Settings › Nudges (and guide step 4), kept per computer: **Full screen** (default) · **Windowed** · **Notification**. The old Quiet / Explained / Firm choice is gone: the reason is always shown, and "Firm" is now a separate switch, *Lock the screen during breaks*.

- **Full screen:** the suggestion takes the whole display. **Windowed:** the same view in a centred 760×480 window that floats over your work. Both are the pop-out window (frameless, always on top), so they appear whether Flow was open, popped out or in the tray.
- **The view (display → read-out → controls):** an amber tide rises from the bottom edge to *your break line* (the Score's nudge line) and calms; "Take 5?" lands above it, then its reason; the controls arrive last: Take a 5 min break · Snooze 5 / 10 / 20 · Why? · Dismiss · Not now. Everything scales with the window.
- **Mouse first:** the keyboard is ignored for 1.5 s (it appears while you type elsewhere). Then Enter takes the break and Esc snoozes; the hint fades in when the keys are live.
- **Steps back by itself:** unanswered for 60 s (or "Not now"), it returns to where it came from and waits as the corner card / the widget's amber dot, with a system notification if Flow is not in front.
- **Notification:** the corner card in Flow (it rises in), the widget's card when popped out, and a system notification when Flow is hidden or behind other work.
- **If the OS refuses the window shape,** the takeover shows inside Flow's own window instead.
- **Dev:** `/dev/login?as=solo&nudge=fullScreen|windowed|notification` signs in, starts a session and sends a nudge in that style.
