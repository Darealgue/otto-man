extends Control
## 10 parçalı öldürme sayacı: her düşman öldürüldüğünde bir parça dolar,
## 10'a ulaşınca (ItemManager item seçimi açtığında) sıfırdan dolmaya devam eder.

const SEGMENT_COUNT := 10

var segments: Array[ProgressBar] = []
var _kills_per_item: int = SEGMENT_COUNT

func _ready() -> void:
	add_to_group("xp_bar")

	segments.clear()
	for child in $Segments.get_children():
		if child is ProgressBar:
			segments.append(child)

	var item_manager := get_node_or_null("/root/ItemManager")
	if item_manager:
		_kills_per_item = int(item_manager.KILLS_PER_ITEM)
		if not item_manager.xp_orbs_collected_changed.is_connected(_on_kill_count_changed):
			item_manager.xp_orbs_collected_changed.connect(_on_kill_count_changed)
		_on_kill_count_changed(int(item_manager.xp_orbs_collected))

	show()
	modulate.a = 1.0

var _force_visible: bool = true  # Allow external control

func _process(_delta: float) -> void:
	if _is_world_map_scene():
		_force_visible = true
		visible = true
		show()
		modulate.a = 1.0

	if !_force_visible:
		return

	if !visible and _force_visible:
		show()
		modulate.a = 1.0

func _on_kill_count_changed(count: int) -> void:
	var filled: int
	if count <= 0:
		filled = 0
	elif count % _kills_per_item == 0:
		filled = _kills_per_item
	else:
		filled = count % _kills_per_item
	_update_segments(filled)

func _update_segments(filled: int) -> void:
	for i in range(segments.size()):
		var seg := segments[i]
		if i < filled:
			seg.value = 1.0
			seg.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			seg.value = 0.0
			seg.modulate = Color(0.7, 0.7, 0.7, 0.6)

func _is_world_map_scene() -> bool:
	var sm := get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("is_world_map_ui_context_active"):
		return bool(sm.is_world_map_ui_context_active())
	if sm == null:
		return false
	var path: String = String(sm.get("current_scene_path"))
	return "worldmap" in path.to_lower()
