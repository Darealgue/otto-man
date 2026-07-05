extends Area2D
class_name Door

@export var door_type: String = "Start"  # "Start", "Finish", "Boss"
@export var is_locked: bool = false
@export var requires_key: bool = false
@export var key_id: String = ""

signal door_opened(door_type: String)
signal door_locked(door_type: String)

var is_player_in_range: bool = false
var is_open: bool = false
var is_animating: bool = false
var _alarm_locked: bool = false
var _lock_flash: Label = null

# Door states
enum DoorState {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING
}

var current_state: DoorState = DoorState.CLOSED

# References
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_prompt: Label = $InteractionPrompt

func _ready() -> void:
	# Add to doors group for decoration spawner to find
	add_to_group("doors")
	
	# Set up collision detection
	collision_layer = CollisionLayers.NONE
	collision_mask = CollisionLayers.PLAYER
	monitoring = true
	monitorable = true
	
	# Connect signals
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# Wait one frame to ensure all nodes are ready, then initialize appearance
	call_deferred("_initialize_door")
	_setup_lock_flash()


func _setup_lock_flash() -> void:
	_lock_flash = Label.new()
	_lock_flash.name = "LockFlash"
	_lock_flash.text = "🔒"
	_lock_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_flash.add_theme_font_size_override("font_size", 30)
	_lock_flash.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	_lock_flash.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.0))
	_lock_flash.add_theme_constant_override("outline_size", 4)
	_lock_flash.position = Vector2(-16, -58)
	_lock_flash.z_index = 30
	_lock_flash.visible = false
	_lock_flash.modulate.a = 0.0
	add_child(_lock_flash)

func _initialize_door() -> void:
	# Initialize door appearance
	_update_door_appearance()
	# Start kapısı hep açık olmalı
	if door_type == "Start":
		_open_door_immediately()

func _process(_delta: float) -> void:
	# Sadece ui_up (W / yön tuşu yukarı); interact Space/ui_forward ile zıplama çakışmasın
	if is_player_in_range and InputManager.is_ui_up_just_pressed():
		_interact_with_door()

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() and area.get_parent().name == "Player":
		_player_entered_range()

func _on_area_exited(area: Area2D) -> void:
	if area.get_parent() and area.get_parent().name == "Player":
		_player_exited_range()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or (body.get_parent() and body.get_parent().name == "Player"):
		_player_entered_range()

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or (body.get_parent() and body.get_parent().name == "Player"):
		_player_exited_range()

func _player_entered_range() -> void:
	is_player_in_range = true
	if interaction_prompt:
		interaction_prompt.visible = true
		if door_type == "Boss" and is_locked:
			interaction_prompt.text = "↑ Yukarı"
		elif is_open:
			interaction_prompt.text = "Açık"
		elif _alarm_locked and requires_key and not _has_required_key():
			interaction_prompt.text = "Kilitli — anahtar düşmanında"
		elif _segment_exit_key_required() and not _has_required_key():
			interaction_prompt.text = "🔒 Anahtar gerekli"
		elif requires_key and not _has_required_key():
			interaction_prompt.text = "Anahtar gerekli"
		else:
			interaction_prompt.text = "↑ Yukarı"

func _player_exited_range() -> void:
	is_player_in_range = false
	if interaction_prompt:
		interaction_prompt.visible = false

func _interact_with_door() -> void:
	if is_animating:
		return

	if door_type == "Boss" and is_locked:
		_handle_boss_door_locked()
		return

	if is_open:
		return

	if _needs_key_to_open() and not _has_required_key():
		_show_lock_denied()
		return
	
	# Check if door is locked
	if is_locked:
		_handle_locked_door()
		return
	
	# Open the door
	_open_door()


func _needs_key_to_open() -> bool:
	if door_type == "Finish" and _segment_exit_key_required():
		return true
	return requires_key or (_alarm_locked and not key_id.is_empty())


func _segment_exit_key_required() -> bool:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	var sm: Node = get_node_or_null("/root/StealthManager")
	if not is_instance_valid(drs) or not is_instance_valid(sm):
		return false
	return bool(drs.get("segment_exit_requires_key")) and bool(sm.get("segment_alarm"))


