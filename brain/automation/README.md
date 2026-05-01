# HeelKawn Universe Brain — Automation Scripts

Helper scripts for AI-assisted development.

## scan-repo.ps1
Scans the repository and produces a context summary for AI assistants.

**Usage:**
```powershell
powershell -File brain/automation/scan-repo.ps1
```

**Output:** Prints a summary of:
- File counts by type
- Recent git changes
- Autoload count
- Key system status
- Any ERROR/WARNING patterns in logs

## summarize.ps1
Generates a session summary from the day's changes.

**Usage:**
```powershell
powershell -File brain/automation/summarize.ps1
```

**Output:** Creates or updates `brain/memory/sessions/YYYY-MM-DD.md` with:
- Files changed today
- Summary of changes from git diff
- Current project state

## apply-edit.ps1
Safely applies a code edit with automatic git checkpoint and rollback capability.

**Usage:**
```powershell
powershell -File brain/automation/apply-edit.ps1 -File "path/to/file.gd" -Description "What changed"
```

**What it does:**
1. Creates a git stash checkpoint of current state
2. Records the edit in the session log
3. After confirmation, commits with the provided description
4. If something goes wrong: `git stash pop` to rollback
