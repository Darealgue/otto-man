extends Control

@onready var gold_label = $HBoxContainer/GoldLabel
@onready var gold_icon = $HBoxContainer/GoldIcon

var _current_gold: int = 0

func _ready() -> void:
	# Work in absolute screen coordinates; anchors handled manually
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2.ZERO

	print("[DungeonGoldDisplay] _ready() called")
	
	# Connect to GlobalPlayerData signal
	var global_player_data = get_node_or_null("/root/GlobalPlayerData")
	if global_player_data:
		if global_player_data.has_signal("dungeon_gold_changed"):
			if not global_player_data.dungeon_gold_changed.is_connected(_on_dungeon_gold_changed):
				global_player_data.dungeon_gold_changed.connect(_on_dungeon_gold_changed)
		
		# Initialize with current value
		if "dungeon_gold" in global_player_data:
			_current_gold = global_player_data.get("dungeon_gold")
			_update_display()
	
	# Wait a frame for scene to be fully loaded
	await get_tree().process_frame
	
	_update_position()

	# React to viewport resize (fullscreen toggle, resolution change, etc.)
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

	# Debug: Check initial node state
	print("[DungeonGoldDisplay] 🔍 Initial node state:")
	print("  - self.visible: %s" % visible)
	print("  - self.modulate: %s" % modulate)
	print("  - self.size: %s" % size)
	print("  - parent: %s" % get_parent())
	if get_parent():
		print("  - parent.visible: %s" % get_parent().visible)
		if get_parent() is Control:
			print("  - parent.modulate: %s" % get_parent().modulate)
			print("  - parent.size: %s" % get_parent().size)
	
	# Ensure all children are visible initially
	var hbox = get_node_or_null("HBoxContainer")
	if hbox:
		hbox.show()
	if gold_label:
		gold_label.show()
	if gold_icon:
		gold_icon.show()
	var bg = get_node_or_null("Background")
	if bg:
		bg.show()
	
	# Check if we should be visible (only in dungeon/forest)
	_update_visibility()
	
	# Connect to scene change to update visibility
	var scene_manager = get_node_or_null("/root/SceneManager")
	if scene_manager:
		if scene_manager.has_signal("scene_change_completed"):
			if not scene_manager.scene_change_completed.is_connected(_on_scene_changed):
				scene_manager.scene_change_completed.connect(_on_scene_changed)
	
	# Also check periodically (in case scene manager hasn't updated yet)
	call_deferred("_delayed_visibility_check")

func _delayed_visibility_check() -> void:
	await get_tree().create_timer(0.5).timeout
	_update_visibility()

func _on_viewport_size_changed() -> void:
	_update_position()

func _on_scene_changed(_new_path: String) -> void:
	_update_visibility()
	_update_position()

func _on_dungeon_gold_changed(new_amount: int) -> void:
	_current_gold = new_amount
	_update_display()
	_update_visibility()

func _update_display() -> void:
	if gold_label:
		gold_label.text = str(_current_gold)
		gold_label.show()  # Ensure label is visible
		print("[DungeonGoldDisplay] Gold label updated: %s" % gold_label.text)
	
	if gold_icon:
		gold_icon.show()  # Ensure icon is visible
	
	var hbox = get_node_or_null("HBoxContainer")
	if hbox:
		hbox.show()  # Ensure container is visible
	
	var bg = get_node_or_null("Background")
	if bg:
		bg.show()  # Ensure background is visible
	
	_update_position()

	# Animate when gold changes
	if _current_gold > 0:
		modulate = Color(1, 1, 1, 1)
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 0.8, 1), 0.3)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

func _update_visibility() -> void:
	# Only show in dungeon/forest scenes when gold > 0
	var scene_manager = get_node_or_null("/root/SceneManager")
	var is_combat_scene = false
	
	if scene_manager:
		var current_scene = scene_manager.get("current_scene_path")
		if current_scene:
			var dungeon_scene = scene_manager.get("DUNGEON_SCENE")
			var forest_scene = scene_manager.get("FOREST_SCENE")
			is_combat_scene = (
				current_scene == dungeon_scene or
				current_scene == forest_scene
			)
	
	# Fallback: check scene name if SceneManager doesn't have current_scene_path
	if not is_combat_scene:
		var scene = get_tree().current_scene
		if scene:
			var scene_path = scene.scene_file_path
			is_combat_scene = ("test_level" in scene_path or "forest" in scene_path)
	
	# Show if in combat scene and has gold
	var should_be_visible = is_combat_scene and _current_gold > 0
	visible = should_be_visible
	
	# Force show if visible
	if should_be_visible:
		show()
		# Ensure it's on top
		z_index = 200
		_update_position()
		# Ensure all children are visible
		var hbox = get_node_or_null("HBoxContainer")
		if hbox:
			hbox.show()
			hbox.z_index = 1
		var bg = get_node_or_null("Background")
		if bg:
			bg.show()
			bg.z_index = -1
		if gold_label:
			gold_label.show()
		if gold_icon:
			gold_icon.show()
		
		# Debug: Check node state (only once when gold is collected)
		if _current_gold > 0 and _current_gold <= 5:
			print("[DungeonGoldDisplay] 🔍 DEBUG - Node state:")
			print("  - visible: %s" % visible)
			print("  - modulate: %s" % modulate)
			print("  - global_position: %s" % global_position)
			print("  - size: %s" % size)
			print("  - z_index: %s" % z_index)
			print("  - gold_label.visible: %s" % (gold_label.visible if gold_label else "null"))
			print("  - gold_icon.visible: %s" % (gold_icon.visible if gold_icon else "null"))
			print("  - parent: %s" % get_parent())
			if get_parent():
				print("  - parent.visible: %s" % get_parent().visible)
				if get_parent() is Control:
					print("  - parent.modulate: %s" % get_parent().modulate)
	else:
		hide()
	
	# Only log when visibility changes
	if should_be_visible != visible:
		print("[DungeonGoldDisplay] Visibility update - is_combat: %s, gold: %d, visible: %s" % [is_combat_scene, _current_gold, visible])

func _update_position() -> void:
	var viewport_rect := get_viewport_rect()
	if viewport_rect.size == Vector2.ZERO:
		return

	var hbox := get_node_or_null("HBoxContainer")
	var panel_size := Vector2.ZERO

	if hbox:
		panel_size = hbox.get_combined_minimum_size()
		if panel_size == Vector2.ZERO:
			panel_size = hbox.get_minimum_size()

	if panel_size == Vector2.ZERO:
		panel_size = get_combined_minimum_size()

	if panel_size == Vector2.ZERO:
		panel_size = Vector2(200, 48)

	size = panel_size

	var margin := 20.0
	var target_x := viewport_rect.size.x - panel_size.x - margin
	var target_y := margin

	global_position = Vector2(max(target_x, margin), target_y)

	var bg := get_node_or_null("Background")
	if bg and bg is Control:
		bg.size = panel_size
