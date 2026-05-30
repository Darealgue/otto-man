extends Node

signal scene_change_started(target_path: String)
signal scene_change_completed(new_path: String)
signal load_menu_requested
signal settings_menu_requested

const MAIN_MENU_SCENE: String = "res://scenes/MainMenu.tscn"
const VILLAGE_SCENE: String = "res://village/scenes/VillageScene.tscn"
## TutorialDungeon.tscn = eski iskelet (zemin/tile yok). Oynanabilir harita: 2 veya 3.
const TUTORIAL_DUNGEON_SCENE: String = "res://tutorial/scenes/TutorialDungeon3.tscn"
const DUNGEON_SCENE: String = "res://scenes/test_level.tscn"
const CAMP_SCENE: String = "res://scenes/CampScene.tscn"
const BOSS_ROOM_SCENE: String = "res://scenes/boss_room.tscn"
const FOREST_SCENE: String = "res://scenes/forest.tscn"
const WORLD_MAP_SCENE: String = "res://worldmap/scenes/WorldMapScene.tscn"
const PortalAreaScript = preload("res://village/scripts/PortalArea.gd")
const LoadingScreenScene = preload("res://ui/LoadingScreen.tscn")
const TimeManagerPath := "/root/TimeManager"

var current_scene_path: String = ""
var previous_scene_path: String = ""
var current_payload: Dictionary = {}
var _level_entry_time: Dictionary = {}  # {scene_path: {day, hour, minute}} - Track when player entered each level
var _loading_screen_instance: CanvasLayer = null
## Köyden harita açıldığında tam sahne değiştirmeden üstte gösterilen dünya haritası (köy sahnesi korunur).
var _world_map_overlay_instance: Node = null
## Overlay açılırken köy kameraları kapatılır; kapanınca geri yüklenir.
var _wm_overlay_cam_backup: Array = []
## Harita CanvasLayer'ları köy UI'sının üstüne çıkar (köy PauseMenu 100 — min 110).
var _wm_overlay_canvas_layer_backup: Array = []
const WORLD_MAP_OVERLAY_CANVAS_LAYER_MIN: int = 110
var _wm_overlay_restore_village_visible: bool = true
## CanvasLayer üst düğüm visible=false'dan etkilenmez; köy CanvasLayer'larını tek tek gizleriz.
var _wm_overlay_village_canvas_visibility_backup: Array = []
var _wm_overlay_open_game_minutes: int = -1
var _wm_overlay_session_left_village_hex: bool = false
var _wm_overlay_departure_snapshot_done: bool = false

func _ready() -> void:
	current_scene_path = _detect_initial_scene()
	print("[SceneManager] ready, current=", current_scene_path)

func start_new_game(play_tutorial: bool = false) -> void:
	current_payload = {}
	previous_scene_path = ""
	# 1) Zaman (kayıttan kalan gün ilerlemesini kaldır)
	var tm0: Node = get_node_or_null(TimeManagerPath)
	if tm0 and tm0.has_method("reset_for_new_game"):
		tm0.call("reset_for_new_game")
	# 2) Global oyuncu verisi (altın, envanter)
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd and gpd.has_method("reset_for_new_game"):
		gpd.call("reset_for_new_game")
	# 3) Köy: stok, moral, inşaat önbelleği (Autoload _ready tekrar çalışmaz)
	if is_instance_valid(VillageManager) and VillageManager.has_method("reset_saved_state_for_new_game"):
		VillageManager.reset_saved_state_for_new_game()
	# 4) Dünya haritası + fraksiyon ilişkileri (save yüklemiş olan ilişkileri sıfırla)
	var world_manager: Node = get_node_or_null("/root/WorldManager")
	if is_instance_valid(world_manager):
		if world_manager.has_method("reset_faction_state_for_new_game"):
			world_manager.reset_faction_state_for_new_game()
		if world_manager.has_method("start_new_world_map"):
			var run_seed: int = int(Time.get_unix_time_from_system()) + randi()
			world_manager.start_new_world_map(run_seed)
	# 5) Görevler / cariyeler / haberler (MissionManager)
	var mm0: Node = get_node_or_null("/root/MissionManager")
	if mm0 and mm0.has_method("reset_for_new_game"):
		mm0.call("reset_for_new_game")
	# 6) Hava
	if is_instance_valid(WeatherManager):
		if WeatherManager.storm_active:
			WeatherManager.reset_storm_completely()
		print("[SceneManager] WeatherManager reset for new game")
	# 7) Oyuncu istatistikleri (can, sefer debuff'ları, world supplies)
	var ps_new: Node = get_node_or_null("/root/PlayerStats")
	if ps_new and ps_new.has_method("reset_world_expedition_supplies"):
		ps_new.call("reset_world_expedition_supplies")
	if ps_new and ps_new.has_method("reset_for_new_game"):
		ps_new.call("reset_for_new_game")
	# 8) Zindan run kuyruğu, eşyalar, geçici güçlendirmeler
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if drs and drs.has_method("end_run"):
		drs.call("end_run")
	var im: Node = get_node_or_null("/root/ItemManager")
	if im and im.has_method("clear_all_items"):
		im.call("clear_all_items")
	var pum: Node = get_node_or_null("/root/PowerupManager")
	if pum and pum.has_method("clear_all_powerups"):
		pum.call("clear_all_powerups")
	var tutorial_mgr: Node = get_node_or_null("/root/TutorialManager")
	if play_tutorial:
		if tutorial_mgr and tutorial_mgr.has_method("mark_started_tutorial_run"):
			tutorial_mgr.call("mark_started_tutorial_run")
		_change_scene(TUTORIAL_DUNGEON_SCENE, true)
	else:
		if tutorial_mgr and tutorial_mgr.has_method("mark_skipped_tutorial_run"):
			tutorial_mgr.call("mark_skipped_tutorial_run")
		_change_scene(VILLAGE_SCENE, true)

func return_to_main_menu() -> void:
	current_payload = {}
	_change_scene(MAIN_MENU_SCENE)

func open_load_menu() -> void:
	load_menu_requested.emit()

func open_settings() -> void:
	settings_menu_requested.emit()

const DUNGEON_SUCCESS_MORALE_BONUS: float = 2.0

