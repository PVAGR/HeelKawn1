extends Node
## Phase 4: Procedural audio cues for settlement meaning transitions
## Uses AudioStreamGenerator for deterministic tone generation (no external assets)

## Audio cue definitions (deterministic from meaning labels)
const CUE_QUIET_TO_SCARRED: Dictionary = {
	"base_freq": 120.0,
	"duration": 2.0,
	"volume": 0.15,
	"type": "hum"
}
const CUE_SCARRED_TO_BLOODY: Dictionary = {
	"base_freq": 250.0,
	"secondary_freq": 200.0,
	"duration": 1.5,
	"volume": 0.25,
	"type": "dissonant"
}
const CUE_BLOODY_TO_GRAVE: Dictionary = {
	"start_freq": 400.0,
	"end_freq": 100.0,
	"duration": 1.5,
	"volume": 0.3,
	"type": "descending"
}
const CUE_GRAVE_TO_RECOVERING: Dictionary = {
	"base_freq": 150.0,
	"note_count": 3,
	"duration": 1.0,
	"volume": 0.2,
	"type": "arpeggio"
}
const CUE_RECOVERING_TO_QUIET: Dictionary = {
	"base_freq": 600.0,
	"duration": 0.5,
	"volume": 0.15,
	"type": "chime"
}

## Cooldown: 30 seconds between same-settlement audio cues
const COOLDOWN_TICKS: int = 1800  # 30s at 60fps
var _last_cue_tick_by_settlement: Dictionary = {}

var _audio_player: AudioStreamPlayer = null
var _audio_playback: AudioStreamGeneratorPlayback = null

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = AudioStreamGenerator.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)
	_audio_player.play()
	_audio_playback = _audio_player.get_stream_playback()


## Play audio cue for settlement meaning transition
## settlement_id: int - unique settlement identifier
## from_label: String - previous meaning label (quiet/scarred/bloodied/grave)
## to_label: String - new meaning label
func play_cue(settlement_id: int, from_label: String, to_label: String) -> void:
	var current_tick: int = GameManager.tick_count if GameManager != null else 0
	
	# Check cooldown
	if _last_cue_tick_by_settlement.has(settlement_id):
		var last_tick: int = int(_last_cue_tick_by_settlement[settlement_id])
		if current_tick - last_tick < COOLDOWN_TICKS:
			return
	
	# Determine cue type from transition
	var cue_key: String = _get_cue_key(from_label, to_label)
	if cue_key.is_empty():
		return
	
	# Generate and play tone
	_generate_tone(cue_key)
	
	# Update cooldown
	_last_cue_tick_by_settlement[settlement_id] = current_tick


## Map meaning label transition to cue definition
func _get_cue_key(from_label: String, to_label: String) -> String:
	if from_label == "quiet" and to_label == "scarred":
		return "quiet_to_scarred"
	if from_label == "scarred" and to_label == "bloodied":
		return "scarred_to_bloody"
	if from_label == "bloodied" and to_label == "grave":
		return "bloody_to_grave"
	if from_label == "grave" and to_label == "recovering":
		return "grave_to_recovering"
	if from_label == "recovering" and to_label == "quiet":
		return "recovering_to_quiet"
	return ""


## Generate procedural tone based on cue definition
func _generate_tone(cue_key: String) -> void:
	var cue: Dictionary = _get_cue_definition(cue_key)
	if cue.is_empty():
		return
	
	match cue.get("type", ""):
		"hum":
			_generate_hum(cue)
		"dissonant":
			_generate_dissonant(cue)
		"descending":
			_generate_descending(cue)
		"arpeggio":
			_generate_arpeggio(cue)
		"chime":
			_generate_chime(cue)


## Get cue definition by key
func _get_cue_definition(cue_key: String) -> Dictionary:
	match cue_key:
		"quiet_to_scarred":
			return CUE_QUIET_TO_SCARRED
		"scarred_to_bloody":
			return CUE_SCARRED_TO_BLOODY
		"bloody_to_grave":
			return CUE_BLOODY_TO_GRAVE
		"grave_to_recovering":
			return CUE_GRAVE_TO_RECOVERING
		"recovering_to_quiet":
			return CUE_RECOVERING_TO_QUIET
	return {}


