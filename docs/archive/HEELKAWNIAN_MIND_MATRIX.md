# HeelKawnian Mind Matrix

## Doctrine

HeelKawnians are not decorative NPCs. They are deterministic simulated people whose inner lives come from world state, memory, relationships, culture, and consequence. The Mind Matrix makes every player story unique because HeelKawnians interpret and respond to player actions differently based on their lived history.

The system obeys the HeelKawn kernel: **facts first, meaning second, UI last**. WorldMemory records what objectively happened. WorldMeaning derives interpretation from those facts. HeelKawnianMind composes what the pawn "thinks" from those layers. The inspect UI only displays what the simulation actually knows.

## Architecture

The Mind Matrix is a **composed computation layer** — it reads existing systems and produces a deterministic mind snapshot. It does NOT store new state (except a short-lived cache). It does NOT replace PawnConsciousness. It **composes** what already exists into a readable mind.

### Eleven Layers

1. **Body Layer** — Immediate needs: hunger, rest, danger, warmth, injury, shelter, work pressure. Derived from PawnData fields.

2. **Memory Layer** — Personal memories from PawnConsciousness. Deaths, fires, starvation, teaching, migration, construction, abandonment witnessed by this pawn. Trauma and growth shape emotional state.

3. **Relationship Layer** — Family from KinshipSystem. Trust, dislike, fear from GrudgeManager. Reputation from GossipManager. Social bonds from RelationalGraph.

4. **Desire Layer** — Pursuit chosen from pressures and identity: eat, sleep, work, flee, help kin, learn, teach, build, farm, gather, guard, migrate, record history, make paper, make books, preserve knowledge, join war, avoid war, mourn, rebuild, wander. Priority: survival > shelter > community > knowledge > growth.

5. **Culture Layer** — Settlement traditions from CulturalMemory. Taboos, customs, stories, laws, farming methods, bookmaking, paper-making, tool traditions, war memories, hospitality.

6. **Meaning Layer** — Pawn-level interpretation of events from WorldMeaning. Not objective truth — pawn-level meaning. "This place feels dangerous because many died here." "I trust this person because they fed people." "I want to learn farming because my settlement is hungry."

7. **Thought Layer** — Composed sentence from dominant pressure + pursuit + meaning + personality. Deterministic template selection based on state.

8. **Work Layer** — Current job or idle state. Read from Pawn._current_job.

9. **Knowledge Layer** — What this pawn knows from KnowledgeSystem. 26 knowledge types (fire keeping, tool making, farming, combat, writing, metallurgy, etc.). At-risk flag when pawn is the only carrier of some knowledge.

10. **War/Conflict Layer** — Conflict events, injuries, witnessed deaths from WorldMemory. Grudge counts from GrudgeManager. Shapes defensive posture and trust.

11. **Settlement Layer** — Population, building count, era, fallen count from SettlementMemory and CivilizationStage.

### Mind Snapshot Structure

When you click a HeelKawnian, the Mind tab shows:

```
Thought: "I need food before I can keep working."
Pursuit: Find food
Body: Starving, tired
Emotion: desperate, anxious
Likes: Warm hearths, familiar shelter
Dislikes: Hunger, unsafe ruins
Family: Parent of 2, Clan Ash
Bonds: Distrusts Osric; reputation: neutral
Memory: Traumatic near_death; Carries deep scars.
Culture: Values farming, mature culture
Work: Foraging for food at (45, 12)
Reason: Hunger (18) is the most pressing need
Knowledge: Knows: fire keeping, tool making, farming (+3 more) [AT RISK]
Conflict: 2 conflicts, witnessed 1 death
Settlement: Pop 12, 8 buildings, Primitive, 2 fallen
```

Every line comes from actual pawn/world variables. No invented text. No random flavor. Deterministic: same seed + same history = same thought.

### Determinism

The system uses `stable_hash()` (FNV-1a-inspired) instead of `randi()`/`randf()`. All "which of N options" choices use deterministic hash from pawn_id + tick + salt. Same world seed, same pawn, same tick = same mind snapshot.

