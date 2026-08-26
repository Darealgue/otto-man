extends Node
## GEÇİCİ - silinecek. Rota onizlemesini sahte bir yolla cizdirip olcer.

func _ready() -> void:
	await get_tree().process_frame
	var map = load("res://worldmap/scenes/WorldMapScene.tscn").instantiate()
	get_tree().root.add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	# Oyuncunun bulundugu hex'ten baslayarak karisik bir rota kur (yatay + capraz)
	var st = map._get_world_map_state_cached()
	var p = st.get("player_pos", {"q": 0, "r": 0})
	var q0 = int(p.get("q", 0))
	var r0 = int(p.get("r", 0))
	var steps = [Vector2i(1,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,-1), Vector2i(0,1), Vector2i(1,0)]
	var path := []
	var cq = q0; var cr = r0
	path.append({"q": cq, "r": cr})
	for s in steps:
		cq += s.x; cr += s.y
		path.append({"q": cq, "r": cr})
	map._preview_path = path
	map.queue_redraw()

	# Nokta sayisini olc: yol uzunlugunu ve aralik basina dusen noktayi hesapla
	var pts := PackedVector2Array()
	for i in range(path.size() - 1):
		pts.append(map._shared_hex_edge_midpoint_between(
			int(path[i].q), int(path[i].r), int(path[i+1].q), int(path[i+1].r), map.HEX_SIZE - 1.0))
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i+1])
	var karo := path.size() - 1
	var nokta := int(total / map.PATH_DOT_SPACING)
	print("[Rota] karo sayisi=%d  yol uzunlugu=%.1fpx  nokta~%d  karo basina=%.2f" % [
		karo, total, nokta, float(nokta) / float(max(1, karo))])

	map._camera.zoom = Vector2(1.6, 1.6)
	map._camera.global_position = pts[0]
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shot_path.png")
	print("[Rota] kaydedildi")
	get_tree().quit()
