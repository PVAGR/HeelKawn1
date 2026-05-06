extends Node
class_name LLMClient

## Unified LLM API for HeelKawn AI systems
## Supports multiple providers: OpenAI, local models, mock responses
##
## Usage:
##   LLMClient.request(prompt, context)
##   LLMClient.request_json(prompt, context, schema)

# Configuration
const DEFAULT_MAX_TOKENS: int = 500
const DEFAULT_TEMPERATURE: float = 0.7
const REQUEST_TIMEOUT_SEC: float = 30.0

# LLM Provider configuration (set in project settings or here)
var config: Dictionary = {
	"provider": "mock",  # "openai", "ollama", "mock"
	"api_key": "",
	"api_url": "",
	"model": "gpt-3.5-turbo",
	"max_tokens": DEFAULT_MAX_TOKENS,
	"temperature": DEFAULT_TEMPERATURE,
	"use_mock": true  # Fallback to mock if API fails
}

# Performance tracking
var stats: Dictionary = {
	"total_requests": 0,
	"successful_requests": 0,
	"failed_requests": 0,
	"mock_fallbacks": 0,
	"total_tokens_used": 0,
	"average_response_time_ms": 0.0
}

# Request queue for rate limiting
var _request_queue: Array[Dictionary] = []
var _is_processing: bool = false
var _last_request_time: float = 0.0
const MIN_REQUEST_INTERVAL_MS: int = 100  # Rate limit: 10 requests/second

# Signals
signal request_completed(request_id: String, response: Dictionary)
signal request_failed(request_id: String, error: String)
signal rate_limit_exceeded(request_id: String)


func _ready() -> void:
	_load_config_from_settings()


func _load_config_from_settings() -> void:
	# Load from ProjectSettings if available
	if ProjectSettings.has_setting("heelkawn/llm/provider"):
		config.provider = ProjectSettings.get_setting("heelkawn/llm/provider")
	if ProjectSettings.has_setting("heelkawn/llm/api_key"):
		config.api_key = ProjectSettings.get_setting("heelkawn/llm/api_key")
	if ProjectSettings.has_setting("heelkawn/llm/api_url"):
		config.api_url = ProjectSettings.get_setting("heelkawn/llm/api_url")
	if ProjectSettings.has_setting("heelkawn/llm/model"):
		config.model = ProjectSettings.get_setting("heelkawn/llm/model")
	if ProjectSettings.has_setting("heelkawn/llm/use_mock"):
		config.use_mock = ProjectSettings.get_setting("heelkawn/llm/use_mock")


## Main request method - returns parsed response
func request(
	prompt: String,
	context: Dictionary = {},
	system_prompt: String = ""
) -> Dictionary:
	var request_id: String = _generate_request_id()
	var start_time: int = Time.get_ticks_msec()
	
	stats.total_requests += 1
	
	# Build full prompt
	var full_prompt: String = _build_prompt(prompt, context, system_prompt)
	
	# Check rate limiting
	if not _check_rate_limit():
		stats.failed_requests += 1
		rate_limit_exceeded.emit(request_id)
		return {"error": "rate_limit", "request_id": request_id}
	
	# Send request based on provider
	var response: Dictionary
	match config.provider:
		"openai":
			response = await _request_openai(full_prompt)
		"ollama":
			response = await _request_ollama(full_prompt)
		"mock", _:
			response = await _request_mock(full_prompt, context)
	
	# Track stats
	var response_time: int = Time.get_ticks_msec() - start_time
	_update_stats(response, response_time)
	
	# Emit signals
	if response.has("error"):
		stats.failed_requests += 1
		request_failed.emit(request_id, response.error)
	else:
		stats.successful_requests += 1
		request_completed.emit(request_id, response)
	
	return response


## Request with JSON schema enforcement
func request_json(
	prompt: String,
	context: Dictionary,
	schema: Dictionary = {},
	system_prompt: String = "Respond with valid JSON only. No markdown, no explanations."
) -> Dictionary:
	var response: Dictionary = await request(prompt, context, system_prompt)
	
	if response.has("error"):
		return response
	
	# Try to parse as JSON
	var parsed: Dictionary = _parse_json_response(response.get("content", ""))
	
	if parsed.is_empty():
		# Retry with stronger JSON instruction
		var retry_prompt: String = "Extract ONLY the JSON data from this response: " + response.get("content", "")
		response = await request(retry_prompt, {}, "Respond with valid JSON only.")
		parsed = _parse_json_response(response.get("content", ""))
	
	return parsed


