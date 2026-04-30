# Session report pack (paste to AI after each run)

Use this **compact pack** so anyone (human or AI) can see what fired, what stalled, and where the world is in time — without drowning in logs.

**Terminology:** A **Heelkawnian** is any embodied citizen (NPC today; player incarnation uses the same `Pawn` / `PawnData` surface). The simulation clock and facts are the shared “matrix”; the right-hand sheet is the in-world face.

## Always paste (every session, any length)

1. **One line of context** (you type):
   - World seed (from reroll / note), game speed you used most, about how many in-game days, anything weird you saw.

2. **F10 → `ERROR · Report`** (`error_report`):
   - Copy the whole block from `=== HEELKAWN_DEBUG_REPORT:error_report:... BEGIN ===` through the matching `END` line.
   - Confirms autoloads, panel wiring, and quick syntax sanity.

3. **F10 → `31 · Playtest bundle`** (`playtest_bundle`):
   - Copy the entire block between its BEGIN and END.
   - Single best **session snapshot**: tick, sim_diag, pawn/settlement counts, PlayerIntentQueue, FactionRegistry, ReligionLens.

## Paste at milestones (pick what applies)

| When | F10 report | Why |
|------|------------|-----|
| After ~1 in-game day or first stress test | `02 · GameManager sim_diag` | Backlog / ticks-per-frame / pause truth |
| Social / bonds / meets acting up | `22 · All pawns` or `26 · Profession liking` | Per-pawn line at a glance |
| Settlement / identity / pressure | `06 · SettlementMemory` + `04 · IntentMemory` | Intent + cluster state |
| Economy / jobs / stock | `11 · Jobs + stockpile zones` | Open vs completed, zone truth |
| Long arc (~1 sim year+) | `32 · Soul bundle` | Handoff paste (trimmed stdout; still heavy) |
| One pawn for web/MMO schema | `33 · Portable character JSON` | `heelkawn_character_portable/v1` export |
| Observer / chronicler tools | `28 · PlayerIntentQueue` | Pin/focus / queue backlog |

## Optional: screenshot

- One **Colony HUD** + **Heelkawnian sheet** (selected pawn) screenshot helps UI/evolution issues.

## What the AI will answer from this

- Whether kernel-adjacent systems **loaded** and **matched tick cadence**
- Whether **jobs / settlement / intent** look consistent with your symptoms
- Whether the next fix belongs in **sim**, **UI signature**, or **content/thresholds**

---

Authoritative project pulse: `docs/HEELKAWN_STATE.md`, `HEELKAWN.txt`.
