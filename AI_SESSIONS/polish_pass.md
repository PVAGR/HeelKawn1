# 🎨 HeelKawn Polish Pass — May 6, 2026

**AI:** Qwen Code  
**Session:** Polish Pass (Tutorial Hints, Tooltips, Quality of Life)

---

## ✅ COMPLETED: TutorialHints System

**File Created:** `scripts/ui/TutorialHints.gd` (~300 lines)

**What It Does:**
- Shows contextual hints for new players
- 9 hint types covering all major systems
- Dismissable after 8 seconds
- Persists across sessions (shown once per hint type)
- Can be reset in settings

**Hint Types:**

| Hint | Trigger | Shows Once? |
|------|---------|-------------|
| 🪵 First Gather | Player near resource with no wood/stone | ✅ Yes |
| 🔨 First Build | Player presses B key | ✅ Yes |
| 🔪 First Craft | Player presses C key | ✅ Yes |
| 🏛️ First Memorial | Pawn dies, memorial created | ✅ Yes |
| 🙏 First Pilgrimage | Pawn visits memorial | ✅ Yes |
| 📚 Knowledge At Risk | Only 1 carrier for a knowledge type | ✅ Yes |
| 💝 Grudge Closure | Grudge closed at memorial | ✅ Yes |
| 🍖 Survival Tip | Pawn hunger < 30% | ❌ No (shows every time) |
| 💾 Save Reminder | Every 5 minutes | ❌ No (repeats) |

**Example Hint Display:**
```
┌─────────────────────────────────────────────────┐
│  🔨 Building: Select a building type, then     │
│  click on the map to place. Resources are      │
│  auto-deducted.                                │
└─────────────────────────────────────────────────┘
```

**Integration:**
- Auto-creates canvas layer (layer 100, top-most)
- Connects to MemorialSystem, KnowledgeSystem, GrudgeManager
- Saves shown hints to `user://tutorial_hints_shown.json`
- Settings functions: `reset_hints()`, `toggle_hints(enabled)`

---

## 📋 Remaining Polish Items

### Tooltips (Not Yet Implemented)

**BuildingToolbar:**
- ✅ Already has tooltips on hover (shows resources, description)
- ✅ Shows affordability (green/red resource colors)

**CraftingMenu:**
- ✅ Already has tooltips on hover (shows recipe, description)
- ✅ Shows affordability

**KnowledgePanel:**
- ❌ Could add tooltips explaining each knowledge type
- ❌ Could add "teaching chain" visualization on hover

**MemorialInscription:**
- ✅ Already shows full inscription text
- ❌ Could add "Click to see this pawn's full story" hint

### Quality of Life (Not Yet Implemented)

1. **Keybinds Display**
   - Could add small "Press H for hints" indicator on first launch
   - Could show all keybinds in settings panel

2. **First-Time Experience**
   - Could add "Welcome to HeelKawn" popup on first launch
   - Could highlight UI elements one at a time (guided tour)

3. **Accessibility**
   - Colorblind mode (resource icons already have emoji + text)
   - Font size slider (already in GameSettings)

---

## 🎯 Next Steps

**Polish Pass Status:**
- ✅ TutorialHints system complete
- ❌ Settings panel integration (toggle hints, reset hints)
- ❌ First-launch welcome popup
- ❌ Keybinds display in settings

**Options:**
1. **Integrate TutorialHints into SettingsPanel** — Add toggle/reset buttons
2. **Add First-Launch Welcome** — "Welcome to HeelKawn" popup with guided tour
3. **You Test in Godot** — Run TESTING_CHECKLIST.md, paste errors, I fix
4. **Archive Session** — Move current.md to archive, mark all tracks complete

---

*Polish Pass in progress: May 6, 2026*
