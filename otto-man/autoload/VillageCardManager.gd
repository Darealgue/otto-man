extends Node
## Köy roguelite kart sistemi — draft/seçim akışının durum makinesi.
## Kart verileri: VillageCardDatabase.gd (SSOT: docs/VILLAGE_ROGUELITE_CARDS.md)
##
## Draft ritmi (SSOT'dan):
##   nüfus 5  -> yol seçimi + aynı anda 1. draft (3 kart, seçilen yoldan)
##   nüfus 10 -> 2. draft (3 kart, seçilen yoldan)
##   nüfus 15 -> 3. draft (3 kart, seçilen yoldan)
##   nüfus 20+ (her 5 nüfusta bir, sonsuza kadar) -> 4.+ draft (3 kendi yol + 1 wildcard)
## Görülüp seçilmeyen kartlar o run'da kalıcı olarak havuzdan düşer.

signal path_choice_ready
signal draft_ready(cards: Array)
signal card_taken(card: Dictionary)
signal state_changed

const DRAFT_POPULATION_STEP: int = 5
const WILDCARD_STARTS_AT_DRAFT: int = 4
## Bir draftta ikilem çifti çıkma ihtimali (o yolda hâlâ tam çift kaldıysa)
const DILEMMA_APPEARANCE_CHANCE: float = 0.25

var chosen_path: String = ""  # "" | "eskiya" | "pasa" | "koylu"
var drafts_completed: int = 0
var taken_card_ids: Array[String] = []
var removed_card_ids: Array[String] = []  # görülüp seçilmeyen kartlar (kalıcı)

## "" | "path" | "draft"
var pending_choice_type: String = ""
var pending_draft_cards: Array[Dictionary] = []
var pending_is_dilemma_draft: bool = false

var _population_poll_accum: float = 0.0
const POPULATION_POLL_INTERVAL: float = 1.5


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_population_poll_accum += delta
	if _population_poll_accum < POPULATION_POLL_INTERVAL:
		return
	_population_poll_accum = 0.0
	_check_population_trigger()


func _get_population() -> int:
	var vm = get_node_or_null("/root/VillageManager")
	if vm == null:
		return 0
	return int(vm.get("total_workers"))


func _next_draft_threshold() -> int:
	return DRAFT_POPULATION_STEP * (drafts_completed + 1)


func _check_population_trigger() -> void:
	if pending_choice_type != "":
		return  # Zaten cevap bekleyen bir seçim var
	var population := _get_population()
	if population < _next_draft_threshold():
		return
	if chosen_path == "":
		pending_choice_type = "path"
		path_choice_ready.emit()
		state_changed.emit()
		return
	start_draft()


## --- Yol seçimi ---
func choose_path(path_key: String) -> bool:
	if pending_choice_type != "path":
		return false
	if not VillageCardDatabase.PATH_NAMES.has(path_key):
		return false
	chosen_path = path_key
	pending_choice_type = ""
	state_changed.emit()
	start_draft()
	return true


## --- Draft üretimi ---
func start_draft() -> void:
	if chosen_path == "":
		return
	var draft_index := drafts_completed + 1
	var own_pool := _available_cards_for_path(chosen_path)

	var dilemma_group := _pick_available_dilemma_group(own_pool)
	if dilemma_group != "" and randf() < DILEMMA_APPEARANCE_CHANCE:
		pending_draft_cards = _dilemma_pair_for_group(own_pool, dilemma_group)
		pending_is_dilemma_draft = true
	else:
		var singles := own_pool.filter(func(c): return not bool(c.get("is_dilemma", false)))
		singles.shuffle()
		var picked: Array[Dictionary] = []
		for i in range(mini(3, singles.size())):
			picked.append(singles[i])
		if draft_index >= WILDCARD_STARTS_AT_DRAFT:
			var wildcard := _pick_wildcard()
			if not wildcard.is_empty():
				picked.append(wildcard)
		pending_draft_cards = picked
		pending_is_dilemma_draft = false

	pending_choice_type = "draft"
	draft_ready.emit(pending_draft_cards)
	state_changed.emit()