## Queue a request (for batch processing)
func queue_request(
	prompt: String,
	context: Dictionary = {},
	priority: int = 0
) -> String:
	var request_id: String = _generate_request_id()
	_request_queue.append({
		"id": request_id,
		"prompt": prompt,
		"context": context,
		"priority": priority,
		"timestamp": Time.get_ticks_msec()
	})
	
	# Sort by priority (higher first)
	_request_queue.sort_custom(func(a, b): return a.priority > b.priority)
	
	# Process queue if not already processing
	if not _is_processing:
		_process_queue()
	
	return request_id


## Set configuration value
func set_config(key: String, value: Variant) -> void:
	config[key] = value


## Get configuration value
func get_config(key: String) -> Variant:
	return config.get(key)


## Get statistics
func get_stats() -> Dictionary:
	return stats.duplicate()


## Reset statistics
func reset_stats() -> void:
	stats = {
		"total_requests": 0,
		"successful_requests": 0,
		"failed_requests": 0,
		"mock_fallbacks": 0,
		"total_tokens_used": 0,
		"average_response_time_ms": 0.0
	}


# ==================== INTERNAL METHODS ====================

func _generate_request_id() -> String:
	return "req_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]


func _build_prompt(prompt: String, context: Dictionary, system_prompt: String) -> String:
	var full_prompt: String = ""
	
	if system_prompt != "":
		full_prompt += "SYSTEM: %s\n\n" % system_prompt
	
	if not context.is_empty():
		full_prompt += "CONTEXT:\n"
		for key in context:
			full_prompt += "- %s: %s\n" % [key, str(context[key])]
		full_prompt += "\n"
	
	full_prompt += "PROMPT:\n%s" % prompt
	
	return full_prompt


func _check_rate_limit() -> bool:
	var current_time: int = Time.get_ticks_msec()
	if current_time - _last_request_time < MIN_REQUEST_INTERVAL_MS:
		return false
	_last_request_time = current_time
	return true


func _update_stats(response: Dictionary, response_time: int) -> void:
	if response.has("usage"):
		stats.total_tokens_used += response.usage.get("total_tokens", 0)
	
	# Smoothed average
	var alpha: float = 0.1
	stats.average_response_time_ms = (
		stats.average_response_time_ms * (1.0 - alpha) +
		float(response_time) * alpha
	)


func _process_queue() -> void:
	if _request_queue.is_empty():
		_is_processing = false
		return
	
	_is_processing = true
	
	while not _request_queue.is_empty():
		var request: Dictionary = _request_queue.pop_front()
		var response: Dictionary = await request(
			request.prompt,
			request.context
		)
		
		# Could emit signal here for queue completion
		await get_tree().create_timer(0.1).timeout  # Small delay between requests
	
	_is_processing = false


# ==================== OPENAI PROVIDER ====================

