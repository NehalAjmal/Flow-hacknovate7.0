"""
rPPG - remote photoplethysmography from a webcam.

Estimates heart rate from tiny brightness variations of facial skin caused by
blood flow. Pipeline per estimate:

  1. mean green-channel value of the forehead ROI per frame  (caller supplies it)
  2. resample the rolling window onto a uniform grid (webcam fps is not exact)
  3. detrend (subtract a slow moving average) + Hanning window
  4. FFT -> dominant peak inside the human heart-rate band (42-200 BPM)
  5. confidence = peak power / total in-band power (drops on motion artefacts)

This is real signal processing, not a simulation: with a still face and decent
lighting a laptop webcam typically lands within ~5 BPM. Estimates below the
confidence threshold are suppressed by the caller.
"""

import time
from collections import deque

import numpy as np

# Heart-rate band in Hz (42 - 200 BPM)
BPM_MIN, BPM_MAX = 42.0, 200.0
HZ_MIN, HZ_MAX = BPM_MIN / 60.0, BPM_MAX / 60.0

# Window of signal kept for analysis
WINDOW_SECONDS = 12.0
MIN_SECONDS = 8.0
# How often to recompute (the fatigue loop runs ~30fps)
COMPUTE_EVERY_SECONDS = 1.0
# Estimates below this peak-purity are considered noise
MIN_CONFIDENCE = 0.12


class PulseEstimator:
    """Rolling rPPG estimator. Call :meth:`add_sample` per frame with the mean
    green value of a forehead ROI, then read :meth:`estimate`."""

    def __init__(self, expected_fps: float = 30.0):
        self.expected_fps = expected_fps
        self._times: deque = deque()      # monotonic seconds
        self._values: deque = deque()     # mean green per frame
        self._last_compute = 0.0
        self._smoothed_bpm: deque = deque(maxlen=3)

        self.bpm: float | None = None
        self.confidence: float = 0.0

    # ── data in ────────────────────────────────────────────────────────────
    def add_sample(self, green_mean: float, now: float | None = None):
        t = time.monotonic() if now is None else now
        self._times.append(t)
        self._values.append(float(green_mean))
        while self._times and t - self._times[0] > WINDOW_SECONDS + 1.0:
            self._times.popleft()
            self._values.popleft()

    # ── estimation ─────────────────────────────────────────────────────────
    def estimate(self, now: float | None = None) -> tuple[float | None, float]:
        """Returns (bpm, confidence). bpm is None when there is not enough
        signal yet or the estimate is too noisy. Recomputes ~1x/second."""
        t = time.monotonic() if now is None else now
        if t - self._last_compute < COMPUTE_EVERY_SECONDS:
            return self.bpm, self.confidence
        self._last_compute = t

        if len(self._times) < 2 or self._times[-1] - self._times[0] < MIN_SECONDS:
            self.bpm, self.confidence = None, 0.0
            return self.bpm, self.confidence

        times = np.array(self._times)
        values = np.array(self._values)

        # resample onto a uniform grid (interpolate missing/uneven frames)
        fps = max(10.0, min(60.0, len(times) / (times[-1] - times[0])))
        grid = np.arange(times[0], times[-1], 1.0 / fps)
        if len(grid) < int(MIN_SECONDS * fps):
            self.bpm, self.confidence = None, 0.0
            return self.bpm, self.confidence
        signal = np.interp(grid, times, values)

        # detrend: remove slow drift (everything below ~0.4 Hz) via moving average
        win = max(3, int(fps * 1.5)) | 1  # odd window ~1.5s
        kernel = np.ones(win) / win
        detrended = signal - np.convolve(signal, kernel, mode="same")

        # window + FFT
        windowed = detrended * np.hanning(len(detrended))
        spectrum = np.abs(np.fft.rfft(windowed))
        freqs = np.fft.rfftfreq(len(windowed), d=1.0 / fps)

        band = (freqs >= HZ_MIN) & (freqs <= HZ_MAX)
        if not band.any() or spectrum[band].sum() <= 0:
            self.bpm, self.confidence = None, 0.0
            return self.bpm, self.confidence

        band_freqs = freqs[band]
        band_power = spectrum[band]
        peak_idx = int(np.argmax(band_power))
        total = band_power.sum()
        confidence = float(band_power[peak_idx] / total)

        if confidence < MIN_CONFIDENCE:
            self.bpm, self.confidence = None, confidence
            return self.bpm, self.confidence

        bpm = float(band_freqs[peak_idx] * 60.0)

        # reject absurd jumps (motion artefact): keep last value if > 25 BPM away
        if self._smoothed_bpm and abs(bpm - np.median(self._smoothed_bpm)) > 25:
            self.bpm, self.confidence = (
                float(np.median(self._smoothed_bpm)) if self._smoothed_bpm else None,
                confidence * 0.5,
            )
            return self.bpm, self.confidence

        self._smoothed_bpm.append(bpm)
        self.bpm = float(np.median(self._smoothed_bpm))
        self.confidence = confidence
        return self.bpm, self.confidence


def forehead_roi_mean(gray_or_frame: "np.ndarray", face_box: tuple[float, float, float, float]) -> float:
    """Mean green intensity of the forehead strip.

    Args:
        frame: BGR frame (H, W, 3)
        face_box: (x, y, w, h) of the detected face in pixels
    Returns the mean of the green channel over the forehead strip, or NaN on
    an empty crop.
    """
    import cv2

    x, y, w, h = face_box
    x0 = int(x + 0.25 * w)
    x1 = int(x + 0.75 * w)
    y0 = int(y + 0.04 * h)
    y1 = int(y + 0.38 * h)
    if x1 <= x0 or y1 <= y0:
        return float("nan")
    crop = gray_or_frame[y0:y1, x0:x1, 1]  # green channel
    if crop.size == 0:
        return float("nan")
    return float(crop.mean())
