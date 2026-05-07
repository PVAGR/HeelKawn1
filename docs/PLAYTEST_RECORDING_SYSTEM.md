# 🎮 Automated Playtest Recording System

**Created:** May 7, 2026  
**Purpose:** Automatically record EVERYTHING during gameplay sessions for AI analysis and debugging

---

## 📋 What Gets Recorded

### 1. **Game Events** (Tick-by-Tick)
- All WorldMemory events (births, deaths, jobs, settlements)
- Game speed changes
- Pause/unpause events
- Tick processing times

### 2. **Pawn Actions**
- Job claims
- Job completions
- State changes (idle → working → sleeping → etc.)
- Movement paths
- Teaching sessions
- Challenge/fight events
- Pilgrimage visits

### 3. **Player Input**
- Mouse clicks (position, button, target UI element, world tile)
- Key presses (keycode, modifiers)
- Camera movement (position, zoom)
- Pawn selections
- Building placements
- Command mode actions

### 4. **Performance Metrics** (Sampled Every 60 Ticks)
- FPS (current + average)
- Memory usage (MB)
- Tick duration (peak + average)
- Game speed

### 5. **Errors & Warnings**
- All Godot errors with stack traces
- All warnings
- Custom validation failures

### 6. **Settlement Changes**
- Settlement founding
- State changes (active → abandoned → reviving → permanent_ruin)
- Rebirth events
- Culture changes

### 7. **Knowledge System**
- Knowledge taught
- Knowledge learned
- Knowledge stones inscribed
- Knowledge rediscovered/lost

### 8. **Social Dynamics**
- Grudges formed
- Grudges closed (memorial visits)
- Gossip spread
- Reputation changes
- Social bond milestones

---

## 📁 Output Files

### Main Playtest Report
**Location:** `logs/playtest/YYYY-MM-DD-HHMMSS_playtest.json`

**Structure:**
```json
{
  "session_id": "20260507_014530_playtest",
  "session_start_time": "2026-05-07T01:45:30",
  "session_end_time": "2026-05-07T02:15:45",
  "start_tick": 0,
  "end_tick": 45678,
  "total_ticks": 45678,
  "total_records": 12345,
  "performance_samples": [...],
  "errors": [...],
  "warnings": [...],
  "records": [
    {
      "tick": 0,
      "timestamp": 1234567,
      "event_type": "session_start",
      "data": {...}
    },
    {
      "tick": 1,
      "timestamp": 1234568,
      "event_type": "world_event",
      "data": {
        "event_type": "pawn_birth",
        "tick": 1,
        "data": {...}
      }
    },
    ...
  ]
}
```

### Backup Files (Auto-Saved Every 100/500/1000/1500 Ticks - Varied)
**Location:** `logs/playtest/YYYY-MM-DD-HHMMSS_backup.json`

Contains incremental backup of records up to that point.

### Input Recording
**Location:** Embedded in main playtest report under `records` with `event_type: "player_action"`

---

## 🔧 How It Works

### System Architecture

```
┌─────────────────────────────────────────────────┐
│          PlaytestRecorder (Autoload)            │
│  - Records all game events                      │
│  - Samples performance metrics                  │
│  - Auto-saves every 100/500/1000/1500 ticks (varied)
│  - Saves final report on game close             │
└─────────────────────────────────────────────────┘
           ↕ connects to signals
┌─────────────────────────────────────────────────┐
│        PlaytestInputRecorder (Autoload)         │
│  - Records mouse clicks                         │
│  - Records key presses                          │
│  - Records camera movement                      │
│  - Records pawn selections                      │
│  - Records building placements                  │
└─────────────────────────────────────────────────┘
           ↕ hooks into
┌─────────────────────────────────────────────────┐
│              Main.gd                            │
│  - Pawn selection events                        │
│  - Camera movement events                       │
└─────────────────────────────────────────────────┘
           ↕ monitors
┌─────────────────────────────────────────────────┐
│           Game Systems                          │
│  - WorldMemory (all events)                     │
│  - JobManager (job lifecycle)                   │
│  - TickManager (tick timing)                    │
│  - SettlementMemory (settlement events)         │
│  - GameManager (speed, pause)                   │
└─────────────────────────────────────────────────┘
```

### Recording Flow