func change_to_village(payload: Dictionary = {}, force_reload: bool = false) -> void:
	_heal_player_on_world_map_arrival(payload)
	payload = _finalize_dungeon_rewards_on_safe_return(payload)
	payload = _finalize_world_expedition_gold_on_safe_return(payload)
	_sync_world_map_pawn_on_dungeon_return(payload)
	# Köye dönüş simülasyonu bayrağı (köyden çıkışta true kalmış olabilir; time_advanced önce sıfırlanmalı)
	var vm0 := get_node_or_null("/root/VillageManager")
	if is_instance_valid(vm0) and vm0.has_method("mark_arriving_to_village_from_travel"):
		vm0.mark_arriving_to_village_from_travel()
	# Köye dönüşte zindan run'ını her zaman bitir (ölüm veya kamp çıkışı fark etmez)
	var drs = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and drs.has_method("end_run"):
		drs.end_run()
	# Zindan itemlarının etkilerini temizle (köyde kalmasın; hangi yoldan gelirse gelsin)
	var im = get_node_or_null("/root/ItemManager")
	if is_instance_valid(im) and im.has_method("clear_all_items"):
		im.clear_all_items()
	# Zindandan sağ çıkış (kamp veya portal): hafif moral artışı (ölümde payload boş gelir, ceza player.gd'de)
	if payload.get("source", "") == "dungeon":
		var vm = get_node_or_null("/root/VillageManager")
		if is_instance_valid(vm) and "village_morale" in vm:
			var m: float = float(vm.get("village_morale"))
			vm.set("village_morale", minf(100.0, m + DUNGEON_SUCCESS_MORALE_BONUS))
	# Calculate time spent in previous level (forest/dungeon)
	var time_spent = _calculate_time_spent_in_level()
	if time_spent > 0.0:
		payload["time_spent_in_level"] = time_spent
	_handle_travel_time(payload)
	# Taşınan orman kaynakları: restore + üretim simülasyonundan SONRA aktar.
	# Aksi halde _handle_travel_time VillageManager.resource_levels'i çıkış snapshot'ı ile ezer ve taşıma kaybolur.
	payload = _finalize_forest_resources_on_safe_return(payload)
	current_payload = payload.duplicate(true)
	_clear_level_entry_time()
	_change_scene(VILLAGE_SCENE, force_reload)

func _finalize_world_expedition_gold_on_safe_return(payload: Dictionary) -> Dictionary:
	# Dünya haritasından köye güvenli dönüşte sefer çantası altını kasaya aktar.
	if String(payload.get("source", "")) != "world_map":
		return payload
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if not is_instance_valid(ps) or not is_instance_valid(gpd):
		return payload
	if not ps.has_method("get_world_expedition_supplies") or not ps.has_method("apply_world_expedition_gold_delta"):
		return payload
	var ex: Dictionary = ps.call("get_world_expedition_supplies")
	var carried_gold: int = max(0, int(ex.get("world_gold", 0)))
	if carried_gold <= 0:
		return payload
	var taken: int = abs(int(ps.call("apply_world_expedition_gold_delta", -carried_gold)))
	if taken <= 0:
		return payload
	if gpd.has_method("add_gold"):
		gpd.call("add_gold", taken)
	elif "gold" in gpd:
		gpd.gold = int(gpd.gold) + taken
	payload["delivered_world_expedition_gold"] = int(payload.get("delivered_world_expedition_gold", 0)) + taken
	return payload

func _sync_world_map_pawn_on_dungeon_return(payload: Dictionary) -> void:
	var src: String = String(payload.get("source", ""))
	var returning_from_dungeon_like: bool = (
		current_scene_path == DUNGEON_SCENE
		or current_scene_path == CAMP_SCENE
		or current_scene_path == BOSS_ROOM_SCENE
		or current_scene_path == FOREST_SCENE
		or src == "dungeon"
		or src == "dungeon_death"
		or src == "forest"
		or src == "forest_death"
	)
	if not returning_from_dungeon_like:
		return
	var wm: Node = get_node_or_null("/root/WorldManager")
	if is_instance_valid(wm) and wm.has_method("sync_player_world_map_pos_to_own_village"):
		wm.call("sync_player_world_map_pos_to_own_village", true)

func _heal_player_on_world_map_arrival(payload: Dictionary) -> void:
	# Dunya haritasindan koye donuste otomatik full heal yapma.
	# Can eksikse koyde zamanla dolacak sekilde recovery'yi baslat.
	if String(payload.get("source", "")) != "world_map":
		return
	var player_stats = get_node_or_null("/root/PlayerStats")
	if not is_instance_valid(player_stats):
		return
	if player_stats.has_method("start_village_health_recovery"):
		player_stats.call("start_village_health_recovery")

func _finalize_dungeon_rewards_on_safe_return(payload: Dictionary) -> Dictionary:
	# Zindan ödüllerini (ganimet + kurtarılanlar) sadece dünya haritasından köye
	# güvenli dönüşte kalıcı hale getir.
	if String(payload.get("source", "")) != "world_map":
		return payload
	var drs = get_node_or_null("/root/DungeonRunState")
	if not is_instance_valid(drs):
		return payload
	
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	var has_dungeon_gold: bool = false
	if is_instance_valid(gpd) and "dungeon_gold" in gpd:
		has_dungeon_gold = int(gpd.get("dungeon_gold")) > 0
	
	var pending_v: Array = drs.get("pending_rescued_villagers") if "pending_rescued_villagers" in drs else []
	var pending_c: Array = drs.get("pending_rescued_cariyes") if "pending_rescued_cariyes" in drs else []
	var has_rescued: bool = (pending_v.size() > 0 or pending_c.size() > 0)
	
	# Run bağlamı yoksa veya teslim edilecek bir şey yoksa dokunma.
	if not bool(drs.get("run_started")) and not has_dungeon_gold and not has_rescued:
		return payload
	
	# 1) Zindan altınını challenge çarpanıyla kalıcı altına aktar.
	if has_dungeon_gold and is_instance_valid(gpd):
		var dungeon_gold: int = int(gpd.get("dungeon_gold"))
		var mult: float = 1.0 + float(drs.get("gold_multiplier_accumulated"))
		var extracted: int = int(floor(float(dungeon_gold) * mult))
		if extracted > 0 and gpd.has_method("add_gold"):
			gpd.add_gold(extracted)
			payload["delivered_dungeon_gold"] = extracted
		if gpd.has_method("clear_dungeon_gold"):
			gpd.clear_dungeon_gold()
	
	# 2) Kurtarılanları payload'a ekle (köyde işlenecek).
	if drs.has_method("get_and_clear_pending_rescued"):
		var rescued: Dictionary = drs.get_and_clear_pending_rescued()
		payload["rescued_villagers"] = rescued.get("villagers", [])
		payload["rescued_cariyes"] = rescued.get("cariyes", [])
		payload["delivered_rescued_villagers"] = (payload["rescued_villagers"] as Array).size()
		payload["delivered_rescued_cariyes"] = (payload["rescued_cariyes"] as Array).size()
	
	# Köy sahnesi bu dönüşün zindan kökenli teslimat olduğunu bilsin.
	payload["delivered_from_dungeon_run"] = true
	return payload

