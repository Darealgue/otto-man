extends Node2D
## Tutorial kökü: zemin/tavan yok; tile haritayı sen eklersin. Oyuncu %%PlayerSpawn konumunda oluşturulur.

const _PLAYER_SCENE := preload("res://player/player.tscn")


func _ready() -> void:
	_warn_if_no_playable_floor()
	_spawn_player_if_missing()


func _warn_if_no_playable_floor() -> void:
	for child in get_children():
		if child is TileMapLayer:
			return
	push_error(
		"[TutorialDungeon] Bu sahnede TileMapLayer yok — oyuncu boşluğa düşer. "
		+ "SceneManager TUTORIAL_DUNGEON_SCENE yolunu TutorialDungeon2/3 yap."
	)


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
	var body := inst as Node2D
	body.global_position = marker.global_position
	add_child(inst)
	call_deferred("_snap_player_to_floor", body)


func _snap_player_to_floor(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	var space := body.get_world_2d().direct_space_state
	if space == null:
		return
	var from := body.global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2.DOWN * 800.0)
	query.collision_mask = 0xFFFFFFFF
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	body.global_position = hit.position + Vector2(0.0, -2.0)
