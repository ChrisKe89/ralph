# Codex Mode Smoke Test (Manual)

This is a lightweight, repeatable manual test plan to verify Ralph’s `--tool codex` path works end-to-end: the prompt is loaded, Codex runs, strict sentinel detection works, and tracking files update.

## Prerequisites

- Bash environment (macOS/Linux/WSL/Git Bash)
- `codex` CLI installed and authenticated

## Setup a throwaway test workspace

```bash
mkdir -p /tmp/ralph-codex-smoke
cd /tmp/ralph-codex-smoke

# Copy Ralph runner + Codex prompt template
cp /path/to/ralph/ralph.sh .
cp /path/to/ralph/CODEX.md .
chmod +x ./ralph.sh
```

Create a single small task in `TODO.md`:

```md
- [ ] Task - Codex smoke: create artifact and update progress
  **Acceptance Criteria**
  * Create `smoke-artifact.txt` containing exactly `ok` (with a trailing newline)
  * Append a line `smoke: ok` to `progress.txt`
```

## Run one iteration

```bash
./ralph.sh --tool codex 1
```

## Verify

- Ralph exits with success and prints `Ralph completed all tasks!` (typically “Completed at iteration 1 of 1”).
- `CODEX.md` was used: inspect `.ralph/iter-1.meta.txt` (it should show the `codex exec ... < CODEX.md` command).
- Codex ran and strict sentinel detection worked:
  - `.ralph/iter-1.last-message.txt` contains a line that is exactly `<promise>COMPLETE</promise>`.
- The task completed and tracking updated:
  - `TODO.md` now has `- [x]` for the task.
  - `smoke-artifact.txt` exists and contains `ok`.
  - `progress.txt` contains `smoke: ok`.
