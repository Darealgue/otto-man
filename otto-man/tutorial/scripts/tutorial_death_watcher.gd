extends Node
## Oyuncu öldüğünde köye geçiş yapıp 2. tutorial bayrağını set eder.
## Sahneye bir Node olarak ekle; script'i ata, başka bir şey yapmana gerek yok.

@export var death_to_village_delay: float = 2.0

var _player: Node = null
var _watching: bool = false


func _ready() -> void:
	call_deferred("_find_player")


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("[TutorialDeathWatcher] Oyuncu bulunamadı, 0.5s sonra tekrar denenecek.")
		await get_tree().create_timer(0.5).timeout
		_find_player()
		return
	_watching = true


func _process(_delta: float) -> void:
	if not _watching or _player == null or not is_instance_valid(_player):
		return
	var dead: bool = false
	if "current_behavior" in _player and _player.current_behavior == "dead":
		dead = true
	elif "is_dead" in _player and bool(_player.is_dead):
		dead = true
	elif "pending_death" in _player and bool(_player.pending_death):
		dead = true
	if dead:
		_watching = false
		_on_player_died()


func _on_player_died() -> void:
	var tm: Node = get_node_or_null("/root/TutorialManager")
	if is_instance_valid(tm) and tm.has_method("mark_dungeon_movement_complete"):
		tm.call("mark_dungeon_movement_complete")
	await get_tree().create_timer(death_to_village_delay).timeout
	if is_instance_valid(SceneManager):
		SceneManager.change_to_village({"source": "tutorial_combat_death"}, true)
