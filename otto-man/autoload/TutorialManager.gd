extends Node
## Tutorial oturumu: zindan + köy bayrakları + MentorInbox posta kutusu.

signal dungeon_movement_lesson_completed
signal mentor_inbox_changed
signal village_objective_changed(objective_text: String)
signal tutorial_forest_gather_complete_changed(complete: bool)
signal village_dungeon_guide_changed

# --- Zindan tutorial bayrakları ---
var run_tutorial: bool = false
var tutorial_skipped: bool = false
var dungeon_movement_complete: bool = false
var village_tutorial_pending: bool = false

# --- Köy tutorial durumu ---
var village_core_complete: bool = false
var village_core_step: int = -1

# --- Bağlamsal hint bayrakları (tek seferlik) ---
var hint_cariye_delivered: bool = false
var hint_trader_delivered: bool = false
var rescue_mission_guide_active: bool = false
var rescue_mission_guide_complete: bool = false
var _rescue_mission_concubine_name: String = ""
var tutorial_forest_gather_complete: bool = false
var village_dungeon_guide_active: bool = false
var tutorial_dungeon_guide_complete: bool = false

const FAREWELL_OBJECTIVE_SECONDS: float = 8.0

# --- Aktif görev (ekranda gösterilen) ---
var active_objective: String = ""
var _objective_tr_key: String = ""
var village_menu_phase: int = 0

# --- MentorInbox: mesaj kuyruğu ---
var _inbox: Array[Dictionary] = []
var _delivered_ids: Dictionary = {}

const _DeathMentorBrief = preload("res://village/narrative/DeathMentorBrief.gd")


func _ready() -> void:
	var lm := get_node_or_null("/root/LocaleManager")
	if lm and lm.has_signal("locale_changed"):
		lm.locale_changed.connect(_on_locale_changed)
	call_deferred("_hook_mission_signals")
	call_deferred("_hook_player_stats_death")


func _hook_mission_signals() -> void:
	var mm := get_node_or_null("/root/MissionManager")
	if mm and mm.has_signal("mission_started") and not mm.mission_started.is_connected(_on_mission_started_for_guide):
		mm.mission_started.connect(_on_mission_started_for_guide)


func _hook_player_stats_death() -> void:
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null or not ps.has_signal("death_recovery_updated"):
		return
	if not ps.death_recovery_updated.is_connected(_on_death_recovery_updated_for_mentor):
		ps.death_recovery_updated.connect(_on_death_recovery_updated_for_mentor, CONNECT_DEFERRED)


func try_enqueue_death_return_brief(payload: Dictionary) -> void:
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null or not ps.has_method("take_death_mentor_brief_context"):
		return
	var ctx: Dictionary = ps.call("take_death_mentor_brief_context")
	if ctx.is_empty():
		return
	_DeathMentorBrief.enqueue_return_messages(self, payload, ctx)


func _on_death_recovery_updated_for_mentor(_state: Dictionary) -> void:
	try_deliver_healed_mentor_brief()


func try_deliver_healed_mentor_brief() -> void:
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null or not ps.has_method("has_healed_mentor_brief_pending"):
		return
	if not bool(ps.call("has_healed_mentor_brief_pending")):
		return
	var sm := get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("is_village_scene_active"):
		if not bool(sm.call("is_village_scene_active")):
			return
	if not ps.has_method("take_healed_mentor_brief_run_id"):
		return
	var run_id: int = int(ps.call("take_healed_mentor_brief_run_id"))
	if run_id <= 0:
		return
	_DeathMentorBrief.enqueue_healed_message(self, run_id)


func _on_locale_changed(_locale: String) -> void:
	if not _objective_tr_key.is_empty():
		set_objective(tr(_objective_tr_key))


func reset_session_flags() -> void:
	run_tutorial = false
	tutorial_skipped = false
	dungeon_movement_complete = false
	village_tutorial_pending = false
	village_core_complete = false
	village_core_step = -1
	hint_cariye_delivered = false
	hint_trader_delivered = false
	rescue_mission_guide_active = false
	rescue_mission_guide_complete = false
	_rescue_mission_concubine_name = ""
	tutorial_forest_gather_complete = false
	village_dungeon_guide_active = false
	tutorial_dungeon_guide_complete = false
	active_objective = ""
	_objective_tr_key = ""
	village_menu_phase = 0
	_inbox.clear()
	_delivered_ids.clear()


