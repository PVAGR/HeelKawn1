# TASKS

## DONE

- Restored the repository to the fullest known historical snapshot on `main`.
- Re-established the deterministic kernel authoring context for future sessions.
- Synced the visible workspace with the restored repository snapshot.
- Fixed persistence decay threshold ordering in `autoloads/PersistenceSystem.gd`.
- Fixed settlement rebirth so revival can run even when no living pawns remain.
- Fixed Pawn parser blockers and added PawnData cleanup for warning reduction.
- Added the Phase 4 settlement lifecycle machine with deterministic revival and ruin thresholds.

## IN PROGRESS

- Canonical startup documentation cleanup.
- Kernel contract review for WorldMemory / WorldMeaning / WorldPersistence.
- Full-run validation of the settlement lifecycle transition path.

## NEXT

- Harden the kernel contract where meaning and persistence read from world facts.
- Add missing kernel-facing documentation if a code path lacks an authoritative spec.
- Verify settlement lifecycle boundaries against the current canonical constraints.

## FUTURE

- Observer/chronicler tooling improvements.
- Lineage and cultural continuity polish.
- PVABazaar integration and export adapters.
- Long-horizon automation helpers under `/ai/`.
