# CHANGELOG

## 2026-05-02

- Fixed remaining Pawn parser blockers so the class now reloads cleanly.
- Cleaned up PawnData warning patterns and marked the unused tick parameter explicitly.
- Added the Phase 4 settlement lifecycle machine with deterministic abandoned, reviving, and permanent ruin states.

## 2026-05-01

- Restored `main` to the fullest verified historical snapshot (`cff67a5`).
- Rehydrated the visible workspace from the restored repository checkout.
- Added root maintenance docs for canonical startup, task tracking, and changelog continuity.
- Fixed `PersistenceSystem` decay threshold ordering so older entities now decay more strongly than recently visited ones.
- Fixed `SettlementRebirth.process()` so revival can proceed even when the world has zero living pawns.
