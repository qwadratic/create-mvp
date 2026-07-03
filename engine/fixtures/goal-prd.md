# Todo app — PRD

## Scope
Single-user todo web app. python3 stdlib + sqlite3 only. Frontend: server-rendered HTML, no JS frameworks.

## Features
1. Create task: title (1-200 chars, required), optional due date (ISO 8601).
2. Toggle complete / reopen.
3. Delete task (hard delete).
4. List view: open tasks first, then completed; each group sorted by due date ascending, undated last.

## Acceptance criteria
- POST with empty title returns 400 and re-renders form with an inline error; nothing is written to the DB.
- Due date must parse as YYYY-MM-DD; invalid input returns 400.
- Completing an already-completed task is a no-op (idempotent), returns 200.
- Deleting a nonexistent task id returns 404.
- DB schema created on first run; restart preserves all tasks.

## Edge cases
- Title with HTML/script content must render escaped (XSS-safe).
- Concurrent toggles on the same task must not corrupt state (last write wins is acceptable).
- Empty list state shows a friendly "no tasks" message, not an empty table.

## Non-goals
Auth, multi-user, pagination, tags.
