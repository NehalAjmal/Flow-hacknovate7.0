from pynput import keyboard

class KeystrokeTracker:
    def __init__(self):
        self.count = 0
        self.listener = keyboard.Listener(on_press=self.on_press)

    def on_press(self, key):
        self.count += 1

    def start(self):
        self.listener.start()

    def get_and_reset(self):
        val = self.count
        self.count = 0
        return val
    


import win32gui

class WindowTracker:
    def __init__(self):
        self.last_window = None
        self.switch_count = 0

    def update(self):
        current = win32gui.GetWindowText(win32gui.GetForegroundWindow())

        if self.last_window and current != self.last_window:
            self.switch_count += 1

        self.last_window = current
        return current

    def get_and_reset(self):
        val = self.switch_count
        self.switch_count = 0
        return val