func _exit_key_id() -> String:
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and "SEGMENT_EXIT_KEY_ID" in drs:
		return String(drs.get("SEGMENT_EXIT_KEY_ID"))
	return "segment_exit_key"


func _show_lock_denied() -> void:
	print("Door locked — key required: ", key_id)
	door_locked.emit(door_type)
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("door_locked", global_position)
	if interaction_prompt:
		interaction_prompt.text = "🔒 Kilitli"
	if _lock_flash:
		_lock_flash.visible = true
		_lock_flash.modulate.a = 1.0
		var tw := create_tween()
		if tw:
			tw.tween_property(_lock_flash, "modulate:a", 0.0, 0.85).set_delay(0.45)
			tw.tween_callback(func() -> void:
				if is_instance_valid(_lock_flash):
					_lock_flash.visible = false
			)
	if sprite and is_instance_valid(sprite):
		var shake := create_tween()
		if shake:
			var base_x := sprite.position.x
			shake.tween_property(sprite, "position:x", base_x + 4.0, 0.04)
			shake.tween_property(sprite, "position:x", base_x - 4.0, 0.04)
			shake.tween_property(sprite, "position:x", base_x, 0.04)
	await get_tree().create_timer(1.2).timeout
	if is_player_in_range:
		_player_entered_range()

func _handle_locked_door() -> void:
	print("Door is locked!")
	door_locked.emit(door_type)
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("door_locked", global_position)
	
	if interaction_prompt:
		if _alarm_locked and requires_key and not _has_required_key():
			interaction_prompt.text = "Alarm! Anahtar için düşman ara"
		else:
			interaction_prompt.text = "Kilitli!"
		await get_tree().create_timer(2.0).timeout
		if is_player_in_range:
			_player_entered_range()


func _handle_missing_key() -> void:
	print("Door requires key: ", key_id)
	door_locked.emit(door_type)
	
	if interaction_prompt:
		if _alarm_locked:
			interaction_prompt.text = "Anahtar düşmanında — yen ve al"
		else:
			interaction_prompt.text = "Anahtar gerekli!"
		await get_tree().create_timer(2.0).timeout
		if is_player_in_range:
			_player_entered_range()

func _handle_boss_door_locked() -> void:
	print("Boss door is locked! Defeat the boss first.")
	door_locked.emit(door_type)
	
	# Show boss locked message
	if interaction_prompt:
		interaction_prompt.text = "Boss'u yen!"
		await get_tree().create_timer(2.0).timeout
		if is_player_in_range:
			interaction_prompt.text = "↑ Yukarı"

func _has_required_key() -> bool:
	if door_type == "Finish" and _segment_exit_key_required():
		var drs: Node = get_node_or_null("/root/DungeonRunState")
		if is_instance_valid(drs) and drs.has_method("has_dungeon_key"):
			return bool(drs.call("has_dungeon_key", _exit_key_id()))
		return false
	if key_id.is_empty():
		return true
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and drs.has_method("has_dungeon_key"):
		if bool(drs.call("has_dungeon_key", key_id)):
			return true
	var im: Node = get_node_or_null("/root/ItemManager")
	if is_instance_valid(im) and im.has_method("has_item"):
		if bool(im.call("has_item", key_id)):
			return true
	return false

func _open_door() -> void:
	if is_animating:
		return
	if _needs_key_to_open() and not _has_required_key():
		_show_lock_denied()
		return
	
	is_animating = true
	current_state = DoorState.OPENING
	
	print("Opening door: ", door_type)
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("door_open", global_position)
	
	# Play opening animation
	if animation_player and animation_player.has_animation("open"):
		animation_player.play("open")
		await animation_player.animation_finished
	else:
		# Fallback: Manual frame-by-frame animation for opening
		if sprite and sprite.hframes == 8:
			for frame in range(1, 8):  # Frame 0 is closed, 1-7 are opening frames
				sprite.frame = frame
				await get_tree().create_timer(0.1).timeout  # 0.1 second per frame
		else:
			# Fallback: Simple visual feedback if no sprite sheet
			if sprite:
				var tween = create_tween()
				tween.tween_property(sprite, "modulate:a", 0.5, 0.3)
	
	is_open = true
	current_state = DoorState.OPEN
	is_animating = false
	
	# Emit signal for level transition
	door_opened.emit(door_type)
	
	# Update interaction prompt
	if interaction_prompt:
		interaction_prompt.text = "Açık"

