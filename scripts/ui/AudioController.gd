class_name AudioController
extends CanvasLayer

## Procedural audio feedback on events. Uses AudioStreamGenerator (same pattern
## as existing ambient audio and MeaningAudioCue). No audio assets needed.
## Plays short tones/chimes on events: death = low descending, birth = high chime,
## fire = dissonant buzz, build = ascending arpeggio, knowledge = bright chime.

const MIX_RATE: float = 22050.0
const POLL_EVERY_N_TICKS: int = 5
const MIN_INTERVAL_SEC: float = 0.5
const SAME_TYPE_COOLDOWN_SEC: float = 2.0
const MAX_SOUNDS_PER_POLL: int = 2

# Event type → tone recipe: {freq, duration, waveform, volume_db, decay}
# waveform: "sine", "square", "saw", "noise"
const TONE_RECIPES: Dictionary = {
	"pawn_birth": {"freq": 880.0, "dur": 0.15, "wave": "sine", "vol": -12.0, "decay": 0.7},
	"birth": {"freq": 880.0, "dur": 0.15, "wave": "sine", "vol": -12.0, "decay": 0.7},
	"pawn_death": {"freq": 220.0, "dur": 0.35, "wave": "sine", "vol": -8.0, "decay": 0.3},
	"starvation_death": {"freq": 165.0, "dur": 0.5, "wave": "sine", "vol": -10.0, "decay": 0.2},
	"building_constructed": {"freq": 440.0, "dur": 0.2, "wave": "sine", "vol": -14.0, "decay": 0.5},
	"bed_built": {"freq": 440.0, "dur": 0.2, "wave": "sine", "vol": -14.0, "decay": 0.5},
	"wall_built": {"freq": 440.0, "dur": 0.2, "wave": "sine", "vol": -14.0, "decay": 0.5},
	"door_built": {"freq": 440.0, "dur": 0.2, "wave": "sine", "vol": -14.0, "decay": 0.5},
	"cooperative_build": {"freq": 523.0, "dur": 0.25, "wave": "sine", "vol": -12.0, "decay": 0.5},
	"fire_started": {"freq": 130.0, "dur": 0.4, "wave": "saw", "vol": -6.0, "decay": 0.2},
	"fire_extinguished": {"freq": 660.0, "dur": 0.15, "wave": "sine", "vol": -14.0, "decay": 0.6},
	"fire_destroyed_building": {"freq": 110.0, "dur": 0.5, "wave": "saw", "vol": -6.0, "decay": 0.15},
	"knowledge_discovery": {"freq": 1047.0, "dur": 0.2, "wave": "sine", "vol": -10.0, "decay": 0.6},
	"knowledge_rediscovery": {"freq": 988.0, "dur": 0.25, "wave": "sine", "vol": -10.0, "decay": 0.6},
	"knowledge_sealed": {"freq": 196.0, "dur": 0.4, "wave": "sine", "vol": -10.0, "decay": 0.2},
	"governance_change": {"freq": 330.0, "dur": 0.3, "wave": "sine", "vol": -12.0, "decay": 0.4},
	"war_proposed": {"freq": 165.0, "dur": 0.3, "wave": "square", "vol": -8.0, "decay": 0.3},
	"war_battle_spawned": {"freq": 130.0, "dur": 0.35, "wave": "square", "vol": -6.0, "decay": 0.2},
	"diaspora_exile": {"freq": 293.0, "dur": 0.3, "wave": "sine", "vol": -12.0, "decay": 0.3},
	"social_bond_milestone": {"freq": 784.0, "dur": 0.15, "wave": "sine", "vol": -14.0, "decay": 0.7},
	"animal_killed": {"freq": 260.0, "dur": 0.2, "wave": "sine", "vol": -14.0, "decay": 0.4},
	"enemy_killed": {"freq": 392.0, "dur": 0.15, "wave": "sine", "vol": -12.0, "decay": 0.5},
	"food_spoiled": {"freq": 200.0, "dur": 0.2, "wave": "saw", "vol": -14.0, "decay": 0.3},
	"crop_harvested": {"freq": 587.0, "dur": 0.12, "wave": "sine", "vol": -14.0, "decay": 0.6},
	"seeds_planted": {"freq": 523.0, "dur": 0.1, "wave": "sine", "vol": -16.0, "decay": 0.7},
}

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _last_play_time: float = 0.0
var _last_type_time: Dictionary = {}  # type -> last play time
var _last_polled_event_id: int = -1
var _tick_counter: int = 0