func reset_for_new_game() -> void:
	reset_session_flags()


func mark_started_tutorial_run() -> void:
	run_tutorial = true
	tutorial_skipped = false
	dungeon_movement_complete = false
	village_tutorial_pending = false


func mark_skipped_tutorial_run() -> void:
	run_tutorial = false
	tutorial_skipped = true
	dungeon_movement_complete = false
	village_tutorial_pending = false
	village_core_complete = true
	village_core_step = 99
	hint_cariye_delivered = true
	hint_trader_delivered = true
	rescue_mission_guide_complete = true
	tutorial_dungeon_guide_complete = true
	village_dungeon_guide_active = false
	_reveal_nearest_dungeon_hex_for_skip()


func is_tutorial_skipped() -> bool:
	return tutorial_skipped


func _reveal_nearest_dungeon_hex_for_skip() -> void:
	var wm := get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("reveal_tutorial_dungeon_for_guide"):
		wm.reveal_tutorial_dungeon_for_guide()


func mark_dungeon_movement_complete() -> void:
	dungeon_movement_complete = true
	village_tutorial_pending = true
	dungeon_movement_lesson_completed.emit()


func is_village_tutorial_pending() -> bool:
	return village_tutorial_pending


func consume_village_tutorial_pending() -> bool:
	if not village_tutorial_pending:
		return false
	village_tutorial_pending = false
	return true


func mark_village_core_complete() -> void:
	village_core_complete = true
	village_core_step = 99
	enqueue_message(
		"village_core_complete",
		tr("tutorial.village.core_complete"),
		"tutorial",
		0
	)


func start_village_dungeon_guide() -> void:
	if village_dungeon_guide_active or tutorial_dungeon_guide_complete:
		return
	village_dungeon_guide_active = true
	var wm := get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("reveal_tutorial_dungeon_for_guide"):
		wm.reveal_tutorial_dungeon_for_guide()
	enqueue_message(
		"dungeon_guide",
		tr("tutorial.dungeon_guide.message"),
		"tutorial",
		1
	)
	village_dungeon_guide_changed.emit()
	set_objective_tr("tutorial.dungeon_guide.objective")


func mark_tutorial_dungeon_guide_complete() -> void:
	if tutorial_dungeon_guide_complete:
		return
	village_dungeon_guide_active = false
	tutorial_dungeon_guide_complete = true
	village_dungeon_guide_changed.emit()
	set_objective_tr("tutorial.farewell")
	var tree := get_tree()
	if tree:
		tree.create_timer(FAREWELL_OBJECTIVE_SECONDS).timeout.connect(_clear_farewell_objective, CONNECT_ONE_SHOT)


func _clear_farewell_objective() -> void:
	if _objective_tr_key == "tutorial.farewell":
		_objective_tr_key = ""
		set_objective("")


func is_village_tutorial_active() -> bool:
	return not village_core_complete and village_core_step >= 0


func mark_tutorial_forest_gather_complete() -> void:
	if tutorial_forest_gather_complete:
		return
	tutorial_forest_gather_complete = true
	tutorial_forest_gather_complete_changed.emit(true)


func try_set_village_menu_objective(min_phase: int, text: String) -> void:
	if village_core_complete or village_core_step < 2 or village_core_step > 3:
		return
	if min_phase < village_menu_phase:
		return
	village_menu_phase = min_phase
	set_objective(text)


func advance_village_core_after_mentor_welcome() -> void:
	if village_core_step != 0:
		return
	village_core_step = 1
	set_objective_tr("tutorial.village.objective_forest")


func begin_village_core_tutorial_messages() -> void:
	if village_core_complete or village_core_step >= 0:
		return
	village_core_step = 0
	enqueue_message(
		"welcome_hud",
		tr("tutorial.village.welcome_hud"),
		"tutorial",
		0
	)
	enqueue_message(
		"go_to_forest",
		tr("tutorial.village.go_to_forest"),
		"tutorial",
		1
	)
	set_objective_tr("tutorial.village.objective_mentor")


func refresh_village_objective_for_step() -> void:
	if village_dungeon_guide_active and not tutorial_dungeon_guide_complete:
		set_objective_tr("tutorial.dungeon_guide.objective")
		return
	if village_core_complete:
		return
	match village_core_step:
		0:
			set_objective_tr("tutorial.village.objective_mentor")
		1:
			if tutorial_forest_gather_complete:
				set_objective_tr("tutorial.village.objective_build_plot")
			else:
				set_objective_tr("tutorial.village.objective_forest")
		2:
			_refresh_village_step2_objective()
		3:
			_refresh_village_step3_objective()


