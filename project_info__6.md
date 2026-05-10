# What else we should put in HeelKawn (based on repo canon + build inventory)

## Bottom line
The repo’s own vision repeatedly says: **don’t add disconnected feature islands—wire loops together under the deterministic kernel, ensure WorldMemory records meaningful events, and only then expand content surfaces.**  
So “what else to put in HeelKawn” is mostly: **finish the missing v1 loops** (truth verification + integrated autonomy/knowledge/lineage/material/exports), not “more gameplay features.”

## Prioritized “add / complete” list (what’s missing)
### P0 — Next v1 gates (highest priority)
1. **Runtime truth pass (in Godot editor)**
   - Headless smoke passed, but the docs explicitly require **in-editor verification** with no red runtime/UI errors before marking systems “Verified Runtime Complete.”

2. **HeelKawnian Matrix AI deepening beyond job bias**
   - Job-bias bridge is live-ish, but the repo calls out remaining gaps:
   - household intent, coordinated group plans, teaching target choice, preservation/recovery behavior, longer-horizon settlement ambitions.
   - Must remain deterministic + auditable (WorldMemory-backed).

3. **Skill trees / progression branching**
   - There are TODO slots at **levels 5/10/15/20** in `scripts/pawn/PawnData.gd`.

4. **Lineage / kinship depth + real child creation**
   - Parent lookup is a TODO and `_spawn_child_pawn` is a TODO/stub in `scripts/pawn/Pawn.gd`.

### P1 — Make current systems “feel real” via integrated loops
5. **Crafting material consumption reality**
   - Recipes exist, but crafting consumption isn’t yet connected to pawn inventory/stockpile.
   - Also requires tool/item checks (so crafting has physical constraints).

6. **Knowledge preservation loop → teaching propagation**
   - Knowledge/letters/stones exist, but teaching propagation isn’t fully wired into pawn teaching behavior.

7. **Chronicle + world seed/state export**
   - Rich Memory exists, but export is marked not implemented / not auto-generated yet.

### P2 — Expand civilization narrative layers after v1 loop cohesion
8. **Civilization-stage lens deepening**
   - Initial derived lens exists; add per-settlement diffusion, literacy, lifespan, institutions.

9. **Governance / faction / religion depth**
   - `FactionRegistry.gd` is still a stub (zone “house” only).
   - `ReligionLens.gd` is read-only, with Sacred/Myth/DRUJ/Asha etc explicitly unimplemented.

## Why this is the correct interpretation of “what else”
Because the docs + `BUILD_INVENTORY.md` mark the core missing work as **integration and auditability**:
- If a “new system” doesn’t connect into WorldMemory → WorldMeaning → player-readable effects, it won’t feel truthful or persistent.
- If AI can’t be replayed from facts (WorldMemory), it violates the deterministic myth-engine contract.

If you want, I can now go one level deeper by scanning the actual code TODO locations (especially `scripts/pawn/Pawn.gd`, `scripts/pawn/PawnData.gd`, `autoloads/CraftingSystem.gd`, `autoloads/KnowledgeSystem.gd`) to produce a “specific file-level checklist” for the above P0/P1 items.