func _request_openai(prompt: String) -> Dictionary:
	if config.api_key == "":
		return {"error": "api_key_missing", "provider": "openai"}
	
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % config.api_key
	]
	
	var body: Dictionary = {
		"model": config.model,
		"messages": [
			{"role": "user", "content": prompt}
		],
		"max_tokens": config.max_tokens,
		"temperature": config.temperature
	}
	
	var error: Error = http_request.request(
		"https://api.openai.com/v1/chat/completions",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if error != OK:
		http_request.queue_free()
		return {"error": "request_failed", "details": error_string(error)}
	
	# Wait for response
	var result: Array = await http_request.request_completed
	http_request.queue_free()
	
	if result[0] != HTTPClient.RESPONSE_OK:
		return {"error": "http_error", "code": result[0]}
	
	# Parse response
	var response: Dictionary = JSON.parse_string(result[3].get_string_from_utf8())
	
	if response.has("choices") and response.choices.size() > 0:
		return {
			"content": response.choices[0].message.content,
			"usage": response.usage
		}
	
	return {"error": "invalid_response_format"}


# ==================== OLLAMA PROVIDER ====================

func _request_ollama(prompt: String) -> Dictionary:
	if config.api_url == "":
		config.api_url = "http://localhost:11434"
	
	var http_request: HTTPRequest = HTTPRequest.new()
	add_child(http_request)
	
	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]
	
	var body: Dictionary = {
		"model": config.model,
		"prompt": prompt,
		"stream": false
	}
	
	var error: Error = http_request.request(
		config.api_url + "/api/generate",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if error != OK:
		http_request.queue_free()
		return {"error": "request_failed", "details": error_string(error)}
	
	# Wait for response
	var result: Array = await http_request.request_completed
	http_request.queue_free()
	
	if result[0] != HTTPClient.RESPONSE_OK:
		return {"error": "http_error", "code": result[0]}
	
	# Parse response
	var response: Dictionary = JSON.parse_string(result[3].get_string_from_utf8())
	
	if response.has("response"):
		return {
			"content": response.response,
			"usage": response.get("prompt_eval_count", 0) + response.get("eval_count", 0)
		}
	
	return {"error": "invalid_response_format"}


# ==================== MOCK PROVIDER (for testing) ====================

func _request_mock(prompt: String, context: Dictionary) -> Dictionary:
	# Simulate network delay
	await get_tree().create_timer(0.1).timeout
	
	stats.mock_fallbacks += 1
	
	# Generate context-aware mock response
	var response: Dictionary = _generate_mock_response(prompt, context)
	
	return {
		"content": response.content,
		"usage": {"total_tokens": len(prompt) / 4 + len(response.content) / 4},
		"mock": true
	}


func _generate_mock_response(prompt: String, context: Dictionary) -> Dictionary:
	# Smart mock responses based on prompt content
	var prompt_lower: String = prompt.to_lower()
	
	if "emotional state" in prompt_lower or "mood" in prompt_lower:
		return {
			"content": '{"mood_modifier": -5, "desire": "socialize", "fear": "isolation", "thought": "I need to talk to someone..."}',
			"usage": {"total_tokens": 20}
		}
	
	elif "settlement strategy" in prompt_lower or "expand" in prompt_lower:
		return {
			"content": '[{"strategy": "expand_housing", "zone": 3, "priority": "high", "reason": "homeless pawns increasing"}]',
			"usage": {"total_tokens": 25}
		}
	
	elif "diplomatic" in prompt_lower or "alliance" in prompt_lower:
		return {
			"content": '{"action": "PROPOSE_TRADE", "reason": "mutual benefit", "terms": {"resource": "wood", "quantity": 50}}',
			"usage": {"total_tokens": 22}
		}
	
	elif "ecosystem" in prompt_lower or "wildlife" in prompt_lower:
		return {
			"content": '[{"event": "wildlife_boom", "species": "deer", "region": "north", "reason": "mild winter"}]',
			"usage": {"total_tokens": 20}
		}
	
	elif "chronicle" in prompt_lower or "history" in prompt_lower or "legend" in prompt_lower:
		return {
			"content": "In this year, the settlement grew strong. The people worked together, and prosperity followed. This chapter will be remembered in stone.",
			"usage": {"total_tokens": 30}
		}
	
	# Default mock response
	return {
		"content": "Acknowledged. Processing request with provided context.",
		"usage": {"total_tokens": 10}
	}


# ==================== UTILITY ====================

func _parse_json_response(text: String) -> Dictionary:
	if text == "":
		return {}
	
	# Try to find JSON in text (handles markdown code blocks)
	var json_start: int = text.find("{")
	var json_end: int = text.rfind("}")
	
	if json_start >= 0 and json_end > json_start:
		text = text.substr(json_start, json_end - json_start + 1)
	
	# Parse JSON
	var parsed: Variant = JSON.parse_string(text)
	
	if parsed is Dictionary:
		return parsed
	
	# Try to extract key-value pairs as fallback
	return _extract_key_value_pairs(text)


func _extract_key_value_pairs(text: String) -> Dictionary:
	var result: Dictionary = {}
	
	# Simple regex-like extraction
	var lines: PackedStringArray = text.split("\n")
	for line in lines:
		if ":" in line:
			var parts: PackedStringArray = line.split(":", 1)
			if parts.size() == 2:
				var key: String = parts[0].strip_edges().replace('"', '')
				var value: String = parts[1].strip_edges().replace('"', '').replace(',', '')
				result[key] = value
	
	return result


func _len(text: String) -> int:
	return text.length()
