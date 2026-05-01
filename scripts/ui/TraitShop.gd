class_name TraitShop
extends Control

var _player_pawn = null
var _traits: Array = []
var _content_vbox: VBoxContainer = null


func _ready() -> void:
	name = "TraitShop"
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 40
	offset_top = 40
	offset_right = -40
	offset_bottom = -40
	visible = false

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Trait Shop"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_vbox)


func open_shop(player_pawn) -> void:
	_player_pawn = player_pawn
	_load_traits()
	_refresh()
	visible = true


func _on_close_pressed() -> void:
	visible = false


func _load_traits() -> void:
	_traits.clear()
	var dir_path := "res://data/traits"
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var file_name := da.get_next()
	while file_name != "":
		if not da.current_is_dir():
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var path := "%s/%s" % [dir_path, file_name]
				var res := ResourceLoader.load(path)
				if res != null:
					_traits.append(res)
		file_name = da.get_next()
	da.list_dir_end()


func _refresh() -> void:
	if _content_vbox == null:
		return
	for child in _content_vbox.get_children():
		child.queue_free()

	for trait_resource in _traits:
		var row := HBoxContainer.new()
		_content_vbox.add_child(row)

		var title := Label.new()
		var trait_name := "trait"
		var trait_cost := 0
		if trait_resource.has_method("get"):
			trait_name = str(trait_resource.get("name"))
			trait_cost = int(trait_resource.get("krond_cost"))
		title.text = "%s  (cost: %d)" % [trait_name, trait_cost]
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)

		var buy := Button.new()
		buy.text = "Buy"
		buy.pressed.connect(Callable(self, "_on_buy_pressed").bind(trait_resource))
		row.add_child(buy)


func _on_buy_pressed(trait_res: Resource) -> void:
	if _player_pawn == null or not is_instance_valid(_player_pawn):
		print("[TraitShop] No player pawn")
		return
	if _player_pawn.apply_trait(trait_res):
		print("[TraitShop] Purchased trait")
		var hud := get_tree().root.get_node_or_null("Main/UI_Viewport/ColonyHUD")
		if hud != null and hud.has_method("_refresh"):
			hud.call("_refresh")
		_refresh()
	else:
		print("[TraitShop] Could not purchase trait")