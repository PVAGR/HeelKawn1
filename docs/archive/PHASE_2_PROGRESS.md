# HEELKAWN: PHASE 2 COMBAT OVERHAUL - PROGRESS

**Date:** May 5, 2026  
**Status:** 🟡 **PHASE 2: COMBAT OVERHAUL - 50% COMPLETE**  
**Started:** Phase 1 Complete  
**ETA:** 4-6 hours total

---

## ✅ **COMPLETED (Phase 2):**

### **Phase 2A: Combat Progression** (Kenshi + Bannerlord ranks)
**File:** `scripts/ai/AICombatProgression.gd` (400+ lines)

**Combat Ranks:**
1. **NOBODY** (0 XP) - "Just a farmer"
2. **RECRUIT** (50 XP) - "Can hold a sword"
3. **SOLDIER** (200 XP) - "Battle veteran"
4. **VETERAN** (500 XP) - "Feared warrior"
5. **CHAMPION** (1000 XP) - "Legendary fighter"
6. **GENERAL** (2000 XP + leadership) - "Commands armies"

**Features:**
- XP from damage (1 per damage), kills (20+ bonus), survival (5-10)
- Combat bonuses: 0% → 10% → 25% → 50% → 100% → 200%
- Leadership slots: 0 → 0 → 2 → 5 → 10 → 999
- Legacy traits: Slayer, Warrior, Tactician, Commander
- Leadership demonstration required for General

**Usage:**
```gdscript
# Award XP:
AICombatProgression.award_xp(pawn_id, 50, "enemy_killed")
AICombatProgression.award_damage_xp(pawn_id, 25)
AICombatProgression.award_kill_xp(pawn_id, enemy_rank)

# Get rank info:
var rank = AICombatProgression.get_rank_name(pawn_id)
var bonus = AICombatProgression.get_combat_bonus(pawn_id)
var capacity = AICombatProgression.get_leadership_capacity(pawn_id)

# Mark leadership:
AICombatProgression.demonstrate_leadership(pawn_id)
```

---

### **Phase 2B: Dynamic Text Combat Log** (Kenshi-style narratives)
**File:** `scripts/ai/CombatNarrative.gd` (350+ lines)

**Combat Templates:**
- Attack hit (4 variants)
- Attack miss (4 variants)
- Critical hit (4 variants)
- Blocked/parried (4 variants)
- Wounded (4 variants)
- Victory (4 variants)
- Fleeing (4 variants)

**Total:** 28+ combat phrase templates

**Kenshi Style:**
> "Gorne swings his rusted blade, connecting with the wolf's flank. The beast yelps, but the farmer's strike lacks conviction. This will be a long fight."

**Features:**
- Body part randomization (head, arm, leg, torso, etc.)
- Damage-based wound descriptions
- Full battle log generation (round-by-round)
- LLM-powered narratives (optional)
- Narrative cache (100 entries)
- WorldMemory event logging

**Usage:**
```gdscript
# Generate attack narrative:
var narrative = CombatNarrative.generate_attack_narrative(
    "Gorne", "Wolf", "rusty sword", 15, true
)

# Generate battle log:
var log = await CombatNarrative.generate_battle_log(
    attacker_id, defender_id, rounds
)

# LLM-powered narrative:
var narrative = await CombatNarrative.generate_llm_narrative(
    "Gorne", "Wolf", "Recruit", "Nobody", "sword", 15, "hit"
)
```

---

## 🔶 **IN PROGRESS:**

### **Phase 2C: Squad Formations** (Bannerlord tactics)
**Status:** TODO  
**Time:** ~2-3 hours

**Planned Features:**
- Squad creation (5-20 pawns per squad)
- Formations: Phalanx, Skirmish, Charge, Defensive
- Squad morale tracking
- Squad XP sharing
- Officer assignments (Captain, Lieutenant, Sergeant)
- Bannerlord-style tactical grid (optional)

**Files to Create:**
- `scripts/ai/SquadSystem.gd`
- `scripts/ai/SquadFormation.gd`

---

### **Phase 2D: Battle Reports** (WorldMemory integration)
**Status:** TODO  
**Time:** ~1-2 hours

**Planned Features:**
- Battle reports saved to WorldMemory
- Witnessed heroism/cowardice tracking
- War memory affecting settlements, families, grudges
- Battle statistics (KIA, WIA, MIA)
- Casualty notifications to families
- Memorial markers for significant battles

**Files to Modify:**
- `autoloads/WorldMemory.gd` (add battle report functions)
- `scripts/ai/BattleReporter.gd` (new)

---

## 📊 **PHASE 2 STATISTICS:**

| System | Lines | Status |
|--------|-------|--------|
| AICombatProgression | 400+ | ✅ Complete |
| CombatNarrative | 350+ | ✅ Complete |
| SquadSystem | 0 | 🔶 TODO |
| BattleReporter | 0 | 🔶 TODO |
| **Total** | **750+ / 1,500** | **🟡 50%** |

---

## 🎯 **KENSHI + BANNERLORD VISION:**

### **Kenshi Elements:**
✅ Harsh world (start as nobody)  
✅ Earned significance (XP through combat)  
✅ Dynamic text combat (gritty narratives)  
✅ Small-group combat (squads coming)  

### **Bannerlord Elements:**
✅ Soldier → General progression  
✅ Leadership demonstration required  
⚠️ Large-scale battles (TODO)  
⚠️ Tactical formations (TODO)  
⚠️ Army composition (TODO)  

---

## 🚀 **NEXT STEPS:**

### **Immediate (Next 2-3 hours):**
1. **SquadSystem.gd** - Squad creation, management
2. **SquadFormation.gd** - Phalanx, Skirmish, Charge, Defensive
3. **BattleReporter.gd** - Battle reports to WorldMemory

### **After Phase 2 Complete:**
- Phase 3: Group/Guild System (BG3 + WOW + ECO)
- Phase 4: Lineage & Genetics (CK3)
- Phase 5: Governor System (Songs of Syx)

---

## 🎮 **HOW TO TEST CURRENT SYSTEMS:**

### **Test Combat Progression:**
```gdscript
# In F10 console or debug:
AICombatProgression.award_xp(1, 250, "testing")
print("Rank:", AICombatProgression.get_rank_name(1))
print("Bonus:", AICombatProgression.get_combat_bonus(1))
print("Leadership:", AICombatProgression.get_leadership_capacity(1))
```

### **Test Combat Narrative:**
```gdscript
# Generate narrative:
var narrative = CombatNarrative.generate_attack_narrative(
    "TestPawn", "Enemy", "sword", 20, true
)
print(narrative)

# Get stats:
print(CombatNarrative.get_stats())
```

---

## ✅ **CHECKLIST:**

- [x] Phase 2A: Combat Progression
- [x] Phase 2B: Combat Narrative
- [ ] Phase 2C: Squad Formations
- [ ] Phase 2D: Battle Reports
- [ ] Integration with existing CombatSystem
- [ ] Testing with actual combat
- [ ] Balance tuning (XP values, bonuses)

---

**PHASE 2: 50% COMPLETE! 🎯**

**Continuing with Squad Formations and Battle Reports...**