func _finalize_forest_resources_on_safe_return(payload: Dictionary) -> Dictionary:
	# Ormanda toplanan kaynaklar dünya haritasında taşınır;
	# sadece köye güvenli varışta depoya aktarılır.
	if String(payload.get("source", "")) != "world_map":
		return payload
	
	var player_stats = get_node_or_null("/root/PlayerStats")
	var has_carried_resources: bool = false
	if is_instance_valid(player_stats) and player_stats.has_method("get_carried_resources"):
		var carried: Dictionary = player_stats.get_carried_resources()
		for key in carried.keys():
			if int(carried[key]) > 0:
				has_carried_resources = true
				break
	if not has_carried_resources:
		return payload
	
	var game_manager = get_node_or_null("/root/GameManager")
	if not is_instance_valid(game_manager) or not game_manager.has_method("transfer_carried_resources_to_village"):
		return payload
	
	var transferred: Dictionary = game_manager.transfer_carried_resources_to_village()
	if not transferred.is_empty():
		payload["forest_resources_delivered"] = transferred.duplicate(true)
	return payload

func change_to_dungeon(payload: Dictionary = {}, force_reload: bool = false) -> void:
	var source: String = str(payload.get("source", ""))
	var from_camp: bool = bool(payload.get("from_camp", false))
	var selected_tier: int = int(payload.get("selected_tier", 0))
	# Yeni zindan run'ı hazırlığı:
	# Sadece köyden ilk çıkışta pending kurtarılanları temizle.
	# Dünya haritasından girişte (taşınan ganimet/kurtarılan olabilir) temizlik yapma.
	if not from_camp and source == "village":
		var drs = get_node_or_null("/root/DungeonRunState")
		if is_instance_valid(drs) and drs.has_method("clear_pending_rescued"):
			drs.clear_pending_rescued()
		# Köy kapasitesini önbelleğe al (zindanda kurtarma minigame'inde "Köy dolu" kontrolü için)
		var vm = get_node_or_null("/root/VillageManager")
		if is_instance_valid(vm) and vm.has_method("record_village_capacity_for_dungeon"):
			vm.record_village_capacity_for_dungeon()
		# Köyden zindana çıkarken sadece zamanı ilerlet (üretim simülasyonu yok)
		if is_instance_valid(vm) and vm.has_method("mark_leaving_village_for_travel_out"):
			vm.mark_leaving_village_for_travel_out()
		_handle_travel_time_out_only(payload)
	# Her yeni zindan girişinde benzersiz portal anahtarını resetle
	if PortalAreaScript:
		PortalAreaScript.reset_unique("dungeon_exit")
	current_payload = payload.duplicate(true)
	# Kamp sahnesinden gelen çağrı: gerçek zindan sahnesine git ve level entry time kaydet
	if from_camp:
		# Kamp sahnesinden geliniyor; seçilen tier'a göre LevelGenerator.current_level ayarlanacak
		_record_level_entry_time(DUNGEON_SCENE)
		_change_scene(DUNGEON_SCENE, force_reload)
		# Seçilen zindan seviyesiyle LevelGenerator'ı ayarla
		if selected_tier > 0:
			call_deferred("_apply_selected_tier_to_level_generator", selected_tier)
	else:
		# Köyden ilk geçiş: önce kamp sahnesine uğra
		_change_scene(CAMP_SCENE, force_reload)

func change_to_camp(payload: Dictionary = {}, force_reload: bool = false) -> void:
	## Zindan seviyesi bittikten sonra kamp sahnesine geçiş (köye değil).
	current_payload = payload.duplicate(true)
	_change_scene(CAMP_SCENE, force_reload)

func change_to_boss_room(payload: Dictionary = {}, force_reload: bool = false) -> void:
	current_payload = payload.duplicate(true)
	_change_scene(BOSS_ROOM_SCENE, force_reload)

func change_to_forest(payload: Dictionary = {}, force_reload: bool = false) -> void:
	# Köyden ormana çıkışta travel_out saatini işlet; dünya haritasından giriste tekrar işletme.
	var src: String = String(payload.get("source", ""))
	if src == "village" or src.is_empty():
		var vmf := get_node_or_null("/root/VillageManager")
		if is_instance_valid(vmf) and vmf.has_method("mark_leaving_village_for_travel_out"):
			vmf.mark_leaving_village_for_travel_out()
		_handle_travel_time_out_only(payload)
	current_payload = payload.duplicate(true)
	# Record entry time AFTER travel time has been applied (so we track time inside the level)
	_record_level_entry_time(FOREST_SCENE)
	_change_scene(FOREST_SCENE, force_reload)

func change_to_world_map(payload: Dictionary = {}, force_reload: bool = false) -> void:
	var src: String = String(payload.get("source", ""))
	var cs_wm: Node = get_tree().current_scene
	# Köyden harita: sahneyi değiştirme — overlay ile aç (tüccar / NPC state korunur).
	if src == "village" and cs_wm != null and String(cs_wm.scene_file_path) == VILLAGE_SCENE:
		open_world_map_overlay_from_village(payload)
		return
	if src == "village" or src.is_empty():
		var vm := get_node_or_null("/root/VillageManager")
		if is_instance_valid(vm) and vm.has_method("mark_leaving_village_for_travel_out"):
			vm.mark_leaving_village_for_travel_out()
	current_payload = payload.duplicate(true)
	_record_level_entry_time(WORLD_MAP_SCENE)
	_change_scene(WORLD_MAP_SCENE, force_reload)


func open_world_map_overlay_from_village(payload: Dictionary = {}) -> void:
	if is_instance_valid(_world_map_overlay_instance):
		return
	var cs: Node = get_tree().current_scene
	if cs == null:
		push_warning("[SceneManager] open_world_map_overlay_from_village: current_scene yok")
		return
	if String(cs.scene_file_path) != VILLAGE_SCENE:
		push_warning("[SceneManager] open_world_map_overlay_from_village: aktif sahne köy değil")
		return
	var packed: PackedScene = load(WORLD_MAP_SCENE) as PackedScene
	if packed == null:
		push_error("[SceneManager] Dünya haritası yüklenemedi: %s" % WORLD_MAP_SCENE)
		return
	var inst: Node = packed.instantiate()
	_world_map_overlay_instance = inst
	get_tree().root.add_child(inst)
	get_tree().root.move_child(inst, get_tree().root.get_child_count() - 1)
	cs.process_mode = Node.PROCESS_MODE_DISABLED
	# Köyün PauseMenu'sü ALWAYS modunda — overlay'da ESC'yi yutmaması için devre dışı bırak
	var village_pause := cs.get_node_or_null("PauseMenuLayer/PauseMenu")
	if village_pause:
		village_pause.process_mode = Node.PROCESS_MODE_DISABLED
	# Köy çizimini kapat: UI, envanter, yağmur partikülleri vb. haritada görünmesin (PROCESS_MODE ile donmuş damlalar da).
	_wm_overlay_restore_village_visible = cs.visible
	cs.visible = false
	_wm_overlay_village_canvas_visibility_backup.clear()
	_hide_village_canvas_layers_for_world_map_overlay(cs)
	_wm_overlay_session_left_village_hex = false
	_wm_overlay_departure_snapshot_done = false
	var tm_open: Node = get_node_or_null(TimeManagerPath)
	if tm_open != null and tm_open.has_method("get_total_game_minutes"):
		_wm_overlay_open_game_minutes = int(tm_open.get_total_game_minutes())
	else:
		_wm_overlay_open_game_minutes = -1
	_wm_overlay_canvas_layer_backup.clear()
	_boost_canvas_layers_recursive(inst, WORLD_MAP_OVERLAY_CANVAS_LAYER_MIN)
	_activate_world_map_overlay_camera(cs, inst)
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm != null and wm.has_method("sync_player_world_map_pos_to_own_village"):
		wm.sync_player_world_map_pos_to_own_village(true)
	current_payload = payload.duplicate(true)
	current_payload["world_map_overlay"] = true


