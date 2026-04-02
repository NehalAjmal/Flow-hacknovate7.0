import asyncio
import io
from PIL import Image, ImageDraw, ImageFont
import google.generativeai as genai
from config import settings
from .schemas import FocusDNARequest

async def generate_weekly_insight(data: FocusDNARequest) -> str:
    """
    Ask Gemini to produce one specific, personal insight based on this
    user's actual week data. This is not a generic tip — it references
    their real numbers so it feels genuinely personalized.
    """
    peak_hours_str = ", ".join([f"{h}:00" for h in data.peak_hours])
 
    prompt = f"""
You are FLOW, an AI cognitive performance assistant.
A user just completed their week. Here is their actual data:
 
- Name: {data.user_name}
- Peak focus hours this week: {peak_hours_str}
- Personal ultradian cycle (their natural focus rhythm): {data.cycle_length_minutes} minutes
- Weekly focus score: {data.weekly_focus_score:.1f} / 100
- Best focus day: {data.best_focus_day}
- Total sessions completed: {data.total_sessions_this_week}
- Average session quality rating: {data.avg_session_quality:.1f} / 5.0
 
Write ONE insight sentence (max 20 words) that is:
1. Specific to THEIR data — reference actual numbers or patterns
2. Actionable — tells them something they can do differently next week
3. Warm but direct — not generic motivational fluff
 
Respond with ONLY the insight sentence. No labels, no quotes, no explanation.
"""
 
    try:
        model = genai.GenerativeModel(settings.gemini_model)
        response = await model.generate_content_async(prompt)
        return response.text.strip().strip('"').strip("'")
    except Exception:
        # Fallback insight if Gemini is unavailable
        return f"Your peak window is {data.peak_hours[0]}:00 — protect that hour next week."
 
 
# ── PNG generation ────────────────────────────────────────────────────────────
 
