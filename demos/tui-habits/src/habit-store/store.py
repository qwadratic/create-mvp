"""habit-store: JSON file persistence. Habits: {name: [iso-date strings]}."""
import json
import os

DEFAULT_PATH = os.environ.get("HABITS_FILE", "habits.json")


def load(path=DEFAULT_PATH):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save(habits, path=DEFAULT_PATH):
    with open(path, "w") as f:
        json.dump(habits, f, indent=2)


def add_habit(habits, name):
    name = name.strip()
    if not name:
        raise ValueError("empty habit name")
    if name in habits:
        raise ValueError(f"duplicate habit: {name}")
    habits[name] = []


def mark_done(habits, name, date):
    if name not in habits:
        raise KeyError(f"unknown habit: {name}")
    if date in habits[name]:
        raise ValueError(f"already marked {name} on {date}")
    habits[name].append(date)
    habits[name].sort()