## health_display / stamina_bar: tam sahne worldmap path'i yerine overlay'i de "harita modu" say.
func is_world_map_ui_context_active() -> bool:
	if is_instance_valid(_world_map_overlay_instance):
		return true
	var p := String(current_scene_path).to_lower()
	return "worldmap" in p


func notify_overlay_player_moved_on_world_map() -> void:
	if not is_instance_valid(_world_map_overlay_instance):
		return
	var wm := get_node_or_null("/root/WorldManager")
	if wm == null or not wm.has_method("is_player_on_own_village_hex"):
		return
	if bool(wm.call("is_player_on_own_village_hex")):
		return
	_wm_overlay_session_left_village_hex = true
	if _wm_overlay_departure_snapshot_done:
		return
	_wm_overlay_departure_snapshot_done = true
	var vm := get_node_or_null("/root/VillageManager")
	if vm != null and vm.has_method("prepare_snapshot_for_overlay_world_map_departure"):
		vm.call("prepare_snapshot_for_overlay_world_map_departure")


func try_close_world_map_overlay_village_return() -> bool:
	if not is_instance_valid(_world_map_overlay_instance):
		return false
	if _wm_overlay_session_left_village_hex:
		_finish_world_map_overlay_return_after_travel()
	else:
		_finish_world_map_overlay_return_soft_no_travel()
	return true


func _finish_world_map_overlay_return_soft_no_travel() -> void:
	_dismiss_world_map_overlay_if_present()
	var vm := get_node_or_null("/root/VillageManager")
	if vm != null and vm.has_method("mark_arriving_to_village_from_travel"):
		vm.mark_arriving_to_village_from_travel()


func _wm_overlay_elapsed_hours_since_open() -> float:
	var tm := get_node_or_null(TimeManagerPath)
	if tm == null or _wm_overlay_open_game_minutes < 0:
		return 0.0
	var now_m: int = int(tm.get_total_game_minutes())
	var dm: int = maxi(0, now_m - _wm_overlay_open_game_minutes)
	var mph: float = 60.0
	if "MINUTES_PER_HOUR" in tm:
		mph = float(tm.MINUTES_PER_HOUR)
	return float(dm) / mph


func _finish_world_map_overlay_return_after_travel() -> void:
	var payload: Dictionary = {
		"source": "world_map",
		"reason": "overlay_travel_return",
		"time_spent_in_level": _wm_overlay_elapsed_hours_since_open(),
		"travel_hours_back": 0.0,
		"travel_hours_out": 0.0
	}
	# Önce ekonomi/zaman simülasyonu (köy düğümü hâlâ donuk olsa da VillageManager güncellenir).
	_apply_village_return_payload_world_map_overlay(payload)
	_dismiss_world_map_overlay_if_present()
	# Haritada gezip gelince sahne durumu donuk kalıyordu (oyuncu havada vb.); tam sahne WM dönüşü gibi köyü yeniden yükle.
	_change_scene(VILLAGE_SCENE, true)


func _apply_village_return_payload_world_map_overlay(payload: Dictionary) -> void:
	_heal_player_on_world_map_arrival(payload)
	var p: Dictionary = _finalize_dungeon_rewards_on_safe_return(payload)
	p = _finalize_forest_resources_on_safe_return(p)
	p = _finalize_world_expedition_gold_on_safe_return(p)
	_sync_world_map_pawn_on_dungeon_return(p)
	var vm0 := get_node_or_null("/root/VillageManager")
	if is_instance_valid(vm0) and vm0.has_method("mark_arriving_to_village_from_travel"):
		vm0.mark_arriving_to_village_from_travel()
	var drs := get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and drs.has_method("end_run"):
		drs.end_run()
	var im := get_node_or_null("/root/ItemManager")
	if is_instance_valid(im) and im.has_method("clear_all_items"):
		im.clear_all_items()
	_handle_travel_time(p)
	current_payload = p.duplicate(true)


func _hide_village_canvas_layers_for_world_map_overlay(root: Node) -> void:
	_hide_village_canvas_layers_visibility_recursive(root)


func _hide_village_canvas_layers_visibility_recursive(n: Node) -> void:
	if n is CanvasLayer:
		var cl: CanvasLayer = n as CanvasLayer
		_wm_overlay_village_canvas_visibility_backup.append({"node": cl, "visible": cl.visible})
		cl.visible = false
	for c in n.get_children():
		_hide_village_canvas_layers_visibility_recursive(c)


func _restore_village_canvas_layers_visibility_after_overlay() -> void:
	for entry in _wm_overlay_village_canvas_visibility_backup:
		var nd = entry.get("node")
		if is_instance_valid(nd) and nd is CanvasLayer:
			(nd as CanvasLayer).visible = bool(entry.get("visible", true))
	_wm_overlay_village_canvas_visibility_backup.clear()


func _dismiss_world_map_overlay_if_present() -> void:
	if not is_instance_valid(_world_map_overlay_instance):
		return
	var cs: Node = get_tree().current_scene
	var overlay_inst: Node = _world_map_overlay_instance
	_restore_village_canvas_layers_visibility_after_overlay()
	if cs != null:
		cs.visible = _wm_overlay_restore_village_visible
		cs.process_mode = Node.PROCESS_MODE_INHERIT
		# Köyün PauseMenu'sünü geri aktifleştir
		var village_pause := cs.get_node_or_null("PauseMenuLayer/PauseMenu")
		if village_pause:
			village_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_restore_canvas_layers_from_world_map_overlay_backup()
	if cs != null:
		_restore_cameras_after_world_map_overlay(cs, overlay_inst)
	overlay_inst.queue_free()
	_world_map_overlay_instance = null


func _collect_camera2d_recursive(n: Node, into: Array) -> void:
	if n is Camera2D:
		into.append(n)
	for c in n.get_children():
		_collect_camera2d_recursive(c, into)


