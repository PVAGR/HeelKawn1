# Ollama Model Configuration

## Installed Models

Check what you have:
```
ollama list
```

## Recommended Models for HeelKawn

### qwen2.5-coder:7b (Recommended)
```
ollama pull qwen2.5-coder:7b
```
- **Size:** 4.7 GB
- **RAM needed:** ~8 GB
- **Speed:** Medium (2-5 tokens/sec on typical hardware)
- **Best for:** General coding, GDScript understanding, architectural decisions
- **Why:** Qwen 2.5 Coder is one of the best open-source coding models. The 7B size is a good balance of quality and speed.

### qwen2.5-coder:1.5b (Lightweight)
```
ollama pull qwen2.5-coder:1.5b
```
- **Size:** 1.1 GB
- **RAM needed:** ~4 GB
- **Speed:** Fast (10-20 tokens/sec)
- **Best for:** Quick edits, simple changes, low-end hardware
- **Why:** Good enough for straightforward code changes when speed matters more than deep analysis.

### qwen2.5-coder:32b (Deep Analysis)
```
ollama pull qwen2.5-coder:32b
```
- **Size:** 20 GB
- **RAM needed:** ~32 GB
- **Speed:** Slow (0.5-2 tokens/sec)
- **Best for:** Complex architecture, system design, multi-file refactors
- **Why:** Significantly better reasoning but requires serious hardware.

## Other Useful Models

| Model | Purpose | Command |
|-------|---------|---------|
| `llama3.2` | General reasoning | `ollama pull llama3.2` |
| `mistral` | Writing/lore | `ollama pull mistral` |
| `nomic-embed-text` | Vector embeddings (future) | `ollama pull nomic-embed-text` |

## Connection Info

- **API URL:** `http://localhost:11434`
- **API format:** OpenAI-compatible
- **Test:** `curl http://localhost:11434/api/tags`

## Integration Points

The existing `addons/ai_assistant_hub/` addon already supports Ollama:
- Provider config: `addons/ai_assistant_hub/llm_providers/ollama.tres`
- API class: `addons/ai_assistant_hub/llm_apis/ollama_api.gd`
- Default port: 11434
