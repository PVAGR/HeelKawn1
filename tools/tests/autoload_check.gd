extends SceneTree
## Autoload integrity check — verifies every autoload registered in project.godot
## points to an existing file and the file loads without parse errors.
##
## Run: godot --headless --path . -s res://tools/tests/autoload_check.gd
##
## Exit codes:
##   0 = all autoloads valid
##   1 = one or more autoloads broken

var _passed: int = 0
var _failed: int = 0
var _broken: PackedStringArray = []
var _done: bool = false


func _init() -> void:
	print("\n=== HEELKAWN AUTOLOAD INTEGRITY CHECK ===")


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# Parse project.godot for autoload entries
	var autoloads: Dictionary = _parse_autoloads()
	print("Found %d autoloads in project.godot\n" % autoloads.size())

	for name in autoloads:
		var path: String = autoloads[name]
		if FileAccess.file_exists(path):
			# Try to load the script
			var script: GDScript = load(path) as GDScript
			if script != null:
				print("[OK] %s -> %s" % [name, path])
				_passed += 1
			else:
				print("[FAIL] %s -> %s (load failed)" % [name, path])
				_failed += 1
				_broken.append(name)
		else:
			print("[MISSING] %s -> %s (file not found)" % [name, path])
			_failed += 1
			_broken.append(name)

	print("\n=== RESULTS ===")
	print("Valid: %d" % _passed)
	print("Broken: %d" % _failed)
	if _broken.size() > 0:
		print("\nBroken autoloads:")
		for b in _broken:
			print("  - %s" % b)
		quit(1)
	else:
		print("\nALL AUTOLOADS VALID")
		quit(0)
	return true


func _parse_autoloads() -> Dictionary:
	var result: Dictionary = {}
	var file: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		print("ERROR: Cannot open project.godot")
		return result

	var in_autoload: bool = false
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.begins_with("[autoload]"):
			in_autoload = true
			continue
		if line.begins_with("[") and in_autoload:
			break
		if in_autoload and "=" in line:
			var parts: PackedStringArray = line.split("=", true, 1)
			if parts.size() == 2:
				var name: String = parts[0].strip_edges()
				var path: String = parts[1].strip_edges()
				# Remove quotes and * prefix
				path = path.replace('"', '').replace('*', '')
				result[name] = path

	file.close()
	return result
