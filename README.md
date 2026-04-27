# HeelKawn

HeelKawn is a deterministic Godot 4.6 world simulation.

- The world remembers facts and evolves without RNG in history.
- Settlements and ecology evolve autonomously.
- The player is an observer/chronicler, not a commander.

Canonical architecture flow: `WorldMemory -> WorldMeaning -> WorldPersistence -> Culture -> Behavior`.

Canonical runtime/autoload surface includes:
- `WorldMemory`, `WorldMeaning`, `WorldPersistence`, `CulturalMemory`
- `SettlementMemory`, `IntentMemory`, `AgeMemory`
- `SettlementPlanner`, `SettlementRebirth`
- `TradePlanner`, `TradeMemory`
- `RemnantMemory`, `MythMemory`, `RoadMemory`
- `SacredMemory`, `ChronicleLog`, `WorldClock`, `WorldEvents`

For canonical project state, read docs/HEELKAWN_STATE.md.
For AI operating rules, read docs/LLM_ONBOARDING.md.
For historical continuity only (not canonical state), read docs/SESSION_LOG.md.
For live phase/next-lane direction, defer to docs/HEELKAWN_STATE.md only.

Quick local run:
- `play.bat` (normal launch)
- `play_capture.bat` (launch + write `logs/playtest_latest.log` for easy sharing)
