# 🧪 HeelKawn Testing Checklist

**For:** Human tester (PVAGR)  
**Version:** v1.0 RC (Release Candidate)  
**Date:** May 6, 2026

---

## 🎯 How to Use This Checklist

1. Open Godot 4.6.2
2. Open HeelKawn project
3. Run `scenes/main/Main.tscn`
4. Check each item below
5. **Paste any errors to AI** — AI will fix immediately

---

## ✅ Startup Tests

- [ ] Godot opens project without errors
- [ ] No red parse errors in Output panel
- [ ] Game runs at 60+ FPS (1x speed)
- [ ] No console warnings about missing nodes/scripts

**If errors:** Paste full error text to AI.

---

## ✅ UI Tests (New Systems)

### SurvivalHUD (Top-Left of Screen)
- [ ] Hunger bar visible (green/yellow/red based on value)
- [ ] Thirst bar visible
- [ ] Energy bar visible
- [ ] Temperature display (shows °C value)
- [ ] Health bar visible
- [ ] Status effects show when applicable (injuries, moodlets)

**Expected:** 4-5 bars stacked vertically, top-left corner

---

### PlayerInventory (Press `I` to Toggle)
- [ ] Inventory panel appears when pressing `I`
- [ ] Shows resource icons (🪵 Wood, 🪨 Stone, 🫐 Berries, etc.)
- [ ] Shows quantities (x5, x10, etc.)
- [ ] Closes when pressing `I` again

**Expected:** Grid of items with emoji icons

---

### PawnInfoPanel (Select a Pawn)
- [ ] Panel appears on right side when a HeelKawnian is selected
- [ ] Shows HeelKawnian name, age, profession
- [ ] Has tabs: ID, Needs, Social, Narrative, **Consciousness**
- [ ] Click "Consciousness" tab → Shows:
  - Self-Awareness level
  - Trauma bar (0-100)
  - Growth points
  - Recent Dreams section
  - Significant Memories section
  - Core Beliefs section

**Expected:** 5 tabs, Consciousness tab shows pawn psychology

---

### MemorialInscriptionUI (Click Memorial Tile)
- [ ] Click on memorial tile → Popup appears
- [ ] Shows memorial type (Grave Marker, Battle Monument, etc.)
- [ ] Shows inscription text
- [ ] Shows year (Year X.X)
- [ ] Lists associated HeelKawnian names
- [ ] "Read [Pawn]'s Story" buttons clickable
- [ ] "Close" button works

**If no memorials exist:**
- Spawn one via F10 → 47 → Check report prints
- Or wait for a HeelKawnian death → Memorial should auto-create

---

## ✅ F10 Debug Menu Tests

- [ ] Press F10 → Debug menu appears
- [ ] Scroll to "Pawns · specialization" section
- [ ] Find button: **"47 · Memorial System"**
- [ ] Click it → Check Output panel for report

**Expected Output:**
```
=== HEELKAWN MEMORIAL SYSTEM ===
Generated: [timestamp]
Game Tick: [number]

--- MEMORIAL STATISTICS ---
Total memorials: [number]
  grave_marker: [number]
  ...

--- SACRED GEOGRAPHY ---
Remembered tiles: [number]
Sacred tiles: [number]
Holy Ground tiles: [number]

=== END MEMORIAL SYSTEM REPORT ===
```

---

## ✅ Memorial System Tests

### Auto-Creation on Events
- [ ] Let a HeelKawnian die (starvation, enemy, etc.)
- [ ] Check death tile → Grave marker should appear
- [ ] Press F10 → 47 → Memorial count should increase by 1

### Sacred Geography
- [ ] Wait for multiple deaths at same location (battle)
- [ ] Tile should become "sacred" (3-4 memorials) or "holy ground" (5+)
- [ ] HeelKawnians crossing tile should slow down (reverence)

### Pilgrimage AI
- [ ] Select a HeelKawnian with family deaths
- [ ] Wait while HeelKawnian is IDLE
- [ ] HeelKawnian should occasionally pathfind to memorial tile
- [ ] On arrival: stands still briefly, then continues

---

## ✅ Performance Tests

### Frame Rate
- [ ] 1x speed: 60+ FPS
- [ ] 26x speed: 30+ FPS
- [ ] 100x speed: Playable (may drop to 20-30 FPS)

### Memory
- [ ] Run for 5 minutes (real time)
- [ ] No memory leak warnings
- [ ] FPS stays stable (no gradual degradation)

---

## ❌ Known Issues / Limitations

**None currently reported.** If you find issues, paste errors to AI.

---

## 📝 Error Reporting Format

**When you find an error, paste this format:**

```
ERROR FOUND:
[Copy full error text from Godot Output panel]

What I was doing:
[Testing SurvivalHUD / Clicking memorial / etc.]

Game Tick:
[If visible in F10 menu]
```

**AI will respond with:**
1. Fix explanation
2. Code changes
3. Instructions to retest

---

*Testing checklist v1.0 — May 6, 2026*
