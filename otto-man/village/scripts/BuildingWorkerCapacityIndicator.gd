class_name BuildingWorkerCapacityIndicator
extends Node2D
## Bina üstünde işçi doluluk göstergesi (worker_in = dolu slot, worker_out = boş slot).
## Oyuncu binaya yaklaşınca görünür; uzaklaşınca fade out.

const WORKER_IN_ICON: Texture2D = preload("res://assets/Icons/worker_in_icon.png")
const WORKER_OUT_ICON: Texture2D = preload("res://assets/Icons/worker_out_icon.png")

const SLOT_ICON_SIZE := 16.0
# worker_in/out_icon.png kaynak dosyalarında siluetin etrafında ~%28 saydam boşluk var (25x25
# tuval içinde ~11px genişliğinde figür) — bu yüzden GAP negatif: kutular üst üste biniyor ama
# görünen siluetler arasında yaklaşık 3px'lik doğal, sıkı bir boşluk kalıyor.
const SLOT_GAP := -6.0
const Y_OFFSET := -118.0
const FADE_NEAR := 130.0
const FADE_FAR := 300.0

var _building: Node = null
var _slot_icons: Array[TextureRect] = []


## Dışarıdan (VillagePlotInteractSpot'un işçi ekle/çıkar ipuçları) slot sırasının tam
## uzunluğunu bilmek için — max_workers'ı burada tekrar hesaplamak yerine tek doğruluk
## kaynağına (bu node'un kendi slot listesine) başvurulsun diye.
func get_slot_count() -> int:
	return _slot_icons.size()


func setup(building: Node) -> void:
	_building = building
	position = Vector2(0, Y_OFFSET)
	z_index = 20
	set_process(true)
	_rebuild_slot_icons()
	if is_instance_valid(VillageManager) and VillageManager.has_signal("building_state_changed"):
		if not VillageManager.building_state_changed.is_connected(_on_building_state_changed):
			VillageManager.building_state_changed.connect(_on_building_state_changed)
	if is_instance_valid(VillageManager) and VillageManager.has_signal("village_data_changed"):
		if not VillageManager.village_data_changed.is_connected(_on_village_data_changed):
			VillageManager.village_data_changed.connect(_on_village_data_changed)
	refresh()


func _process(_delta: float) -> void:
	_update_proximity_alpha()


func _update_proximity_alpha() -> void:
	if not is_instance_valid(_building):
		modulate.a = 0.0
		visible = false
		return
	var max_w := int(_building.max_workers) if "max_workers" in _building else 0
	if max_w <= 0:
		modulate.a = 0.0
		visible = false
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		modulate.a = 1.0
		visible = true
		return
	var dist := player.global_position.distance_to(_building.global_position)
	var alpha := 1.0
	if dist > FADE_NEAR:
		alpha = 1.0 - clampf((dist - FADE_NEAR) / maxf(FADE_FAR - FADE_NEAR, 1.0), 0.0, 1.0)
	modulate.a = alpha
	visible = alpha > 0.03


func _on_building_state_changed(changed_building: Node) -> void:
	if changed_building == _building:
		refresh()


func _on_village_data_changed() -> void:
	refresh()


func refresh() -> void:
	if not is_instance_valid(_building):
		visible = false
		return
	if not _building.has_method("add_worker"):
		visible = false
		return
	var max_w := int(_building.max_workers) if "max_workers" in _building else 0
	var assigned := int(_building.assigned_workers) if "assigned_workers" in _building else 0
	if max_w <= 0:
		visible = false
		return
	if _slot_icons.size() != max_w:
		_rebuild_slot_icons()
	for i in max_w:
		if i >= _slot_icons.size():
			break
		var icon: TextureRect = _slot_icons[i]
		icon.texture = WORKER_IN_ICON if i < assigned else WORKER_OUT_ICON
	_update_proximity_alpha()


func _rebuild_slot_icons() -> void:
	for icon in _slot_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	_slot_icons.clear()
	if not is_instance_valid(_building):
		return
	var max_w := int(_building.max_workers) if "max_workers" in _building else 0
	if max_w <= 0:
		return
	var total_w := float(max_w) * (SLOT_ICON_SIZE + SLOT_GAP) - SLOT_GAP
	var start_x := -total_w * 0.5
	for i in max_w:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(SLOT_ICON_SIZE, SLOT_ICON_SIZE)
		icon.size = icon.custom_minimum_size
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(start_x + float(i) * (SLOT_ICON_SIZE + SLOT_GAP), -SLOT_ICON_SIZE * 0.5)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		_slot_icons.append(icon)