PawnConsciousness dream system was fixed to use stable_hash instead of randi/randf.

### Decision Pipeline

Mind snapshot feeds into PawnDecisionRuleMatrix via WorldAI._pawn_decision_rule_context:

- **Emotional pressure**: desperate → urgent food + avoid risk; anxious → seek food + cautious; fearful → rest + observe + avoid combat; gloomy → seek social comfort; content → productive work; curious → explore + forage
- **Place feeling**: dangerous → observe + defend + avoid forage; sacred → social + build; home → social + build; haunted → observe + cautious rest
- **Culture tradition**: martial → defend + provide; scholarly → teach + craft; agrarian → forage + feed; mercantile → gather + socialize
- **Reputation**: high → lead + defend; low → withdraw + observe
- **Knowledge**: scholar (8+) → teach + craft; educated (4+) → share + apply; at risk → teach urgently
- **Conflict**: scarred (3+) → defensive + watchful + less social; aware (1+) → mild defend

## Milestones

### Milestone 1 (DONE): Every clicked HeelKawnian has a deterministic inspectable mind snapshot.

- HeelKawnianMind autoload computes mind snapshot from existing systems
- PawnInfoPanel "Mind" tab shows composed readable state
- PawnConsciousness dreams are now deterministic
- All text derived from actual state, no invention

### Milestone 2 (DONE): Pawn decisions read from the mind snapshot.

- PawnDecisionRuleMatrix reads mind snapshot fields via WorldAI context
- Emotional pressure influences job choice (6 rules)
- Place feeling influences behavior (4 rules)
- Culture tradition influences work preference (4 rules)
- Reputation influences social behavior (2 rules)

### Milestone 3 (DONE): Knowledge, war memory, settlement history feed the mind.

- Knowledge layer: what pawn knows + at-risk flag
- War/conflict layer: conflicts, injuries, witnessed deaths
- Settlement layer: population, buildings, era, fallen
- 5 new decision rules: knowledge scholar, educated, at-risk, conflict scarred, conflict aware

### Future Milestones

- Teacher/student bonds and neighbor bonds
- Cultural taboos directly affect job choice
- Books and records carry knowledge between generations
- Farming methods spread through teaching
- Knowledge loss when no one carries it
- Mind snapshot influences pawn-to-pawn interactions
- Debt and obligation system

## Game Inspirations

The spirit (not literal copies):
- **Dwarf Fortress**: Depth of simulated lives, thoughts, relationships
- **WorldBox**: Living world where civilization emerges from people
- **Crusader Kings**: Lineage, memory, relationships, consequence
- **Eco**: Ecology, consequence, player impact
- **Elder Scrolls / Fallout**: Inspectable lives, world feeling alive
- **RimWorld**: Social pressure, mood, relationships
- **Mount & Blade**: War scale, faction dynamics
- **HeelKawn's own myth-engine identity**: The Truman experience — NPCs live so unpredictably that neither player nor AI can predict what happens after a few in-world years

## Implementation Rules

- Do not break determinism.
- Do not break existing saves.
- Do not remove existing kernel systems.
- Do not make UI invent truth.
- Do not add morality meters.
- Do not add chosen-one mechanics.
- Do not make random personality spam.
- Do not hardcode fake lore events.
- Do not implement the whole dream at once.
- First make the state visible. Then use it for decisions.
- Every displayed line must come from actual pawn/world variables.

## Files

- `autoloads/HeelKawnianMind.gd` — Mind snapshot computation engine (11 layers)
- `autoloads/PawnConsciousness.gd` — Fixed nondeterminism (stable_hash)
- `scripts/ui/PawnInfoPanel.gd` — Mind tab with composed snapshot + Deep Mind section
- `scripts/ai/WorldAI.gd` — Mind context helpers for decision pipeline
- `scripts/ai/PawnDecisionRuleMatrix.gd` — 17 mind-driven decision rules
- `project.godot` — HeelKawnianMind autoload registration
