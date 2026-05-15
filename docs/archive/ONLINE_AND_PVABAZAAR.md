# Online play and pvabazaar.org (planned)

This document records the **intended** architecture for later phases. It is not shipped functionality.

## Goals

- Optional **multiplayer or async shared worlds** without breaking deterministic local sim rules for single-player chronicle mode.
- **Narrative / history export** surfaced on **pvabazaar.org** (static chronicle pages or a small API).

## Authoritative vs summary

| Model | Pros | Cons |
|--------|------|------|
| **Authoritative server** | Single source of truth, anti-cheat | Highest operational cost |
| **Async summaries** | Cheap, works with long runs | Eventual consistency, merge rules needed |

Recommended first step: **append-only export bundles** (`WorldMemory` JSON or text) uploaded or published by the player; the site renders read-only chronicles.

## Client shape (Godot)

- Keep sim **deterministic offline**; any “online” layer consumes **exports** or **diffs**, not raw per-tick RPC, unless you commit to a full server sim.

## Web pipeline (sketch)

1. CI or local script produces `export/` artifacts (versioned schema — see `WorldMemory` history export header).
2. Static site (e.g. GitHub Pages) or small host stores JSON + markdown.
3. **pvabazaar.org** links to chronicle URLs or embeds iframe viewer.

## Security / abuse

- Treat player exports as **untrusted text**; sanitize display, cap size, no arbitrary script execution from chronicle payloads.
