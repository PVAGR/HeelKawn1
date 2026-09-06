extends SceneTree
func _initialize() -> void:
	call_deferred("_gen")

func _gen() -> void:
	var dir := "res://assets/sprites/structures"
	DirAccess.make_dir_recursive_absolute("res://assets/sprites/structures")
	# Create simple 16x16 pixel art for each missing structure
	_make_fire_pit()
	_make_storage_hut()
	_make_shelter()
	_make_workshop()
	_make_farm()
	_make_shrine()
	_make_hearth()
	_make_road()
	_make_granary()
	print("Sprites generated")
	quit(0)

func _make_fire_pit() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	# Stone ring: dark gray border
	for x in range(4,12):
		for y in range(4,12):
			if x==4 or x==11 or y==4 or y==11:
				img.set_pixel(x,y, Color8(80,70,60))
	# Fire: orange center
	for x in range(6,10):
		for y in range(6,10):
			img.set_pixel(x,y, Color8(255,140,30))
	# Flame highlight
	img.set_pixel(7,7, Color8(255,220,80))
	img.set_pixel(8,6, Color8(255,200,50))
	img.save_png("res://assets/sprites/structures/fire_pit.png")
	print("fire_pit.png saved")

func _make_storage_hut() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	# Walls tan
	for x in range(3,13):
		for y in range(5,14):
			img.set_pixel(x,y, Color8(150,120,70))
	# Roof darker
	for x in range(2,14):
		for y in range(3,6):
			img.set_pixel(x,y, Color8(110,85,45))
	# Door dark
	for x in range(7,9):
		for y in range(10,14):
			img.set_pixel(x,y, Color8(60,45,25))
	print("storage_hut")
	img.save_png("res://assets/sprites/structures/storage_hut.png")

func _make_shelter() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	# Roof triangular
	for y in range(3,7):
		var w: int = 7 - (y-3)*2
		for x in range(8-w, 8+w+1):
			img.set_pixel(x,y, Color8(160,120,70))
	# Walls
	for x in range(4,12):
		for y in range(7,13):
			img.set_pixel(x,y, Color8(180,150,110))
	# Door
	for x in range(7,9):
		for y in range(9,13):
			img.set_pixel(x,y, Color8(90,60,30))
	img.save_png("res://assets/sprites/structures/shelter.png")
	print("shelter saved")

func _make_workshop() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	# Base
	for x in range(2,14):
		for y in range(4,13):
			img.set_pixel(x,y, Color8(160,120,80))
	# Roof
	for x in range(1,15):
		img.set_pixel(x,4, Color8(120,90,60))
	# Anvil dark
	for x in range(6,10):
		for y in range(7,9):
			img.set_pixel(x,y, Color8(80,80,90))
	img.save_png("res://assets/sprites/structures/workshop.png")
	print("workshop saved")

func _make_farm() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color8(90,65,35))
	# Crop rows green
	for y in [5,8,11]:
		for x in range(2,14):
			img.set_pixel(x,y, Color8(60,160,60))
			if x%3==0:
				img.set_pixel(x,y-1, Color8(80,180,70))
	img.save_png("res://assets/sprites/structures/farm.png")
	print("farm saved")

func _make_shrine() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	for x in range(6,10):
		for y in range(3,13):
			img.set_pixel(x,y, Color8(140,140,160))
	img.set_pixel(8,2, Color8(200,200,255))
	img.save_png("res://assets/sprites/structures/shrine.png")
	print("shrine saved")

func _make_hearth() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	for x in range(4,12):
		for y in range(4,12):
			img.set_pixel(x,y, Color8(100,90,80))
	for x in range(6,10):
		for y in range(6,10):
			img.set_pixel(x,y, Color8(255,100,20))
	img.save_png("res://assets/sprites/structures/hearth.png")
	print("hearth saved")

func _make_road() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color8(160,150,130))
	# Center line
	for x in range(2,14):
		img.set_pixel(x,7, Color8(140,130,110))
		img.set_pixel(x,8, Color8(140,130,110))
	img.save_png("res://assets/sprites/structures/road.png")
	print("road saved")

func _make_granary() -> void:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	for x in range(3,13):
		for y in range(5,12):
			img.set_pixel(x,y, Color8(180,160,80))
	img.save_png("res://assets/sprites/structures/granary.png")
	print("granary saved")
