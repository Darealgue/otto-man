extends Node2D

## Kamp sahnesi:
## - Köyden zindana ilk girişte seviye seçimi (initial_selection)
## - Zindandan sonra kamp (mid_run_selection): çıkış + daha yüksek seviye kapıları

@export var door_scenes: Array[PackedScene] = []
@export var fountain_scene: PackedScene

var mode: String = "initial_selection" # "initial_selection" | "mid_run_selection"
var has_exit_option: bool = false

var _current_doors: Array[Dictionary] = []  # Bu kamptaki kapı challenge verileri (0: Normal)
var _door_generator: ChallengeDoorGenerator

const MAX_DOORS: int = 4

var _run_stats_panel: Control = null

func _ready() -> void:
	# DungeonRunState'e bakarak modu otomatik belirle
	print("[CampScene] _ready called")
	var drs = _get_dungeon_run_state()
	if drs and drs.run_started and drs.run_segment_count > 0:
		# En az bir segment oynandı, bu bir mid-run kamp
		print("[CampScene] Detected mid-run camp, run_segment_count=%d" % drs.run_segment_count)
		setup_mid_run()
	else:
		# Yeni run başlangıcı, köyden geliyoruz
		print("[CampScene] Initial camp from village")
		setup_initial_from_village()
	_setup_run_stats_ui()

## Dışarıdan çağrılacak kurulum fonksiyonları

func _get_generator() -> ChallengeDoorGenerator:
	if _door_generator:
		return _door_generator
	_door_generator = ChallengeDoorGenerator.new()
	add_child(_door_generator)
	return _door_generator

func setup_initial_from_village() -> void:
	mode = "initial_selection"
	has_exit_option = false
	_clear_spawned()
	_current_doors = _get_generator().generate_doors(true)
	# İlk kamp: Normal kapı gerçekten "basesiz artış" olsun (ilk zindan Lv1 kalsın)
	# Bu yüzden 0. kapının deltasını sıfırlıyoruz (sadece ilk kampta geçerli)
	if _current_doors.size() > 0:
		var normal := _current_doors[0]
		normal["enemy_level_delta"] = 0
		normal["enemy_count_delta"] = 0
		normal["trap_level_delta"] = 0
		normal["trap_count_delta"] = 0
		normal["dungeon_size_delta"] = 0
		normal["gold_multiplier_delta"] = 0.0
		_current_doors[0] = normal
	_spawn_entrance_door_and_fountain()
	_spawn_doors()

func setup_mid_run() -> void:
	mode = "mid_run_selection"
	has_exit_option = true
	_clear_spawned()
	var generated: Array = _get_generator().generate_doors(false)
	# Sıra: [0]=Çıkış (DoorSpot0), [1]=Normal (DoorSpot1), [2..]=prosedürel (DoorSpot2-5)
	_current_doors = [{"is_exit": true, "label_short": "Köye dön"}]
	_current_doors.append_array(generated)
	_spawn_entrance_door_and_fountain()
	_spawn_doors()

## Giriş kapısı (açık, dekoratif) + çeşme: FountainSpot'ta kapı, yanında çeşme
const FOUNTAIN_OFFSET_FROM_DOOR := Vector2(140, 0)

func _spawn_entrance_door_and_fountain() -> void:
	if not has_node("Spots/FountainSpot"):
		return
	var spot: Node2D = get_node("Spots/FountainSpot")
	var container: Node = $"FountainContainer" if has_node("FountainContainer") else self
	var container_2d: Node2D = container as Node2D
	var pos_local: Vector2 = spot.global_position
	if container_2d:
		pos_local = container_2d.to_local(spot.global_position)
	var player_node: Node = get_tree().current_scene.get_node_or_null("Player")
	var door_z: int = (player_node as CanvasItem).z_index - 1 if player_node and player_node is CanvasItem else -1

	# Giriş kapısı: FountainSpot'ta, açık halde (oyuncu buradan girmiş gibi)
	var door_scene: PackedScene = load("res://scenes/CampDoor.tscn") as PackedScene
	if door_scene:
		var entrance_door: Node = door_scene.instantiate()
		if entrance_door is Node2D:
			entrance_door.position = pos_local
		if entrance_door is CanvasItem:
			entrance_door.z_index = door_z
		if entrance_door.get("entrance_only") != null:
			entrance_door.set("entrance_only", true)
		container.add_child(entrance_door)

	# Çeşme: kapının yanında (offset), z_index kapılarla aynı (oyuncunun arkasında)
	var fountain_scene_to_use: PackedScene = fountain_scene
	if fountain_scene_to_use == null:
		fountain_scene_to_use = load("res://scenes/CampFountain.tscn") as PackedScene
	if fountain_scene_to_use:
		var f: Node = fountain_scene_to_use.instantiate()
		if f is Node2D:
			f.position = pos_local + FOUNTAIN_OFFSET_FROM_DOOR
		if f is CanvasItem:
			f.z_index = door_z
		container.add_child(f)

