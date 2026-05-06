# World Event Seed System (WESS)

Summary
- Introduce a deterministic, data-driven seed system to drive emergent WorldRichness events (WORLD-001 to WORLD-004). Seeds generate events (seasonal, social, environmental) that interact with pawns, settlements, and memory, producing emergent narratives without scripting each outcome.

Why this fits HeelKawn
- Forges deeper emergent life by letting the world co-create events from seeds tied to state: biome, settlement identity, proximity networks, and memory history. Supports the vision of a living, readable world where stories arise from cause/effect rather than hand-authored narratives.

Design goals
- Deterministic seeds produced from stable inputs (settlement_id, biome, region signature, tick seed). No randomness beyond deterministic seeding.
- Seeds produce events that are logged in WorldMemory and meaning is updated in WorldMeaning.
- Seeds enable repeatable playthroughs with different emergent outcomes depending on history, not random variance.

Core concepts
- Seed types: SeasonalSeed, SocialSeed, EnvironmentSeed. Each type yields a family of events and publishes to WorldMemory.
- Seed registry: WorldEventSeedManager (autoload) holds seed definitions and current state per seed_id.
- Event integration: events trigger changes in pawns, gossip, grudges, rituals, or settlement dynamics; all are logged and deduced by WorldMeaning.

Data model (simplified)
- SeedRecord: { id: String, type: String, seed_value: Int, last_tick: Int, emitted: Int, params: Dictionary }
- EventPayload: { event_type: String, data: Dictionary, timestamp: Int, related_seed: String }

API surface (to be implemented)
- WorldEventSeedManager.get_seed(seed_id: String) -> SeedRecord
- WorldEventSeedManager.advance_all_seeds(current_tick: int) -> Array of EventPayload
- WorldEventSeedManager.emit_event_for_seed(seed_id, payload) -> void (writes to WorldMemory)

Prototype plan (phases)
- Phase 1: Implement SeedRegistry with two seeds (SeasonalSeed and SocialSeed) and basic emission on each tick batch.
- Phase 2: Hook seeds into WorldMemory writing; update WorldMeaning based on new events.
- Phase 3: Add a simple UI hook to observe seeds and emitted events (debug mode).

Risks & Mitigations
- Determinism risk: ensure all seed calculations rely on WorldRNG or tick seeds and do not read real-time data.
- Clutter risk: keep event definitions minimal and extensible; log all events to WorldMemory with explicit types.

Related Decisions
- DEC-001 Deterministic Kernel, DEC-002 WorldMemory, DEC-003 Pawn-Activated Events, DEC-004 UI Polling Interval, DEC-005 Consciousness Tab Location.

Next steps
- Create skeleton WorldEventSeed.gd and WorldEventSeedManager.gd autoloads.
- Wire Phase 1 seeds into WORLD events and log first few seed-driven outputs.

End
