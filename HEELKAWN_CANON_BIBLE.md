# HEELKAWN CANON BIBLE

Status: Living canonical summary
Scope: Repository-wide recovery guide for future human and AI maintainers

## Purpose

HeelKawn is a deterministic simulation universe. This document is the shortest useful map of what the project is, what must never change, and where the authoritative details live.

## Current Project State

- Current branch: `main`
- Current restored snapshot: `cff67a5`
- Current overall phase: Kernel-first maintenance with later support systems already present
- Active priority: stabilize and preserve the deterministic kernel contract

## Canonical Read Order

1. `docs/lore/UNIVERSE_CONSTITUTION.md`
2. `docs/lore/METAPHYSICS.md`
3. `docs/HEELKAWN_STATE.md`
4. `docs/WORLD_BIBLE/MASTER_INDEX.md`
5. `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md`

## Non-Negotiable Laws

- Deterministic history: identical conditions must produce identical outcomes.
- Facts first: `WorldMemory` records objective events before any interpretation layer runs.
- Meaning is derived: `WorldMeaning` and related layers may summarize but may not rewrite history.
- Persistence is earned: scars, ruins, reputation, and continuity must emerge from recorded cause and effect.
- The player is primarily an observer/chronicler; incarnation is a secondary mode.

## Current Kernel Contract

- `autoloads/WorldMemory.gd` is the append-only factual ledger.
- `autoloads/WorldMeaning.gd` derives regional meaning from recorded facts.
- `autoloads/WorldPersistence.gd` applies lasting consequences to the world.
- `autoloads/PersistenceSystem.gd` tracks durable entities and their survival pressure.
- `autoloads/CulturalMemory.gd` turns history into deterministic regional identity.

## Current Design Focus

1. Kernel correctness and replayability.
2. Settlement revival vs permanent ruin boundaries.
3. Lineage and cultural memory continuity.
4. Observer/chronicler readability.
5. PVABazaar / external sync only after the kernel is stable.

## Recovery Notes

- If this repo feels empty, first verify whether the visible folder is the actual git checkout or a partial workspace mirror.
- If history is missing, rebuild from `main` and then read the world-bible files before editing code.
- If a proposed change conflicts with the constitution, block it and document the conflict instead of forcing it through.
