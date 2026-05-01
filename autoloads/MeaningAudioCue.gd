extends Node
## Phase 4: Procedural audio cues for settlement meaning transitions
## Uses AudioStreamGenerator for deterministic tone generation (no external assets)
##
## Safe on headless / no-audio / delayed AudioServer: never calls push_frame on null playback.

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

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100.0
	gen.buffer_length = 0.5
	_audio_player.stream = gen
	_audio_player.bus = "Master"
	add_child(_audio_player)
	_audio_player.play()


func _mix_rate() -> float:
	if _audio_player == null or not is_instance_valid(_audio_player):
		return 44100.0
	var st: Variant = _audio_player.stream
	if st is AudioStreamGenerator:
		var g: AudioStreamGenerator = st as AudioStreamGenerator
		return g.mix_rate if g.mix_rate > 0.0 else 44100.0
	return 44100.0


func _ensure_generator_playback() -> AudioStreamGeneratorPlayback:
	if _audio_player == null or not is_instance_valid(_audio_player):
		return null
	var st: Variant = _audio_player.stream
	if not (st is AudioStreamGenerator):
		return null
	if not _audio_player.playing:
		_audio_player.play()
	return _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


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
	
	# Generate and play tone (no-op if playback unavailable — avoids crash)
	if not _generate_tone(cue_key):
		return
	
	_last_cue_tick_by_settlement[settlement_id] = current_tick


## Map meaning label transition to cue definition key
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


func _generate_tone(cue_key: String) -> bool:
	var cue: Dictionary = _get_cue_definition(cue_key)
	if cue.is_empty():
		return false
	var pb: AudioStreamGeneratorPlayback = _ensure_generator_playback()
	if pb == null:
		return false
	var sample_rate: float = _mix_rate()
	match cue.get("type", ""):
		"hum":
			_generate_hum(cue, pb, sample_rate)
		"dissonant":
			_generate_dissonant(cue, pb, sample_rate)
		"descending":
			_generate_descending(cue, pb, sample_rate)
		"arpeggio":
			_generate_arpeggio(cue, pb, sample_rate)
		"chime":
			_generate_chime(cue, pb, sample_rate)
		_:
			return false
	return true


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


func _generate_hum(cue: Dictionary, pb: AudioStreamGeneratorPlayback, sample_rate: float) -> void:
	var base_freq: float = float(cue.get("base_freq", 120.0))
	var duration: float = float(cue.get("duration", 2.0))
	var volume: float = float(cue.get("volume", 0.15))
	var frames: int = int(sample_rate * duration)
	for i in range(frames):
		var phase: float = (float(i) / sample_rate) * base_freq * TAU
		var sample: float = sin(phase) * volume
		pb.push_frame(Vector2(sample, sample))


func _generate_dissonant(cue: Dictionary, pb: AudioStreamGeneratorPlayback, sample_rate: float) -> void:
	var base_freq: float = float(cue.get("base_freq", 250.0))
	var secondary_freq: float = float(cue.get("secondary_freq", 200.0))
	var duration: float = float(cue.get("duration", 1.5))
	var volume: float = float(cue.get("volume", 0.25))
	var frames: int = int(sample_rate * duration)
	for i in range(frames):
		var phase1: float = (float(i) / sample_rate) * base_freq * TAU
		var phase2: float = (float(i) / sample_rate) * secondary_freq * TAU
		var sample: float = (sin(phase1) + sin(phase2)) * 0.5 * volume
		pb.push_frame(Vector2(sample, sample))


func _generate_descending(cue: Dictionary, pb: AudioStreamGeneratorPlayback, sample_rate: float) -> void:
	var start_freq: float = float(cue.get("start_freq", 400.0))
	var end_freq: float = float(cue.get("end_freq", 100.0))
	var duration: float = float(cue.get("duration", 1.5))
	var volume: float = float(cue.get("volume", 0.3))
	var frames: int = int(sample_rate * duration)
	if frames < 1:
		return
	for i in range(frames):
		var t: float = float(i) / float(frames)
		var freq: float = start_freq + (end_freq - start_freq) * t
		var phase: float = (float(i) / sample_rate) * freq * TAU
		var sample: float = sin(phase) * volume
		pb.push_frame(Vector2(sample, sample))


func _generate_arpeggio(cue: Dictionary, pb: AudioStreamGeneratorPlayback, sample_rate: float) -> void:
	var base_freq: float = float(cue.get("base_freq", 150.0))
	var note_count: int = maxi(1, int(cue.get("note_count", 3)))
	var duration: float = float(cue.get("duration", 1.0))
	var volume: float = float(cue.get("volume", 0.2))
	var frames: int = int(sample_rate * duration)
	var frames_per_note: int = maxi(1, frames / note_count)
	for note in range(note_count):
		var freq: float = base_freq * pow(1.2, note)
		var start_frame: int = note * frames_per_note
		var end_frame: int = mini((note + 1) * frames_per_note, frames)
		for i in range(start_frame, end_frame):
			var phase: float = (float(i) / sample_rate) * freq * TAU
			var sample: float = sin(phase) * volume
			pb.push_frame(Vector2(sample, sample))


func _generate_chime(cue: Dictionary, pb: AudioStreamGeneratorPlayback, sample_rate: float) -> void:
	var base_freq: float = float(cue.get("base_freq", 600.0))
	var duration: float = float(cue.get("duration", 0.5))
	var volume: float = float(cue.get("volume", 0.15))
	var frames: int = int(sample_rate * duration)
	if frames < 1:
		return
	for i in range(frames):
		var phase: float = (float(i) / sample_rate) * base_freq * TAU
		var decay: float = 1.0 - (float(i) / float(frames))
		var sample: float = sin(phase) * volume * decay
		pb.push_frame(Vector2(sample, sample))
