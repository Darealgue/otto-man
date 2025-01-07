extends PowerupEffect

const FIRE_SCENE = preload("res://effects/fire_effect.tscn")
const SPAWN_INTERVAL = 0.1  # Spawn fire every 0.1 seconds
const FIRE_DAMAGE = 10.0
const FIRE_DURATION = 2.0

var spawn_timer := 0.0
var last_position: Vector2

func _init() -> void:
	powerup_name = "Fire Trail"
	description = "Leave a trail of damaging fire behind you"
	duration = -1  # Permanent until death
	powerup_type = PowerupType.DAMAGE

func activate(player: CharacterBody2D) -> void:
	super.activate(player)
	spawn_timer = 0.0
	last_position = player.global_position

func process(player: CharacterBody2D, delta: float) -> void:
	spawn_timer -= delta
	
	# Only spawn fire if we've moved enough and timer is ready
	if spawn_timer <= 0 and player.global_position.distance_to(last_position) > 10:
		spawn_fire(player)
		spawn_timer = SPAWN_INTERVAL
		last_position = player.global_position

func spawn_fire(player: CharacterBody2D) -> void:
	var fire = FIRE_SCENE.instantiate()
	player.get_parent().add_child(fire)
	fire.global_position = player.global_position
	fire.setup(FIRE_DAMAGE, FIRE_DURATION)
