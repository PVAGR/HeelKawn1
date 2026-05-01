# Design Decisions

## Why These Choices Were Made

### Deterministic Kernel
**Decision:** All world history is deterministic. No unseeded RNG in sim paths.
**Why:** The world must be reproducible. Every event has a traceable cause. Seeded variety (WorldRNG) is allowed for initial conditions, but history itself is cause-and-effect only.
**Impact:** Players can share world seeds and get identical histories. Debugging is possible because every outcome is traceable.

### Append-Only Memory
**Decision:** WorldMemory records facts as append-only entries, never overwrites.
**Why:** History cannot be erased. Death, conflict, and loss are permanent. This matches the game's themes of legacy and incompleteness.
**Impact:** Memory grows over time. Queries scan history. Performance optimizations (budgets, cursors) are needed for long runs.

### Player as Observer
**Decision:** Player cannot command pawns. Player watches, inspects, and records.
**Why:** The world is not about the player. It exists independently. The player is a chronicler of emergent stories.
**Impact:** UI focuses on observation tools (HUD, inspector, chronicle) rather than control interfaces.

### Settlements Are Autonomous
**Decision:** Settlements plan, build, trade, and evolve without player input.
**Why:** The world must feel alive even when unobserved. Settlements should develop unique identities.
**Impact:** SettlementPlanner runs on intervals. SettlementMemory tracks individual settlement history. Identity divergence creates cultural variation.

### Collapse and Rebirth
**Decision:** Settlements can die and be reborn. Memory degrades into form, not explanation.
**Why:** Impermanence is a core theme. What survives is shaped by what was lost, not a perfect record.
**Impact:** SettlementRebirth system tracks revival thresholds. RemnantMemory preserves fragments of dead settlements.

### No Morality System
**Decision:** No good/evil alignment. Emergent behavior from pressure and scarcity.
**Why:** Real conflict comes from competing needs, not abstract morality. The world should feel grounded.
**Impact:** Pawn decisions are driven by hunger, rest, safety, social bonds — not ethical frameworks.

### Performance Over Features
**Decision:** Extensive smoothing, throttling, and budgeting systems.
**Why:** Long simulation runs at high speeds (50x, 100x) cause massive hitches without guardrails.
**Impact:** Every periodic system has speed-aware cadences, scan budgets, and phase offsets.

### File-Based AI Memory
**Decision:** AI context lives in markdown files, not databases or cloud services.
**Why:** Local-first, no dependencies, human-readable, version-controlled.
**Impact:** This brain/ folder. Simple but effective for a single-developer project.