## Kapı ve çeşme spawn (eski _spawn_fountain artık _spawn_entrance_door_and_fountain içinde)

func _clear_spawned() -> void:
	if has_node("DoorContainer"):
		for child in $"DoorContainer".get_children():
			child.queue_free()
	if has_node("FountainContainer"):
		for child in $"FountainContainer".get_children():
			child.queue_free()

func _spawn_doors() -> void:
	print("[CampScene] _spawn_doors start. current mode=%s, door_scenes.size=%d" % [mode, door_scenes.size()])
	if door_scenes.is_empty():
		# Varsayılan olarak kamp kapısı sahnesini kullan (inspector'da override edebilirsin)
		var default_door_scene: PackedScene = load("res://scenes/CampDoor.tscn")
		if default_door_scene:
			print("[CampScene] door_scenes empty, loading default door.tscn")
			door_scenes.append(default_door_scene)
		else:
			print("[CampScene] ERROR: Could not load res://scenes/door.tscn")
			return
	if not has_node("Spots/Doors"):
		print("[CampScene] No Spots/Doors node found")
		return
	# Spot sırası: ilk kampta 1,2,3,4,5 (0=çıkış yok). Mid-run'da 0,1,2,3,4,5 (0=çıkış)
	var spot_names: PackedStringArray = PackedStringArray()
	if has_exit_option:
		spot_names = ["DoorSpot0", "DoorSpot1", "DoorSpot2", "DoorSpot3", "DoorSpot4", "DoorSpot5"]
	else:
		spot_names = ["DoorSpot1", "DoorSpot2", "DoorSpot3", "DoorSpot4", "DoorSpot5"]
	var spots: Array = []
	for name in spot_names:
		if has_node("Spots/Doors/%s" % name):
			var spot: Node2D = get_node("Spots/Doors/%s" % name) as Node2D
			spots.append(spot)
	if spots.is_empty():
		print("[CampScene] No door spots found")
		return

	if _current_doors.is_empty():
		print("[CampScene] _current_doors empty, nothing to spawn")
		return

	var door_count: int = mini(_current_doors.size(), spots.size())

	# Spotları X pozisyonuna göre sırala; soldan sağa kapı 1-2-3...
	spots.sort_custom(Callable(self, "_sort_spots_by_x"))
	print("[CampScene] Spawning %d doors on %d spots (sorted by X)" % [door_count, spots.size()])

	for i in range(door_count):
		var spot: Node2D = spots[i]
		var scene: PackedScene = door_scenes[randi() % door_scenes.size()]
		var door := scene.instantiate()
		if door is Node2D:
			# Kapının pivotunu senin koyduğun Marker2D'nin local pozisyonuna oturt.
			# Hem kapı hem spot root'un doğrudan çocukları olduğu için local position yeterli.
			door.position = spot.position
			print("[CampScene] Spawned door #%d at local %s (spot=%s) using scene %s" % [i, str(door.position), str(spot.position), scene.resource_path])
		if door is CanvasItem:
			# Kapı oyuncunun ARKASINDA kalsın: oyuncunun z_index'inden 1 düşük
			var player := get_tree().current_scene.get_node_or_null("Player")
			if player and player is CanvasItem:
				door.z_index = (player as CanvasItem).z_index - 1
			else:
				door.z_index = -1
		door.set_meta("door_index", i)
		# Kamp kapısı etkileşimi için sinyal bağlantısı
		if door.has_signal("door_selected"):
			door.connect("door_selected", Callable(self, "_on_door_selected"))

		# Etiket: cezalar kırmızı, ödüller yeşil (BBCode)
		var label_text := ""
		if i < _current_doors.size():
			var challenge: Dictionary = _current_doors[i]
			label_text = _build_door_label_bbcode(challenge)
		door.set_meta("challenge_data", _current_doors[i])
		if not label_text.is_empty() and door.has_method("set_label_text"):
			door.set_label_text(label_text)
		if has_node("DoorContainer"):
			$"DoorContainer".add_child(door)
		else:
			add_child(door)