func _boost_canvas_layers_recursive(node: Node, min_layer: int) -> void:
	if node is CanvasLayer:
		var cl: CanvasLayer = node as CanvasLayer
		_wm_overlay_canvas_layer_backup.append({"node": cl, "layer": cl.layer})
		cl.layer = maxi(cl.layer, min_layer)
	for c in node.get_children():
		_boost_canvas_layers_recursive(c, min_layer)


func _restore_canvas_layers_from_world_map_overlay_backup() -> void:
	for entry in _wm_overlay_canvas_layer_backup:
		var nd = entry.get("node")
		if is_instance_valid(nd) and nd is CanvasLayer:
			(nd as CanvasLayer).layer = int(entry.get("layer", 0))
	_wm_overlay_canvas_layer_backup.clear()


func _activate_world_map_overlay_camera(village_root: Node, world_map_root: Node) -> void:
	_wm_overlay_cam_backup.clear()
	var village_cams: Array = []
	_collect_camera2d_recursive(village_root, village_cams)
	var wm_cam: Camera2D = world_map_root.get_node_or_null("Camera2D") as Camera2D
	if wm_cam == null:
		var wm_cams: Array = []
		_collect_camera2d_recursive(world_map_root, wm_cams)
		if not wm_cams.is_empty():
			wm_cam = wm_cams[0] as Camera2D
	for cam in village_cams:
		if cam is Camera2D:
			var c2: Camera2D = cam as Camera2D
			_wm_overlay_cam_backup.append({"cam": c2, "enabled": c2.enabled})
			c2.enabled = false
	if wm_cam != null:
		wm_cam.enabled = true
		wm_cam.make_current()


func _restore_cameras_after_world_map_overlay(village_root: Node, world_map_root: Node) -> void:
	var wm_cam: Camera2D = world_map_root.get_node_or_null("Camera2D") as Camera2D
	if wm_cam == null:
		var wm_cams: Array = []
		_collect_camera2d_recursive(world_map_root, wm_cams)
		if not wm_cams.is_empty():
			wm_cam = wm_cams[0] as Camera2D
	if is_instance_valid(wm_cam):
		wm_cam.enabled = false
	var restore_current: Camera2D = null
	for entry in _wm_overlay_cam_backup:
		var cam: Camera2D = entry.get("cam") as Camera2D
		if not is_instance_valid(cam):
			continue
		var was_en: bool = bool(entry.get("enabled", false))
		cam.enabled = was_en
		if was_en:
			restore_current = cam
	_wm_overlay_cam_backup.clear()
	if is_instance_valid(restore_current):
		restore_current.make_current()

func _handle_travel_time_out_only(payload: Dictionary) -> void:
	"""Handle travel time when LEAVING village (going to forest/dungeon).
	Only advances time, does NOT simulate production (production continues while away)."""
	var out_hours: float = float(payload.get("travel_hours_out", 0.0))
	
	# Validation: Check for invalid values
	if out_hours <= 0.0:
		return
	if is_nan(out_hours) or is_inf(out_hours):
		push_error("[SceneManager] ❌ Invalid travel_hours_out value: %f (NaN or Infinity). Skipping time advance." % out_hours)
		return
	# Check for extremely large values
	var max_hours: float = 1000.0 * 24.0
	if out_hours > max_hours:
		push_warning("[SceneManager] ⚠️ Very large travel time detected: %.1f hours. Capping to %.1f hours." % [out_hours, max_hours])
		out_hours = max_hours
	
	var time_manager: Node = get_node_or_null(TimeManagerPath)
	if not time_manager:
		push_error("[SceneManager] ❌ TimeManager not found!")
		return
	
	print("[SceneManager] _handle_travel_time_out_only: out=%.1f hours (no production simulation)" % out_hours)
	
	# Just advance time, no production simulation
	if time_manager.has_method("advance_hours"):
		time_manager.call("advance_hours", out_hours)

