extends Area2D
class_name PoisonDropProjectileV2

## A poison drop that falls straight down from a ceiling trap.
## Applies poison status effect on player hit, destroyed on any collision.

var fall_speed: float = 480.0
var poison_ticks: int = 5
var poison_damage_per_tick: float = 2.0
var _hit: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("trap_projectile")
	if sprite and sprite.sprite_frames:
		# Play default loop animation for the drop
		if sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
		else:
			sprite.play()
	else:
		_create_drop_placeholder()

func _create_drop_placeholder() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.2, 0.9, 0.2)
	rect.size = Vector2(6, 8)
	rect.position = Vector2(-3, -4)
	add_child(rect)

func _physics_process(delta: float) -> void:
	if _hit:
		return
	position.y += fall_speed * delta

func _spawn_pool() -> void:
	var scene_path := "res://traps_v2/ceiling/poison_pool.tscn"
	if not ResourceLoader.exists(scene_path):
		return
	# If there is already a pool very close to this position, just retrigger its impact
	for pool in get_tree().get_nodes_in_group("poison_pools"):
		if not is_instance_valid(pool):
			continue
		if pool.global_position.distance_to(global_position) <= 8.0:
			if pool.has_method("trigger_impact"):
				pool.trigger_impact()
			return
	var scene := load(scene_path) as PackedScene
	if not scene:
		return
	var pool := scene.instantiate()
	if pool:
		get_tree().current_scene.add_child(pool)
		pool.global_position = global_position

func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	_hit = true
	var is_player := body.is_in_group("player")
	if is_player:
		# Respect dodge / invincibility for poison status as well
		if not body.is_dodging and (not (body.invincibility_timer > 0.0)):
			var sem: StatusEffectManager = body.get("status_effects") as StatusEffectManager
			if sem:
				sem.apply_poison(poison_ticks, poison_damage_per_tick)
	else:
		# Only create pool when drop hits the ground / environment, not when it hits the player mid-air
		_spawn_pool()
	queue_free()
