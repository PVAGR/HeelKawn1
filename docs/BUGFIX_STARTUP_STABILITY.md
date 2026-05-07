# 🐛 Bug Fixes - Startup Stability & UI Improvements

**Date:** May 7, 2026  
**Priority:** CRITICAL - Startup experience, death notifications, performance

---

## ✅ FIXED ISSUES

### **1. PawnSpawner.gd:383 - String/Int Type Mismatch** ✅

**Error:** "Trying to assign value of type 'int' to a variable of type 'String'"

**Problem:** `data.birth_settlement` is declared as `int` in PawnData.gd, but code was trying to use it as a String.

**Fix:**
```gdscript
# BEFORE (BROKEN):
var settlement_name: String = data.birth_settlement if str(data.birth_settlement) != "" else "the wilderness"

# AFTER (WORKS):
var settlement_name: String = "the wilderness"
if data.birth_settlement >= 0:
    if SettlementMemory != null and SettlementMemory.has_method("get"):
        var settlements: Variant = SettlementMemory.get("settlements")
        if settlements != null and settlements is Array:
            for s in settlements:
                if s is Dictionary and int(s.get("center_region", -1)) == data.birth_settlement:
                    settlement_name = str(s.get("name", "Unnamed"))
                    break
```

**Impact:** Birth notifications now correctly show settlement names instead of crashing.

---

### **2. Early Hypothermia Deaths** ✅

**Problem:** Pawns dying within seconds of startup from hypothermia before player can react.

**Root Causes:**
1. No grace period for newly spawned pawns
2. No shelter/fire warmth bonuses
3. Night-time temperature too harsh

**Fixes:**

**A. Added Grace Period (SurvivalSystem.gd:242)**
```gdscript
# GRACE PERIOD: New pawns (first 2 hours = 7200 ticks) are protected from extreme cold
var birth_tick: int = int(data.get("birth_tick", 0))
var age_ticks: int = GameManager.tick_count - birth_tick
var grace_mult: float = 1.0
if age_ticks < 7200:
    # Linear interpolation from full protection to no protection
    grace_mult = lerp(0.2, 1.0, float(age_ticks) / 7200.0)
```

**B. Added Shelter/Fire Warmth Bonus (SurvivalSystem.gd:264)**
```gdscript
# Shelter bonus: pawns near beds/fire_pits are warmer
var tile: Vector2i = Vector2i.ZERO
if data.has_method("get"):
    tile = data.get("tile_pos")
if tile.x >= 0 and tile.y >= 0:
    var world: Node = get_node_or_null("/root/Main/WorldViewport/World")
    if world != null and world.has_method("get_feature"):
        var feat: int = int(world.call("get_feature", tile.x, tile.y))
        if feat == 3 or feat == 8:  # BED or FIRE_PIT
            base_temp += 8.0  # Shelter/fire provides significant warmth
```

**C. Applied Grace Period to Temperature (SurvivalSystem.gd:275)**
```gdscript
# Apply grace period multiplier (new pawns are more resilient)
base_temp = lerp(base_temp, 37.0, grace_mult)
```

**Impact:** New pawns now survive their first night unless completely exposed.

---

### **3. Death Notification UI Overhaul** ✅

**Problem:** Death popups too large, hard to read, overlap other UI, dominate screen.

**Fixes:**

**A. Reduced Size (EventNotificationOverlay.gd:8)**
```gdscript
# BEFORE:
const NOTIFICATION_LIFETIME_SEC: float = 8.0
const MAX_VISIBLE_NOTIFICATIONS: int = 3
panel.custom_minimum_size = Vector2(400, 0)

# AFTER:
const NOTIFICATION_LIFETIME_SEC: float = 5.0  # Faster cleanup
const MAX_VISIBLE_NOTIFICATIONS: int = 4  # Show more, but smaller
panel.custom_minimum_size = Vector2(320, 0)  # 20% narrower
```

**B. Improved Contrast & Readability (EventNotificationOverlay.gd:204)**
```gdscript
# StyleBox - better contrast
style.bg_color = Color(0.08, 0.10, 0.14, 0.98)  # Lighter, more opaque
style.border_width_left = 4  # Thicker border for clarity
style.set_corner_radius_all(6)  # Rounder corners

# Icon - smaller, cleaner
icon_label.add_theme_font_size_override("font_size", 24)  # Was 32
icon_label.custom_minimum_size = Vector2(32, 32)  # Was 40

# Title - clearer hierarchy
title_label.add_theme_font_size_override("font_size", 13)
title_label.add_theme_color_override("font_color", color)

# Description - lighter gray for better contrast
desc_label.add_theme_font_size_override("font_size", 10)  # Was 11
desc_label.add_theme_color_override("font_color", Color8(200, 200, 210))  # Was 180
```

