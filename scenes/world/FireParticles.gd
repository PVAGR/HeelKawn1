extends GPUParticles2D

func _ready():
	modulate = Color(1.2, 0.8, 0.4)
	process_material.direction = Vector3(0, 1, 0)

