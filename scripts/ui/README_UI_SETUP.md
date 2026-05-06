# HeelKawn UI - One-Click Installation

## 🎮 **AUTOMATIC SETUP (EASIEST)**

### **Method 1: Auto-Add to Main Scene**

1. **Open Main.tscn** in Godot
2. **Right-click on Main node** → "Add Child Node"
3. **Search for "UIAutoSetup"** → Select it → Click Create
4. **Done!** UI is now installed

**That's it. No manual setup required.**

The UI will:
- ✅ Add Survival HUD (always visible)
- ✅ Add Inventory (press I)
- ✅ Add Action Menu (right-click)
- ✅ Add Chronicles (press C)
- ✅ Add Character Status (press K)
- ✅ Show help on first run (press H)

---

### **Method 2: Manual Add (If Auto Doesn't Work)**

1. **Open Main.tscn**
2. **Add Child Node** → Script → Create New
3. **Path:** `res://scripts/ui/UIManager.gd`
4. **Done!**

---

## 🎮 **CONTROLS**

### **Always Visible:**
- **Survival HUD** (top-left) - Shows hunger, thirst, energy, temperature, health

### **Hotkeys:**
| Key | Action |
|-----|--------|
| **I** | Toggle Inventory |
| **C** | Toggle Chronicles (history) |
| **K** | Toggle Character Status |
| **H** or **F1** | Toggle Help |
| **TAB** | Toggle all UI |
| **Right-Click** | Action Menu (gather/build) |

---

## 🎨 **WHAT YOU SEE**

### **Survival HUD (Top-Left):**
```
❤️ Health:   [==========] 100%
🍖 Hunger:   [========--]  80%
💧 Thirst:   [=======---]  70%
⚡ Energy:   [=========]  90%
🌡️ Temp:     37.0°C (Normal)
```

### **Inventory (Press I):**
```
🎒 Inventory

🪵 Wood      x15
🪨 Stone     x8
🫐 Berries   x12
🔩 Flint     x5
🥢 Stick     x10
```

### **Action Menu (Right-Click):**
```
Actions

🪵 Gather Wood
🪨 Gather Stone
🫐 Gather Berries
🏗️ Build Foundation
🔥 Build Fire Pit
❌ Cancel
```

### **Chronicles (Press C):**
```
📜 Chronicles & History

Tab: [Chronicles] [Actions] [Scars]

In the Year 1, the people struggled to survive.
Notable: Player gathered wood; Player built shelter
```

### **Character Status (Press K):**
```
👤 Character

Awareness: Aware (Level 2)
Trauma: 25.5/100 🟢
Growth Points: 150

Recent Memories:
😊 Built first shelter
😢 Witnessed death
😐 Gathered wood
```

---

## 🔧 **TROUBLESHOOTING**

### **UI Not Showing:**
1. Check if UIManager is child of Main node
2. Press H or F1 to show help
3. Check Output panel for errors

### **Hotkeys Not Working:**
1. Make sure game window is focused
2. Check if other scripts are blocking input
3. Try pressing keys while game is running (not editor)

### **Inventory Empty:**
1. Gather resources first (right-click tree/rock/bush)
2. Check if PlayerGathering autoload is enabled

### **Chronicles Empty:**
1. Perform some actions (gather, build, etc.)
2. Wait for chronicle generation (every 100 actions)

---

## 🎮 **FIRST TIME PLAYING:**

1. **Press H** - Read help menu
2. **Right-click tree** - Gather wood
3. **Press I** - See wood in inventory
4. **Right-click ground** - Build foundation
5. **Press C** - See your action recorded in chronicles
6. **Press K** - See your character status

---

## ✅ **THAT'S IT!**

**No complex setup. No manual configuration.**

**Just add UIAutoSetup node and play!**

---

## 🚀 **NEXT STEPS:**

After UI is working:
1. Test survival (watch hunger/thirst bars)
2. Gather resources (right-click trees/rocks)
3. Build shelter (right-click ground → Build)
4. Read your history (press C)
5. Watch your pawn grow conscious (press K)

**Enjoy HeelKawn!** 🎉