def draw_focus_dna_card(data: FocusDNARequest, insight: str) -> bytes:
    """
    Draw the Focus DNA card using Pillow and return it as PNG bytes.
 
    The card layout:
    ┌─────────────────────────────────┐
    │  FLOW  •  Focus DNA             │  ← header bar (dark navy)
    │  Week of [date]                 │
    ├─────────────────────────────────┤
    │  [Name]'s Focus DNA             │  ← title
    ├──────────┬──────────┬───────────┤
    │  Peak    │  Cycle   │  Score    │  ← 3 stat cards
    │  Hours   │  Length  │           │
    ├──────────┴──────────┴───────────┤
    │  Best Day: [day]                │  ← secondary stats
    │  Sessions: [n]  Quality: [n]    │
    ├─────────────────────────────────┤
    │  " [Gemini insight] "           │  ← AI insight
    └─────────────────────────────────┘
    """
 
    # Card dimensions
    W, H = 800, 500
 
    # Color palette — matches FLOW's dark theme
    COLOR_BG         = (10, 15, 30)      # deep navy background
    COLOR_CARD       = (17, 24, 39)      # card surface
    COLOR_ACCENT     = (6, 182, 212)     # cyan accent
    COLOR_SECONDARY  = (13, 148, 136)    # teal
    COLOR_WHITE      = (255, 255, 255)
    COLOR_MUTED      = (148, 163, 184)
    COLOR_AMBER      = (217, 119, 6)
 
    # Create the base image
    img = Image.new("RGB", (W, H), COLOR_BG)
    draw = ImageDraw.Draw(img)
 
    # Try to load a system font, fall back to default if not available.
    # On Mac, Arial is available. The fallback is Pillow's built-in bitmap font.
    # Safely load fonts with a guaranteed fallback
    try:
        # Try finding Arial by name (macOS usually supports this)
        font_large  = ImageFont.truetype("Arial", 32)
        font_medium = ImageFont.truetype("Arial", 22)
        font_small  = ImageFont.truetype("Arial", 16)
        font_tiny   = ImageFont.truetype("Arial", 13)
    except IOError:
        try:
            # Try the hardcoded macOS path
            font_large  = ImageFont.truetype("/Library/Fonts/Arial.ttf", 32)
            font_medium = ImageFont.truetype("/Library/Fonts/Arial.ttf", 22)
            font_small  = ImageFont.truetype("/Library/Fonts/Arial.ttf", 16)
            font_tiny   = ImageFont.truetype("/Library/Fonts/Arial.ttf", 13)
        except IOError:
            # Bulletproof Fallback: Use Pillow's default built-in font
            # (Note: The default font cannot be resized, so all text will be the same size,
            # but it guarantees the server won't crash)
            font_large = ImageFont.load_default()
            font_medium = ImageFont.load_default()
            font_small = ImageFont.load_default()
            font_tiny = ImageFont.load_default()
 
    # ── Header bar ────────────────────────────────────────────────────────────
    draw.rectangle([(0, 0), (W, 60)], fill=(13, 20, 40))
    draw.rectangle([(0, 0), (5, 60)], fill=COLOR_ACCENT)   # left cyan stripe
    draw.text((20, 18), "⚡ FLOW", font=font_medium, fill=COLOR_ACCENT)
    draw.text((100, 20), "Focus DNA  •  Weekly Summary", font=font_small, fill=COLOR_MUTED)
 
    # ── Title ─────────────────────────────────────────────────────────────────
    name_line = f"{data.user_name}'s Focus DNA"
    draw.text((20, 80), name_line, font=font_large, fill=COLOR_WHITE)
 
    # Thin separator line
    draw.rectangle([(20, 122), (W - 20, 124)], fill=(30, 58, 95))
 
    # ── Three stat cards ──────────────────────────────────────────────────────
    card_y = 140
    card_h = 100
    card_configs = [
        {
            "x": 20,
            "label": "PEAK HOURS",
            "value": "  ".join([f"{h}:00" for h in data.peak_hours[:3]]),
            "color": COLOR_ACCENT
        },
        {
            "x": 290,
            "label": "CYCLE LENGTH",
            "value": f"{data.cycle_length_minutes} min",
            "color": COLOR_SECONDARY
        },
        {
            "x": 560,
            "label": "FOCUS SCORE",
            "value": f"{data.weekly_focus_score:.0f} / 100",
            "color": COLOR_AMBER
        }
    ]
 
    for card in card_configs:
        cx = card["x"]
        # Card background
        draw.rectangle([(cx, card_y), (cx + 220, card_y + card_h)], fill=COLOR_CARD)
        # Top color accent line
        draw.rectangle([(cx, card_y), (cx + 220, card_y + 4)], fill=card["color"])
        # Label (small, muted)
        draw.text((cx + 12, card_y + 14), card["label"], font=font_tiny, fill=COLOR_MUTED)
        # Value (large, colored)
        draw.text((cx + 12, card_y + 38), card["value"], font=font_medium, fill=card["color"])
 
    # ── Secondary stats row ───────────────────────────────────────────────────
    stats_y = 265
    draw.text((20, stats_y), f"Best Day:  {data.best_focus_day}",
              font=font_small, fill=COLOR_WHITE)
    draw.text((260, stats_y), f"Sessions:  {data.total_sessions_this_week}",
              font=font_small, fill=COLOR_MUTED)
    draw.text((430, stats_y), f"Avg Quality:  {data.avg_session_quality:.1f} / 5.0",
              font=font_small, fill=COLOR_MUTED)
 
    # ── Separator ─────────────────────────────────────────────────────────────
    draw.rectangle([(20, 300), (W - 20, 302)], fill=(30, 58, 95))
 
    # ── AI insight block ──────────────────────────────────────────────────────
    draw.rectangle([(20, 318), (W - 20, 430)], fill=COLOR_CARD)
    draw.rectangle([(20, 318), (24, 430)], fill=COLOR_ACCENT)  # left accent bar
 
    draw.text((36, 330), "FLOW INSIGHT", font=font_tiny, fill=COLOR_MUTED)
 
    # Word-wrap the insight text manually (Pillow doesn't auto-wrap)
    # Split into lines of ~60 chars
    words = insight.split()
    lines, current_line = [], ""
    for word in words:
        if len(current_line) + len(word) + 1 <= 65:
            current_line = current_line + " " + word if current_line else word
        else:
            lines.append(current_line)
            current_line = word
    if current_line:
        lines.append(current_line)
 
    for i, line in enumerate(lines):
        draw.text((36, 358 + i * 26), line, font=font_medium, fill=COLOR_WHITE)
 
    # ── Footer ────────────────────────────────────────────────────────────────
    draw.rectangle([(0, H - 36), (W, H)], fill=(6, 10, 20))
    draw.text((20, H - 24), "Generated by FLOW  •  Team Error 011  •  Hacknovate 7.0",
              font=font_tiny, fill=COLOR_MUTED)
 
    # ── Serialize to PNG bytes ────────────────────────────────────────────────
    # Instead of saving to a file on disk, we write to an in-memory buffer.
    # This is cleaner for an API — no temp files to clean up.
    buffer = io.BytesIO()
    img.save(buffer, format="PNG", optimize=True)
    buffer.seek(0)
    return buffer.read()
 