1. **Game Boot** → `PlaytestRecorder._ready()` → `start_recording()`
2. **Each Tick** → Records tick event (sampled every 10th tick)
3. **World Event** → `WorldMemory.event_appended` → Record event
4. **Job Posted/Claimed/Done** → Record job lifecycle
5. **Player Input** → `PlaytestInputRecorder._unhandled_input()` → Record input
6. **Every 60 Ticks** → Sample performance (FPS, memory, tick duration)
7. **Every 100/500/1000/1500 Ticks (Varied)** → Auto-save backup
8. **Game Close** → Save final report

---

## 📊 How AI Uses This Data

### After Each Playtest Session

**AI scans the JSON report to understand:**

1. **What Broke?**
   - Check `errors` array for Godot errors
   - Check `warnings` for potential issues
   - Correlate errors with game state at time of failure

2. **Performance Issues?**
   - Analyze `performance_samples` for FPS drops
   - Check `peak_tick_ms` for lag spikes
   - Identify ticks with longest processing times

3. **Player Behavior?**
   - Analyze `player_action` records
   - See which UI elements player used most
   - Track camera movement patterns
   - Identify common pawn selection patterns

4. **Game Balance?**
   - Count job types claimed vs ignored
   - Track pawn death causes (starvation, dehydration, etc.)
   - Measure time to first settlement
   - Analyze resource consumption rates

5. **Emergent Behavior?**
   - Track grudge formation chains
   - Monitor gossip spread patterns
   - Identify memorial pilgrimage frequency
   - Observe teaching chain formation

### Example AI Analysis Workflow

```
1. AI reads playtest report JSON
2. Extracts error/warning counts
3. If errors found:
   - Filter records by tick range around first error
   - Identify what player was doing (input records)
   - Check what game events preceded error
   - Correlate with performance metrics
   - Propose fix based on root cause
4. If performance issues:
   - Identify ticks with peak duration
   - Check what systems were active
   - Propose optimizations
5. Update AI_SESSIONS/current.md with findings
6. Implement fixes
7. Ask human to re-test
```

---

## 🎯 Usage Instructions

### For Humans

**You don't need to do anything!** The system:
- ✅ Starts recording automatically on game boot
- ✅ Records everything in the background
- ✅ Auto-saves every 100/500/1000/1500 ticks (varied, no data loss on crash)
- ✅ Saves final report when you close the game
- ✅ Stores in `logs/playtest/` folder

**To Review a Playtest:**
1. Open `logs/playtest/` folder
2. Find the most recent JSON file (sorted by date in filename)
3. Open in text editor or JSON viewer
4. Search for `"event_type": "error"` to find errors
5. Share the JSON with AI for analysis

### For AI

**At session start:**
1. Read `logs/playtest/` folder
2. Find most recent playtest JSON
3. Parse and analyze:
   - Error count and types
   - Performance metrics
   - Player behavior patterns
4. Update `AI_SESSIONS/current.md` with findings
5. Prioritize fixes based on severity

**Key Analysis Queries:**
```python
# Find all errors
errors = [r for r in records if r['event_type'] == 'error']

# Find performance spikes (>100ms tick)
spikes = [s for s in performance_samples if s['peak_tick_ms'] > 100]

# Find player actions around tick X
actions = [r for r in records 
           if r['event_type'] == 'player_action' 
           and abs(r['tick'] - X) < 50]

# Find all pawn deaths
deaths = [r for r in records 
          if r['event_type'] == 'world_event' 
          and r['data'].get('event_type') == 'pawn_death']
```

---

## 📈 Performance Impact

**Minimal overhead:**
- Event recording: ~0.01ms per event (sampled every 10th tick)
- Performance sampling: ~0.1ms every 60 ticks
- Auto-save: ~50ms every 100/500/1000/1500 ticks (varied, async, doesn't block game)
- Memory: ~100MB for 1-hour session at 100x speed

**Disabled automatically if:**
- Game running at >200x speed (reduce overhead)
- Memory usage exceeds 1GB (prevent crash)
- Record count exceeds 100,000 (cap file size)

---

## 🔮 Future Enhancements

**Potential additions:**
- [ ] Replay system (deterministic replay from recording)
- [ ] Heatmap visualization (pawn movement, player clicks)
- [ ] Automated anomaly detection (AI flags unusual patterns)
- [ ] Comparative analysis (compare multiple playtests)
- [ ] Live streaming to AI (real-time analysis during playtest)

---

*Automated Playtest Recording System v1.0 — "Every tick matters. Every action recorded."*
