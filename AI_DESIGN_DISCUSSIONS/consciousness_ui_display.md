# 💭 Design Discussion: Consciousness UI

**Status:** ✅ Decided (May 6, 2026)  
**Topic:** How to display pawn consciousness data (dreams, memories, trauma, growth)

---

## Context

PawnConsciousness.gd implements rich pawn psychology:
- Memories with emotional valence (-100 to +100)
- Dreams with themes (trauma, desire, survival, social, achievement)
- Trauma accumulation (0-100)
- Growth points from positive experiences
- Self-awareness levels (0-5: Unconscious → Transcendent)
- Core beliefs formed from experiences

**Question:** How should this data be displayed to players?

---

## Options Considered

### Option 1: Separate ConsciousnessPanel
**Description:** Dedicated panel (like PawnInfoPanel) for consciousness data.

**Pros:**
- Maximum space for detailed display
- Can show memory timeline visualization
- Room for dream interpretation text
- Doesn't crowd PawnInfoPanel

**Cons:**
- Another panel to manage/open
- UI clutter (already has ColonyHUD, ObserverHUD, etc.)
- Discovery issue (players may not find it)
- Inconsistent with existing UX patterns

---

### Option 2: Tab in PawnInfoPanel ✅ CHOSEN
**Description:** Add "Consciousness" as a tab in existing PawnInfoPanel.

**Pros:**
- Consistent with existing UX (already has Identity, Needs, Social, Narrative tabs)
- Players already know where to find pawn data
- No new scene files needed
- Shares ModernTheme styling
- Tab organization scales well

**Cons:**
- Tab can get crowded with content
- Limited vertical space
- Another tab to click through

**Mitigation:**
- Use collapsible sections
- Limit dreams/memories to 3-5 most recent
- Use compact formatting (emoji + color coding)

---

### Option 3: Overlay on Pawn Selection
**Description:** Small consciousness indicators appear above pawn when selected.

**Pros:**
- Always visible when pawn selected
- At-a-glance understanding (icon = consciousness level, color = trauma)
- Encourages noticing pawn psychology

**Cons:**
- Very limited information density
- Visual clutter above pawns
- Doesn't replace need for detailed view

**Status:** ✅ Implemented as FUTURE ENHANCEMENT (UI-007 in AI_TODO_QUEUE.md)

---

### Option 4: Chronicle Integration Only
**Description:** Show consciousness events only in ChronicleLedger, no dedicated UI.

**Pros:**
- Minimal UI addition
- Events already flow to WorldMemory
- Players discover through reading

**Cons:**
- Hard to discover
- No at-a-glance pawn mental state
- Buried in event feed

**Status:** ❌ Rejected - Consciousness too important to hide

---

## Decision

**Chosen:** Option 2 (Tab in PawnInfoPanel) + Future Option 3 (Status Icons)

**Rationale:**
- Best balance of discoverability, information density, and UI consistency
- Builds on existing patterns (PawnInfoPanel already the place for pawn data)
- Tab organization allows future expansion
- Status icons can complement (not replace) the tab

---

## Implementation Details

**Tab Structure:**
```
Consciousness
├── Self-Awareness: [Level Name] (Level N)
├── Trauma: [=====>----] 45/100 [color-coded status text]
├── Growth: Growth Points: N
├── Recent Dreams: [3 dreams with emoji, emotion color, time]
├── Significant Memories: [5 memories sorted by significance]
└── Core Beliefs: [bulleted list]
```

**Formatting:**
- Dreams: `💀 Being chased [color=#FF4444](trauma) [color=#666](12 min ago)`
- Memories: `[color=#44FF44]Joyful[/color] • First hunt success [color=#666](2 hr ago)`
- Trauma bar: Green (<25), Yellow (25-49), Orange (50-79), Red (≥80)

**Update Frequency:**
- Polls every 0.35s (same as PawnInfoPanel)
- Only updates if data signature changes

---

## Future Enhancements

**If players want more:**
1. Click dream/memory to expand full details
2. Memory timeline visualization (graph over time)
3. Beliefs editor (let players name beliefs)
4. Consciousness comparison (compare two pawns)

**If tab too crowded:**
1. Collapsible sections
2. Reduce dream/memory count (3→2)
3. Move beliefs to Identity tab

---

## Related Files

- `scripts/ui/PawnInfoPanel.gd` - Implementation
- `autoloads/PawnConsciousness.gd` - Data source
- `AI_TODO_QUEUE.md` UI-007 - Future status icon enhancement

---

*Discussion closed: May 6, 2026 (Decision implemented)*
