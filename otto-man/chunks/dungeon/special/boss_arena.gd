extends Node2D

@onready var finish_door: Node = get_node_or_null("FinishDoor")
@onready var spawner: Node2D = $EnemySpawner if has_node("EnemySpawner") else null

func _ready() -> void:
	# If spawner exists, listen for the first enemy and its defeat
	if spawner and spawner.has_signal("enemy_spawned"):
		spawner.connect("enemy_spawned", Callable(self, "_on_enemy_spawned"))

func _on_enemy_spawned(enemy: Node) -> void:
	if enemy and enemy.has_signal("enemy_defeated"):
		enemy.connect("enemy_defeated", Callable(self, "_on_boss_defeated"))

func _on_boss_defeated() -> void:
	# Unlock finish door when boss dies
	if finish_door and finish_door.has_method("unlock_door"):
		finish_door.unlock_door()
		#print("[BossArena] Boss defeated. FinishDoor unlocked.")
	else:
		print("[BossArena] Boss defeated but no FinishDoor found.")
