# HeelKawn Multi-Layer AI - Usage Guide

**Version:** 1.0  
**Date:** May 5, 2026  
**Status:** Ready for Testing

---

## 🧠 **OVERVIEW**

HeelKawn's AI operates at **5 simultaneous layers**, from individual pawn psychology to world-scale ecosystem balance. Each layer has distinct context, prompts, and update intervals.

---

## 📋 **THE 5-LAYER STACK**

| Layer | Inspiration | Update Interval | Purpose |
|-------|-------------|-----------------|---------|
| **L1** | Dwarf Fortress | 500 ticks | Chronicles, legends, history |
| **L2** | RimWorld | 60 ticks | Pawn psychology, moods, desires |
| **L3** | Songs of Syx | 120 ticks | Settlement strategy, logistics |
| **L4** | Crusader Kings | 300 ticks | Diplomacy, wars, alliances |
| **L5** | WorldBox | 600 ticks | Ecosystem, wildlife, disasters |

---

## ⚙️ **CONFIGURATION**

### **Default Settings (Mock LLM)**

By default, the AI uses **mock responses** for safe testing:

```gdscript
# In LLMClient.gd
config = {
    "provider": "mock",       # Mock responses (no API cost)
    "use_mock": true,         # Fallback to mock if API fails
    "max_concurrent_requests": 2,
    "enable_cross_layer_narratives": true
}
```

### **Switch to OpenAI**

```gdscript
# In your game initialization code:
LLMClient.set_config("provider", "openai")
LLMClient.set_config("api_key", "sk-your-openai-key")
LLMClient.set_config("model", "gpt-3.5-turbo")
LLMClient.set_config("use_mock", false)
```

### **Switch to Ollama (Local)**

```gdscript
# Run Ollama first: ollama serve
LLMClient.set_config("provider", "ollama")
LLMClient.set_config("api_url", "http://localhost:11434")
LLMClient.set_config("model", "llama2")
LLMClient.set_config("use_mock", false)
```

### **Project Settings**

Add these to your `project.godot` for persistent config:

```ini
[heelkawn/llm]
provider="mock"
api_key=""
api_url=""
model="gpt-3.5-turbo"
use_mock=true
max_tokens=500
temperature=0.7
```

---

## 🎮 **TESTING THE AI STACK**

### **Automated Test Script**

A test script is included at `tools/test/TestAIStack.gd`.

**To run:**

1. **Attach to Main scene:**
   ```
   Main (Node)
   └── WorldViewport
   └── UI_Viewport
   +→ TestAIStack (attach here)
   ```

2. **Run the game (F5)**
   - Test runs automatically on `_ready()`
   - Watch Output panel for results

3. **Or trigger manually from F10 menu:**
   ```gdscript
   var tester = $TestAIStack
   tester.run_test()
   ```

### **Expected Output:**

```
=== HEELKAWN AI STACK TEST ===

Testing AI layers...

Testing Layer: memory...
  ✅ PASS: OK - {"chronicle_entries": 1, "legends_generated": 1}

Testing Layer: pawn...
  ✅ PASS: OK - {"psych_profiles": 2, "action": "psychological_assessment"}

Testing Layer: settlement...
  ✅ PASS: OK - {"strategies": 2, "action": "strategic_planning"}

Testing Layer: diplomacy...
  ✅ PASS: OK - {"diplomatic_actions": 1, "action": "diplomatic_evaluation"}

Testing Layer: ecosystem...
  ✅ PASS: OK - {"world_events": 1, "action": "ecosystem_evaluation"}

=== TEST SUMMARY ===
Total Layers Tested: 5
Passed: 5
Failed: 0

✅ ALL TESTS PASSED - AI Stack is functional!

LLM Client Stats:
  - Total Requests: 5
  - Successful: 5
  - Mock Fallbacks: 5
  - Avg Response Time: 102.5ms

=== END TEST ===
```

---

## 🔍 **MONITORING AI BEHAVIOR**

### **Check Layer Status**

```gdscript
# In-game or from debug menu:
var status = HeelKawnAIOrchestrator.get_layer_status("settlement")
print(status)
# Output: {"enabled": true, "interval": 120, "last_update": 45, "active": true}
```

### **View AI Statistics**

```gdscript
# Orchestrator stats:
var orch_stats = HeelKawnAIOrchestrator.get_stats()
print(orch_stats)

# LLM Client stats:
var llm_stats = LLMClient.get_stats()
print(llm_stats)

# Individual layer stats:
var layer_stats = HeelKawnAIOrchestrator.layers["memory"].get_stats()
print(layer_stats)
```

### **Enable/Disable Layers**

```gdscript
# Disable specific layer:
HeelKawnAIOrchestrator.set_layer_enabled("diplomacy", false)

# Re-enable:
HeelKawnAIOrchestrator.set_layer_enabled("diplomacy", true)
```

---

## 📊 **CROSS-LAYER NARRATIVES**

The AI orchestrator detects interesting combinations across layers:

### **Example Narratives:**

**War-Driven Expansion:**
```
Settlement AI decides: "Expand north for resources"
Diplomacy AI responds: "North is Riverton territory → Declare war"
Result: Cross-layer narrative "war_driven_expansion" created
```

