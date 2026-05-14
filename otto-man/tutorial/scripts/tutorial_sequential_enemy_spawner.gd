extends Node2D
## Tutorial: aynı anda en fazla bir düşman; biri yenilince sıradaki doğar.

const _ENEMY_Z_INDEX := 4

@export var enemy_scene: PackedScene = preload("res://enemy/basic/basic_enemy.tscn")
@export var tutorial_level: int = 1
## Toplam kaç düşman çıksın (-1 = sınırsız).
@export var max_spawns: int = -1

var _defeated_count: int = 0
var _live_enemy: Node = null
var _spawning_stopped: bool = false


func _ready() -> void:
	call_deferred("_try_spawn")


## Dövüş listesi bittiğinde vb.: yeni düşman doğmaz (sahnedeki canlı düşmana dokunmaz).
func stop_spawning() -> void:
	_spawning_stopped = true


func _try_spawn() -> void:
	if _spawning_stopped:
		return
	if is_instance_valid(_live_enemy):
		return
	if max_spawns >= 0 and _defeated_count >= max_spawns:
		return
	if enemy_scene == null:
		push_error("[TutorialSequentialEnemySpawner] enemy_scene atanmadı.")
		return

	var enemy: Node = enemy_scene.instantiate()
	add_child(enemy)

	var spawn_pos := global_position
	enemy.global_position = spawn_pos

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(spawn_pos, spawn_pos + Vector2.DOWN * 500.0)
	query.collision_mask = CollisionLayers.WORLD
	var result := space_state.intersect_ray(query)
	if result:
		enemy.global_position = result.position - Vector2(0, 32)
		if enemy is CharacterBody2D:
			(enemy as CharacterBody2D).move_and_slide()
	else:
		push_warning("[TutorialSequentialEnemySpawner] Zemin raycast yok; ham konum kullanılıyor: %s" % str(spawn_pos))

	enemy.z_index = _ENEMY_Z_INDEX
	var spr := enemy.get_node_or_null("AnimatedSprite2D")
	if spr:
		spr.z_index = _ENEMY_Z_INDEX

	if enemy.stats:
		enemy.stats.scale_to_level(tutorial_level - 1)
	if "enemy_level" in enemy:
		enemy.enemy_level = tutorial_level

	_live_enemy = enemy
	if enemy.has_signal("enemy_defeated"):
		enemy.enemy_defeated.connect(_on_enemy_defeated.bind(enemy), CONNECT_ONE_SHOT)


func _on_enemy_defeated(enemy: Node) -> void:
	if enemy != _live_enemy:
		return
	_live_enemy = null
	_defeated_count += 1
	if _spawning_stopped:
		return
	if max_spawns >= 0 and _defeated_count >= max_spawns:
		return
	call_deferred("_try_spawn")