## Generate sustained hum tone
func _generate_hum(cue: Dictionary) -> void:
	var base_freq: float = float(cue.get("base_freq", 120.0))
	var duration: float = float(cue.get("duration", 2.0))
	var volume: float = float(cue.get("volume", 0.15))
	
	var sample_rate: float = _audio_player.stream.mix_rate
	var frames: int = int(sample_rate * duration)
	
	for i in range(frames):
		var phase: float = (float(i) / sample_rate) * base_freq * TAU
		var sample: float = sin(phase) * volume
		_audio_playback.push_frame(Vector2(sample, sample))


## Generate dissonant chord (two frequencies)
func _generate_dissonant(cue: Dictionary) -> void:
	var base_freq: float = float(cue.get("base_freq", 250.0))
	var secondary_freq: float = float(cue.get("secondary_freq", 200.0))
	var duration: float = float(cue.get("duration", 1.5))
	var volume: float = float(cue.get("volume", 0.25))
	
	var sample_rate: float = _audio_player.stream.mix_rate
	var frames: int = int(sample_rate * duration)
	
	for i in range(frames):
		var phase1: float = (float(i) / sample_rate) * base_freq * TAU
		var phase2: float = (float(i) / sample_rate) * secondary_freq * TAU
		var sample: float = (sin(phase1) + sin(phase2)) * 0.5 * volume
		_audio_playback.push_frame(Vector2(sample, sample))


## Generate descending tone
func _generate_descending(cue: Dictionary) -> void:
	var start_freq: float = float(cue.get("start_freq", 400.0))
	var end_freq: float = float(cue.get("end_freq", 100.0))
	var duration: float = float(cue.get("duration", 1.5))
	var volume: float = float(cue.get("volume", 0.3))
	
	var sample_rate: float = _audio_player.stream.mix_rate
	var frames: int = int(sample_rate * duration)
	
	for i in range(frames):
		var t: float = float(i) / float(frames)
		var freq: float = start_freq + (end_freq - start_freq) * t
		var phase: float = (float(i) / sample_rate) * freq * TAU
		var sample: float = sin(phase) * volume
		_audio_playback.push_frame(Vector2(sample, sample))


## Generate arpeggio (multiple notes)
func _generate_arpeggio(cue: Dictionary) -> void:
	var base_freq: float = float(cue.get("base_freq", 150.0))
	var note_count: int = int(cue.get("note_count", 3))
	var duration: float = float(cue.get("duration", 1.0))
	var volume: float = float(cue.get("volume", 0.2))
	
	var sample_rate: float = _audio_player.stream.mix_rate
	var frames: int = int(sample_rate * duration)
	var frames_per_note: int = frames / note_count
	
	for note in range(note_count):
		var freq: float = base_freq * pow(1.2, note)  # Ascending arpeggio
		var start_frame: int = note * frames_per_note
		var end_frame: int = mini((note + 1) * frames_per_note, frames)
		
		for i in range(start_frame, end_frame):
			var phase: float = (float(i) / sample_rate) * freq * TAU
			var sample: float = sin(phase) * volume
			_audio_playback.push_frame(Vector2(sample, sample))


## Generate short chime
func _generate_chime(cue: Dictionary) -> void:
	var base_freq: float = float(cue.get("base_freq", 600.0))
	var duration: float = float(cue.get("duration", 0.5))
	var volume: float = float(cue.get("volume", 0.15))
	
	var sample_rate: float = _audio_player.stream.mix_rate
	var frames: int = int(sample_rate * duration)
	
	for i in range(frames):
		var phase: float = (float(i) / sample_rate) * base_freq * TAU
		var decay: float = 1.0 - (float(i) / float(frames))
		var sample: float = sin(phase) * volume * decay
		_audio_playback.push_frame(Vector2(sample, sample))
