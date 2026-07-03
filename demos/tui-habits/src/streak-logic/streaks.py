"""Pure streak computations over lists of ISO date strings."""
from datetime import date, timedelta


def _dates(dates):
    return sorted({date.fromisoformat(d) for d in dates})


def current_streak(dates, today):
    """Consecutive-day run ending at today (or yesterday if today unmarked)."""
    ds = set(_dates(dates))
    t = date.fromisoformat(today) if isinstance(today, str) else today
    d = t if t in ds else t - timedelta(days=1)
    n = 0
    while d in ds:
        n += 1
        d -= timedelta(days=1)
    return n


def best_streak(dates):
    """Longest consecutive-day run anywhere."""
    ds = _dates(dates)
    best = run = 0
    prev = None
    for d in ds:
        run = run + 1 if prev is not None and d - prev == timedelta(days=1) else 1
        best = max(best, run)
        prev = d
    return best