func _handle_travel_time(payload: Dictionary) -> void:
	"""Handle travel time when RETURNING to village.
	Advances time AND simulates production for the time spent away.
	
	Note: When returning, we simulate:
	- travel_hours_back: Time to travel back to village
	- time_spent_in_level: Time spent in forest/dungeon (already advanced by TimeManager, but we simulate production)
	
	We do NOT simulate travel_hours_out again because it was already advanced when leaving.
	"""
	var out_hours: float = float(payload.get("travel_hours_out", 0.0))
	var back_hours: float = float(payload.get("travel_hours_back", 0.0))
	var time_spent: float = float(payload.get("time_spent_in_level", 0.0))  # Time spent in forest/dungeon
	
	# Validation: Check for invalid values
	if is_nan(back_hours) or is_inf(back_hours):
		push_error("[SceneManager] ❌ Invalid travel_hours_back value: %f (NaN or Infinity). Skipping time advance." % back_hours)
		return
	if is_nan(time_spent) or is_inf(time_spent):
		push_warning("[SceneManager] ⚠️ Invalid time_spent_in_level value: %f (NaN or Infinity). Setting to 0." % time_spent)
		time_spent = 0.0
	if time_spent < 0.0:
		push_warning("[SceneManager] ⚠️ Negative time_spent_in_level detected: %f. Setting to 0." % time_spent)
		time_spent = 0.0
	
	# When returning, time_spent was already advanced by TimeManager during gameplay
	# So we only need to advance back_hours for the travel back
	# But we simulate production for (back_hours + time_spent) total time
	
	var time_to_advance: float = back_hours  # Only advance travel back time
	var time_to_simulate: float = back_hours + time_spent  # Simulate production for total time away
	
	# Check for extremely large values
	var max_hours: float = 1000.0 * 24.0
	if time_to_advance > max_hours:
		push_warning("[SceneManager] ⚠️ Very large travel back time detected: %.1f hours. Capping to %.1f hours." % [time_to_advance, max_hours])
		time_to_advance = max_hours
	if time_to_simulate > max_hours:
		push_warning("[SceneManager] ⚠️ Very large simulation time detected: %.1f hours. Capping to %.1f hours." % [time_to_simulate, max_hours])
		time_to_simulate = max_hours
	
	var time_manager: Node = get_node_or_null(TimeManagerPath)
	if not time_manager:
		return
	var minutes_per_hour_early: int = 60
	if "MINUTES_PER_HOUR" in time_manager:
		minutes_per_hour_early = time_manager.MINUTES_PER_HOUR
	var total_minutes: int = int(round(time_to_simulate * float(minutes_per_hour_early)))
	# Dünya haritasında süre TimeManager'da zaten ilerlediyse back_hours=0 olabilir; üretim simülasyonu yine de gerekir.
	if time_to_advance <= 0.0 and total_minutes <= 0:
		return
	
	var village_manager = get_node_or_null("/root/VillageManager")
	
	# Get start time for simulation - use snapshot time if available (when player left village)
	# Otherwise fall back to current time
	var start_day: int = 0
	var start_hour: int = 0
	var start_minute: int = 0
	
	if village_manager:
		var snapshot_time = village_manager.get("_saved_snapshot_time")
		if snapshot_time is Dictionary and not snapshot_time.is_empty():
			start_day = int(snapshot_time.get("day", 0))
			start_hour = int(snapshot_time.get("hour", 0))
			start_minute = int(snapshot_time.get("minute", 0))
			print("[SceneManager] Using snapshot time for simulation: Day %d, %02d:%02d" % [start_day, start_hour, start_minute])
		else:
			# Fallback to current time if snapshot time not available
			if time_manager.has_method("get_day"):
				start_day = time_manager.get_day()
			if time_manager.has_method("get_hour"):
				start_hour = time_manager.get_hour()
			if time_manager.has_method("get_minute"):
				start_minute = time_manager.get_minute()
			print("[SceneManager] No snapshot time found, using current time: Day %d, %02d:%02d" % [start_day, start_hour, start_minute])
	else:
		# Fallback if VillageManager not available
		if time_manager.has_method("get_day"):
			start_day = time_manager.get_day()
		if time_manager.has_method("get_hour"):
			start_hour = time_manager.get_hour()
		if time_manager.has_method("get_minute"):
			start_minute = time_manager.get_minute()
	
	print("[SceneManager] _handle_travel_time (RETURN): out=%.1f, back=%.1f, spent=%.1f" % [out_hours, back_hours, time_spent])
	print("[SceneManager] Will advance time: %.1f hours, simulate production: %.1f hours (total_minutes=%d)" % [time_to_advance, time_to_simulate, total_minutes])
	
	# Check if VillageManager's time_advanced signal is connected BEFORE advancing time
	var signal_connected: bool = false
	if village_manager and time_manager.has_signal("time_advanced"):
		var connections = time_manager.time_advanced.get_connections()
		for conn in connections:
			if conn.get("target") == village_manager:
				signal_connected = true
				break
	
	# IMPORTANT: Restore saved resources BEFORE simulating production
	# This ensures we simulate based on the resources we had when leaving
	# We restore here because simulation happens before register_village_scene
	if village_manager:
		var saved_resources = village_manager.get("_saved_resource_levels")
		var saved_progress = village_manager.get("_saved_base_production_progress")
		if saved_resources is Dictionary and not saved_resources.is_empty():
			print("[SceneManager] Restoring resources before simulation: ", saved_resources)
			village_manager.resource_levels = (saved_resources as Dictionary).duplicate(true)
		if saved_progress is Dictionary and not saved_progress.is_empty():
			village_manager.base_production_progress = (saved_progress as Dictionary).duplicate(true)
	
	# Advance time (only travel back time, time_spent was already advanced during gameplay)
	# This will emit time_advanced signal if VillageManager is connected
	# If signal is connected, it will trigger simulation automatically
	# If NOT connected, we need to call simulation manually AFTER time advance
	if time_manager.has_method("advance_hours") and time_to_advance > 0.0:
		time_manager.call("advance_hours", time_to_advance)
		# Log end time
		var end_day: int = start_day
		var end_hour: int = start_hour
		if time_manager.has_method("get_day"):
			end_day = time_manager.get_day()
		if time_manager.has_method("get_hour"):
			end_hour = time_manager.get_hour()
		print("[SceneManager] End time after advance: Day %d, %02d:%02d" % [end_day, end_hour, time_manager.get_minute() if time_manager.has_method("get_minute") else 0])
	
	# Safety net / overlay dönüşü: Süre haritada zaten ilerlediyse advance_hours=0 olabilir; time_advanced tetiklenmez.
	var need_manual_sim: bool = false
	if village_manager != null and total_minutes > 0:
		if not signal_connected:
			need_manual_sim = true
		elif time_to_advance <= 0.0:
			need_manual_sim = true
	if need_manual_sim and village_manager.has_method("_simulate_time_skip"):
		if not signal_connected:
			print("[SceneManager] ⚠️ Time_advanced signal not connected, calling simulation directly")
		else:
			print("[SceneManager] Overlay/kayıtlı süre: zaman zaten ilerledi, üretim simülasyonu doğrudan uygulanıyor")
		village_manager.call("_simulate_time_skip", total_minutes, start_day, start_hour, start_minute)
	elif village_manager and total_minutes > 0 and not village_manager.has_method("_simulate_time_skip"):
		print("[SceneManager] ⚠️ VillageManager._simulate_time_skip method not found!")
	
	# Clear snapshot time after simulation (so it doesn't interfere with future trips)
	if village_manager:
		village_manager.set("_saved_snapshot_time", {})

func get_current_payload() -> Dictionary:
	return current_payload.duplicate(true)

func clear_payload() -> void:
	current_payload.clear()

func _change_scene(target_path: String, force_reload: bool = false) -> void:
	_dismiss_world_map_overlay_if_present()
	if target_path == "":
		push_warning("SceneManager: Hedef sahne yolu boş")
		return
	if not ResourceLoader.exists(target_path):
		push_error("SceneManager: Sahne bulunamadı -> %s" % target_path)
		return
	var same_scene := current_scene_path == target_path
	if same_scene and not force_reload:
		print("[SceneManager] same scene request, ignoring", target_path)
		return
	
	# Show loading screen
	_show_loading_screen(_get_scene_name(target_path))
	
	# Use call_deferred to ensure loading screen is visible before heavy operations
	call_deferred("_perform_scene_change", target_path, same_scene and force_reload)

func _show_loading_screen(scene_name: String = "") -> void:
	if not LoadingScreenScene:
		return
	
	# Create loading screen instance if it doesn't exist
	if not is_instance_valid(_loading_screen_instance):
		_loading_screen_instance = LoadingScreenScene.instantiate() as CanvasLayer
		get_tree().root.add_child(_loading_screen_instance)
	
	# Show loading screen
	var loading_text = "Yükleniyor"
	if not scene_name.is_empty():
		loading_text += "... " + scene_name
	else:
		loading_text += "..."
	
	# Script is attached to CanvasLayer, so methods are directly accessible
	if _loading_screen_instance.has_method("show_loading"):
		_loading_screen_instance.show_loading(loading_text)
	else:
		push_error("[SceneManager] LoadingScreen.show_loading() method not found!")

func _hide_loading_screen() -> void:
	if is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.hide_loading()
		# Don't remove the instance, keep it for next use
		# The loading screen will handle its own fade out

