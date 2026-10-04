"""
FLOW Activity Agent — cross-platform input & window tracking.

Keystroke / mouse tracking uses pynput (Windows / macOS / Linux).
Frontmost-window tracking is platform-specific:
  Windows → win32gui
  macOS   → Quartz CGWindowListCopyWindowInfo (pyobjc)
  Linux   → best-effort via xdotool if installed
Anything unavailable degrades to "Unknown" without crashing the agent.
"""

import platform
import time

from pynput import keyboard


class KeystrokeTracker:
    def __init__(self):
        self.count = 0
        self.last_press_time = None
        self.listener = keyboard.Listener(on_press=self.on_press)

    def on_press(self, key):
        self.count += 1
        self.last_press_time = time.time()

    def start(self):
        self.listener.start()

    def get_and_reset(self):
        val = self.count
        self.count = 0
        return val

    def idle_seconds(self, cap: int) -> int:
        if self.last_press_time is None:
            return cap
        return min(cap, int(time.time() - self.last_press_time))


# ── per-platform frontmost window getters ────────────────────

def _get_window_win32():
    import win32gui
    return win32gui.GetWindowText(win32gui.GetForegroundWindow())


def _get_window_macos():
    # Layer 0 = normal windows (menu bar, dock and overlays sit on higher layers).
    # kCGWindowName needs Screen Recording permission on macOS 10.15+; the
    # owner name does not, so we degrade to owner-only if the title is withheld.
    from Quartz import (
        CGWindowListCopyWindowInfo,
        kCGWindowListOptionOnScreenOnly,
        kCGNullWindowID,
        kCGWindowLayer,
        kCGWindowOwnerName,
        kCGWindowName,
    )
    windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID)
    for w in windows:
        if w.get(kCGWindowLayer, 1) != 0:
            continue
        owner = w.get(kCGWindowOwnerName) or ""
        title = w.get(kCGWindowName) or ""
        if owner:
            return f"{owner} - {title}" if title else owner
    return "Unknown"


def _get_window_linux():
    import subprocess
    out = subprocess.run(
        ["xdotool", "getactivewindow", "getwindowname"],
        capture_output=True, text=True, timeout=1,
    )
    if out.returncode == 0 and out.stdout.strip():
        return out.stdout.strip()
    return "Unknown"


class WindowTracker:
    def __init__(self):
        self.last_window = None
        self.switch_count = 0

        system = platform.system()
        impl = None
        if system == "Windows":
            try:
                import win32gui  # noqa: F401
                impl = _get_window_win32
            except ImportError:
                print(" pywin32 not installed — window tracking disabled")
        elif system == "Darwin":
            try:
                import Quartz  # noqa: F401
                impl = _get_window_macos
            except ImportError:
                print(" pyobjc not installed — window tracking disabled "
                      "(pip install pyobjc-framework-Quartz)")
        elif system == "Linux":
            impl = _get_window_linux

        self._impl = impl

    @property
    def available(self) -> bool:
        return self._impl is not None

    def update(self):
        current = "Unknown"
        if self._impl:
            try:
                current = self._impl() or "Unknown"
            except Exception:
                current = "Unknown"

        if self.last_window and current != self.last_window:
            self.switch_count += 1

        self.last_window = current
        return current

    def get_and_reset(self):
        val = self.switch_count
        self.switch_count = 0
        return val
