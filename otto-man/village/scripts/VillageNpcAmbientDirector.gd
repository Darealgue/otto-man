extends Node
## Köyde iki köylü arasında el yapımı ambient diyalog oynatır (LLM gerekmez).

const _Catalog = preload("res://village/narrative/VillageNpcAmbientCatalog.gd")
const _NpcAmbientBubble = preload("res://ui/npc_ambient_bubble.gd")

@export var enabled: bool = true
@export var min_interval_sec: float = 20.0
@export var max_interval_sec: float = 36.0
@export var pair_distance_px: float = 130.0
@export var player_block_distance_px: float = 220.0

var _cooldown_sec: float = 8.0
var _next_interval_sec: float = 28.0
var _busy: bool = false


func _ready() -> void:
	_next_interval_sec = randf_range(min_interval_sec, max_interval_sec)


func _process(delta: float) -> void:
	if not enabled or _busy:
		return
	var vm: Node = get_parent()
	if not is_instance_valid(vm) or not ("village_scene_instance" in vm):
		return
	if not is_instance_valid(vm.get("village_scene_instance")):
		return
	if _player_in_dialogue(vm):
		return
	_cooldown_sec -= delta
	if _cooldown_sec > 0.0:
		return
	if _try_start_exchange(vm):
		_cooldown_sec = _next_interval_sec
		_next_interval_sec = randf_range(min_interval_sec, max_interval_sec)
	else:
		_cooldown_sec = 6.0


func _player_in_dialogue(vm: Node) -> bool:
	if "active_dialogue_npc" in vm and is_instance_valid(vm.get("active_dialogue_npc")):
		return true
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return false
	if player.has_method("is_in_dialogue") and _variant_is_true(player.call("is_in_dialogue")):
		return true
	return false


func _variant_is_true(value: Variant) -> bool:
	return value == true


func _try_start_exchange(vm: Node) -> bool:
	var workers: Array[Node2D] = _collect_eligible_workers(vm)
	if workers.size() < 2:
		return false
	var pair: Array[Node2D] = _pick_nearby_pair(workers)
	if pair.size() < 2:
		return false
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		for npc in pair:
			if player.global_position.distance_to(npc.global_position) > player_block_distance_px:
				return false
	var tags: Array[String] = _Catalog.gather_context_tags(vm)
	var conv: Dictionary = _Catalog.pick_conversation(tags)
	if conv.is_empty():
		return false
	_play_exchange(pair, conv)
	return true


func _collect_eligible_workers(vm: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var container: Node = vm.get("workers_container") if "workers_container" in vm else null
	if not is_instance_valid(container):
		return out
	for child in container.get_children():
		if not child is Node2D or not child.visible:
			continue
		if child.is_in_group("cats"):
			continue
		if not _is_worker_eligible(child):
			continue
		out.append(child)
	return out


func _is_worker_eligible(worker: Node) -> bool:
	if _node_flag(worker, "is_guest_villager") or _node_flag(worker, "is_deployed"):
		return false
	if _node_flag(worker, "is_dungeon_prisoner"):
		return false
	if worker.has_node("NpcWindow"):
		var nw: Node = worker.get_node("NpcWindow")
		if nw.visible:
			return false
	if _NpcAmbientBubble.has_active_bubble(worker):
		return false
	if "current_state" in worker:
		var st: int = int(worker.get("current_state"))
		if st not in [1, 9]:
			return false
	return true


func _node_flag(node: Node, key: StringName) -> bool:
	if not key in node:
		return false
	return node.get(key) == true


func _pick_nearby_pair(workers: Array[Node2D]) -> Array[Node2D]:
	var shuffled := workers.duplicate()
	shuffled.shuffle()
	for i in range(shuffled.size()):
		for j in range(i + 1, shuffled.size()):
			var a: Node2D = shuffled[i]
			var b: Node2D = shuffled[j]
			if a.global_position.distance_to(b.global_position) <= pair_distance_px:
				return [a, b]
	return []


func _play_exchange(pair: Array[Node2D], conv: Dictionary) -> void:
	_busy = true
	var lines: Array = conv.get("lines", [])
	for line_variant in lines:
		if not line_variant is Dictionary:
			continue
		var line: Dictionary = line_variant
		var speaker_idx: int = clampi(int(line.get("speaker", 0)), 0, pair.size() - 1)
		var npc: Node2D = pair[speaker_idx]
		if not is_instance_valid(npc):
			continue
		var key: String = String(line.get("key", ""))
		if key.is_empty():
			continue
		var text: String = tr(key)
		var duration: float = float(line.get("duration", 3.2))
		var pause_after: float = float(line.get("pause_after", 2.4))
		_NpcAmbientBubble.show_on_npc(npc, text, duration)
		if pause_after > 0.0:
			await get_tree().create_timer(pause_after).timeout
	_busy = false
