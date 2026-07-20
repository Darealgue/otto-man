class_name OverheadUiTracker
extends Node
## Bir Control'ü (etkileşim göstergesi, isim plakası vb.) sahne ışığından/CanvasModulate'tan
## etkilenmesin diye paylaşılan bir CanvasLayer'a taşıyıp, sahibi olan Node2D hedefi ekran
## uzayında (kamera zoom/pan dahil) her frame takip ettirir.
##
## npc_window.gd'nin kendini bir CanvasLayer'a taşıma deseninin genellenmiş hali — oradan farkı,
## bu Control'ün SABİT durmayıp hareketli bir dünya hedefini takip etmesi gerekmesi.

const _CANVAS_LAYER_NAME := "OverheadUiCanvas"
const _CANVAS_LAYER_INDEX := 55

var _control: Control
var _target: Node2D
var _world_center_offset: Vector2


## control: dünyada bir Node2D'nin üstünde asılı duracak Control (Label/PanelContainer vb.),
## zaten target'a child olarak eklenmiş ve boyutu belli olmalı (size hesaplanabilsin diye).
## target: takip edilecek Node2D.
## world_center_offset: control'ün MERKEZİNİN target'ın local uzayında nerede duracağı
## (ör. Vector2(0, -80) = başının biraz üstü).
static func attach(control: Control, target: Node2D, world_center_offset: Vector2 = Vector2.ZERO) -> OverheadUiTracker:
	if control == null or target == null or not is_instance_valid(target):
		return null
	var tracker := OverheadUiTracker.new()
	tracker.name = "OverheadUiTracker_" + control.name
	tracker._control = control
	tracker._target = target
	tracker._world_center_offset = world_center_offset
	target.add_child(tracker)
	# Control artık kalıcı bir global CanvasLayer'da yaşıyor (tree.root'a bağlı, sahneyle birlikte
	# silinmiyor). target/tracker sahne kapanırken (queue_free veya toplu sahne değişimi) toplu
	# olarak silinirse _process() bir daha çalışamayabilir — bu yüzden tree_exiting'e bağlanıp
	# control'ü SENKRON olarak (bir sonraki frame'i beklemeden) temizliyoruz, yoksa ekranda
	# sahibi olmayan, hiçbir şeyin gizleyemediği "yapışık" bir Control kalır.
	tracker.tree_exiting.connect(tracker._cleanup_control)
	tracker.call_deferred("_move_control_to_shared_layer")
	return tracker


func _cleanup_control() -> void:
	if is_instance_valid(_control):
		_control.queue_free()


func _move_control_to_shared_layer() -> void:
	if not is_instance_valid(_control):
		return
	var layer := _resolve_canvas_layer()
	if layer == null:
		return
	_control.reparent(layer, false)


func _resolve_canvas_layer() -> CanvasLayer:
	var tree := get_tree()
	if tree == null:
		return null
	var existing := tree.root.get_node_or_null(_CANVAS_LAYER_NAME) as CanvasLayer
	if is_instance_valid(existing):
		return existing
	var layer := CanvasLayer.new()
	layer.name = _CANVAS_LAYER_NAME
	layer.layer = _CANVAS_LAYER_INDEX
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	return layer


func _process(_delta: float) -> void:
	# Hedef (NPC/bina spotu) yok olduysa Control'ü de (artık ayrı bir CanvasLayer'da, otomatik
	# silinmeyecek) temizleyip kendimizi kaldır.
	if not is_instance_valid(_target):
		if is_instance_valid(_control):
			_control.queue_free()
		queue_free()
		return
	if not is_instance_valid(_control):
		queue_free()
		return
	if not _control.visible:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_2d()
	if cam == null:
		return
	var world_pos: Vector2 = _target.global_position + _world_center_offset
	var center: Vector2 = cam.get_screen_center_position()
	var screen_pos: Vector2 = (world_pos - center) * cam.zoom + vp.get_visible_rect().size * 0.5
	# Control artık world-space değil CanvasLayer'da (screen-space), yani kamera zoom'undan
	# otomatik etkilenmiyor. Eskiden dünya uzayında göründüğü boyutu korumak için zoom'u
	# scale olarak uyguluyoruz; pivot_offset merkezde olduğundan bu satırın altındaki position
	# formülü scale'den bağımsız olarak merkezi doğru yerde tutar.
	_control.pivot_offset = _control.size * 0.5
	_control.scale = cam.zoom
	_control.position = screen_pos - _control.size * 0.5