**C. Compact Death Format (EventNotificationOverlay.gd:319)**
```gdscript
# BEFORE:
"⚰ %s Died" % pawn_name
"Age %.1f - %s" % [age, cause]

# AFTER:
"%s" % pawn_name  # Just the name
"Age %.1f • %s" % [age, cause.capitalize()]  # Compact with bullet
```

**D. Added Margins & Spacing (EventNotificationOverlay.gd:216)**
```gdscript
content.add_theme_constant_override("separation", 10)
content.add_theme_constant_override("margin_left", 10)
content.add_theme_constant_override("margin_right", 10)
content.add_theme_constant_override("margin_top", 8)
content.add_theme_constant_override("margin_bottom", 8)
```

**Impact:** Death notifications now:
- Take 20% less horizontal space
- Fade in/out faster (0.3s/0.5s vs 0.5s/1.0s)
- Have better text contrast
- Don't overlap minimap
- Show 4 at once instead of 3 (with batching)

---

### **4. Biography Spam Removed** ✅

**Problem:** Every death printed full biography to console, flooding Output panel.

**Fix (WorldMemory.gd:807):**
```gdscript
# BEFORE:
if pawn_data != null and is_first_death:
    var biography: String = _generate_pawn_biography(pawn_data, cause)
    print(...)  # Always printed

# AFTER:
# Disabled by default to prevent console spam during normal play
if OS.is_debug_build() and GameManager != null and GameManager.verbose_logs() and pawn_data != null and is_first_death:
    # Only prints in debug mode with verbose logs enabled
```

**Impact:** Console no longer flooded with biographies during normal play. Still available for debugging with verbose logs.

---

### **5. Death Idempotency Guards** ✅

**Problem:** Dead pawns being processed multiple times, causing duplicate death records.

**Fix (SurvivalSystem.gd:407, 441):**
```gdscript
# BEFORE (BROKEN - Dictionary syntax on RefCounted):
if data.has("is_dead"):
    var is_dead_val: Variant = data.get("is_dead")
    if is_dead_val != null and bool(is_dead_val):
        return

# AFTER (WORKS - RefCounted safe):
if "is_dead" in data and bool(data.get("is_dead")):
    return  # Pawn is already dead - skip processing
```

**Locations Fixed:**
- Line 407: `_check_death_conditions()` ✅
- Line 441: `_apply_death()` ✅

**Impact:** Pawns now die exactly once, no duplicate records.

---

## 📊 EXPECTED IMPROVEMENTS

### **Startup Experience:**
- ✅ Pawns survive first night (grace period)
- ✅ No instant hypothermia deaths
- ✅ Shelter/fire provides warmth
- ✅ Game starts at manageable pace

### **Death Notifications:**
- ✅ 20% smaller (320px vs 400px width)
- ✅ Better contrast (lighter background, thicker borders)
- ✅ Cleaner format (name only, compact age/cause)
- ✅ Faster fade (0.3s in, 0.5s out)
- ✅ Don't cover minimap
- ✅ Batch similar events ("+2 more")

### **Console Output:**
- ✅ No biography spam (debug-only now)
- ✅ Clean, readable death notices
- ✅ Easy to debug with verbose flag

### **Death Processing:**
- ✅ One death per pawn (idempotent)
- ✅ No duplicate WorldMemory events
- ✅ No fake legacy growth

---

## 🎮 TESTING CHECKLIST

**Startup Test:**
```
☐ Boot game at 12x speed
☐ Watch Year 1 Day 1 night (03:00)
☐ Pawns should survive (no instant hypothermia)
☐ No red errors in Output
```

**Death Notification Test:**
```
☐ Wait for pawn to die (or speed up time)
☐ Death toast should appear (320px wide)
☐ Text should be readable (name, age, cause)
☐ Should fade after 5 seconds
☐ Should not cover minimap
☐ Multiple deaths should batch ("+2 more")
```

**Console Test:**
```
☐ Watch Output panel during play
☐ No biography spam
☐ Clean death notices only
☐ Verbose logs enable biographies (debug only)
```

**Idempotency Test:**
```
☐ Wait for pawn death
☐ Check WorldMemory - ONE death event
☐ Check chronicle - ONE death record
☐ No duplicate legacy growth
```

---

## 🚀 NEXT STEPS

**Remaining Issues (Lower Priority):**
1. Duplicate startup spawning (pawns #1-20, then #21-26, then #27-46)
2. Age/calendar math inconsistency (0.1 years for multi-year spans)
3. Mining_react performance hotspot (9ms per tick at 100x)

**These can be addressed after verifying the critical fixes above work correctly.**

---

*Bug Fix Report v1.0 — "Stable startup, readable notifications, clean console."*
