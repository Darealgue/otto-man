extends Node
## Tutorial oturumu: zindan + köy bayrakları + MentorInbox posta kutusu.

signal dungeon_movement_lesson_completed
signal mentor_inbox_changed
signal village_objective_changed(objective_text: String)
signal tutorial_forest_gather_complete_changed(complete: bool)
signal village_dungeon_guide_changed

# --- Zindan tutorial bayrakları ---
var run_tutorial: bool = false
var dungeon_movement_complete: bool = false
var village_tutorial_pending: bool = false

# --- Köy tutorial durumu ---
var village_core_complete: bool = false
var village_core_step: int = -1

# --- Bağlamsal hint bayrakları (tek seferlik) ---
var hint_cariye_delivered: bool = false
var hint_trader_delivered: bool = false
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


func _ready() -> void:
	var lm := get_node_or_null("/root/LocaleManager")
	if lm and lm.has_signal("locale_changed"):
		lm.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	if not _objective_tr_key.is_empty():
		set_objective(tr(_objective_tr_key))


func reset_session_flags() -> void:
	run_tutorial = false
	dungeon_movement_complete = false
	village_tutorial_pending = false
	village_core_complete = false
	village_core_step = -1
	hint_cariye_delivered = false
	hint_trader_delivered = false
	tutorial_forest_gather_complete = false
	village_dungeon_guide_active = false
	tutorial_dungeon_guide_complete = false
	active_objective = ""
	_objective_tr_key = ""
	village_menu_phase = 0
	_inbox.clear()
	_delivered_ids.clear()


func mark_started_tutorial_run() -> void:
	run_tutorial = true
	dungeon_movement_complete = false
	village_tutorial_pending = false


func mark_skipped_tutorial_run() -> void:
	run_tutorial = false
	dungeon_movement_complete = false
	village_tutorial_pending = false


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
