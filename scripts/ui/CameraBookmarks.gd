class_name CameraBookmarks
extends Node

## Camera position bookmarks: Ctrl+1–5 saves, 1–5 jumps back.
## Works across the full 256×256 world for quick navigation between settlements.

const SLOT_COUNT: int = 5
const SAVE_PATH: String = "user://camera_bookmarks.json"

var _bookmarks: Array[Vector2] = []  # world positions
var _camera: Camera2D = null


func _ready() -> void:
	_bookmarks.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		_bookmarks[i] = Vector2.ZERO
	_load()


func initialize(camera_ref: Camera2D) -> void:
	_camera = camera_ref


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.keycode
		# Ctrl+1-5 = save bookmark
		if event.ctrl_pressed and key >= KEY_1 and key <= KEY_5:
			var slot: int = int(key) - int(KEY_1)
			_save_bookmark(slot)
			get_viewport().set_input_as_handled()
		# 1-5 without modifiers = jump to bookmark (only when no other input active)
		elif not event.ctrl_pressed and not event.shift_pressed and not event.alt_pressed:
			if key >= KEY_1 and key <= KEY_5:
				var slot: int = int(key) - int(KEY_1)
				_jump_to_bookmark(slot)
				# Don't consume — number keys also control speed. Camera jump is a bonus.


func _save_bookmark(slot: int) -> void:
	if _camera == null:
		return
	_bookmarks[slot] = _camera.global_position
	_persist()
	if OS.is_debug_build():
		print("[CameraBookmarks] Saved slot %d at %s" % [slot + 1, _camera.global_position])


func _jump_to_bookmark(slot: int) -> void:
	if _camera == null:
		return
	var pos: Vector2 = _bookmarks[slot]
	if pos == Vector2.ZERO:
		return
	_camera.global_position = pos


func _persist() -> void:
	var data: Dictionary = {}
	for i in range(SLOT_COUNT):
		data[str(i)] = {"x": _bookmarks[i].x, "y": _bookmarks[i].y}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return
	var data: Dictionary = json.data as Dictionary
	for i in range(SLOT_COUNT):
		var entry: Variant = data.get(str(i), null)
		if entry is Dictionary:
			_bookmarks[i] = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