func _refresh_village_step2_objective() -> void:
	match village_menu_phase:
		0:
			set_objective_tr("tutorial.village.objective_build_plot")
		_:
			set_objective_tr("tutorial.village.objective_build_woodcutter")


func _refresh_village_step3_objective() -> void:
	match village_menu_phase:
		0, 1, 2, 3:
			set_objective_tr("tutorial.village.objective_assign_worker")
		_:
			set_objective_tr("tutorial.village.objective_assign_worker")


func get_mission_center_locked_page() -> int:
	# Görev Merkezi artık köy tutorialında kullanılmıyor (parsel etkileşimi).
	return -1


func start_rescue_mission_guide(concubine_name: String) -> void:
	if tutorial_skipped or rescue_mission_guide_complete:
		return
	rescue_mission_guide_active = true
	_rescue_mission_concubine_name = concubine_name.strip_edges()
	if _rescue_mission_concubine_name.is_empty():
		_rescue_mission_concubine_name = tr("cariye.unknown")
	enqueue_message(
		"rescue_chain_guide",
		tr("tutorial.rescue_chain.message") % _rescue_mission_concubine_name,
		"tutorial",
		6
	)
	set_objective(tr("tutorial.rescue_chain.objective") % _rescue_mission_concubine_name)


func mark_rescue_mission_guide_complete() -> void:
	if rescue_mission_guide_complete:
		return
	rescue_mission_guide_active = false
	rescue_mission_guide_complete = true
	set_objective("")


func _on_mission_started_for_guide(cariye_id: int, mission_id: String) -> void:
	if not rescue_mission_guide_active or rescue_mission_guide_complete:
		return
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("is_rescue_onboarding_mission"):
		return
	if not mm.is_rescue_onboarding_mission(mission_id):
		return
	if mm.get_rescue_onboarding_concubine_id() >= 0 and cariye_id != mm.get_rescue_onboarding_concubine_id():
		return
	mark_rescue_mission_guide_complete()


func can_open_mission_page(page_index: int) -> bool:
	var locked := get_mission_center_locked_page()
	if locked < 0:
		return true
	return page_index == locked


func is_tutorial_building_allowed(building_scene_path: String) -> bool:
	if not is_village_tutorial_active() or village_core_step != 2:
		return true
	return "woodcutter" in String(building_scene_path).to_lower()


func is_tutorial_worker_assignment_allowed(building_key: String) -> bool:
	if not is_village_tutorial_active() or village_core_step != 3:
		return true
	return "woodcutter" in String(building_key).to_lower()


func export_save_state() -> Dictionary:
	var delivered: Array[String] = []
	for id in _delivered_ids.keys():
		delivered.append(String(id))
	return {
		"run_tutorial": run_tutorial,
		"tutorial_skipped": tutorial_skipped,
		"dungeon_movement_complete": dungeon_movement_complete,
		"village_core_complete": village_core_complete,
		"village_core_step": village_core_step,
		"hint_cariye_delivered": hint_cariye_delivered,
		"hint_trader_delivered": hint_trader_delivered,
		"rescue_mission_guide_active": rescue_mission_guide_active,
		"rescue_mission_guide_complete": rescue_mission_guide_complete,
		"rescue_mission_concubine_name": _rescue_mission_concubine_name,
		"tutorial_forest_gather_complete": tutorial_forest_gather_complete,
		"village_dungeon_guide_active": village_dungeon_guide_active,
		"tutorial_dungeon_guide_complete": tutorial_dungeon_guide_complete,
		"village_menu_phase": village_menu_phase,
		"delivered_ids": delivered,
	}


