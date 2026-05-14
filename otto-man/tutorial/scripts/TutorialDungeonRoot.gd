extends Node2D
## Tutorial kökü: zemin/tavan yok; tile haritayı sen eklersin. Oyuncu %%PlayerSpawn konumunda oluşturulur.

const _PLAYER_SCENE := preload("res://player/player.tscn")


func _ready() -> void:
	_spawn_player_if_missing()


func _spawn_player_if_missing() -> void:
	if get_node_or_null(^"%Player") != null:
		return
	var marker: Marker2D = get_node_or_null(^"%PlayerSpawn") as Marker2D
	if marker == null:
		push_warning("[TutorialDungeon] %PlayerSpawn yok; oyuncuyu sahneye elle koy veya Marker2D ekle.")
		return
	var inst: Node = _PLAYER_SCENE.instantiate()
	inst.name = "Player"
	inst.unique_name_in_owner = true
	(inst as Node2D).global_position = marker.global_position
	add_child(inst)
