extends Node2D

@onready var finish_zone: Area2D = get_node_or_null("../FinishZone")
@onready var spawner: Node2D = $EnemySpawner if has_node("EnemySpawner") else null

func _ready() -> void:
	# If spawner exists, listen for the first enemy and its defeat
	if spawner and spawner.has_signal("enemy_spawned"):
		spawner.connect("enemy_spawned", Callable(self, "_on_enemy_spawned"))

func _on_enemy_spawned(enemy: Node) -> void:
	if enemy and enemy.has_signal("enemy_defeated"):
		enemy.connect("enemy_defeated", Callable(self, "_on_boss_defeated"))

func _on_boss_defeated() -> void:
	# Enable finish zone when boss dies
	var fz = _find_finish_zone()
	if fz:
		fz.monitoring = true
		fz.visible = true
		print("[BossArena] Boss defeated. FinishZone enabled.")

func _find_finish_zone() -> Area2D:
	# FinishZone is reparented under this chunk by level_generator in setup_level_transitions
	# So search in self children for a node named FinishZone
	var fz = get_node_or_null("FinishZone")
	if fz and fz is Area2D:
		return fz
	# Fallback: search upwards or in tree
	var candidates = get_tree().get_nodes_in_group("")
	return fz


