# HeelKawn System Testing Guide
## Complete Verification and Troubleshooting Instructions

### 🎯 **QUICK START - 5 Minute Verification**

1. **Launch the Game**
   ```bash
   .\tools\godot\Godot_v4.6.2-stable_win64.exe --path "." "scenes/main/Main.tscn"
   ```

2. **Verify Success Indicators**
   - ✅ Look for: `[DayNight] Day 1 begins (tick 1)`
   - ✅ Game window opens with world view
   - ✅ No red error messages in console
   - ✅ Pawns spawn and move around

3. **Check AI Agents**
   - Look for right-side AI Agent Debug Panel
   - Should show 8 agents (2 Strategic, 4 Tactical, 2 Reactive)
   - Enable checkbox should be checked

---

## 🔧 **COMPLETE SYSTEM CHECKLIST**

### **Phase 4 Systems (Cultural Divergence)**
- [ ] **Settlements spawn and develop cultures**
  - Check for different colored buildings (OPEN=blue, CAUTIOUS=gray, DEFENSIVE=red)
  - Settlements should show cultural architectural styles
- [ ] **Wildlife HUD displays trends**
  - Bottom-left should show animal populations
  - Should update with momentum sparks
- [ ] **Settlement rebirth system**
  - Abandoned settlements should eventually recover
  - Check for scar levels and recovery stages

### **Phase 5 Systems (Grand Strategy Bridge)**
- [ ] **ObservationAPI working**
  - AI agents should observe pawn/tile/settlement data
  - Check debug panel for agent observations
- [ ] **CommandAPI functional**
  - AI agents should execute move/work commands
  - Same validation as human players
- [ ] **MapModeOverlay (Press M)**
  - Should show regional overlays
  - TAB cycles through: Regions, Settlements, Culture, Scar Level, Governance

### **AI Agent Framework**
- [ ] **Agent Population**
  - 8 initial agents should spawn
  - Agents should incarnate into available pawns
  - Dead agents should be replaced
- [ ] **Decision Making**
  - Agents should set goals (survival, work, social)
  - Should execute actions every 30 ticks
  - Personality affects behavior choices
- [ ] **Debug Panel**
  - Real-time agent status updates
  - Click agents to see details
  - Spawn button creates new agents

---

## 🐛 **COMMON ISSUES & SOLUTIONS**

### **Game Won't Start**
**Problem**: Compilation errors, red console messages
**Solution**:
1. Check for missing files in `logs/*.log`
2. Verify Godot version is 4.6.2
3. Ensure all autoload scripts are in `autoloads/` folder
4. Check `project.godot` for correct paths

### **AI Agents Not Working**
**Problem**: Debug panel shows "Agent not found"
**Solution**:
1. Check if AIAgentManager autoload is enabled
2. Verify `AIAgentManager.enabled = true`
3. Look for agent spawn errors in console
4. Ensure pawns are available for incarnation

### **Map Mode Overlay Issues**
**Problem**: Pressing M does nothing
**Solution**:
1. Check if MapModeOverlay initialized in Main.gd
2. Verify scene file exists: `scenes/ui/MapModeOverlay.tscn`
3. Check for CanvasLayer rendering errors

### **Performance Issues**
**Problem**: Game runs slowly or stutters
**Solution**:
1. Reduce AI agent count in AIAgentManager
2. Lower update frequency from 30 to 60 ticks
3. Disable debug panels in production
4. Check for infinite loops in AI decision-making

---

## 🔍 **DETAILED VERIFICATION STEPS**

### **1. Core Game Loop Test**
```bash
# Run game and watch for these messages:
[INFO] PawnSpawner: pawn_scene loaded successfully
[DayNight] Day 1 begins (tick 1)
```

**Expected**: Game starts, pawns spawn, day/night cycle begins

### **2. Phase 4 Cultural Systems**
```bash
# In game, look for:
- Different colored buildings
- Wildlife trends in bottom-left
- Settlement state changes
```

**Expected**: Cultural divergence visible, wildlife population dynamics

### **3. Phase 5 APIs Test**
```bash
# In debug console (F1), test:
ObservationAPI.observe_camera_view()
CommandAPI.get_available_commands(-1)
```

**Expected**: API calls return valid data structures

