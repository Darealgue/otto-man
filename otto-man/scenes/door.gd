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

func _initialize_door() -> void:
	# Initialize door appearance
	_update_door_appearance()
	# Start kapısı hep açık olmalı
	if door_type == "Start":
		_open_door_immediately()

func _process(_delta: float) -> void:
	# Handle interaction input
	if is_player_in_range and (
		InputManager.is_interact_just_pressed()
		or InputManager.is_portal_enter_just_pressed()
	):
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
		interaction_prompt.text = "E - Etkileşim"

func _player_exited_range() -> void:
	is_player_in_range = false
	if interaction_prompt:
		interaction_prompt.visible = false

func _interact_with_door() -> void:
	if is_animating or is_open:
		return
	
	# Boss kapısı için özel kontrol
	if door_type == "Boss" and is_locked:
		_handle_boss_door_locked()
		return
	
	# Check if door is locked
	if is_locked:
		_handle_locked_door()
		return
	
	# Check if door requires a key
	if requires_key and not _has_required_key():
		_handle_missing_key()
		return
	
	# Open the door
	_open_door()

func _handle_locked_door() -> void:
	print("Door is locked!")
	door_locked.emit(door_type)
	
	# Show locked message
	if interaction_prompt:
		interaction_prompt.text = "Kilitli!"
		await get_tree().create_timer(2.0).timeout
		if is_player_in_range:
			interaction_prompt.text = "E - Etkileşim"

func _handle_missing_key() -> void:
	print("Door requires key: ", key_id)
	door_locked.emit(door_type)
	
	# Show missing key message
	if interaction_prompt:
		interaction_prompt.text = "Anahtar gerekli!"
		await get_tree().create_timer(2.0).timeout
		if is_player_in_range:
			interaction_prompt.text = "E - Etkileşim"

func _handle_boss_door_locked() -> void:
	print("Boss door is locked! Defeat the boss first.")
	door_locked.emit(door_type)
	
	# Show boss locked message
	if interaction_prompt:
		interaction_prompt.text = "Boss'u yen!"
		await get_tree().create_timer(2.0).timeout
		if is_player_in_range:
			interaction_prompt.text = "E - Etkileşim"

func _has_required_key() -> bool:
	# TODO: Implement key checking logic
	# This should check player's inventory for the required key
	return false

func _open_door() -> void:
	if is_animating:
		return
	
	is_animating = true
	current_state = DoorState.OPENING
	
	print("Opening door: ", door_type)
	
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
		interaction_prompt.text = "E - Etkileşim"

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
			# Boss door appearance - use door_1 with reddish tint
			var texture = load("res://assets/objects/dungeon/door_1.png")
			if texture:
				sprite.texture = texture
				sprite.hframes = 8  # Set horizontal frames for sprite sheet
				sprite.frame = 0  # Start with first frame (closed)
				sprite.modulate = Color(1.2, 0.8, 0.8, 1.0)  # Reddish tint for boss doors
	
	# Update appearance based on lock state
	if is_locked:
		sprite.modulate.a = 0.7  # Make locked doors semi-transparent
	else:
		sprite.modulate.a = 1.0  # Full opacity for unlocked doors

func set_door_type(new_type: String) -> void:
	door_type = new_type
	call_deferred("_update_door_appearance")

func lock_door() -> void:
	is_locked = true
	call_deferred("_update_door_appearance")

func unlock_door() -> void:
	is_locked = false
	call_deferred("_update_door_appearance")

func set_requires_key(required: bool, key: String = "") -> void:
	requires_key = required
	key_id = key

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
