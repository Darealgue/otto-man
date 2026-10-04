extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var diff := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("diff="): diff = int(a.substr(5))
	var sm = get_node("/root/SceneManager")
	sm.current_payload = {"kind": "tirmanis", "biome": "orman", "difficulty": diff}
	var room = load("res://scenes/challenge/challenge_room.tscn").instantiate()
	get_tree().root.add_child.call_deferred(room)
	await get_tree().create_timer(3.5, true).timeout
	var p = room._player
	var route: Array = []
	for q in room._layout["plats"]:
		if bool(q.get("route", false)):
			route.append(q)
	print("MOVIE route=", route.size(), " plats=", room._layout["plats"].size(), " coins=", room._layout["coins"].size())
	var picks := [3, 4, int(route.size() * 0.35), int(route.size() * 0.7), route.size() - 1]
	for k in picks:
		var q: Dictionary = route[k]
		var sp: Vector2 = SummitTowerBuilder.span_px(q)
		p.global_position = Vector2((sp.x + minf(sp.y, sp.x + 160.0)) * 0.5, SummitTowerBuilder.surface_y(q) - 2.0)
		p.velocity = Vector2.ZERO
		await get_tree().create_timer(1.6, true).timeout
	get_tree().quit()