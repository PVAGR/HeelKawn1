# HeelKawn Universe Brain

The local-first AI development brain for the HeelKawn project. It remembers lore, design decisions, code changes, and tasks across sessions so any AI assistant can pick up where the last one left off.

---

## Quick Start (5 minutes)

### Step 1: Make sure Ollama is running

1. Open your Start menu and launch **Ollama**
2. Wait for the Ollama icon to appear in your system tray (near the clock)
3. Test it by opening a command prompt and typing: `ollama list`

If you see an error or Ollama isn't installed:
- Download from [ollama.com](https://ollama.com)
- Run the installer
- Launch it

### Step 2: Download the coding model

Open a command prompt and run:
```
ollama pull qwen2.5-coder:7b
```

This downloads a 4.7 GB model optimized for code understanding and generation. For a smaller/faster model, use `qwen2.5-coder:1.5b` instead (1.1 GB).

### Step 3: Verify it works

```
ollama run qwen2.5-coder:7b "What is GDScript?"
```

You should get a text response about GDScript. Press `Ctrl+D` to exit.

### Step 4: Start working with an AI assistant

When you open an AI coding tool (Cursor, Roo Code, Copilot, etc.), tell it:

> "Read brain/README.md first, then follow brain/prompts/session-start.md to begin."

The AI will automatically load the brain's memory, understand the current state, and know what to work on.

---

## How It Works

```
brain/
├── README.md              ← You are here
├── memory/                ← The AI's long-term memory
│   ├── active_context.md  ← What we're working on RIGHT NOW
│   ├── knowledge/         ← Permanent facts about the project
│   ├── sessions/          ← Daily session logs
│   └── index.json         ← Fast lookup for the AI
├── lore/                  ← Canonical universe truth
├── automation/            ← Helper scripts
├── adapters/              ← Future integrations (PVABazaar, etc.)
└── prompts/               ← One-click starter prompts for AI
```

### Memory Flow

1. **Before work**: AI reads `active_context.md` + `knowledge/` to understand current state
2. **During work**: AI logs changes to `knowledge/code_changes.md`
3. **After work**: AI writes a summary to `memory/sessions/YYYY-MM-DD.md`
4. **Next session**: New AI reads the latest session log and picks up where the last one left off

### Lore Flow

The `lore/` folder contains the canonical truth about the HeelKawn universe. Before making any change that affects game design, story, or world rules, the AI must check `lore/canonical.md` first.

---

## For AI Assistants

When you are loaded into this project, follow this order:

1. Read `brain/README.md` (this file)
2. Read `brain/memory/active_context.md` (current work)
3. Read `brain/memory/index.json` (knowledge map)
4. Read relevant `brain/memory/knowledge/*.md` files
5. Read `brain/lore/canonical.md` (universe truth)
6. Read `docs/HEELKAWN_STATE.md` (project state — always wins on conflicts)
7. Read `HEELKAWN.txt` (session handoff)
8. Then begin work

**After completing work:**
1. Update `brain/memory/active_context.md` with new status
2. Append to `brain/memory/knowledge/code_changes.md`
3. Create/update `brain/memory/sessions/YYYY-MM-DD.md`
4. Update `brain/memory/index.json` if new knowledge was added

---

## Available Models

| Model | Size | Speed | Best For |
|-------|------|-------|----------|
| `qwen2.5-coder:1.5b` | 1.1 GB | Fast | Quick edits, small changes |
| `qwen2.5-coder:7b` | 4.7 GB | Medium | General coding (recommended) |
| `qwen2.5-coder:32b` | 20 GB | Slow | Complex architecture, deep analysis |

See `brain/adapters/ollama/models.md` for details.

---

## Safety Rules

- **Never** break the deterministic kernel (see `lore/canonical.md`)
- **Always** use `brain/automation/apply-edit.ps1` for code changes (creates git checkpoint first)
- **Never** commit or push without asking the user
- **Always** read `docs/HEELKAWN_STATE.md` before modifying code
- **Never** invent lore that contradicts `docs/WORLD_BIBLE/`

---

## Future Integrations

- **PVABazaar.org**: Async world export for web chronicles (see `brain/adapters/pvabazaar/`)
- **Vector memory**: Semantic search over lore and code (future — requires ChromaDB or similar)
- **Autonomous coding**: Self-directed task execution from task queue (future)
