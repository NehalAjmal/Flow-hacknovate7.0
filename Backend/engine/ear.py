import numpy as np


# ─────────────────────────────────────────────
# CORE EAR COMPUTATION
# ─────────────────────────────────────────────

def compute_ear(eye_points: np.ndarray) -> float:
    """
    Compute Eye Aspect Ratio (EAR)

    eye_points: np.array of shape (6, 2)
    indices order:
        [p1, p2, p3, p4, p5, p6]

    Returns:
        float EAR value
    """

    if eye_points.shape != (6, 2):
        raise ValueError("eye_points must be shape (6,2)")

    # vertical distances
    A = np.linalg.norm(eye_points[1] - eye_points[5])
    B = np.linalg.norm(eye_points[2] - eye_points[4])

    # horizontal distance
    C = np.linalg.norm(eye_points[0] - eye_points[3])

    if C == 0:
        return 0.0

    ear = (A + B) / (2.0 * C)
    return float(ear)


# ─────────────────────────────────────────────
# BOTH EYES COMBINED
# ─────────────────────────────────────────────

def compute_avg_ear(left_eye: np.ndarray, right_eye: np.ndarray) -> float:
    """
    Compute average EAR from both eyes
    """
    left = compute_ear(left_eye)
    right = compute_ear(right_eye)

    return (left + right) / 2.0


# ─────────────────────────────────────────────
# NORMALIZATION (optional but useful)
# ─────────────────────────────────────────────

def normalize_ear(ear: float, baseline: float) -> float:
    """
    Normalize EAR based on baseline

    Returns:
        ratio (0–1+)
    """
    if baseline is None or baseline == 0:
        return 1.0

    return ear / baseline


# ─────────────────────────────────────────────
# STATE DETECTION HELPERS
# ─────────────────────────────────────────────

def is_eye_closed(ear_ratio: float, threshold: float = 0.75) -> bool:
    """
    Determine if eye is closed based on normalized EAR
    """
    return ear_ratio < threshold