func _available_cards_for_path(path_key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card in VillageCardDatabase.get_cards_for_path(path_key):
		var cid := String(card.get("id", ""))
		if taken_card_ids.has(cid) or removed_card_ids.has(cid):
			continue
		out.append(card)
	return out


func _pick_available_dilemma_group(pool: Array[Dictionary]) -> String:
	var groups: Dictionary = {}
	for card in pool:
		if not bool(card.get("is_dilemma", false)):
			continue
		var g := String(card.get("dilemma_group", ""))
		if g == "":
			continue
		groups[g] = groups.get(g, 0) + 1
	for g in groups.keys():
		if int(groups[g]) >= 2:
			return String(g)
	return ""


func _dilemma_pair_for_group(pool: Array[Dictionary], group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card in pool:
		if String(card.get("dilemma_group", "")) == group:
			out.append(card)
	return out


func _pick_wildcard() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for path_key in VillageCardDatabase.PATH_NAMES.keys():
		if path_key == chosen_path:
			continue
		for card in _available_cards_for_path(String(path_key)):
			if not bool(card.get("is_dilemma", false)):
				candidates.append(card)
	if candidates.is_empty():
		return {}
	candidates.shuffle()
	return candidates[0]


## --- Kart seçimi ---
func choose_card(card_id: String) -> bool:
	if pending_choice_type != "draft":
		return false
	var chosen: Dictionary = {}
	for card in pending_draft_cards:
		if String(card.get("id", "")) == card_id:
			chosen = card
			break
	if chosen.is_empty():
		return false

	for card in pending_draft_cards:
		var cid := String(card.get("id", ""))
		if cid == card_id:
			taken_card_ids.append(cid)
		elif not removed_card_ids.has(cid):
			removed_card_ids.append(cid)  # Görülüp seçilmedi -> kalıcı olarak havuzdan düşer

	drafts_completed += 1
	pending_draft_cards = []
	pending_is_dilemma_draft = false
	pending_choice_type = ""

	card_taken.emit(chosen)
	state_changed.emit()
	return true


## --- Durum sorguları ---
func get_taken_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cid in taken_card_ids:
		var card := VillageCardDatabase.get_card_by_id(cid)
		if not card.is_empty():
			out.append(card)
	return out


func has_card(card_id: String) -> bool:
	return taken_card_ids.has(card_id)


## --- Kayıt/Yükleme ---
func serialize_for_save() -> Dictionary:
	return {
		"chosen_path": chosen_path,
		"drafts_completed": drafts_completed,
		"taken_card_ids": taken_card_ids.duplicate(),
		"removed_card_ids": removed_card_ids.duplicate(),
		"pending_choice_type": pending_choice_type,
		"pending_draft_cards": pending_draft_cards.duplicate(true),
		"pending_is_dilemma_draft": pending_is_dilemma_draft,
	}


func load_from_save(data: Dictionary) -> void:
	chosen_path = String(data.get("chosen_path", ""))
	drafts_completed = int(data.get("drafts_completed", 0))
	taken_card_ids.clear()
	for cid in data.get("taken_card_ids", []):
		taken_card_ids.append(String(cid))
	removed_card_ids.clear()
	for cid in data.get("removed_card_ids", []):
		removed_card_ids.append(String(cid))
	pending_choice_type = String(data.get("pending_choice_type", ""))
	pending_draft_cards.clear()
	var raw_draft: Variant = data.get("pending_draft_cards", [])
	if raw_draft is Array:
		for c in raw_draft:
			if c is Dictionary:
				pending_draft_cards.append((c as Dictionary).duplicate(true))
	pending_is_dilemma_draft = bool(data.get("pending_is_dilemma_draft", false))
	state_changed.emit()
	# Yükleme sonrası bekleyen bir seçim varsa UI bunu dinleyip yeniden gösterecek.
	if pending_choice_type == "path":
		call_deferred("emit_signal", "path_choice_ready")
	elif pending_choice_type == "draft" and not pending_draft_cards.is_empty():
		call_deferred("emit_signal", "draft_ready", pending_draft_cards)


func reset_for_new_game() -> void:
	chosen_path = ""
	drafts_completed = 0
	taken_card_ids.clear()
	removed_card_ids.clear()
	pending_choice_type = ""
	pending_draft_cards.clear()
	pending_is_dilemma_draft = false
	_population_poll_accum = 0.0
