# AI Assistant Handoff Prompt for GPT

**Subject: HeelKawn1 Performance Optimization - Bundle 4 Implementation**

Hello GPT,

I'm **Cline**, your AI collaborator working on the **HeelKawn1** project. I'm currently implementing **TRUE 100x BUNDLE 4 — Pawn Tick Shell Reduction** and need to hand off context for potential continuation or review.

## About Me & My Capabilities

I'm an AI assistant specialized in:
- **Godot 4.6 development** with deep understanding of GDScript, scene systems, and performance optimization
- **Deterministic simulation architecture** - I understand and enforce the kernel rules
- **Performance profiling and optimization** - I've already completed Bundles 1-3
- **Code analysis and refactoring** - I can inspect, classify, and restructure complex systems
- **Systematic problem-solving** - I follow structured approaches like the lane-gating pattern

## Project Context: HeelKawn1

**HeelKawn** is a deterministic 2D world simulation built in Godot 4.6. It's a living myth engine where:
- History is computed, not scripted
- Memory does not decay randomly
- Persistence is earned strictly by impact
- The kernel must be replayable and auditable

**Current Status:**
- Phase 5 (Emergent Life) - ~80% complete
- Kernel health: 🟢 Stable
- Performance: Stable at 100x speed (our optimization target)
- Recent work: Bundles 1-3 of the TRUE 100x optimization series completed

## Current Task: Bundle 4 - Pawn Tick Shell Reduction

**Goal:** Reduce per-pawn per-tick cost while preserving pawn correctness.

**Primary File:** `scripts/pawn/HeelKawnian.gd`

**Approach:** Split pawn logic into deterministic lanes:
1. **Critical every-tick** - death safety, player input, active combat/work
2. **Medium lane** (every 5-15 ticks) - job search, AI state selection
3. **Slow lane** (every 30-120 ticks) - nearby scans, social refresh, narrative
4. **Cached/proximity** - replace repeated group scans with cached results

**Key Constraints:**
- Do NOT slow 100x
- Do NOT drop ticks
- Do NOT fake speed
- Do NOT hide backlog
- Do NOT randomly skip simulation
- Do NOT move world truth into UI
- Maintain determinism (no randomness, stable-id/tick lanes only)

**Accepted Previous Bundles:**
- Bundle 1: Hidden backlog dropping removed, batched pawn brain work
- Bundle 2: Path cache, phase-spread animal AI, gated combat prints
- Bundle 3: Alive pawn accessors, cached job counts, ~1.11 ratio improvement

## What I Need From You

If you're continuing this work:

1. **Read the analysis** I've prepared in the task description
2. **Understand the classification system** for `_on_world_tick` blocks
3. **Apply the lane-gating pattern** using stable tick IDs
4. **Preserve all critical safety rules** (death, player control, combat, work completion)
5. **Test thoroughly** - headless boot, main scene, parse errors, runtime errors, benchmark

If you're reviewing:

1. **Verify determinism** - no uncontrolled randomness, no pawn skipped forever
2. **Check safety** - critical paths remain every-tick
3. **Validate performance** - expected improvement in per-pawn tick cost
4. **Ensure compatibility** - Bundles 1-3 remain intact

## Key Files & References

**Must Read:**
- `AI_README.md` - Foundational philosophy and rules
- `docs/HEELKAWN_STATE.md` - Current project status
- `HEELKAWN.txt` - Quick context and git workflow

**Primary Implementation:**
- `scripts/pawn/HeelKawnian.gd` - Main pawn logic
- `scripts/pawn/Pawn.gd` - Base pawn class (check if active)
- `scripts/pawn/PawnSpawner.gd` - Pawn lifecycle management

**Related Systems (DO NOT MODIFY):**
- `TickManager.gd` - Speed/backlog policy
- `Main.gd` - Core tick loop
- `SurvivalSystem.gd` - Needs already batched
- `PawnBrainBridge.gd` - Brain work already batched
- `PathFinder.gd` - Path caching already implemented
- `Animal.gd` / `Enemy.gd` - Already phase-spread
- `WorldMemory` / `WorldMeaning` / `WorldPersistence` - Core memory systems

## Expected Deliverables

When work is complete, provide:

1. **Modified `HeelKawnian.gd`** with lane-gated logic
2. **Bundle 4 Report** following the required format:
   - Files changed
   - Tick classification results
   - New constants/helpers
   - Work moved out of every tick
   - Nearby/group scan reductions
   - Job/path changes
   - Debug/logging changes
   - Determinism check
   - Test results
   - Gameplay sanity check
   - Expected 100x improvement
   - Remaining blockers
   - Next recommended bundle

3. **Git commit** with clear message and push to `origin/main`

## My Working Style

- **Methodical** - I analyze before implementing
- **Conservative** - I preserve existing working systems
- **Thorough** - I test and verify changes
- **Documented** - I provide clear reports
- **Respectful** - I follow project conventions and constraints

## If You Encounter Issues

1. **Check determinism** - Is any randomness uncontrolled?
2. **Check safety** - Are critical paths preserved?
3. **Check performance** - Is the lane interval appropriate?
4. **Check compatibility** - Does this break Bundles 1-3?
5. **Ask for clarification** - The project has deep context

## Final Note

This is a **living, evolving simulation** - never finished, always improving. Our goal is to make 100x speed truly playable while maintaining the deterministic kernel that makes HeelKawn unique.

**Remember:** The world is a machine of cause and effect. If the same things happen, the same history emerges.

Good luck, and may your optimizations be swift and safe!