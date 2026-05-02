# TASKS

## DONE

- Restored the repository to the fullest known historical snapshot on `main`.
- Re-established the deterministic kernel authoring context for future sessions.
- Synced the visible workspace with the restored repository snapshot.
- Fixed persistence decay threshold ordering in `autoloads/PersistenceSystem.gd`.
- Fixed settlement rebirth so revival can run even when no living pawns remain.

## IN PROGRESS

- Canonical startup documentation cleanup.
- Kernel contract review for WorldMemory / WorldMeaning / WorldPersistence.

## NEXT

- Harden the kernel contract where meaning and persistence read from world facts.
- Add missing kernel-facing documentation if a code path lacks an authoritative spec.
- Verify settlement revival boundaries against the current canonical constraints.

## FUTURE

- Observer/chronicler tooling improvements.
- Lineage and cultural continuity polish.
- PVABazaar integration and export adapters.
- Long-horizon automation helpers under `/ai/`.