func _perform_scene_change(target_path: String, is_reload: bool) -> void:
	# Allow the loading screen to render before heavy operations
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var same_scene := current_scene_path == target_path
	
	if same_scene and is_reload:
		print("[SceneManager] reloading current scene ->", target_path)
		var vm_reload := get_node_or_null("/root/VillageManager")
		if is_instance_valid(vm_reload) and vm_reload.has_method("schedule_skip_next_snapshot"):
			vm_reload.schedule_skip_next_snapshot()
		scene_change_started.emit(target_path)
		previous_scene_path = current_scene_path
		Engine.time_scale = 1.0
		
		# Update progress
		if is_instance_valid(_loading_screen_instance):
			_loading_screen_instance.set_progress(25.0)
		
		var reload_err := get_tree().reload_current_scene()
		if reload_err != OK:
			var error_msg = "Sahne yeniden yüklenemedi: %s\nHata kodu: %d" % [target_path, reload_err]
			push_error("SceneManager: %s" % error_msg)
			_hide_loading_screen()
			_handle_scene_load_error(error_msg, target_path)
			return
		
		# Wait a frame for scene to be ready
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_hide_loading_screen()
		scene_change_completed.emit(target_path)
		return
	
	print("[SceneManager] changing scene ->", target_path)
	scene_change_started.emit(target_path)
	previous_scene_path = current_scene_path
	current_scene_path = target_path
	
	# Update progress
	if is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.set_progress(25.0)
	
	# Reset time scale before scene change to prevent player state issues
	Engine.time_scale = 1.0
	
	# Change scene
	var err := get_tree().change_scene_to_file(target_path)
	if err != OK:
		var error_msg = "Sahne yüklenemedi: %s\nHata kodu: %d" % [target_path, err]
		push_error("SceneManager: %s" % error_msg)
		_hide_loading_screen()
		_handle_scene_load_error(error_msg, target_path)
		return
	
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	# Update progress and hide
	if is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.set_progress(100.0)
	
	# Small delay for progress to be visible, then fade out
	await get_tree().create_timer(0.2).timeout
	_hide_loading_screen()
	
	# Wait for fade out to complete
	if is_instance_valid(_loading_screen_instance):
		await _loading_screen_instance.fade_out_complete
	
	# Update UI visibility based on scene
	_update_ui_visibility(target_path)
	
	scene_change_completed.emit(target_path)

func _update_ui_visibility(scene_path: String) -> void:
	"""Show/hide health and stamina bars based on current scene."""
	var is_combat_scene = (
		scene_path == DUNGEON_SCENE
		or scene_path == TUTORIAL_DUNGEON_SCENE
		or scene_path == FOREST_SCENE
		or scene_path == CAMP_SCENE
		or scene_path == BOSS_ROOM_SCENE
		or scene_path == WORLD_MAP_SCENE
		or scene_path == VILLAGE_SCENE
	)
	var should_show_ui = is_combat_scene
	
	print("[SceneManager] 🎮 Updating UI visibility for scene: %s (show UI: %s)" % [scene_path, should_show_ui])
	
	# Wait a frame for scene to be fully loaded
	await get_tree().process_frame
	await get_tree().process_frame
	
	var current_scene := get_tree().current_scene
	HudCanvasLayers.apply_to_autoload_fx()
	if current_scene:
		HudCanvasLayers.apply_to_scene_root(current_scene)
	
	# Find health display and stamina bar — önce sahne GameUI, yoksa grup
	var health_display: Node = null
	var stamina_bar: Node = null
	if current_scene:
		health_display = current_scene.get_node_or_null("GameUI/Container/HealthDisplay")
		stamina_bar = current_scene.get_node_or_null("GameUI/Container/StaminaBar")
	if health_display == null:
		health_display = get_tree().get_first_node_in_group("health_display")
	if stamina_bar == null:
		stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	var player = null  # Declare outside if block
	
	if current_scene:
		# Check for GameUI scene
		var game_ui = current_scene.get_node_or_null("GameUI")
		if game_ui:
			var hd = game_ui.get_node_or_null("Container/HealthDisplay")
			if hd and hd is Control:
				if should_show_ui:
					hd.show()
				else:
					hd.hide()
			
			var sb = game_ui.get_node_or_null("Container/StaminaBar")
			if sb and sb is Control:
				if should_show_ui:
					sb.show()
				else:
					sb.hide()
			
			# Update DungeonGoldDisplay visibility
			var dgd = game_ui.get_node_or_null("DungeonGoldDisplay")
			if dgd and dgd is Control:
				# Visibility managed by DungeonGoldDisplay itself
				pass
		
		# Check for player UI (player.tscn has UI as child)
		player = current_scene.get_node_or_null("Player")
		if not player:
			# Try finding player in group
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player = players[0]
		
		var scene_has_game_ui := current_scene.get_node_or_null("GameUI") != null
		if player and not scene_has_game_ui:
			var player_ui = player.get_node_or_null("UI")
			if player_ui:
				var hd_player = player_ui.get_node_or_null("HealthDisplay")
				if hd_player and hd_player is Control:
					if should_show_ui:
						hd_player.show()
					else:
						hd_player.hide()
				
				var sb_player = player_ui.get_node_or_null("StaminaBar")
				if sb_player and sb_player is Control:
					if should_show_ui:
						sb_player.show()
					else:
						sb_player.hide()
	
	# Update nodes found via groups (only if they are Control nodes)
	if health_display and health_display is Control:
		if "_force_visible" in health_display:
			health_display._force_visible = should_show_ui
		if should_show_ui:
			health_display.show()
		else:
			health_display.hide()
	
	if stamina_bar and stamina_bar is Control:
		if "_force_visible" in stamina_bar:
			stamina_bar._force_visible = should_show_ui
		if should_show_ui:
			stamina_bar.show()
		else:
			stamina_bar.hide()
	
	# Oyuncu gömülü UI: sahne GameUI kullanıyorsa atla (çift bar + karartma riski)
	if player and player.has_node("UI") and current_scene and current_scene.get_node_or_null("GameUI") == null:
		var player_ui = player.get_node("UI")
		var hd_player = player_ui.get_node_or_null("HealthDisplay")
		if hd_player and hd_player is Control:
			if "_force_visible" in hd_player:
				hd_player._force_visible = should_show_ui
			if should_show_ui:
				hd_player.show()
			else:
				hd_player.hide()
		
		var sb_player = player_ui.get_node_or_null("StaminaBar")
		if sb_player and sb_player is Control:
			if "_force_visible" in sb_player:
				sb_player._force_visible = should_show_ui
			if should_show_ui:
				sb_player.show()
			else:
				sb_player.hide()
	
	# Also update GameUI nodes
	if current_scene:
		var game_ui = current_scene.get_node_or_null("GameUI")
		if game_ui:
			var hd = game_ui.get_node_or_null("Container/HealthDisplay")
			if hd and hd is Control:
				if "_force_visible" in hd:
					hd._force_visible = should_show_ui
				if should_show_ui:
					hd.show()
				else:
					hd.hide()
			
			var sb = game_ui.get_node_or_null("Container/StaminaBar")
			if sb and sb is Control:
				if "_force_visible" in sb:
					sb._force_visible = should_show_ui
				if should_show_ui:
					sb.show()
				else:
					sb.hide()
			
			# Update DungeonGoldDisplay
			var dgd = game_ui.get_node_or_null("DungeonGoldDisplay")
			if dgd and dgd is Control:
				if should_show_ui:
					# Visibility will be handled by DungeonGoldDisplay itself based on gold amount
					pass
				else:
					dgd.hide()
	
	print("[SceneManager] ✅ UI visibility updated")

