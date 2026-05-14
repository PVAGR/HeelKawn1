<!--
  This is an aspirational design document. LLMClient.gd does not currently exist in the codebase.
  See brain/README.md for current state.
  Date: May 14, 2026
-->
# HeelKawn Free LLM Setup Guide

**Best Free Options for HeelKawn AI**

---

## 🏆 **RECOMMENDED: Ollama (Local, Free, Unlimited)**

**Why Ollama:**
- ✅ 100% Free (runs on your machine)
- ✅ No API keys required
- ✅ No rate limits
- ✅ Works offline
- ✅ Many models available (Llama2, Mistral, Phi, Gemma, etc.)
- ✅ Fast HTTP API
- ✅ Privacy (your data stays local)

**System Requirements:**
- **Minimum:** 8GB RAM, CPU only
- **Recommended:** 16GB RAM, GPU preferred
- **Disk Space:** 2-8GB per model

---

## 📥 **INSTALL OLLAMA (5 minutes)**

### **Windows:**

1. **Download:**
   ```
   Visit: https://ollama.com/download
   Click "Download for Windows"
   ```

2. **Install:**
   ```
   Run OllamaSetup.exe
   Follow installation wizard
   ```

3. **Verify Installation:**
   ```bash
   # Open Command Prompt or PowerShell
   ollama --version
   ```

4. **Download a Model:**
   ```bash
   # Small & Fast (4GB RAM)
   ollama pull phi3
   
   # Balanced (8GB RAM)
   ollama pull llama3.1
   
   # Large & Smart (16GB RAM)
   ollama pull mistral:7b
   
   # Best Quality (32GB RAM)
   ollama pull mixtral:8x7b
   ```

5. **Test the Model:**
   ```bash
   ollama run phi3 "Hello, how are you?"
   ```

6. **Start Ollama Server:**
   ```bash
   # Ollama runs automatically in background
   # Verify it's running:
   curl http://localhost:11434/api/version
   ```

---

### **macOS:**

```bash
# Install via Homebrew
brew install ollama

# Or download from: https://ollama.com/download

# Pull a model
ollama pull phi3

# Start server
ollama serve

# Test
ollama run phi3 "Hello"
```

---

### **Linux:**

```bash
# Install
curl -fsSL https://ollama.com/install.sh | sh

# Pull a model
ollama pull phi3

# Start server
ollama serve

# Test
ollama run phi3 "Hello"
```

---

## ⚙️ **CONFIGURE HEELKAWN FOR OLLAMA**

### **In-Game Configuration:**

Add this to your game initialization code (e.g., in `Main.gd._ready()`):

```gdscript
func _ready() -> void:
    # Configure LLMClient for Ollama
    LLMClient.set_config("provider", "ollama")
    LLMClient.set_config("api_url", "http://localhost:11434")
    LLMClient.set_config("model", "phi3")  # or "llama3.1", "mistral:7b"
    LLMClient.set_config("use_mock", false)
    LLMClient.set_config("max_tokens", 500)
    LLMClient.set_config("temperature", 0.7)
    
    print("HeelKawn AI configured for Ollama (local LLM)")
```

### **Project Settings:**

Add to `project.godot`:

```ini
[heelkawn/llm]
provider="ollama"
api_url="http://localhost:11434"
model="phi3"
use_mock=false
max_tokens=500
temperature=0.7
```

---

## 🎯 **RECOMMENDED MODELS**

### **For Low-End Systems (4-8GB RAM):**

| Model | Size | Speed | Quality | Command |
|-------|------|-------|---------|---------|
| **Phi-3 Mini** | 3.8GB | ⚡⚡⚡⚡⚡ | ⭐⭐⭐ | `ollama pull phi3` |
| **Gemma 2B** | 1.6GB | ⚡⚡⚡⚡⚡ | ⭐⭐ | `ollama pull gemma:2b` |
| **TinyLlama** | 0.7GB | ⚡⚡⚡⚡⚡ | ⭐⭐ | `ollama pull tinyllama` |

### **For Mid-Range Systems (8-16GB RAM):**

| Model | Size | Speed | Quality | Command |
|-------|------|-------|---------|---------|
| **Llama 3.1** | 8GB | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | `ollama pull llama3.1` |
| **Mistral 7B** | 7GB | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | `ollama pull mistral:7b` |
| **Phi-3 Medium** | 7GB | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | `ollama pull phi3:medium` |

### **For High-End Systems (16-32GB RAM):**

| Model | Size | Speed | Quality | Command |
|-------|------|-------|---------|---------|
| **Mixtral 8x7B** | 26GB | ⚡⚡⚡ | ⭐⭐⭐⭐⭐ | `ollama pull mixtral:8x7b` |
| **Llama 3 70B** | 40GB | ⚡⚡ | ⭐⭐⭐⭐⭐ | `ollama pull llama3:70b` |
| **Command R+** | 35GB | ⚡⚡ | ⭐⭐⭐⭐⭐ | `ollama pull command-r-plus` |

---

## 🔧 **OLLAMA CONFIGURATION**

### **Change Port (if 11434 is busy):**

```bash
# Windows (PowerShell)
$env:OLLAMA_HOST="0.0.0.0:11435"
ollama serve

# macOS/Linux
export OLLAMA_HOST="0.0.0.0:11435"
ollama serve
```

Then update HeelKawn config:
```gdscript
LLMClient.set_config("api_url", "http://localhost:11435")
```

### **GPU Acceleration:**

```bash
# Ollama auto-detects GPU
# Verify GPU is being used:
ollama run phi3 "test" --verbose

# Should show: "eval time: X ms/token (GPU)"
```

### **Model Settings:**