func _close_door() -> void:
	if is_animating:
		return
	
	is_animating = true
	current_state = DoorState.CLOSING
	
	print("Closing door: ", door_type)
	
	# Play closing animation
	if animation_player and animation_player.has_animation("close"):
		animation_player.play("close")
		await animation_player.animation_finished
	else:
		# Fallback: Manual frame-by-frame animation for closing
		if sprite and sprite.hframes == 8:
			for frame in range(7, -1, -1):  # Frame 7 to 0 (reverse opening)
				sprite.frame = frame
				await get_tree().create_timer(0.1).timeout  # 0.1 second per frame
		else:
			# Fallback: Simple visual feedback if no sprite sheet
			if sprite:
				var tween = create_tween()
				tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
	
	is_open = false
	current_state = DoorState.CLOSED
	is_animating = false
	
	# Update interaction prompt
	if interaction_prompt and is_player_in_range:
		interaction_prompt.text = "↑ Yukarı"

func _update_door_appearance() -> void:
	if not sprite:
		return
	
	# Update door appearance based on type and state
	match door_type:
		"Start":
			# Start door appearance - use new door_1 sprite
			var texture = load("res://assets/objects/dungeon/door_1.png")
			if texture:
				sprite.texture = texture
				sprite.hframes = 8  # Set horizontal frames for sprite sheet
				sprite.frame = 0  # Start with first frame (closed)
		"Finish":
			# Finish door appearance - use door_1 with different tint
			var texture = load("res://assets/objects/dungeon/door_1.png")
			if texture:
				sprite.texture = texture
				sprite.hframes = 8  # Set horizontal frames for sprite sheet
				sprite.frame = 0  # Start with first frame (closed)
				sprite.modulate = Color(0.8, 1.0, 0.8, 1.0)  # Greenish tint for finish doors
		"Boss":
			var texture = load("res://assets/objects/dungeon/door_1.png")
			if texture:
				sprite.texture = texture
				sprite.hframes = 8
				sprite.frame = 0
				sprite.modulate = Color(1.0, 0.85, 0.85, 1.0)

	if sprite:
		sprite.modulate.a = 1.0

func set_door_type(new_type: String) -> void:
	door_type = new_type
	call_deferred("_update_door_appearance")

func lock_door() -> void:
	is_locked = true
	call_deferred("_update_door_appearance")

func unlock_door() -> void:
	is_locked = false
	call_deferred("_update_door_appearance")


func close_door_now() -> void:
	if is_animating:
		return
	if not is_open and current_state == DoorState.CLOSED:
		return
	_close_door()


func open_door_immediately() -> void:
	_open_door_immediately()


func set_requires_key(required: bool, key: String = "") -> void:
	requires_key = required
	key_id = key


func set_alarm_locked(locked: bool, key: String = "") -> void:
	_alarm_locked = locked
	if locked:
		is_locked = true
		set_requires_key(true, key)
		if is_open and has_method("close_door_now"):
			close_door_now()
	else:
		is_locked = false
		set_requires_key(false, "")
	call_deferred("_update_door_appearance")
	if is_player_in_range:
		call_deferred("_player_entered_range")

func _open_door_immediately() -> void:
	# Start kapısı için animasyon olmadan direkt açık konuma getir
	is_open = true
	is_animating = false
	current_state = DoorState.OPEN
	if sprite and sprite.hframes == 8:
		sprite.frame = 7  # Son frame (açık kapı)
	elif sprite:
		sprite.modulate = Color(1, 1, 1, 1)
	
	# Update interaction prompt
	if interaction_prompt:
		interaction_prompt.text = "Açık"