func _get_scene_name(scene_path: String) -> String:
	if scene_path == MAIN_MENU_SCENE:
		return "Ana Menü"
	elif scene_path == VILLAGE_SCENE:
		return "Köy"
	elif scene_path == TUTORIAL_DUNGEON_SCENE:
		return "Öğretici"
	elif scene_path == DUNGEON_SCENE:
		return "Zindan"
	elif scene_path == FOREST_SCENE:
		return "Orman"
	else:
		var filename = scene_path.get_file().get_basename()
		return filename.capitalize()

func _apply_selected_tier_to_level_generator(tier: int) -> void:
	# TestLevel sahnesindeki LevelGenerator node'unun current_level değerini,
	# kamp sahnesinde seçilen tier ile eşitle.
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	var level_gen: Node = current_scene.get_node_or_null("LevelGenerator")
	if not level_gen:
		# Gerekirse sahne ağacında rekürsif ara
		level_gen = current_scene.find_child("LevelGenerator", true, false)
	if level_gen and "current_level" in level_gen:
		level_gen.set("current_level", tier)
		print("[SceneManager] Applied selected tier %d to LevelGenerator.current_level" % tier)

func _detect_initial_scene() -> String:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != "":
		return scene.scene_file_path
	return ""

func _record_level_entry_time(scene_path: String) -> void:
	"""Record when player enters a level (forest/dungeon)"""
	var time_manager = get_node_or_null(TimeManagerPath)
	if not time_manager:
		return
	var entry_time: Dictionary = {}
	if time_manager.has_method("get_day"):
		entry_time["day"] = time_manager.get_day()
	if time_manager.has_method("get_hour"):
		entry_time["hour"] = time_manager.get_hour()
	if time_manager.has_method("get_minute"):
		entry_time["minute"] = time_manager.get_minute()
	_level_entry_time[scene_path] = entry_time
	print("[SceneManager] Recorded entry time for %s: Day %d, %02d:%02d" % [scene_path, entry_time.get("day", 0), entry_time.get("hour", 0), entry_time.get("minute", 0)])

func _calculate_time_spent_in_level() -> float:
	"""Calculate hours spent in the current runtime level (forest/dungeon/world_map)."""
	var time_manager = get_node_or_null(TimeManagerPath)
	if not time_manager:
		return 0.0
	
	# Validate that we have valid entry time data
	var entry_key: String = ""
	if current_scene_path == FOREST_SCENE:
		entry_key = FOREST_SCENE
	elif current_scene_path == DUNGEON_SCENE:
		entry_key = DUNGEON_SCENE
	elif current_scene_path == WORLD_MAP_SCENE:
		entry_key = WORLD_MAP_SCENE
	else:
		return 0.0
	
	if not _level_entry_time.has(entry_key):
		push_warning("[SceneManager] ⚠️ No entry time recorded for current level. Returning 0 hours.")
		return 0.0
	
	var entry_time = _level_entry_time[entry_key]
	var entry_day: int = entry_time.get("day", 0)
	var entry_hour: int = entry_time.get("hour", 0)
	var entry_minute: int = entry_time.get("minute", 0)
	
	var exit_day: int = 0
	var exit_hour: int = 0
	var exit_minute: int = 0
	if time_manager.has_method("get_day"):
		exit_day = time_manager.get_day()
	if time_manager.has_method("get_hour"):
		exit_hour = time_manager.get_hour()
	if time_manager.has_method("get_minute"):
		exit_minute = time_manager.get_minute()
	
	# Calculate total minutes difference
	var minutes_per_hour: int = 60
	if "MINUTES_PER_HOUR" in time_manager:
		minutes_per_hour = time_manager.MINUTES_PER_HOUR
	var hours_per_day: int = 24
	if "HOURS_PER_DAY" in time_manager:
		hours_per_day = time_manager.HOURS_PER_DAY
	
	# Convert to total minutes
	var entry_total_minutes: int = entry_day * hours_per_day * minutes_per_hour + entry_hour * minutes_per_hour + entry_minute
	var exit_total_minutes: int = exit_day * hours_per_day * minutes_per_hour + exit_hour * minutes_per_hour + exit_minute
	
	var diff_minutes: int = exit_total_minutes - entry_total_minutes
	if diff_minutes < 0:
		# This shouldn't happen, but handle it gracefully
		push_warning("[SceneManager] ⚠️ Negative time difference detected (exit time before entry time). This may indicate a time reset or bug. Returning 0 hours.")
		return 0.0
	
	var time_spent_hours: float = float(diff_minutes) / float(minutes_per_hour)
	print("[SceneManager] Time spent in level: %.2f hours (from Day %d %02d:%02d to Day %d %02d:%02d)" % [time_spent_hours, entry_day, entry_hour, entry_minute, exit_day, exit_hour, exit_minute])
	return time_spent_hours

func _clear_level_entry_time() -> void:
	"""Clear entry time tracking when returning to village"""
	_level_entry_time.clear()

func _handle_scene_load_error(error_message: String, failed_scene_path: String) -> void:
	"""Handle scene loading errors by showing error dialog and returning to village"""
	push_error("[SceneManager] Scene load error: %s" % error_message)
	
	# Try to show error dialog
	var error_dialog_scene = load("res://ui/ErrorDialog.tscn")
	if error_dialog_scene:
		var error_dialog = error_dialog_scene.instantiate()
		get_tree().root.add_child(error_dialog)
		if error_dialog.has_method("show_error"):
			error_dialog.show_error(
				"Sahne Yüklenemedi",
				"Oyun sahnesi yüklenirken bir hata oluştu.\n\nKöye dönülüyor..."
			)
			# Wait for dialog to close, then return to village
			if error_dialog.has_signal("dialog_closed"):
				error_dialog.dialog_closed.connect(func(): _return_to_village_on_error())
			else:
				# Fallback: return to village after a delay
				await get_tree().create_timer(2.0).timeout
				_return_to_village_on_error()
		else:
			_return_to_village_on_error()
	else:
		# Fallback: just return to village
		_return_to_village_on_error()

func _return_to_village_on_error() -> void:
	"""Return to village scene as fallback when scene loading fails"""
	if ResourceLoader.exists(VILLAGE_SCENE):
		print("[SceneManager] Returning to village due to scene load error")
		current_scene_path = VILLAGE_SCENE
		var err := get_tree().change_scene_to_file(VILLAGE_SCENE)
		if err != OK:
			push_error("[SceneManager] CRITICAL: Failed to return to village scene!")
	else:
		push_error("[SceneManager] CRITICAL: Village scene not found!")