```bash
# Create custom model with specific settings
ollama create mymodel -f Modelfile

# Modelfile example:
FROM phi3
PARAMETER temperature 0.7
PARAMETER num_predict 500
PARAMETER top_p 0.9
```

---

## 🆓 **OTHER FREE OPTIONS**

### **1. Groq Cloud (Free Tier)**

**Pros:**
- ✅ Very fast (LPU inference)
- ✅ Free tier (100 requests/day)
- ✅ No setup required

**Cons:**
- ❌ Rate limited
- ❌ Requires internet
- ❌ API key required

**Setup:**
```
1. Visit: https://console.groq.com
2. Sign up for free account
3. Create API key
4. Configure in HeelKawn:
   LLMClient.set_config("provider", "groq")
   LLMClient.set_config("api_key", "your-groq-key")
   LLMClient.set_config("model", "llama3-8b-8192")
```

---

### **2. Hugging Face Inference API (Free Tier)**

**Pros:**
- ✅ Many models available
- ✅ Free tier available
- ✅ No setup required

**Cons:**
- ❌ Rate limited (300 requests/hour)
- ❌ Slower than local
- ❌ Requires internet

**Setup:**
```
1. Visit: https://huggingface.co
2. Sign up for free account
3. Create access token
4. Configure in HeelKawn:
   LLMClient.set_config("provider", "huggingface")
   LLMClient.set_config("api_key", "your-hf-token")
   LLMClient.set_config("model", "mistralai/Mistral-7B-Instruct")
```

---

### **3. LM Studio (Local, Free)**

**Alternative to Ollama with GUI**

**Pros:**
- ✅ User-friendly GUI
- ✅ Many models available
- ✅ Local (no internet required)
- ✅ HTTP API compatible

**Setup:**
```
1. Download: https://lmstudio.ai
2. Install and launch
3. Download a model from the hub
4. Start local server (port 1234)
5. Configure in HeelKawn:
   LLMClient.set_config("provider", "ollama")  # Uses same API
   LLMClient.set_config("api_url", "http://localhost:1234/v1")
   LLMClient.set_config("model", "local-model")
```

---

## 🎯 **FINAL RECOMMENDATION**

### **For Most Users: Ollama + Phi-3**

```bash
# Install Ollama
# Download Phi-3 model
ollama pull phi3

# Configure HeelKawn
LLMClient.set_config("provider", "ollama")
LLMClient.set_config("api_url", "http://localhost:11434")
LLMClient.set_config("model", "phi3")
LLMClient.set_config("use_mock", false)
```

**Why this combo:**
- Phi-3 is small (3.8GB) but smart
- Runs on most modern computers
- Fast responses (~1-2 seconds)
- Good quality for game AI
- Completely free forever
- No API keys, no rate limits

---

## 🧪 **TEST YOUR SETUP**

```gdscript
# In HeelKawn, run this test:
func test_llm() -> void:
    print("Testing LLM connection...")
    
    var response = await LLMClient.request("What is 2+2?")
    
    if response.has("error"):
        print("❌ LLM Error: " + response.error)
    else:
        print("✅ LLM Working: " + response.content)
    
    # Check stats
    var stats = LLMClient.get_stats()
    print("Total Requests: " + str(stats.total_requests))
    print("Successful: " + str(stats.successful_requests))
```

---

## 🐛 **TROUBLESHOOTING**

### **Issue: "Connection refused"**

**Solution:**
```
1. Verify Ollama is running:
   ollama list
   
2. Start Ollama server:
   ollama serve
   
3. Check port is open:
   curl http://localhost:11434/api/version
```

### **Issue: "Model not found"**

**Solution:**
```
1. Pull the model:
   ollama pull phi3
   
2. Verify it's downloaded:
   ollama list
   
3. Check model name matches config
```

### **Issue: Slow responses**

**Solution:**
```
1. Use a smaller model:
   ollama pull phi3  # Instead of llama3.1
   
2. Enable GPU acceleration:
   # Ollama auto-detects GPU
   # Verify: ollama run phi3 "test" --verbose
   
3. Reduce max_tokens:
   LLMClient.set_config("max_tokens", 300)
```

### **Issue: Out of memory**

**Solution:**
```
1. Use smaller model:
   ollama pull tinyllama  # 0.7GB
   
2. Close other applications
   
3. Reduce context length:
   ollama run phi3 --num_ctx 2048
```

---

## 📊 **COMPARISON TABLE**

| Option | Cost | Speed | Quality | Setup | Best For |
|--------|------|-------|---------|-------|----------|
| **Ollama (Phi-3)** | Free | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | Easy | Most users |
| **Ollama (Llama3)** | Free | ⚡⚡⚡ | ⭐⭐⭐⭐⭐ | Easy | High-end PCs |
| **Groq** | Free* | ⚡⚡⚡⚡⚡ | ⭐⭐⭐⭐ | Easy | Testing |
| **HF API** | Free* | ⚡⚡⚡ | ⭐⭐⭐⭐ | Easy | Prototyping |
| **Mock** | Free | ⚡⚡⚡⚡⚡ | ⭐ | None | Development |

*Rate limited

---

## ✅ **QUICK START (5 Minutes)**

```bash
# 1. Install Ollama
# Visit https://ollama.com/download and install

# 2. Download model
ollama pull phi3

# 3. Verify it works
ollama run phi3 "Hello"

# 4. Configure HeelKawn
# Add to Main.gd._ready():
LLMClient.set_config("provider", "ollama")
LLMClient.set_config("api_url", "http://localhost:11434")
LLMClient.set_config("model", "phi3")
LLMClient.set_config("use_mock", false)

# 5. Run game and test!
```

---

**You now have a free, unlimited, local LLM for HeelKawn AI!** 🎉
