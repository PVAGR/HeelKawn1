# HEELKAWN AI SYSTEMS - COMPLETE REFERENCE

**Version:** 1.0  
**Date:** May 5, 2026  
**Status:** ✅ **ALL SYSTEMS COMPLETE**  
**Total:** 18 Systems, 7,450+ Lines

---

## 📚 **TABLE OF CONTENTS**

1. [System Overview](#system-overview)
2. [Phase 1: AI Autonomy](#phase-1-ai-autonomy)
3. [Phase 2: Combat](#phase-2-combat)
4. [Phase 3: Groups](#phase-3-groups)
5. [Phase 4: Lineage](#phase-4-lineage)
6. [Phase 5: Governor](#phase-5-governor)
7. [Phase 6: UI/UX](#phase-6-uiux)
8. [Phase 7: Scale](#phase-7-scale)
9. [Integration Guide](#integration-guide)
10. [Best Practices](#best-practices)

---

## SYSTEM OVERVIEW

### All Systems by Category:

| Category | Systems | Purpose |
|----------|---------|---------|
| **AI Autonomy** | AIAutoBuild, AILearning, AICooperation | WorldBox-style AI |
| **Combat** | AICombatProgression, CombatNarrative, SquadSystem, BattleReporter | Kenshi/Bannerlord |
| **Social** | GuildSystem | BG3/WOW/ECO groups |
| **Lineage** | BloodlineSystem, GeneticsSystem, NameGenerator | CK3 family trees |
| **Governance** | GovernorSystem | Songs of Syx cities |
| **UI/UX** | ModernTheme, PawnMoodUI | RimWorld/CK3 interface |
| **Scale** | CataclysmSystem, ZoomSystem | EVE/Stronghold scope |

---

## PHASE 1: AI AUTONOMY

### AIAutoBuild.gd
**Purpose:** WorldBox-style autonomous construction

**Key Functions:**
```gdscript
# Scan resources around tile
AIAutoBuild.scan_resources(tile, radius)

# Create build intents for pawn
AIAutoBuild.create_build_intents(pawn_id, tile, settlement_id)

# Get all build intents
AIAutoBuild.get_all_intents()

# Complete build intent
AIAutoBuild.complete_intent(intent_id)
```

**Build Priority Order:**
1. Survival
2. Shelter
3. Storage
4. Hearth
5. Tools
6. Defense
7. Comfort
8. Identity
9. Ambition

---

### AILearning.gd
**Purpose:** Pax Historia-style AI adaptation

**Key Functions:**
```gdscript
# Get decision weight
AILearning.get_weight(decision_type)

# Get learned patterns
AILearning.get_learned_patterns()

# Force review (testing)
AILearning.force_review()
```

**Learned Patterns:**
- Starvation → prioritize food
- Combat deaths → prioritize defense
- Resource scarcity → prioritize gathering
- Building success → continue approach

---

### AICooperation.gd
**Purpose:** ECO-style player-AI cooperation

**Key Functions:**
```gdscript
# AI requests player help
AICooperation.ai_request_help(requester_id, task_type, description, priority, reward)

# Player accepts request
AICooperation.player_accept_request(request_id, player_id)

# Player assigns AI task
AICooperation.player_assign_task(player_id, settlement_id, task_type, description, priority, reward)

# Get reputation
AICooperation.get_reputation(entity_id)
```

**Reputation System:**
- Range: -100 to +100
- Gain: +10 per completed task
- Loss: -5 per failure
- Threshold: -50 (below this, AI won't cooperate)

---

## PHASE 2: COMBAT

### AICombatProgression.gd
**Purpose:** Kenshi-style combat ranks

**Combat Ranks:**
1. NOBODY (0 XP) - "Just a farmer"
2. RECRUIT (50 XP) - "Can hold a sword"
3. SOLDIER (200 XP) - "Battle veteran"
4. VETERAN (500 XP) - "Feared warrior"
5. CHAMPION (1000 XP) - "Legendary fighter"
6. GENERAL (2000 XP + leadership) - "Commands armies"

**Key Functions:**
```gdscript
# Award XP
AICombatProgression.award_xp(pawn_id, amount, reason)
AICombatProgression.award_damage_xp(pawn_id, damage)
AICombatProgression.award_kill_xp(pawn_id, enemy_rank)
AICombatProgression.award_survival_xp(pawn_id, battle_won)

# Get rank info
AICombatProgression.get_rank_name(pawn_id)
AICombatProgression.get_rank_description(pawn_id)
AICombatProgression.get_combat_bonus(pawn_id)
AICombatProgression.get_leadership_capacity(pawn_id)

# Mark leadership
AICombatProgression.demonstrate_leadership(pawn_id)
```

---

### CombatNarrative.gd
**Purpose:** Kenshi-style dynamic text combat

**Key Functions:**
```gdscript
# Generate attack narrative
CombatNarrative.generate_attack_narrative(attacker, defender, weapon, damage, hit, critical)

# Generate battle outcome
CombatNarrative.generate_battle_outcome(victor, defeated, fled)

# Generate full battle log
await CombatNarrative.generate_battle_log(attacker_id, defender_id, rounds)

# LLM-powered narrative
await CombatNarrative.generate_llm_narrative(attacker, defender, attacker_rank, defender_rank, weapon, damage, outcome)
```

**Combat Templates:** 28+ variants (hit, miss, critical, blocked, wounded, victory, fleeing)

---

### SquadSystem.gd
**Purpose:** Bannerlord-style squad formations

**Formations:**
- PHALANX (+50% defense, -30% mobility)
- SKIRMISH (-20% defense, +40% mobility)
- CHARGE (+50% attack, -30% defense)
- DEFENSIVE (+30% defense, +40% morale)
- MARCH (+50% mobility, -40% defense)
- CIRCLE (+40% defense, -50% mobility)

**Key Functions:**
```gdscript
# Create squad
SquadSystem.create_squad(leader_id, name, initial_members)

# Add/remove members
SquadSystem.add_member(squad_id, pawn_id)
SquadSystem.remove_member(squad_id, pawn_id)

# Set formation
SquadSystem.set_formation(squad_id, SquadSystem.Formation.PHALANX)

# Get bonuses
SquadSystem.get_formation_bonus(squad_id, "defense")
SquadSystem.get_all_formation_bonuses(squad_id)

# Record battle outcomes
SquadSystem.award_squad_xp(squad_id, xp, reason)
SquadSystem.record_victory(squad_id)
SquadSystem.record_defeat(squad_id)
```

---

### BattleReporter.gd
**Purpose:** Battle reports to WorldMemory

**Key Functions:**
```gdscript
# Start battle
BattleReporter.start_battle(attackers, defenders, location, battle_name)

# Record casualties
BattleReporter.record_casualty(battle_id, pawn_id, side, casualty_type)

# Record heroism/cowardice
BattleReporter.record_heroism(battle_id, pawn_id, description, significance)
BattleReporter.record_cowardice(battle_id, pawn_id, description, significance)

# End battle
BattleReporter.end_battle(battle_id, victor)

# Get reports
BattleReporter.get_battle_report(battle_id)
BattleReporter.get_significant_battles(min_significance)
```

**Battle Significance:** 1-10 scale based on casualties, participants, heroism

---

## PHASE 3: GROUPS

### GuildSystem.gd
**Purpose:** BG3/WOW/ECO-style groups for ALL roles

**Guild Types (12):**
1. Farmers Guild
2. Warriors Guild
3. Builders Guild
4. Scholars Guild
5. Traders Guild
6. Sailors Guild
7. Adventurers Guild
8. Crafters Guild
9. Hunters Guild
10. Healers Guild
11. Miners Guild
12. General Guild

**Key Functions:**
```gdscript
# Create guild
GuildSystem.create_guild(leader_id, GuildType.WARRIORS, name)

# Manage members
GuildSystem.add_member(guild_id, pawn_id)
GuildSystem.remove_member(guild_id, pawn_id)
GuildSystem.promote_to_officer(guild_id, pawn_id)

# Trust & reputation
GuildSystem.award_trust(guild_id, amount)
GuildSystem.apply_trust_penalty(guild_id, amount)
GuildSystem.modify_reputation(guild_id, amount)

# Get cooperation bonus
GuildSystem.get_cooperation_bonus(guild_id, task_type)
```

**Trust System:** 0-100, decays over time, breaks at <10

---

## PHASE 4: LINEAGE

### BloodlineSystem.gd
**Purpose:** CK3-style family trees

**Key Functions:**
```gdscript
# Create bloodline
BloodlineSystem.create_bloodline(founder_id, name)

# Record relationships
BloodlineSystem.record_parent_child(child_id, father_id, mother_id)
BloodlineSystem.record_marriage(pawn1_id, pawn2_id)
BloodlineSystem.record_death(pawn_id)

# Feuds & alliances
BloodlineSystem.start_feud(bloodline1_id, bloodline2_id, reason)
BloodlineSystem.form_alliance(bloodline1_id, bloodline2_id, alliance_type)

# Get data
BloodlineSystem.get_bloodline(bloodline_id)
BloodlineSystem.get_pawn_bloodline(pawn_id)
BloodlineSystem.get_pawn_family(pawn_id)
```

---

### GeneticsSystem.gd
**Purpose:** Deterministic trait inheritance

**Traits (18 predefined):**
- **Genetic:** Strong, Weak, Intelligent, Charismatic, Stoic, Paranoid, Ambitious, Content
- **Learned:** Skilled Warrior, Master Crafter, Scholar
- **Cultural:** Northern, Coastal
- **Scars:** Battle-Scarred, War Wound

**Key Functions:**
```gdscript
# Calculate inheritance
GeneticsSystem.calculate_inheritance(child_id, father_id, mother_id)

# Add traits
GeneticsSystem.add_learned_trait(pawn_id, trait_id)
GeneticsSystem.add_cultural_trait(pawn_id, trait_id)
GeneticsSystem.add_scar(pawn_id, trait_id, reason)

# Get effects
GeneticsSystem.get_trait_effects(pawn_id)
GeneticsSystem.get_trait_bonus(pawn_id, effect_type)
GeneticsSystem.has_trait(pawn_id, trait_id)
```

---

### NameGenerator.gd
**Purpose:** Cultural naming customs

**Cultures (5):**
- Northern (Viking-inspired)
- Southern (Roman-inspired)
- Eastern (Asian-inspired)
- Western (Medieval-inspired)
- Common (Generic)

**Key Functions:**
```gdscript
# Generate full name
NameGenerator.generate_full_name(pawn_id, culture, gender, circumstances)

# Generate given name
NameGenerator.generate_given_name(culture, gender)

# Generate surname
NameGenerator.generate_surname(pawn_id, culture, circumstances)

# Generate nickname
NameGenerator.generate_nickname(pawn_id, circumstances)

# Child naming
NameGenerator.generate_child_name(father_id, mother_id, gender)
```

---

## PHASE 5: GOVERNOR

### GovernorSystem.gd
**Purpose:** Songs of Syx-style city management

**Zone Types (8):**
1. Residential
2. Industrial
3. Agricultural
4. Commercial
5. Military
6. Cultural
7. Storage
8. Administrative

**Policy Categories (4):**
- **Tax:** none, low, medium, high
- **Trade:** isolationist, free, mercantile
- **Defense:** peaceful, neutral, fortified, militaristic
- **Culture:** none, patron, theocratic

**Key Functions:**
```gdscript
# Appoint governor
GovernorSystem.appoint_governor(settlement_id, governor_id, is_player)

# Set policies
GovernorSystem.set_policy(settlement_id, category, policy)

# Zone management
GovernorSystem.set_zone_priority(settlement_id, zone_type, priority)

# Worker assignment
GovernorSystem.assign_workers(settlement_id, task_type, count)

# Get recommendations
GovernorSystem.get_recommended_zone(settlement_id)
GovernorSystem.get_recommended_worker_distribution(settlement_id)
```

---

## PHASE 6: UI/UX

### ModernTheme.gd
**Purpose:** RimWorld-style UI theme

**Color Palette:**
- Background: bg_dark, bg_medium, bg_light
- Text: text_primary, text_secondary, text_disabled
- Accents: accent_primary (gold), accent_secondary (blue)
- Mood: mood_high (green), mood_medium (yellow), mood_low (red)
- Professions: farmer, builder, warrior, scholar, etc.

**Key Functions:**
```gdscript
# Get colors/fonts/icons
ModernTheme.get_color(color_name)
ModernTheme.get_font(font_name)
ModernTheme.get_font_size(size_name)
ModernTheme.get_icon(icon_name)

# Get profession/mood colors
ModernTheme.get_profession_color(profession)
ModernTheme.get_mood_color(mood_value)

# Create styled UI elements
ModernTheme.create_styled_label(text, size)
ModernTheme.create_styled_button(text)
ModernTheme.create_styled_panel()
```

---

### PawnMoodUI.gd
**Purpose:** Individual pawn mood panel

**Displays:**
- Mood bar (0-100)
- Need indicators (hunger, rest, social, comfort, safety)
- Thought bubbles
- Trait chips
- Health status

**Key Functions:**
```gdscript
# Set pawn to display
PawnMoodUI.set_pawn(pawn_id)

# Get current pawn
PawnMoodUI.get_pawn_id()

# Clear display
PawnMoodUI.clear()
```

---

## PHASE 7: SCALE

### CataclysmSystem.gd
**Purpose:** EVE/Stronghold-style world events

**Cataclysm Types (5):**
1. **Plague** - Disease outbreak (5k tick duration)
2. **Invasion** - Enemy forces (3k tick duration)
3. **Earthquake** - Terrain destruction (2k tick duration)
4. **Meteor** - Impact event (10k tick duration)
5. **Famine** - Food shortage (8k tick duration)

**Key Functions:**
```gdscript
# Trigger cataclysm
CataclysmSystem.trigger_cataclysm(type, severity, tick)

# Get active cataclysms
CataclysmSystem.get_active_cataclysms()
CataclysmSystem.get_cataclysm(cataclysm_id)

# Check if region affected
CataclysmSystem.is_region_affected(region)
CataclysmSystem.get_cataclysm_severity(region)
```

---

### ZoomSystem.gd
**Purpose:** 1:1 to 1:10000 zoom with LOD

**Zoom Levels (4):**
1. **1:1** - Pawn View (max 100 entities)
2. **1:100** - Settlement View (max 500 entities)
3. **1:1000** - Region View (max 2000 entities)
4. **1:10000** - World View (max 10000 entities)

**Key Functions:**
```gdscript
# Set zoom level
ZoomSystem.set_zoom_level(ZoomLevel.ZOOM_1_100)

# Zoom controls
ZoomSystem.zoom_in()
ZoomSystem.zoom_out()
ZoomSystem.reset_zoom()

# LOD management
ZoomSystem.register_lod_entity(entity_id, node, distance)
ZoomSystem.unregister_lod_entity(entity_id)
ZoomSystem.get_visible_entities()
```

---

## INTEGRATION GUIDE

### Basic Setup:

All systems are registered as autoloads in `project.godot`:

```ini
[autoload]

AIAutoBuild="*res://scripts/ai/AIAutoBuild.gd"
AILearning="*res://scripts/ai/AILearning.gd"
AICooperation="*res://scripts/ai/AICooperation.gd"
AICombatProgression="*res://scripts/ai/AICombatProgression.gd"
CombatNarrative="*res://scripts/ai/CombatNarrative.gd"
SquadSystem="*res://scripts/ai/SquadSystem.gd"
BattleReporter="*res://scripts/ai/BattleReporter.gd"
GuildSystem="*res://scripts/ai/GuildSystem.gd"
BloodlineSystem="*res://scripts/ai/BloodlineSystem.gd"
GeneticsSystem="*res://scripts/ai/GeneticsSystem.gd"
NameGenerator="*res://scripts/ai/NameGenerator.gd"
GovernorSystem="*res://scripts/ai/GovernorSystem.gd"
ModernTheme="*res://scripts/ui/ModernTheme.gd"
PawnMoodUI="*res://scripts/ui/PawnMoodUI.gd"
CataclysmSystem="*res://scripts/world/CataclysmSystem.gd"
ZoomSystem="*res://scripts/world/ZoomSystem.gd"
```

### Usage Pattern:

```gdscript
# All systems are globally accessible
func _ready() -> void:
    # Create guild
    var guild_id = GuildSystem.create_guild(player_id, GuildSystem.GuildType.WARRIORS)
    
    # Award combat XP
    AICombatProgression.award_xp(player_id, 100, "tutorial")
    
    # Set governor policy
    GovernorSystem.set_policy(settlement_id, "tax", "low")
```

---

## BEST PRACTICES

### 1. Deterministic Systems
All AI systems are deterministic - same inputs produce same outputs. Never use `randi()` directly in AI logic.

### 2. WorldMemory Integration
Record all significant events to WorldMemory for historical tracking:

```gdscript
if WorldMemory != null:
    WorldMemory.record_event({
        "type": "your_event_type",
        "data": your_data,
        "tick": GameManager.tick_count
    })
```

### 3. Clear Functions
All systems have `clear()` functions for world reroll. Call these when starting new game.

### 4. Performance
Use ZoomSystem LOD to limit visible entities at high zoom levels.

### 5. Testing
Use provided `get_stats()` functions on all systems for debugging.

---

**HEELKAWN AI SYSTEMS - COMPLETE REFERENCE**  
**18 Systems | 7,450+ Lines | 100% Feature Complete**