func _ready() -> void:
	layer = 0  # Audio doesn't need visual layer

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.3

	_player = AudioStreamPlayer.new()
	_player.name = "EventAudio"
	_player.stream = stream
	_player.volume_db = -6.0
	_player.bus = "Master"
	add_child(_player)


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % POLL_EVERY_N_TICKS == 0:
		_poll_events()


func _poll_events() -> void:
	if WorldMemory == null:
		return
	if GameSettings != null and not bool(GameSettings.get_value("event_sounds")):
		return

	var total: int = WorldMemory.event_count()
	if total == 0:
		return

	var recent: Array = WorldMemory.get_recent_events(mini(20, total))
	if recent.is_empty():
		return

	if _last_polled_event_id < 0:
		var latest: Dictionary = recent[recent.size() - 1] as Dictionary
		_last_polled_event_id = int(latest.get("eid", 0))
		return

	var new_events: Array[Dictionary] = []
	for e in recent:
		var eid: int = int(e.get("eid", 0))
		if eid > _last_polled_event_id:
			new_events.append(e)

	if new_events.is_empty():
		return

	var max_eid: int = _last_polled_event_id
	for e in new_events:
		max_eid = maxi(max_eid, int(e.get("eid", 0)))
	_last_polled_event_id = max_eid

	var played: int = 0
	var now: float = Time.get_ticks_msec() / 1000.0
	for e in new_events:
		if played >= MAX_SOUNDS_PER_POLL:
			break
		var typ: String = str(e.get("type", ""))
		if not TONE_RECIPES.has(typ):
			continue
		# Cooldown: same type within N seconds
		if _last_type_time.has(typ):
			if now - _last_type_time[typ] < SAME_TYPE_COOLDOWN_SEC:
				continue
		# Global cooldown
		if now - _last_play_time < MIN_INTERVAL_SEC:
			continue
		_play_tone(typ)
		_last_play_time = now
		_last_type_time[typ] = now
		played += 1


func _play_tone(event_type: String) -> void:
	var recipe: Dictionary = TONE_RECIPES.get(event_type, {})
	if recipe.is_empty():
		return

	var freq: float = float(recipe.get("freq", 440.0))
	var dur: float = float(recipe.get("dur", 0.2))
	var wave: String = str(recipe.get("wave", "sine"))
	var vol_db: float = float(recipe.get("vol", -12.0))
	var decay: float = float(recipe.get("decay", 0.5))

	_player.volume_db = vol_db
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null:
		return

	var sr: float = MIX_RATE
	var samples: int = int(sr * dur)
	for i in range(samples):
		var t: float = float(i) / sr
		var envelope: float = pow(1.0 - t / dur, 1.0 / maxf(decay, 0.01))
		var sample: float = 0.0
		match wave:
			"sine":
				sample = sin(2.0 * PI * freq * t) * envelope
			"square":
				sample = (1.0 if sin(2.0 * PI * freq * t) >= 0.0 else -1.0) * envelope * 0.6
			"saw":
				sample = (2.0 * (freq * t - floor(freq * t)) - 1.0) * envelope * 0.5
			"noise":
				sample = (randf() * 2.0 - 1.0) * envelope * 0.3
		_playback.push_frame(Vector2(sample, sample))