func import_save_state(data: Dictionary) -> void:
	reset_session_flags()
	if data.is_empty():
		return
	run_tutorial = bool(data.get("run_tutorial", false))
	tutorial_skipped = bool(data.get("tutorial_skipped", false))
	dungeon_movement_complete = bool(data.get("dungeon_movement_complete", false))
	village_core_complete = bool(data.get("village_core_complete", false))
	village_core_step = int(data.get("village_core_step", -1))
	hint_cariye_delivered = bool(data.get("hint_cariye_delivered", false))
	hint_trader_delivered = bool(data.get("hint_trader_delivered", false))
	rescue_mission_guide_active = bool(data.get("rescue_mission_guide_active", false))
	rescue_mission_guide_complete = bool(data.get("rescue_mission_guide_complete", false))
	_rescue_mission_concubine_name = String(data.get("rescue_mission_concubine_name", ""))
	tutorial_forest_gather_complete = bool(data.get("tutorial_forest_gather_complete", false))
	village_dungeon_guide_active = bool(data.get("village_dungeon_guide_active", false))
	tutorial_dungeon_guide_complete = bool(data.get("tutorial_dungeon_guide_complete", false))
	village_menu_phase = int(data.get("village_menu_phase", 0))
	var delivered: Variant = data.get("delivered_ids", [])
	if delivered is Array:
		for id in delivered:
			_delivered_ids[String(id)] = true
	_rebuild_pending_messages_after_load()
	refresh_village_objective_for_step()
	village_dungeon_guide_changed.emit()
	tutorial_forest_gather_complete_changed.emit(tutorial_forest_gather_complete)


func _rebuild_pending_messages_after_load() -> void:
	if village_core_complete:
		if village_dungeon_guide_active and not tutorial_dungeon_guide_complete:
			if not is_delivered("dungeon_guide"):
				enqueue_message(
					"dungeon_guide",
					tr("tutorial.dungeon_guide.message"),
					"tutorial",
					1
				)
		return
	if village_core_step < 0:
		return
	if village_core_step == 0:
		if not is_delivered("welcome_hud"):
			enqueue_message(
				"welcome_hud",
				tr("tutorial.village.welcome_hud"),
				"tutorial",
				0
			)
		if not is_delivered("go_to_forest"):
			enqueue_message(
				"go_to_forest",
				tr("tutorial.village.go_to_forest"),
				"tutorial",
				1
			)
	elif not is_delivered("village_core_complete") and village_core_step >= 99:
		enqueue_message(
			"village_core_complete",
			tr("tutorial.village.core_complete"),
			"tutorial",
			0
		)
		if village_dungeon_guide_active and not is_delivered("dungeon_guide"):
			enqueue_message(
				"dungeon_guide",
				tr("tutorial.dungeon_guide.message"),
				"tutorial",
				1
			)


# =======================================================
# MentorInbox — posta kutusu
# =======================================================

## Kuyruğa mesaj ekle. Aynı id tekrar eklenmez.
func enqueue_message(id: String, speech_bbcode: String, kind: String = "tutorial", priority: int = 10) -> void:
	if _delivered_ids.has(id):
		return
	for msg in _inbox:
		if msg.get("id", "") == id:
			return
	_inbox.append({
		"id": id,
		"speech_bbcode": speech_bbcode,
		"kind": kind,
		"priority": priority,
	})
	_inbox.sort_custom(_sort_by_priority)
	mentor_inbox_changed.emit()


## Bekleyen mesaj sayısı (badge).
func pending_count() -> int:
	return _inbox.size()


## Kuyrukta mesaj var mı?
func has_pending() -> bool:
	return not _inbox.is_empty()


## Etkileşimde sıradaki mesajı al (FIFO, priority'ye göre sıralı).
## Döndürülen dict: {id, speech_bbcode, kind} veya boş dict.
func drain_next() -> Dictionary:
	if _inbox.is_empty():
		return {}
	var msg: Dictionary = _inbox.pop_front()
	_delivered_ids[msg.get("id", "")] = true
	mentor_inbox_changed.emit()
	return msg


## Tüm bekleyen mesajları sırayla al (tek seferde hepsini göstermek için).
func drain_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	while not _inbox.is_empty():
		var msg: Dictionary = _inbox.pop_front()
		_delivered_ids[msg.get("id", "")] = true
		result.append(msg)
	if not result.is_empty():
		mentor_inbox_changed.emit()
	return result


## Mesaj daha önce teslim edildi mi?
func is_delivered(id: String) -> bool:
	return _delivered_ids.has(id)


## Aktif görev metnini ayarla (ekran şeridi).
func set_objective(text: String) -> void:
	if active_objective == text:
		return
	active_objective = text
	village_objective_changed.emit(text)


func set_objective_tr(key: String) -> void:
	_objective_tr_key = key
	set_objective(tr(key))


func _sort_by_priority(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("priority", 10)) < int(b.get("priority", 10))
