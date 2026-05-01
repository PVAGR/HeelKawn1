# Brain/ System — Owner's Guide

This page explains the `brain/` folder in plain language. You don't need to understand coding to use it.

---

## What Is This?

The `brain/` folder is a shared memory system for you and any AI tool helping with HeelKawn. It keeps track of:
- What you're currently working on
- Important decisions that were made and why
- The rules of your game universe (so the AI doesn't break them)
- A daily log of what happened

Think of it as a shared notebook between you and the AI.

---

## What Each Folder Does

| Folder | What It's For | Example |
|--------|--------------|---------|
| `memory/` | The AI's working memory — current state, knowledge, daily logs | "What were we working on last time?" |
| `memory/knowledge/` | Permanent facts about the project — architecture, decisions, changelog | "Why did we build it this way?" |
| `memory/sessions/` | Daily logs — one file per day of work | "What happened today?" |
| `lore/` | The rules of your game universe | "What are the non-negotiable rules?" |
| `automation/` | Helper scripts — scan the project, summarize changes | "What's changed recently?" |
| `adapters/` | Future connections (PVABazaar website, Ollama models) | "How do we connect to the website later?" |
| `prompts/` | Ready-made questions to paste into an AI | "Start the AI with the right context" |

---

## Files For You (Human)

These files are written for you to read and edit:

| File | What It Tells You |
|------|------------------|
| `memory/active_context.md` | **Start here** — what's happening right now |
| `memory/knowledge/tasks.md` | What needs to be done next |
| `memory/knowledge/design_decisions.md` | Why things were built the way they were |
| `memory/knowledge/code_changes.md` | What was changed and when |
| `lore/canonical.md` | The rules of your game world |
| `memory/sessions/YYYY-MM-DD.md` | What happened on a specific day |

---

## Files For AI Tools

These files are mainly for the AI to read and update. You can look at them but don't need to edit them:

| File | What The AI Does With It |
|------|------------------------|
| `memory/index.json` | Fast lookup map — the AI uses this to find things quickly |
| `automation/scan-repo.ps1` | Scans the project and reports what's there |
| `automation/summarize.ps1` | Creates a summary of today's work |
| `automation/apply-edit.ps1` | Makes safe code changes with a backup point |

---

## Files You Can Ignore For Now

These exist for future features. You can safely ignore them until you need them:

| File/Folder | When You'll Need It |
|-------------|-------------------|
| `adapters/pvabazaar/` | When you're ready to connect the game to your website |
| `adapters/ollama/models.md` | Only if you want to change AI model settings |
| `prompts/code-review.md` | When you want the AI to double-check its own work |
| `prompts/lore-recall.md` | When you want the AI to check game rules before making a change |

---

## How To Use This Day To Day (Simple Steps)

### Before asking an AI to work on HeelKawn:

1. Open `brain/memory/active_context.md` and check what the current task is
2. Open your AI tool (Cursor, Copilot, etc.)
3. Open `brain/prompts/session-start.md` and copy the text
4. Paste it into the AI

That's it. The AI will read everything it needs and know what to do.

### After the AI does some work:

1. Check `brain/memory/sessions/today's-date.md` to see what it did
2. Check `brain/memory/knowledge/code_changes.md` to see what files changed
3. Update `brain/memory/active_context.md` if you want to change the next task

### If something goes wrong:

1. The AI should have created a backup point before editing code
2. You can undo the last change using the normal "undo" in your code editor
3. Or ask the AI to fix it — it can see what it changed in the session log

### Adding a new task:

1. Open `brain/memory/knowledge/tasks.md`
2. Add a line under "Pending" like: `- [ ] Make the colony HUD show food storage`
3. Next time you talk to the AI, it will see it

---

## One Thing To Remember

The AI will update these files automatically as it works. You only need to:
- Read `active_context.md` before starting
- Paste the session-start prompt
- Check the session log afterward to see what happened

Everything else runs itself.
