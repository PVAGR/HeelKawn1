# CANON + SYSTEMS FEATURE QUEUE

Purpose: convert old-doc universe history and legacy design language into actionable, phase-aligned implementation targets without reviving stale engineering assumptions.

Authority:
- Canon/state truth: `docs/HEELKAWN_STATE.md`
- Active chronology and shipped changes: `HEELKAWN.txt`
- Legacy context reference: `HEELKAWN_INTEGRATION.md` (historical only)

## Immediate Queue (execute first)

1. [done 2026-04-30] Canon glossary normalization pass
   - Map legacy terms ("neural matrix", "civilization layer", "monitoring") to currently supported systems and terms in world-bible files.
   - Update: `docs/WORLD_BIBLE/GLOSSARY.md`
   - Exit criteria: each reused legacy term has one canonical definition and one implementation anchor.

2. [done 2026-04-30] Era hooks to simulation events
   - Turn open hooks in `TIMELINE.md` into measurable triggers based on existing facts (revival, conflict recurrence, identity divergence).
   - Update: `docs/WORLD_BIBLE/TIMELINE.md`
   - Exit criteria: every hook includes a detection condition tied to `WorldMemory`/settlement state.

3. [done 2026-04-30] Region-to-faction canon bridge
   - Connect `REGIONS.md` tendencies to `FACTIONS.md` identity seeds with deterministic causes (scar profile, conflict profile, recovery profile).
   - Update: `docs/WORLD_BIBLE/REGIONS.md`, `docs/WORLD_BIBLE/FACTIONS.md`
   - Exit criteria: each seed faction points to at least one region archetype and one supporting history profile.

## Near-Term Systems Queue

0. [new 2026-05-28] Egregore + Matrix coupling baseline
   - Define deterministic runtime contract for collective-belief pressure (egregore) coupled to existing matrix/simulation layers.
   - Spec added: `docs/WORLD_BIBLE/EGREGORE_MATRIX_RUNTIME_SPEC.md`
   - Next implementation anchor: new `EgregoreMemory` autoload + bounded decision bias integration.
   - Exit criteria: deterministic replay-safe pressure accumulation visible via read-only diagnostics and reflected in at least one pawn decision channel.

1. Cultural architecture signature set (Phase 4 target) ✅ DOCUMENTED
   - Status: SPECIFIED in docs/WORLD_BIBLE/GLOSSARY.md (Architecture Signature Constants table)
   - Implementation exists in autoloads/SettlementPlanner.gd with OPEN/CAUTIOUS/DEFENSIVE branches
   - Exit criteria: Documented with implementation anchor — COMPLETE

2. [done 2026-04-30] Player-readable meaning refinement packet
   - Specify non-text-forward cues for quiet/scarred/bloodied/grave transitions (audio, ambiance, behavior density, settlement posture).
   - Update: docs/PLAYER_READABLE_MEANING_SPEC.md (spec), autoloads/MeaningAudioCue.gd (audio), scripts/pawn/Pawn.gd (behavior), scripts/world/TileFeature.gd (visual posture)
   - Exit criteria: All 4 cue types implemented with deterministic behavior — COMPLETE

3. [done 2026-04-30] Revival storyline constraints
   - Document canon-safe revival boundaries so rebirth behavior remains emergent but interpretable (no heroic script overrides).
   - Update: docs/WORLD_BIBLE/TIMELINE.md (boundaries section), docs/WORLD_BIBLE/CANON_CHANGELOG.md (entry)
   - Exit criteria: All revival gates documented with implementation anchors — COMPLETE

## Legacy-to-Current Mapping Notes

- Keep legacy integration claims as inspiration, not runtime guarantees.
- Promote only concepts that can be expressed as:
  - append-only facts,
  - derived meaning,
  - deterministic (seeded) simulation behavior.
- Reject concepts that require hidden scripting or non-auditable state changes.
