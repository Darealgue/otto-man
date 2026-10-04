extends Node

var _fails: Array = []
var _hops: int = 0
var _pass: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 4.0
	var diff := 9
	var runs := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("diff="): diff = int(a.substr(5))
		if a.begins_with("runs="): runs = int(a.substr(5))
	for run in range(runs):
		var sm = get_node("/root/SceneManager")
		sm.current_payload = {"kind": "tirmanis", "biome": "orman", "difficulty": diff}
		var room = load("res://scenes/challenge/challenge_room.tscn").instantiate()
		get_tree().root.add_child.call_deferred(room)
		await get_tree().create_timer(2.5, true).timeout
		await _test_tower(room, run)
		room.queue_free()
		await get_tree().create_timer(0.5, true).timeout
	print("BOT hops=", _hops, " pass=", _pass, " fails=", _fails.size())
	for f in _fails:
		print("BOT FAIL ", f)
	get_tree().quit()


func _test_tower(room, run: int) -> void:
	var p = room._player
	room._climb.set_physics_process(false)
	var plats: Array = room._layout["plats"]
	var route: Array = []
	for q in plats:
		if bool(q.get("route", false)):
			route.append(q)
	print("BOT run=", run, " platforms=", plats.size(), " route=", route.size(), " height_m=", room._climb.total_meters)
	# Zeminden ilk dala
	var b0: Dictionary = route[0]
	var sp0: Vector2 = SummitTowerBuilder.span_px(b0)
	var left_of: bool = sp0.x < 960.0
	var gx: float = (sp0.x - 130.0) if left_of else (sp0.y + 130.0)
	var ground := {"kind": "wall", "x0": gx, "x1": gx + 20.0, "surf_y": 936.0, "c0": 0, "c1": 1, "r": 29}
	_hops += 1
	var gok := false
	for variant in range(3):
		if await _try_hop(p, ground, b0, variant):
			gok = true
			break
	if gok:
		_pass += 1
	else:
		_fails.append("run%d ground->branch0" % run)
	for i in range(route.size() - 1):
		var a: Dictionary = route[i]
		var b: Dictionary = route[i + 1]
		_hops += 1
		var ok := false
		for variant in range(3):
			if await _try_hop(p, a, b, variant):
				ok = true
				break
		if ok:
			_pass += 1
		else:
			var sa: Vector2 = SummitTowerBuilder.span_px(a)
			var sb: Vector2 = SummitTowerBuilder.span_px(b)
			var gap_px: float = maxf(sb.x - sa.y, sa.x - sb.y)
			_fails.append("run%d hop%d %s(w%d)->%s(w%d) dy=%d gap=%d" % [run, i, a["kind"], int((sa.y - sa.x) / 32.0), b["kind"], int((sb.y - sb.x) / 32.0), int((SummitTowerBuilder.surface_y(a) - SummitTowerBuilder.surface_y(b)) / 32.0), int(gap_px / 32.0)])


func _try_hop(p, a: Dictionary, b: Dictionary, variant: int) -> bool:
	var sa: Vector2 = SummitTowerBuilder.span_px(a)
	var sb: Vector2 = SummitTowerBuilder.span_px(b)
	var ca: float = (sa.x + sa.y) * 0.5
	var cb: float = (sb.x + sb.y) * 0.5
	var dir: int = 1 if cb > ca else -1
	var edge_x: float = (sa.y - 14.0) if dir > 0 else (sa.x + 14.0)
	if sa.y - sa.x <= 40.0:
		edge_x = ca
	var start_surf: float = SummitTowerBuilder.surface_y(a)
	var target_y: float = SummitTowerBuilder.surface_y(b)
	p.global_position = Vector2(edge_x, start_surf - 2.0)
	p.velocity = Vector2.ZERO
	for k in range(10):
		await get_tree().physics_frame
	var need_double: bool = (p.global_position.y - target_y) > 150.0
	Input.action_release("jump")
	if dir > 0:
		Input.action_press("right")
	else:
		Input.action_press("left")
	Input.action_press("jump")
	var second_done := false
	var success := false
	for f in range(170):
		await get_tree().physics_frame
		var xx: float = p.global_position.x
		var lo: float = sb.x + 4.0
		var hi: float = sb.y - 4.0
		if xx < lo:
			Input.action_release("left")
			Input.action_press("right")
		elif xx > hi:
			Input.action_release("right")
			Input.action_press("left")
		else:
			Input.action_release("left")
			Input.action_release("right")
		if not second_done and f > 6 and (p.velocity.y > -60.0 + float(variant) * 120.0) and (need_double or variant == 2):
			Input.action_release("jump")
			await get_tree().physics_frame
			Input.action_press("jump")
			second_done = true
		if f > 12 and p.is_on_floor():
			var px: float = p.global_position.x
			if absf(p.global_position.y - target_y) < 7.0 and px >= sb.x - 6.0 and px <= sb.y + 6.0:
				success = true
			break
	Input.action_release("jump")
	Input.action_release("right")
	Input.action_release("left")
	return success