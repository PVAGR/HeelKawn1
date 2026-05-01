class_name TraitShop
extends Control

# Minimal programmatic trait shop UI. Loads trait resources from `res://data/traits/`.
# Usage: call `open_shop(player_pawn: Pawn)` from Main.

var _player_pawn: Pawn = null
var _traits: Array = []
var _content_vbox: VBoxContainer = null

func _ready() -> void:
	self.name = "TraitShop"
	self.anchor_right = 1.0
	self.anchor_bottom = 1.0
	self.margin_left = 40
	self.margin_top = 40
	self.margin_right = -40
	self.margin_bottom = -40
	self.visible = false
	# Panel background
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)
	var header := HBoxContainer.new()
	header.margin_right = 8
	var title := Label.new()
	title.text = "Trait Shop"
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.connect("pressed", Callable(self, "_on_close_pressed"))
	header.add_child(close_btn)
	vbox.add_child(header)
	# Scroll for trait list
	var scroll := ScrollContainer.new()
	scroll.v_size_flags = Control.SIZE_EXPAND_FILL
	scroll.h_size_flags = Control.SIZE_EXPAND_FILL
	_content_vbox = VBoxContainer.new()
	_content_vbox.name = "Content"
	_content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_vbox)
	vbox.add_child(scroll)

func open_shop(player_pawn: Pawn) -> void:
	_player_pawn = player_pawn
	_load_traits()
	_refresh()
	self.visible = true

func _on_close_pressed() -> void:
	self.visible = false

func _load_traits() -> void:
	_traits.clear()
	# Try to open data/traits dir and load *.tres or *.res files.
	var dir_path := "res://data/traits"
	var da := DirAccess.open(dir_path)
	if da == null:
		# No trait assets folder; nothing to show.
		return
	if da.list_dir_begin():
		var fname := da.get_next()
		while fname != "":
			if not da.current_is_dir():
				if fname.ends_with(".tres") or fname.ends_with(".res") or fname.ends_with(".gd"):
					var p := "%s/%s" % [dir_path, fname]
					var r := ResourceLoader.load(p)
					if r != null:
						_traits.append(r)
			fname = da.get_next()
		da.list_dir_end()

func _refresh() -> void:
	# Clear old entries
	for child in _content_vbox.get_children():
		_content_vbox.remove_child(child)
		child.queue_free()
	# Populate
	for trait in _traits:
		var line := HBoxContainer.new()
		var label := Label.new()
		var cost := trait.krond_cost if trait.has("krond_cost") else 0
		label.text = "%s  (cost: %g)" % [trait.name if trait.has("name") else "trait", cost]
		line.add_child(label)
		var btn := Button.new()
		btn.text = "Buy"
		btn.disabled = false
		btn.connect("pressed", Callable(self, "_on_buy_pressed"), [trait])
		line.add_child(btn)
		_content_vbox.add_child(line)

func _on_buy_pressed(trait_res: Resource) -> void:
	if _player_pawn == null or not is_instance_valid(_player_pawn):
		print("[TraitShop] No player pawn")
		return
	# Ask pawn to apply trait (Pawn.apply_trait delegates to PawnData.apply_trait)
	if _player_pawn.apply_trait(trait_res):
		print("[TraitShop] Purchased trait: %s" % str(trait_res.name if trait_res.has("name") else trait_res))
		_player_pawn.data.grant_krond(0) # noop trigger to ensure persistence path (no-op)
		# Refresh HUD if present on tree
		var hud := get_tree().get_root().get_node_or_null("Main/UI_Viewport/ColonyHUD")
		if hud != null:
			hud._refresh()
		_refresh()
	else:
		print("[TraitShop] Could not purchase trait: %s" % str(trait_res))
*** End Patch