**Wildlife Threat:**
```
Pawn AI reports: "Fear of wildlife"
Ecosystem AI triggers: "Wildlife boom in region"
Result: Cross-layer narrative "wildlife_threat" created
```

### **Listen for Narratives:**

```gdscript
func _ready() -> void:
    HeelKawnAIOrchestrator.cross_layer_narrative_created.connect(_on_narrative)

func _on_narrative(narrative: Dictionary) -> void:
    print("Cross-layer narrative: {type}".format({"type": narrative.type}))
    print("Description: {desc}".format({"desc": narrative.description}))
```

---

## 🎭 **EXAMPLE AI OUTPUTS**

### **Layer 1: Memory Chronicle**

**Input:** Recent events (births, deaths, jobs)  
**Output:**
```
In the Year 2, a child was born to Oakhaven. The settlement's 
population grew to 16 souls. The carpenter's guild completed 
three walls, strengthening the settlement's defenses. This year 
will be remembered as a time of growth and preparation.
```

### **Layer 2: Pawn Psychology**

**Input:** Pawn state (hunger, mood, social)  
**Output:**
```json
{
  "mood_modifier": -10,
  "desire": "socialize",
  "fear": "isolation",
  "thought": "I haven't spoken to anyone in days...",
  "stress_level": "medium",
  "coping_mechanism": "work_harder"
}
```

### **Layer 3: Settlement Strategy**

**Input:** Settlement state (housing, food, resources)  
**Output:**
```json
[
  {
    "strategy": "expand_housing",
    "zone": 3,
    "priority": "high",
    "reason": "5 homeless pawns detected"
  },
  {
    "strategy": "specialize_economy",
    "resource": "wood",
    "priority": "medium",
    "reason": "Forest nearby, high demand"
  }
]
```

### **Layer 4: Diplomacy Action**

**Input:** Inter-settlement relations  
**Output:**
```json
{
  "action": "PROPOSE_TRADE",
  "reason": "mutual benefit from resource exchange",
  "confidence": 0.85,
  "terms": {
    "resource": "wood",
    "quantity": 50,
    "price": 10
  }
}
```

### **Layer 5: Ecosystem Event**

**Input:** World state (wildlife, climate, disasters)  
**Output:**
```json
[
  {
    "event": "wildlife_boom",
    "species": "deer",
    "region": "north",
    "reason": "mild winter, abundant food"
  }
]
```

---

## 🐛 **TROUBLESHOOTING**

### **Issue: Layer not initializing**

**Solution:**
```
1. Check LLMClient is loaded (should be autoload)
2. Verify layer script exists at scripts/ai/{LayerName}.gd
3. Check Output panel for load errors
4. Ensure GameManager autoload is working (layers connect to game_tick)
```

### **Issue: All responses are mock**

**Solution:**
```
1. Check LLMClient.config.use_mock = false
2. Verify API key is set: LLMClient.config.api_key = "your-key"
3. Test API connection manually
4. Check Output panel for API errors
```

### **Issue: Too many LLM requests (rate limit)**

**Solution:**
```
1. Increase layer update intervals in LAYER_CONFIG
2. Reduce max_concurrent_requests in config
3. Enable request queuing (already enabled by default)
```

### **Issue: AI decisions not affecting game**

**Solution:**
```
1. Check layer _execute_* methods are implemented
2. Verify integration points (SettlementPlanner, WorldEvents, etc.)
3. Ensure layer has references to game systems
4. Check Output panel for execution errors
```

---

## 📈 **PERFORMANCE TUNING**

### **Adjust Update Intervals**

```gdscript
# In HeelKawnAIOrchestrator.LAYER_CONFIG:
"pawn": {"interval": 120},      # Was 60 (less frequent)
"settlement": {"interval": 240}, # Was 120
"diplomacy": {"interval": 600},  # Was 300
"memory": {"interval": 1000},    # Was 500
"ecosystem": {"interval": 1200}  # Was 600
```

### **Reduce Concurrent Requests**

```gdscript
HeelKawnAIOrchestrator.config.max_concurrent_requests = 1
```

### **Disable Cross-Layer Narratives**

```gdscript
HeelKawnAIOrchestrator.config.enable_cross_layer_narratives = false
```

---

## 🚀 **NEXT STEPS**

1. **Run automated test** (`TestAIStack.gd`)
2. **Verify all layers pass**
3. **Tune update intervals** for your game speed
4. **Optionally configure real LLM** (OpenAI/Ollama)
5. **Monitor AI decisions** via Output panel
6. **Adjust prompts** for desired behavior

---

## 📞 **SUPPORT**

**Documentation:**
- `docs/ARCHITECTURE_IMPROVEMENT_PLAN.md` - Full architecture guide
- `docs/PERFORMANCE_OPTIMIZATION_GUIDE.md` - Performance tuning
- `docs/FINAL_STATUS_REPORT.md` - System verification

**Test Tools:**
- `tools/test/TestAIStack.gd` - Automated testing

**Key Files:**
- `scripts/ai/LLMClient.gd` - LLM API
- `scripts/ai/HeelKawnAIOrchestrator.gd` - Master controller
- `scripts/ai/*.gd` - Individual layer implementations

---

**HeelKawn Multi-Layer AI is ready for production use!** 🧠