## Kapı etkileşimi

func _on_door_selected(door: Node) -> void:
	var index: int = int(door.get_meta("door_index", -1))
	if index < 0:
		return
	if mode == "initial_selection":
		_handle_initial_selection(index)
	else:
		_handle_mid_run_selection(index)

func _handle_initial_selection(index: int) -> void:
	if index < 0 or index >= _current_doors.size():
		return
	var drs = _get_dungeon_run_state()
	if drs:
		if not drs.run_started:
			drs.start_run_from_village()
		var challenge: Dictionary = _current_doors[index]
		drs.apply_challenge(challenge)
	# Buradan sonra gerçek zindan sahnesine geçiş yapılacak (SceneManager üzerinden)
	var sm = _get_scene_manager()
	if sm and sm.has_method("change_to_dungeon"):
		var payload: Dictionary = {}
		payload["source"] = "village"
		# from_camp = true -> SceneManager gerçek zindan sahnesine gidecek
		payload["from_camp"] = true
		sm.change_to_dungeon(payload)

func _handle_mid_run_selection(index: int) -> void:
	var drs = _get_dungeon_run_state()
	if not drs:
		return
	var sm = _get_scene_manager()

	# İlk kapı çıkış ise: toplam altın * (1.0 + biriken gold multiplier) köye aktarılır
	if has_exit_option and index == 0:
		var gpd = get_node_or_null("/root/GlobalPlayerData")
		if is_instance_valid(gpd) and "dungeon_gold" in gpd:
			var dungeon_gold: int = int(gpd.dungeon_gold)
			var mult: float = 1.0 + float(drs.gold_multiplier_accumulated)
			var extracted: int = int(floor(float(dungeon_gold) * mult))
			if extracted > 0 and gpd.has_method("add_gold"):
				gpd.add_gold(extracted)
			if gpd.has_method("clear_dungeon_gold"):
				gpd.clear_dungeon_gold()
		var rescued: Dictionary = drs.get_partial_exit_rescued(0.5)
		var payload: Dictionary = {}
		payload["source"] = "dungeon"
		payload["rescued_villagers"] = rescued.get("villagers", [])
		payload["rescued_cariyes"] = rescued.get("cariyes", [])
		payload["travel_hours_back"] = 2.0
		drs.end_run()
		if sm and sm.has_method("change_to_village"):
			sm.change_to_village(payload)
		return

	# Çıkış kapısı (index 0) yukarıda işlendi; diğer kapılar challenge uygular
	if index < 0 or index >= _current_doors.size():
		return
	var challenge: Dictionary = _current_doors[index]
	if bool(challenge.get("is_exit", false)):
		return
	drs.apply_challenge(challenge)
	if sm and sm.has_method("change_to_dungeon"):
		var payload2: Dictionary = {}
		payload2["source"] = "dungeon"
		# from_camp = true -> sahneden gerçek zindana katlar arası geçiş
		payload2["from_camp"] = true
		sm.change_to_dungeon(payload2)

## Autoload yardımcıları

func _get_dungeon_run_state() -> Node:
	return get_node_or_null("/root/DungeonRunState")

func _get_scene_manager() -> Node:
	return get_node_or_null("/root/SceneManager")

func _sort_spots_by_x(a: Node2D, b: Node2D) -> bool:
	return a.position.x < b.position.x

## Dizi elemanlarını sep ile birleştirir (Array.join uyumluluğu için)
func _str_join(parts: Array, sep: String) -> String:
	var s := ""
	for i in range(parts.size()):
		if i > 0:
			s += sep
		s += str(parts[i])
	return s

