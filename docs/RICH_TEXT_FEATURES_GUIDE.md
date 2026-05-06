# HeelKawn - Rich Text Features Guide

## 🎮 HOW TO ACCESS ALL RICH TEXT FEATURES

### **1. Pawn Narratives (Click Any Pawn)**
**Location:** Right-side info panel → "Narrative" tab

**How to see it:**
1. Click on any pawn in the game
2. Right-side panel opens
3. Click the **"Narrative"** tab (last tab)
4. See their current activity, skills, family, history

**What you'll see:**
```
═══ XARA THE FARMER ═══
Age: 28.5 years | Level: 5 | Mood: Content

📍 CURRENTLY: Foraging at (145,89)
🎒 CARRYING: 3 berries → heading to stockpile
📊 SKILLS: Foraging 15, Building 3
📜 RECENT HISTORY: Completed foraging (2 min ago)
🏠 HOME: Ashwell Settlement (Active)
👨‍👩‍👧‍👦 FAMILY: 3 children | Child of Aldric & Brenna
⭐ LEGACY SCORE: 245
```

---

### **2. Event Notifications (Automatic Popups)**
**Location:** Right side of screen

**How to see them:**
- Just play the game! They appear automatically when:
  - A pawn is born (👶 teal)
  - A pawn dies (⚰ red) - **CLICK IT to see full biography!**
  - Knowledge is inscribed (📜 purple)
  - Buildings are constructed (🏗 gold)
  - Friendship milestones (💕 orange)

**Interactive Feature:**
- **Click death notifications** → Opens full pawn biography dialog!

---

### **3. Knowledge Stones (Right-Click to Read)**
**Location:** In the game world (blue stone sprites)

**How to access:**
1. Wait for a pawn to carve knowledge (Scholar profession)
2. Find the blue stone that appears
3. **Right-click the stone**
4. Full inscription text appears in dialog

**What you'll see:**
```
═══ KNOWLEDGE STONE ═══

Inscribed by Xara, 5 years ago

PRESERVED KNOWLEDGE:
  • Fire Keeping
  • Tool Making
  • Shelter Building

"Knowledge preserved, that it might not be lost."
```

---

### **4. Pawn Biographies (On Death)**
**Location:** Output panel (bottom of Godot editor)

**How to see them:**
1. Let a pawn die (old age, starvation, etc.)
2. Watch the **Output panel** (Godot editor bottom)
3. Full life story prints automatically

**Alternative:**
- Click a death notification popup → Biography dialog opens!

**What you'll see:**
```
═══ BIOGRAPHY: Xara ═══
Born: Year 1, Day 5
Died: Year 29, Day 15 (28.5 years old)

IDENTITY
  Profession: Farmer
  Level: 5 | Legacy Score: 245

FAMILY
  Parents: Aldric & Brenna
  Spouse: Cormac
  Children: 3

SKILLS & KNOWLEDGE
  Foraging 15, Building 8, Hunting 5

LIFE EVENTS
  Y1 D5: Born
  Y5 D12: Completed foraging
  Y8 D3: Taught foraging
```

---

### **5. Settlement Legends (F10 Debug Menu)**
**Location:** F10 → #72 Settlement Legends

**How to access:**
1. Press **F10** during gameplay
2. Click **"72 · Settlement Legends"**
3. Read emergent myths for each settlement

**What you'll see:**
```
═══ THE LEGEND OF ASHWELL ═══

THE FOUNDING
  In the beginning, ASHWELL was but a dream...

THE SETTLEMENT'S CHARACTER
  The people of ASHWELL are known for their wisdom...

REMEMBERED HEROES
  Xara: taught 12 students, preserved knowledge on stone.
  Aldric: built 8 structures.
```

---

### **6. Chronicle View (F10 Debug Menu)**
**Location:** F10 → #71 Chronicle View

**How to access:**
1. Press **F10** during gameplay
2. Click **"71 · Chronicle View"**
3. See settlement history organized by year

**What you'll see:**
```
═══ Ashwell Settlement ═══

Year 1:
  🏰 Ashwell Settlement was founded
  👶 Aldric was born
  📚 Taught foraging
  ⚰ Brenna died (old_age)

Year 2:
  👶 Cormac was born
  🏗 Built storage hut
```

---

### **7. Dynasty Tree (F10 Debug Menu)**
**Location:** F10 → #74 Dynasty Tree

**How to access:**
1. Press **F10** during gameplay
2. Click **"74 · Dynasty Tree"**
3. New window opens with visual family tree

**Features:**
- Shows all generations
- Click any member → See their biography
- Shows profession, legacy score

---

### **8. Endgame Status (F10 Debug Menu)**
**Location:** F10 → #75 Endgame Status

**How to access:**
1. Press **F10** during gameplay
2. Click **"75 · Endgame Status"**
3. See your run completion progress

**What you'll see:**
```
--- RUN PROGRESS ---
Total Legacy Score: 450 / 1000 (goal)
Total Dynasties: 1
Total Dynasty Members: 8
Player Incarnations: 0

OVERALL RUN COMPLETION: 29.6%

[color=#FF9F6B]Halfway there. Your dynasty is growing.[/color]
```

---

## 🎯 QUICK REFERENCE

| Feature | How to Access | Where |
|---------|--------------|-------|
| **Pawn Narrative** | Click pawn → Narrative tab | Right panel |
| **Event Notifications** | Automatic | Right side popups |
| **Knowledge Stones** | Right-click stone | Game world |
| **Pawn Biographies** | Pawn dies OR click death notification | Output panel / Dialog |
| **Settlement Legends** | F10 → #72 | Debug menu |
| **Chronicle View** | F10 → #71 | Debug menu |
| **Dynasty Tree** | F10 → #74 | Debug menu (new window) |
| **Endgame Status** | F10 → #75 | Debug menu |

---

## ⚙️ TROUBLESHOOTING

### "I don't see the Narrative tab!"
- Make sure you're clicking a pawn (not empty ground)
- The panel opens on the RIGHT side
- Click the last tab labeled "Narrative"

### "No event notifications appearing!"
- They throttle automatically (0.3 sec minimum between notifications)
- Wait for births, deaths, or knowledge inscription events

### "Knowledge stones aren't spawning!"
- Only Scholars can inscribe knowledge
- Assign a pawn to Scholar profession
- Wait for them to complete "Inscribe Knowledge" job

### "Biographies aren't printing!"
- Check the Output panel (bottom of Godot editor)
- Or click death notification popups for dialog view

### "F10 doesn't work!"
- F10 opens debug/creator menu
- Make sure game window has focus
- Try pressing it again

---

## 🎨 VISUAL TUNING

All text-rich features use **beautiful formatting**:
- **Color-coded** sections (gold, purple, teal, red)
- **Emoji icons** for quick recognition
- **Bold headers** for organization
- **Indented lists** for readability
- **Timestamps** on events (Y1 D5 = Year 1, Day 5)

---

**All features are IMPLEMENTED and WORKING.** If you can't see something, check the troubleshooting section above!