### **4. AI Agent Framework Test**
```bash
# Check AI Agent Debug Panel:
- Agent count should be 8
- Click agents to see details
- Spawn button should create new agents
```

**Expected**: Agents active, making decisions, executing actions

### **5. Map Mode Test**
```bash
# Press M to toggle map overlay
# Press TAB to cycle modes
```

**Expected**: Regional overlays appear, modes cycle correctly

---

## 📊 **PERFORMANCE MONITORING**

### **Key Metrics to Watch**
- **FPS**: Should stay above 30 for smooth gameplay
- **Memory Usage**: Monitor for memory leaks
- **AI Agent Count**: Should not exceed max_agents (10)
- **Update Frequency**: 30 ticks = ~0.5 seconds at 1x speed

### **Debug Commands**
```bash
# In game console (F1):
AIAgentManager.get_all_agent_status()
AIAgentManager.get_agent_count()
ObservationAPI.observe_camera_view()
```

---

## 🚀 **OPTIMIZATION TIPS**

### **For Better Performance**
1. **Reduce AI Agents**: Lower `max_agents` in AIAgentManager
2. **Increase Update Frequency**: Change from 30 to 60 ticks
3. **Disable Debug Panels**: Hide in production builds
4. **Limit Map Mode**: Don't keep overlay active continuously

### **For Development**
1. **Enable Debug Mode**: Keep AI Agent Debug Panel visible
2. **Monitor Logs**: Check `logs/*.log` for errors
3. **Test Incrementally**: Verify each system separately
4. **Use Godot Debugger**: Set breakpoints in critical code

---

## 🎮 **INTERACTIVE TESTING**

### **Human Player Tests**
1. **Incarnation System**
   - Press I to open incarnation menu
   - Select a pawn to incarnate
   - Verify control transfer works

2. **Command System**
   - Move pawn with mouse clicks
   - Try to claim jobs
   - Test inspect actions

3. **Map Mode Navigation**
   - Press M to toggle overlay
   - Use TAB to cycle modes
   - Check different data visualizations

### **AI Agent Tests**
1. **Agent Behavior**
   - Watch agents make decisions
   - Observe goal completion
   - Check personality-driven choices

2. **Agent Interaction**
   - Spawn new agents with debug panel
   - Force incarnation into specific pawns
   - Add custom goals for testing

---

## 📋 **FINAL VALIDATION CHECKLIST**

### **Before Committing Changes**
- [ ] Game boots without errors
- [ ] All Phase 4 systems functional
- [ ] All Phase 5 APIs working
- [ ] AI agents active and making decisions
- [ ] Debug panels operational
- [ ] Performance acceptable (>30 FPS)
- [ ] No memory leaks detected
- [ ] All autoload scripts loaded

### **After Major Changes**
- [ ] Run full system test
- [ ] Check all debug panels
- [ ] Verify AI agent population
- [ ] Test map mode overlay
- [ ] Confirm cultural systems
- [ ] Validate performance metrics

---

## 🆘 **TROUBLESHOOTING FLOW**

### **If Something Doesn't Work**
1. **Check Console Logs**: Look for red error messages
2. **Verify File Structure**: Ensure all files in correct folders
3. **Test Components Individually**: Isolate the problem
4. **Check Recent Changes**: Revert if necessary
5. **Consult Logs**: Review `logs/*.log` files
6. **Ask for Help**: Provide specific error messages

### **Critical Files to Check**
- `project.godot` - Autoload configuration
- `scenes/main/Main.tscn` - Main scene structure
- `autoloads/*.gd` - Core system scripts
- `logs/*.log` - Error and debug information

---

## 🏆 **SUCCESS CRITERIA**

### **System Working Correctly When**
✅ Game boots with "Day 1 begins (tick 1)"
✅ Pawns spawn and move autonomously
✅ Cultural divergence visible (colored buildings)
✅ Wildlife HUD shows population trends
✅ AI agents make decisions and execute actions
✅ Map mode overlay displays regional data
✅ Debug panels show real-time information
✅ Performance stays above 30 FPS
✅ No critical errors in console
✅ All systems integrate seamlessly

---

**Remember**: This is a complex simulation system. Some minor warnings are normal, but the game should be fully functional with all major systems operational.