## Kapı etiketi: cezalar kırmızı, ödüller yeşil (BBCode)
func _build_door_label_bbcode(challenge: Dictionary) -> String:
	if bool(challenge.get("is_exit", false)):
		return "Köye dön"
	if bool(challenge.get("is_normal", false)):
		return "Normal (standart artan zorluk)"
	var red_parts: Array = []
	if int(challenge.get("enemy_level_delta", 0)) > 0:
		red_parts.append("+%d düşman seviyesi" % int(challenge["enemy_level_delta"]))
	if int(challenge.get("enemy_count_delta", 0)) > 0:
		red_parts.append("+%d düşman yoğunluğu" % int(challenge["enemy_count_delta"]))
	if int(challenge.get("trap_level_delta", 0)) > 0:
		red_parts.append("+%d tuzak seviyesi" % int(challenge["trap_level_delta"]))
	if int(challenge.get("trap_count_delta", 0)) > 0:
		red_parts.append("+%d tuzak yoğunluğu" % int(challenge["trap_count_delta"]))
	if int(challenge.get("dungeon_size_delta", 0)) > 0:
		red_parts.append("+%d zindan boyutu" % int(challenge["dungeon_size_delta"]))
	var green_parts: Array = []
	if float(challenge.get("gold_multiplier_delta", 0.0)) > 0.0:
		green_parts.append("altın x+%.2f" % float(challenge["gold_multiplier_delta"]))
	if bool(challenge.get("guaranteed_rescue", false)):
		green_parts.append("garanti kurtarma odası")
	var out: Array = []
	if not red_parts.is_empty():
		out.append("[color=red]%s[/color]" % _str_join(red_parts, ", "))
	if not green_parts.is_empty():
		out.append("[color=green]%s[/color]" % _str_join(green_parts, ", "))
	if out.is_empty():
		return "Hafif risk"
	return _str_join(out, "  ")

## Kamp ortasında mevcut run birikimini gösteren panel (multiplier, düşman seviyesi vb.)
func _setup_run_stats_ui() -> void:
	if _run_stats_panel:
		return
	var layer := CanvasLayer.new()
	layer.name = "RunStatsLayer"
	add_child(layer)
	var panel := Panel.new()
	panel.name = "RunStatsPanel"
	# Ekran üst-orta, biraz aşağıda
	var viewport_w: int = get_viewport().get_visible_rect().size.x
	var viewport_h: int = get_viewport().get_visible_rect().size.y
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.set_anchor(SIDE_LEFT, 0.0)
	panel.set_anchor(SIDE_TOP, 0.0)
	panel.set_anchor(SIDE_RIGHT, 1.0)
	panel.set_anchor(SIDE_BOTTOM, 0.0)
	panel.offset_left = viewport_w * 0.25
	panel.offset_right = -viewport_w * 0.25
	panel.offset_top = 12.0
	panel.offset_bottom = 120.0
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8.0
	vbox.offset_top = 6.0
	vbox.offset_right = -8.0
	vbox.offset_bottom = -6.0
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var title := Label.new()
	title.name = "Title"
	title.text = "Run birikimi (şu ana kadar)"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	_run_stats_panel = panel
	_update_run_stats_ui()

func _update_run_stats_ui() -> void:
	if not _run_stats_panel:
		return
	var vbox: VBoxContainer = _run_stats_panel.get_child(0) as VBoxContainer
	if not vbox:
		return
	var drs = _get_dungeon_run_state()
	var lines: PackedStringArray = PackedStringArray()
	if drs and drs.run_started:
		lines.append("Altın çarpanı: x%.2f (1 + %.2f)" % [1.0 + drs.gold_multiplier_accumulated, drs.gold_multiplier_accumulated])
		lines.append("Düşman seviyesi: +%d" % drs.enemy_level_offset)
		lines.append("Tuzak seviyesi: +%d" % drs.trap_level_offset)
		lines.append("Düşman yoğunluğu: +%d" % drs.enemy_count_offset)
		lines.append("Tuzak yoğunluğu: +%d" % drs.trap_count_offset)
		lines.append("Zindan boyutu: +%d" % drs.dungeon_size_offset)
		if drs.guaranteed_rescue_next:
			lines.append("Sonraki bölüm: garanti kurtarma odası")
	else:
		lines.append("Henüz birikim yok (ilk kamp)")
	# vbox: 0 = title, 1.. = stat satırları
	var idx: int = 1
	for line in lines:
		var lbl: Label
		if idx < vbox.get_child_count():
			lbl = vbox.get_child(idx) as Label
		else:
			lbl = Label.new()
			lbl.add_theme_font_size_override("font_size", 12)
			vbox.add_child(lbl)
		if lbl:
			lbl.text = line
		idx += 1
	# Fazla Label'ları sondan sil
	for i in range(vbox.get_child_count() - 1, idx - 1, -1):
		vbox.get_child(i).queue_free()
