extends WorldEnvironment
## BloomGlow — adds a subtle glow/bloom post-processing effect.
## Fire pits, windows, and the sun get a soft halo.
## Uses the Compatibility renderer's built-in glow system.

var _world: World = null


func initialize(world_ref: World) -> void:
	_world = world_ref
	# Configure environment for glow
	var env: Environment = Environment.new()
	env.set_background(Environment.BG_CLEAR_COLOR)
	# Glow settings — subtle bloom for pixel art
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.7
	env.glow_bloom = 0.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.7
	env.glow_hdr_scale = 1.5
	# Tone mapping for richer colors
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	environment = env
