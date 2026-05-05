class_name AmbientAudio
extends Node

## Continuous procedural ambient sounds based on biome and time of day.
## Uses a separate AudioStreamGenerator from AudioController so event sounds
## and ambient sounds don't conflict. No audio assets needed.
##
## Biome + time → sound recipe:
##   Forest/Plains day: birds (high chirps, sparse)
##   Forest/Plains night: crickets (steady high pulse)
##   Desert day: wind (low noise)
##   Desert night: embers (soft crackle)
##   Tundra/Mountain: wind (low howl)
##
## Runs a slow loop that fills the audio buffer with procedural samples.

const MIX_RATE: float = 22050.0
const BUFFER_LENGTH: float = 0.5
const UPDATE_EVERY_N_TICKS: int = 30
const AMBIENT_VOLUME_DB: float = -20.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _world: World = null
var _camera: Camera2D = null
var _tick_counter: int = 0
var _current_biome: int = -1
var _is_night: bool = false
var _phase: float = 0.0  # oscillator phase for procedural generation


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref


func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_LENGTH

	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.volume_db = AMBIENT_VOLUME_DB
	_player.bus = "Master"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	# In headless mode, playback is null — that's fine, _process guards against it
	if _playback == null:
		set_process(false)  # no audio server, skip per-frame work


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % UPDATE_EVERY_N_TICKS == 0:
		_update_biome()

	if _playback == null:
		return

	# Fill buffer with ambient samples
	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var samples: PackedVector2Array = PackedVector2Array()
	samples.resize(mini(frames_available, 512))

	for i in range(samples.size()):
		var sample: float = _generate_sample()
		samples[i] = Vector2(sample, sample)

	_playback.push_buffer(samples)


func _update_biome() -> void:
	if _camera == null or _world == null or _world.data == null:
		return
	var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position)
	if not _world.data.in_bounds(cam_tile.x, cam_tile.y):
		return
	_current_biome = _world.data.get_biome(cam_tile.x, cam_tile.y)
	if GameManager != null:
		_is_night = DayNightCycle.is_night_for_tick(GameManager.tick_count)


func _generate_sample() -> float:
	# Procedural ambient generation based on biome + time
	match _current_biome:
		Biome.Type.FOREST, Biome.Type.PLAINS:
			if _is_night:
				return _cricket_sample()
			else:
				return _bird_sample()
		Biome.Type.DESERT:
			if _is_night:
				return _ember_sample()
			else:
				return _wind_sample()
		Biome.Type.TUNDRA, Biome.Type.MOUNTAIN:
			return _wind_sample()
		_:
			return _wind_sample() * 0.3


func _cricket_sample() -> float:
	# High-pitched chirp: rapid on/off pulse
	_phase += 55.0 / MIX_RATE  # ~55 Hz pulse
	var pulse: float = sin(_phase * TAU)
	var chirp: float = 0.0
	if pulse > 0.7:
		# Active chirp portion — high frequency oscillation
		var chirp_phase: float = fmod(_phase * 40.0, 1.0)  # ~2200 Hz
		chirp = sin(chirp_phase * TAU) * 0.08
	return chirp


func _bird_sample() -> float:
	# Sparse bird chirps: occasional high-pitched tones
	_phase += 1.0 / MIX_RATE
	# Use a slow modulator to create sparse chirps
	var slow_mod: float = sin(_phase * 3.7 * TAU)  # ~3.7 Hz
	var chirp: float = 0.0
	if slow_mod > 0.92:
		# Brief chirp — high frequency
		var bird_phase: float = fmod(_phase * 30.0, 1.0)  # ~2000 Hz
		chirp = sin(bird_phase * TAU) * 0.06
		# Add slight frequency warble
		chirp *= 0.5 + 0.5 * sin(_phase * 50.0 * TAU)
	return chirp


func _wind_sample() -> float:
	# Low-frequency noise with slow modulation
	_phase += 1.0 / MIX_RATE
	# Pseudo-random noise from phase
	var noise: float = sin(_phase * 12345.6789 * TAU) * sin(_phase * 98765.4321 * TAU)
	# Low-pass: slow modulation
	var wind_mod: float = 0.3 + 0.7 * (0.5 + 0.5 * sin(_phase * 0.5 * TAU))
	return noise * 0.05 * wind_mod


func _ember_sample() -> float:
	# Soft crackle: sparse random pops
	_phase += 1.0 / MIX_RATE
	var crackle: float = 0.0
	# Sparse random trigger
	var trigger: float = sin(_phase * 17.3 * TAU) * sin(_phase * 23.7 * TAU)
	if trigger > 0.85:
		crackle = sin(_phase * 100.0 * TAU) * 0.04
	return crackle
