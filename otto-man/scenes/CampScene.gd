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
	_spawn_entrance_door_and_fountain()
	_spawn_doors()

func setup_mid_run() -> void:
	mode = "mid_run_selection"
	has_exit_option = true
	_clear_spawned()

	var drs = _get_dungeon_run_state()
	var run_complete: bool = drs and drs.is_run_complete()

	if run_complete:
		# 3 segment tamamlandı — sadece çıkış kapısı, devam yok
		_current_doors = [{"is_exit": true, "label_short": "[color=green]Köye Dön — Zafer![/color]"}]
	else:
		var generated: Array = _get_generator().generate_doors(false)
		_current_doors = [{"is_exit": true, "label_short": "[color=green]Köye Dön[/color]"}]
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

	# İlk kapı çıkış ise: ödülleri teslim ETME, dünya haritasına taşı.
	if has_exit_option and index == 0:
		var payload: Dictionary = {"source": "dungeon", "return_reason": "dungeon_exit"}
		if sm and sm.has_method("change_to_world_map"):
			sm.change_to_world_map(payload)
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


## Kapı etiketi: generator'dan gelen minimal label veya çıkış metni
func _build_door_label_bbcode(challenge: Dictionary) -> String:
	if bool(challenge.get("is_exit", false)):
		return "[color=green]Köye Dön[/color]"
	return str(challenge.get("label_short", ""))

## Kamp ortasında oyuncu dostu durum göstergesi
func _setup_run_stats_ui() -> void:
	if _run_stats_panel:
		return
	var layer := CanvasLayer.new()
	layer.name = "RunStatsLayer"
	add_child(layer)
	var panel := Panel.new()
	panel.name = "RunStatsPanel"
	var viewport_w: int = get_viewport().get_visible_rect().size.x
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.set_anchor(SIDE_LEFT, 0.0)
	panel.set_anchor(SIDE_TOP, 0.0)
	panel.set_anchor(SIDE_RIGHT, 1.0)
	panel.set_anchor(SIDE_BOTTOM, 0.0)
	panel.offset_left = viewport_w * 0.3
	panel.offset_right = -viewport_w * 0.3
	panel.offset_top = 12.0
	panel.offset_bottom = 72.0
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8.0
	vbox.offset_top = 6.0
	vbox.offset_right = -8.0
	vbox.offset_bottom = -6.0
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var title := RichTextLabel.new()
	title.name = "Title"
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(title)
	var detail := RichTextLabel.new()
	detail.name = "Detail"
	detail.bbcode_enabled = true
	detail.fit_content = true
	detail.scroll_active = false
	detail.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(detail)
	_run_stats_panel = panel
	_update_run_stats_ui()

func _update_run_stats_ui() -> void:
	if not _run_stats_panel:
		return
	var vbox: VBoxContainer = _run_stats_panel.get_child(0) as VBoxContainer
	if not vbox:
		return
	var title_lbl: RichTextLabel = vbox.get_node_or_null("Title") as RichTextLabel
	var detail_lbl: RichTextLabel = vbox.get_node_or_null("Detail") as RichTextLabel
	if not title_lbl or not detail_lbl:
		return

	var drs = _get_dungeon_run_state()
	if not drs or not drs.run_started or drs.run_segment_count == 0:
		title_lbl.text = "İlk giriş — bir kapı seç"
		detail_lbl.text = ""
		return

	if drs.is_run_complete():
		title_lbl.text = "[color=green]Zindan tamamlandı![/color]"
		detail_lbl.text = "Ganimetlerinle köye dönebilirsin."
		return

	var total_risk: int = drs.enemy_level_offset + drs.enemy_count_offset \
		+ drs.trap_level_offset + drs.trap_count_offset + drs.dungeon_size_offset * 2
	var tier: int = _risk_score_to_tier(total_risk)
	var tier_name: String = _risk_tier_display_name(tier)
	var tier_color: String = _risk_tier_display_color(tier)

	var skull := "\u2620"
	var skull_display := ""
	if tier <= 0:
		skull_display = "Güvenli"
	else:
		skull_display = skull.repeat(tier)
	title_lbl.text = "[color=%s]Tehlike: %s[/color]" % [tier_color, skull_display]

	var coin := "\u2742"
	var heart := "\u2665"
	var details: Array = []
	if drs.gold_multiplier_accumulated > 0.0:
		var coin_count: int = 1
		if drs.gold_multiplier_accumulated >= 1.5:
			coin_count = 3
		elif drs.gold_multiplier_accumulated >= 0.75:
			coin_count = 2
		details.append("[color=yellow]%s[/color]" % coin.repeat(coin_count))
	if drs.guaranteed_rescue_next:
		details.append("[color=green]%s[/color]" % heart)
	details.append("Bölüm %d/%d" % [drs.run_segment_count, drs.MAX_SEGMENTS])
	detail_lbl.text = "  ".join(details)

func _risk_score_to_tier(score: int) -> int:
	if score <= 0:
		return 0
	elif score <= 2:
		return 1
	elif score <= 4:
		return 2
	elif score <= 7:
		return 3
	else:
		return 4

func _risk_tier_display_name(tier: int) -> String:
	match tier:
		0: return "Güvenli"
		1: return "Düşük"
		2: return "Orta"
		3: return "Yüksek"
		4: return "Aşırı"
		_: return "Bilinmeyen"

func _risk_tier_display_color(tier: int) -> String:
	match tier:
		0: return "white"
		1: return "green"
		2: return "yellow"
		3: return "orange"
		4: return "red"
		_: return "white"
