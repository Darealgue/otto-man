extends Area2D

signal hit(area: Area2D)

@export var damage: int = 10
@export var is_player: bool = false
var is_active: bool = false

func _ready():
	if is_player:
		collision_layer = 16  # Layer 5 (PLAYER HITBOX)
		collision_mask = 32   # Layer 6 (ENEMY HURTBOX)
	else:
		collision_layer = 64  # Layer 7 (ENEMY HITBOX)
		collision_mask = 8    # Layer 4 (PLAYER HURTBOX)
	
	add_to_group("hitbox")
	area_entered.connect(_on_hitbox_area_entered)
	disable()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.get_parent().has_method("is_dead") and area.get_parent().is_dead():
		return
		
	if not area.is_in_group("hurtbox"):
		return
	
	hit.emit(area)

func enable(duration: float = 0.2) -> void:
	is_active = true
	monitoring = true
	monitorable = true
	if has_node("CollisionShape2D"):
		var shape = $CollisionShape2D
		shape.disabled = false
	
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(disable)

func disable() -> void:
	is_active = false
	set_deferred("monitoring", false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

func get_damage() -> int:
	return damage
