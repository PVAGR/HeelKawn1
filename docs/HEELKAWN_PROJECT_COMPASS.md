# HeelKawn Project Compass

**Last updated:** May 7, 2026
**Purpose:** The single orientation document for humans and AI assistants before changing HeelKawn.

HeelKawn is a deterministic myth engine: a living world where history is computed from pawn action, memory, place, bloodline, culture, loss, and rediscovery. The project is not trying to be a conventional finished game with a narrow end state. It is meant to remain open-ended: an indefinitely deep world where HeelKawnians can move from primitive survival toward civilization, institutions, science, collapse, remembrance, and renewal.

The current priority is not to add more disconnected systems. The current priority is to make the existing world truthful, playable, inspectable, and ready to grow.

---

## Ground Truth

Use this stack when deciding what is real:

1. **Source code and Godot runtime checks** are the highest truth.
2. [HEELKAWN_BLUEPRINT.md](HEELKAWN_BLUEPRINT.md) is the canonical Persistent Simulation Universe blueprint; it is vision, not runtime proof.
3. [BUILD_INVENTORY.md](BUILD_INVENTORY.md) is the most honest built-vs-missing inventory.
4. [HEELKAWN_STATE.md](HEELKAWN_STATE.md) is the current working state and next-step file.
5. [HEELKAWNIAN_EVOLUTION_SYSTEM.md](HEELKAWNIAN_EVOLUTION_SYSTEM.md) is the long-range indefinite evolution vision.
6. Older completion reports, preflight reports, and AI session notes are historical evidence, not authority.

When docs conflict, preserve the dream but trust the running code.

---

## Current Honest Status

HeelKawn is a large playable Godot simulation prototype with a stable deterministic kernel and many integrated systems. It is **not** a 98% complete release candidate yet.

What is strong now:

- Deterministic tick/world kernel.
- World memory, meaning, persistence, and seeded RNG foundations.
- Settlement lifecycle: active, abandoned, reviving, permanent ruin.
- Pawn jobs, needs, social dynamics, knowledge, stories, and debug surfaces.
- An initial read-only civilization stage lens that derives era labels from live world state.
- Initial per-pawn HeelKawnian development profiles that derive phase, drive, next need, skill/knowledge summaries, and era context.
- Initial HeelKawnian Matrix AI job-bias wiring: derived profiles now nudge real pawn job choices and log strong Matrix decisions for auditability.
- A deep canon and design identity centered on memory, inheritance, knowledge loss, and emergent civilization.

What still needs consolidation:

- Player-facing verification in the running Godot editor.
- Full in-editor confirmation after the onboarding `RichTextLabel` runtime fix.
- Skill tree branches and deeper profession progression.
- HeelKawnian Matrix AI expanded beyond job bias into social target selection, household intent, teaching target choice, recovery plans, and settlement ambitions.
- Real lineage/child creation depth.
- Crafting material consumption connected cleanly to inventory/stockpile.
- Household, leadership, faction, governance, and religion systems moved beyond stubs.
- Chronicle/world seed export and clearer release gates.
- Documentation pruning so "complete" means "verified in-game", not merely "planned" or "stubbed".

---

## North Star

Every meaningful change should strengthen at least one of these:

- **Indefinite existence:** the world can continue across eras, disasters, memory loss, rediscovery, and rebirth.
- **Deterministic causality:** same seed and same actions produce the same history.
- **Pawn-centered emergence:** events arise from pawn behavior, relationships, places, and needs.
- **Memory with consequence:** history persists by impact, not random decay.
- **Readable meaning:** players can understand why a place, pawn, faction, ruin, book, or ritual matters.
- **Playable inspection:** the player can observe, verify, and intervene without breaking the simulation's soul.

Avoid adding isolated feature islands. Prefer wiring existing systems together so the world feels more alive.

---

## Immediate Path

The best next work is a consolidation sequence:

1. **Runtime truth pass:** run the game, use F10 diagnostics, verify UI panels, capture any red errors.
2. **HeelKawnian Matrix AI deepening:** extend the initial profile-to-job-bias bridge into learning targets, teaching targets, preservation choices, recovery behavior, household intent, and settlement ambitions.
3. **Lineage and progression:** finish parent lookup, child creation, skill tree thresholds, and inheritance hooks.
4. **Material reality:** make crafting consume real inventory/stockpile resources and require tools where intended.
5. **Knowledge preservation:** connect books, stones, teaching, literacy, and lost/rediscovered knowledge into one loop.
6. **Civilization stage foundation:** initial derived lens is live; deepen it with per-settlement tech diffusion, literacy, lifespan, and institutions.
7. **Readable exports:** generate chronicle and seed/state exports so long worlds can be remembered outside the runtime.
8. **Governance/faction/religion depth:** only after the core loop above is reliable.

---

## Rules For AI Assistants

- Read this file first, then [HEELKAWN_STATE.md](HEELKAWN_STATE.md), then [BUILD_INVENTORY.md](BUILD_INVENTORY.md).
- Do not mark a system complete unless it compiles, runs, and has at least one clear user-facing or diagnostic verification path.
- Keep all randomness routed through deterministic seeded systems such as `WorldRNG`.
- Record meaningful world changes through memory/event systems where practical.
- Prefer small, integrated improvements over grand new documents.
- Update docs when reality changes, but do not inflate completion language.
- Never remove lore or vision just because it is not implemented; label it as vision, roadmap, partial, or live.

HeelKawn should remain vast. The repo should become calm enough to carry that vastness.
