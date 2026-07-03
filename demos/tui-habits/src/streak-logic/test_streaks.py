from streaks import current_streak, best_streak

T = "2026-07-03"

# empty
assert current_streak([], T) == 0
assert best_streak([]) == 0

# today only
assert current_streak(["2026-07-03"], T) == 1

# today not yet marked, yesterday marked -> streak alive
assert current_streak(["2026-07-01", "2026-07-02"], T) == 2

# gap before yesterday
assert current_streak(["2026-06-29", "2026-07-01", "2026-07-02", "2026-07-03"], T) == 3

# last mark two days ago -> dead
assert current_streak(["2026-07-01"], T) == 0

# duplicates + unsorted input
assert current_streak(["2026-07-03", "2026-07-02", "2026-07-02"], T) == 2

# best streak across gaps
assert best_streak(["2026-06-01", "2026-06-02", "2026-06-03", "2026-06-10", "2026-06-11"]) == 3
assert best_streak(["2026-06-05"]) == 1

# best not necessarily current
d = ["2026-06-20", "2026-06-21", "2026-06-22", "2026-06-23", "2026-07-02", "2026-07-03"]
assert best_streak(d) == 4
assert current_streak(d, T) == 2

print("streak-logic: all tests passed")
