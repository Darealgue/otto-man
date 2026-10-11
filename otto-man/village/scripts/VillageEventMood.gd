extends Node
## Aktif felaket/nimet eventi varken boşta köylüler kafalarında kısa bir emoji tepkisi gösterir (köyde olay "yaşansın" diye).
## Ekrana renk filtresi UYGULANMAZ (denendi, kötü göründüğü için kaldırıldı).
## Emojiler PLACEHOLDER: metinler strings.csv `village.event.bubble.*`; ileride sprite/ikon ile değiştirilecek.

## Olay tipi -> köylünün kafasında çıkan tepki balonunun çeviri anahtarı
const EVENT_BUBBLE_KEYS: Dictionary = {
	"famine": "village.event.bubble.famine",
	"pest": "village.event.bubble.pest",
	"wolf_attack": "village.event.bubble.wolf",
	"severe_storm": "village.event.bubble.storm",
	"weather_blessing": "village.event.bubble.blessing",
	"worker_strike": "village.event.bubble.strike",
	"disease": "village.event.bubble.disease",
	"plague": "village.event.bubble.disease",
	"bandit_activity": "village.event.bubble.bandit",
	"rebellion": "village.event.bubble.strike",
}
const _BUBBLE_MIN_SEC := 7.0
const _BUBBLE_MAX_SEC := 14.0

var _bubble_cooldown: float = 6.0


func _process(delta: float) -> void:
	_bubble_cooldown -= delta
	if _bubble_cooldown > 0.0:
		return
	_bubble_cooldown = randf_range(_BUBBLE_MIN_SEC, _BUBBLE_MAX_SEC)
	_show_event_reaction_bubble()


func _village_visible() -> bool:
	var vm: Node = get_parent()
	return is_instance_valid(vm) and "village_scene_instance" in vm and is_instance_valid(vm.get("village_scene_instance"))


func _collect_event_types() -> Array[String]:
	var out: Array[String] = []
	var vm: Node = get_parent()
	if is_instance_valid(vm) and vm.has_method("get_active_events"):
		for ev in vm.call("get_active_events"):
			if ev is Dictionary:
				out.append(String(ev.get("type", "")))
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm != null and wm.get("active_events") != null:
		for ev in wm.get("active_events"):
			if ev is Dictionary:
				out.append(String(ev.get("type", "")))
	return out


func _show_event_reaction_bubble() -> void:
	if not _village_visible():
		return
	var keys: Array[String] = []
	for t in _collect_event_types():
		var k: String = String(EVENT_BUBBLE_KEYS.get(t, ""))
		if not k.is_empty() and not keys.has(k):
			keys.append(k)
	if keys.is_empty():
		return
	var vm: Node = get_parent()
	var container: Node = vm.get("workers_container") if "workers_container" in vm else null
	if not is_instance_valid(container):
		return
	var candidates: Array[Node2D] = []
	for child in container.get_children():
		if not (child is Node2D) or not child.visible or child.is_in_group("cats"):
			continue
		if "current_state" in child and int(child.get("current_state")) not in [1, 9]:
			continue
		if child.get("is_deployed") == true or NpcAmbientBubble.has_active_bubble(child):
			continue
		candidates.append(child)
	if candidates.is_empty():
		return
	var worker: Node2D = candidates[randi() % candidates.size()]
	NpcAmbientBubble.show_on_npc(worker, tr(keys[randi() % keys.size()]), 3.0, 120.0, 16)
