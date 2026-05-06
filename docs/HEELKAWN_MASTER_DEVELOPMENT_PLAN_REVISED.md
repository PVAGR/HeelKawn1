# HEELKAWN: PERSISTENT SIMULATION UNIVERSE BLUEPRINT

**Status:** Canonical Vision / Not Runtime Truth

This document describes where HeelKawn is going. It must not be treated as proof that listed systems are stable or complete in the current repo until verified by Godot runtime.

---

## 1) Core Philosophy

**HeelKawn is not just a game. It is a living world simulation where every action accrues into irreversible consequence.**

Core canon phrase (non-negotiable feel):

> **Every sprite matters. Every human matters. Every choice echoes through generations.**

The player does not “win.” The player witnesses, participates, and is shaped by history.

The three pillars remain:

- **SOVEREIGNTY** — every player chooses their path.
- **AUTONOMY** — the world lives without you.
- **LEGACY** — every action is remembered.

---

## 2) Non-Negotiable HeelKawn Laws

These laws govern how we design, implement, and present systems.

- **Deterministic history:** same inputs (tick-stable) → same outcomes (within defined time windows).
- **Facts first:** `WorldMemory` records objective events before interpretation.
- **Meaning is derived:** `WorldMeaning` may summarize contextual meaning, but must not rewrite recorded facts.
- **Persistence is earned:** ruins, scars, bloodlines, reputation, and customs must emerge through cause and effect.
- **No chosen ones:** no prophecy destiny; ascent is earned through circumstance, labor, failure, and survival.
- **No morality meter:** conflict arises from scarcity, loyalties, ideology, accident.
- **No UI lies:** UI must reflect simulation truth (e.g., starvation is physical consequence, not “just morale”).
- **No random memory decay:** ledger/history remains until actively destroyed by time/conflict.
- **No victory screen as final completion:** the game cycles into a new epoch; there is no “you won HeelKawn.”
- **Players begin as ordinary humans:** rise is earned.
- **Everything matters:** every sprite can carry memory, labor, knowledge, bloodline, witness, or consequence.

---

## 3) Inspiration Translation (HeelKawn-language)

HeelKawn does not copy other games. It takes the *feeling* and rebuilds it under HeelKawn’s deterministic myth-engine laws.

- **ECO** — sovereignty + cooperation optional: independent survival with systemic rewards for coordination.
- **Kenshi / Bannerlord** — nobody-to-somebody progression and human escalation: combat is tactical, remembered, and tied to war memory.
- **Crusader Kings 3** — dynasty, lineage, inherited identity: bloodlines are continuity and burden; map colors reflect political reality.
- **RimWorld / Songs of Syx** — modern readability of individuals + governance: pawn mood and needs drive labor; settlement needs drive governance decisions.
- **Baldur’s Gate 3 / World of Warcraft** — group content for every playstyle: groups are social institutions with memory, trust, and reputations.
- **Stronghold / EVE Online** — long-lived world scale: cataclysms reshape eras; zoom changes view density, not simulation truth.
- **Arma Reforger** — every human matters: individual agency and death/casualty changes outcomes.
- **Pax Historia** — AI ambition: AI adapts through recorded facts via deterministic weight changes.
- **WorldBox** — autonomy from local resources + knowledge:** auto-build is constrained by survival/order (shelter → storage → hearth…).

---

## 4) Current Runtime Truth

**This section reflects only what we have verified by runtime.**

At the moment, **visible red runtime errors exist** (see Section 8). Therefore, any broader “complete” claims are prohibited until Godot boots cleanly.

---

## 5) Implemented but Needs Verification

Systems can be “implemented in code” but must be treated as **partial/prototype** until verified to run without red blockers.

- `OnboardingSystem.gd` exists but currently fails at runtime due to `bbcode_enabled` assignment type mismatch on a `Label`.
- World rendering improvements (e.g., tint/foliage/weather) may be present, but runtime FPS/perf stability must be measured in Godot.
- Any AI learning/adaptation must be confirmed deterministic and tick-stable before claiming “learning.”

---

## 6) Vision / TODO

The vision is the end-state *direction*.

**Core upgrade goals** (high level):

- **Auto-Build Seed (WorldBox feeling):** deterministic survival-first autonomous construction.
- **Combat Memory (Kenshi/Bannerlord feeling):** dynamic text-based combat log + wounds/recovery + morale + war reports saved to `WorldMemory`.
- **Group Institutions (BG3/WoW feeling):** groups form around work/danger/kinship/trade/teaching; they have memory, reputation, internal trust.
- **Lineage & Genetics (CK3 feeling):** genetics serve legacy, not eugenics power fantasy.
- **Governance Tools (Songs of Syx feeling):** governor roles with zone/work/storage/defense posture decisions.
- **UI Modernization (RimWorld/CK3 feeling):** modern legible 2D readability and accurate presentation.

---

## 7) Corrected Roadmap (Safer Build Order)

This roadmap is aspirational and **dependent on runtime stability**.

### Required sequence (do not skip):

1. **Fix current red Godot runtime errors**
2. **Verify the game boots clean**
3. **Confirm which systems actually run without crashing**
4. **Then build AI Autonomy** (starting small)
5. **Then Combat Overhaul**
6. **Then Group/Guild System**
7. **Then Lineage/Genetics polish**
8. **Then Governor tools**
9. **Then UI modernization**
10. **Then scale, cataclysms, launch preparation**

### 20-week timeline note

The timeline is **aspirational**, dependent on testing/performance/scope control.

---

## 8) Immediate Red Error Fixes

**Current visible red blocker:**

- `Invalid assignment of property or key 'bbcode_enabled' with value of type 'bool' on a base object of type 'Label'.`
- File: `res://autoloads/OnboardingSystem.gd`
- Stack:
  - Line 276 at `_create_tutorial_panel`
  - Line 200 at `_show_welcome_message`
  - Line 81 at `_ready`

**Likely cause:** a normal `Label` is being treated like a `RichTextLabel` (or BBCode is enabled on a non-RichText node).

**Fast safe fix:** remove/comment the `bbcode_enabled` line, or ensure the node is truly a `RichTextLabel` if BBCode is required.

---

## 9) First Safe Build Step (Phase 1A)

**Auto-Build Seed (deterministic, auditable):**

Goal: establish a stable, minimal autonomy loop without advanced learning.

- When pawns spawn, scan nearby resources.
- Deterministic priority stack:
  1. Survival
  2. Storage
  3. Hearth
- If no shelter exists → create shelter intent.
- If food is unsafe → create food intent.
- If storage missing → create storage intent.
- Builders choose jobs from deterministic priority.
- Record important construction decisions in `WorldMemory`.

**Learning rule:** AI adapts via deterministic weight updates based on recorded world facts. No hidden non-auditable state.

---

## 10) Long-Term Persistent Simulation Universe Goals

These are the long-term pillars the runtime should eventually fulfill:

- **Combat is historical and remembered** (wounds/recovery, morale/fear, battle reports saved).
- **Groups are social institutions** with memory, trust, reputation, leadership that can fail.
- **Lineage is legacy** (family as memory, grief, burden, continuity).
- **Autonomy obeys local causality** (resources/knowledge/memory/climate/danger/trust).
- **Scale and cataclysms reshape eras** without narrative power fantasy.
- **LLM output is presentation only** unless explicitly converted into deterministic world data through approved systems.

---

## HEELKAWN NON-NEGOTIABLES (Short Reminder)

Deterministic history • Facts first • Meaning derived • Persistence earned • No chosen ones • No prophecy • No morality meter • No UI lies • No random memory decay • No victory finality • Ordinary start • Every sprite matters.

