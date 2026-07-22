class_name NpcAmbientBubble
extends RefCounted
## Köylü kafasında kısa ambient konuşma balonu (kod ile oluşturulur).
## Sahne ışığından (gece CanvasModulate) etkilenmesin ve karakter flip olduğunda metin ters
## dönmesin diye ekran-uzayı bir CanvasLayer'da, kamera zoom/pan'ini takip ederek çizilir
## (bkz. Worker.gd + OverheadUiTracker'daki nameplate/interact button aynı fikri kullanıyor,
## ama burada üst üste binmeyi önleyen bir yığın ve dinamik kuyruk gerektiği için kendi
## takip mantığımızı yazıyoruz).
##
## Aynı anda görünen balonlar (WhatsApp mesajları gibi) üst üste binmesin diye ortak bir
## yığında (_active) tutulur: en yeni balon köylünün hemen üstünde durur, öncekiler otomatik
## olarak yukarı kayar. Her balonun altındaki üçgen kuyruk, balon ile konuşanın kafası
## arasında HER KAREDE yeniden hesaplanır — balon yığından dolayı yukarı kaysa da, köylü
## yürüyerek uzaklaşsa da kuyruk her zaman konuşanı gösterecek şekilde şeklini değiştirir.

const BUBBLE_NAME := "AmbientSpeechBubble"

const _CANVAS_LAYER_NAME := "AmbientBubbleCanvas"
const _CANVAS_LAYER_INDEX := 56  # OverheadUiTracker'ın paylaşılan katmanının (55) hemen üstü

const _PANEL_WIDTH := 144.0
const _TAIL_WIDTH := 16.0
const _RANK_GAP := 10.0
const _BASE_OFFSET := Vector2(0.0, -130.0)        # en yeni (rank 0) balonun merkezi
const _HEAD_ANCHOR_OFFSET := Vector2(0.0, -68.0)  # kuyruğun ucunun hedeflediği "baş" noktası
const _SLIDE_LERP_SPEED := 8.0                    # eski balonların yukarı kayma hızı

const _PANEL_BG_COLOR := Color(0.0, 0.0, 0.0, 0.9)
const _PANEL_BORDER_COLOR := Color(0.4, 0.38, 0.34, 1.0)

## Aynı anda en fazla bu kadar balon görünsün (WhatsApp gibi: 2. balon gelince 1. hâlâ
## okunabilsin, ancak 3. balon gelince en eskisi hemen silinsin).
const _MAX_VISIBLE := 2
## Yeni balon gelmese bile (konuşmanın son satırı gibi) balonun sonsuza kadar ekranda
## kalmaması için güvenlik süresi — normalde balonlar sayı limitiyle (yukarıdaki) kalkar.
const _FALLBACK_LIFETIME := 7.0

static var _active: Array = []  # _BubbleTracker dizisi, eskiden yeniye sıralı


static func show_on_npc(npc: Node2D, text: String, duration: float = 3.5) -> void:
	if not is_instance_valid(npc) or text.strip_edges().is_empty():
		return
	clear_on_npc(npc)
	var tree := npc.get_tree()
	if tree == null:
		return
	var tracker := _BubbleTracker.new()
	tracker.setup(npc, text)
	_active.push_back(tracker)
	_evict_overflow()
	_reflow()
	var wait_time := maxf(duration, _FALLBACK_LIFETIME)
	var timer := tree.create_timer(wait_time)
	timer.timeout.connect(func() -> void:
		_fade_and_remove(tracker)
	)


## _MAX_VISIBLE'ı aşan en eski (henüz solmaya başlamamış) balonları hemen soldurmaya başlar
## — "3. balon gelince 1. silinsin" isteği için.
static func _evict_overflow() -> void:
	var visible: Array = []
	for tracker in _active:
		if is_instance_valid(tracker) and not tracker.is_fading:
			visible.append(tracker)
	while visible.size() > _MAX_VISIBLE:
		_fade_and_remove(visible.pop_front())


static func clear_on_npc(npc: Node2D) -> void:
	if not is_instance_valid(npc):
		return
	var remaining: Array = []
	for tracker in _active:
		if is_instance_valid(tracker) and tracker.npc == npc:
			tracker.queue_free()
		else:
			remaining.append(tracker)
	_active = remaining
	_reflow()


static func has_active_bubble(npc: Node) -> bool:
	for tracker in _active:
		if is_instance_valid(tracker) and tracker.npc == npc:
			return true
	return false


## Balon _active listesinden HEMEN çıkmaz (has_active_bubble / clear_on_npc onu solma
## sırasında da tanısın diye) — sadece is_fading işaretlenir ve _reflow bunu sayıp
## diğerlerinin yerini hemen boşaltır; gerçek çıkarma solma tween'i bitince olur.
static func _fade_and_remove(tracker) -> void:
	if not is_instance_valid(tracker) or tracker.is_fading:
		return
	tracker.is_fading = true
	_reflow()
	if not is_instance_valid(tracker.panel):
		_active.erase(tracker)
		tracker.queue_free()
		return
	var fade_tween: Tween = tracker.panel.create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(tracker.panel, "modulate:a", 0.0, 0.35)
	if is_instance_valid(tracker.tail):
		fade_tween.tween_property(tracker.tail, "modulate:a", 0.0, 0.35)
	fade_tween.set_parallel(false)
	fade_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(tracker):
			_active.erase(tracker)
			tracker.queue_free()
	)


## En yeni balon (dizinin sonu) rank 0 olur; her eski balon, altındaki (solmayan) balonların
## gerçek yüksekliği + boşluk kadar yukarı itilir (WhatsApp'ta yeni mesaj gelince eskilerin
## kayması gibi). Solmakta olan balonlar yer kaplamaz ki diğerleri hemen aşağı insin.
static func _reflow() -> void:
	var cumulative_y := 0.0
	for i in range(_active.size() - 1, -1, -1):
		var tracker = _active[i]
		if not is_instance_valid(tracker) or tracker.is_fading:
			continue
		tracker.set_target_offset_y(_BASE_OFFSET.y - cumulative_y)
		cumulative_y += tracker.get_panel_height() + _RANK_GAP


static func _resolve_canvas_layer() -> CanvasLayer:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	var root := (loop as SceneTree).root
	var existing := root.get_node_or_null(_CANVAS_LAYER_NAME) as CanvasLayer
	if is_instance_valid(existing):
		return existing
	var layer := CanvasLayer.new()
	layer.name = _CANVAS_LAYER_NAME
	layer.layer = _CANVAS_LAYER_INDEX
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	return layer


static func _build_panel(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = BUBBLE_NAME
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(_PANEL_WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	# Diğer menülerde kullanılan düz siyah kutu (bkz. DungeonRunReport.gd) — parşömen çerçevesi yok.
	style.bg_color = _PANEL_BG_COLOR
	style.border_color = _PANEL_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(_PANEL_WIDTH - 16.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	NpcOverheadUi.apply_nameplate_text_style(label)
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)
	panel.reset_size()
	return panel


## Bir balonu kendi köylüsüne ekran-uzayında bağlar (kamera zoom/pan dahil), yığın sırasına
## göre hedeflenen dikey ofsete yumuşakça kayar ve altındaki kuyruğu her karede köylünün
## güncel kafa konumuna göre yeniden çizer.
class _BubbleTracker extends Node:
	var npc: Node2D
	var panel: PanelContainer
	var tail: NpcAmbientBubble._SpeechTail
	var target_offset_y: float = NpcAmbientBubble._BASE_OFFSET.y
	var _current_offset_y: float = NpcAmbientBubble._BASE_OFFSET.y
	var _offset_initialized := false
	var is_fading := false


	func setup(p_npc: Node2D, text: String) -> void:
		npc = p_npc
		panel = NpcAmbientBubble._build_panel(text)
		tail = NpcAmbientBubble._SpeechTail.new()
		tail.fill_color = NpcAmbientBubble._PANEL_BG_COLOR
		tail.edge_color = NpcAmbientBubble._PANEL_BORDER_COLOR
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
		npc.add_child(self)
		npc.add_child(tail)
		npc.add_child(panel)
		tree_exiting.connect(_cleanup_controls)
		call_deferred("_move_to_shared_layer")


	func get_panel_height() -> float:
		return panel.size.y if is_instance_valid(panel) else 0.0


	func set_target_offset_y(y: float) -> void:
		target_offset_y = y


	func _cleanup_controls() -> void:
		if is_instance_valid(tail):
			tail.queue_free()
		if is_instance_valid(panel):
			panel.queue_free()


	func _move_to_shared_layer() -> void:
		var layer := NpcAmbientBubble._resolve_canvas_layer()
		if layer == null:
			return
		if is_instance_valid(tail):
			tail.reparent(layer, false)
		if is_instance_valid(panel):
			panel.reparent(layer, false)


	func _process(delta: float) -> void:
		if not is_instance_valid(npc) or not is_instance_valid(panel) or not is_instance_valid(tail):
			queue_free()
			return
		var vp := get_viewport()
		if vp == null:
			return
		var cam := vp.get_camera_2d()
		if cam == null:
			return
		if _offset_initialized:
			_current_offset_y = lerpf(_current_offset_y, target_offset_y, clampf(delta * NpcAmbientBubble._SLIDE_LERP_SPEED, 0.0, 1.0))
		else:
			_current_offset_y = target_offset_y
			_offset_initialized = true

		var center: Vector2 = cam.get_screen_center_position()
		var vp_size: Vector2 = vp.get_visible_rect().size

		var head_world: Vector2 = npc.global_position + NpcAmbientBubble._HEAD_ANCHOR_OFFSET
		var head_screen: Vector2 = (head_world - center) * cam.zoom + vp_size * 0.5

		var panel_world: Vector2 = npc.global_position + Vector2(NpcAmbientBubble._BASE_OFFSET.x, _current_offset_y)
		var panel_screen: Vector2 = (panel_world - center) * cam.zoom + vp_size * 0.5

		panel.pivot_offset = panel.size * 0.5
		panel.scale = cam.zoom
		panel.position = panel_screen - panel.size * 0.5

		_update_tail(panel_screen, cam.zoom, head_screen)


	func _update_tail(panel_screen: Vector2, zoom: Vector2, head_screen: Vector2) -> void:
		var half_w: float = (NpcAmbientBubble._TAIL_WIDTH * 0.5) * zoom.x
		var bottom_y: float = panel_screen.y + panel.size.y * 0.5 * zoom.y
		var bottom_left := Vector2(panel_screen.x - half_w, bottom_y)
		var bottom_right := Vector2(panel_screen.x + half_w, bottom_y)

		var min_pt := Vector2(
			minf(minf(bottom_left.x, bottom_right.x), head_screen.x),
			minf(minf(bottom_left.y, bottom_right.y), head_screen.y)
		)
		var max_pt := Vector2(
			maxf(maxf(bottom_left.x, bottom_right.x), head_screen.x),
			maxf(maxf(bottom_left.y, bottom_right.y), head_screen.y)
		)

		tail.position = min_pt
		tail.size = max_pt - min_pt
		tail.points = PackedVector2Array([
			bottom_left - min_pt,
			bottom_right - min_pt,
			head_screen - min_pt,
		])
		tail.queue_redraw()


## Konuşan köylüyü işaret eden üçgen kuyruk — noktaları dışarıdan (her karede) veriliyor.
class _SpeechTail extends Control:
	var fill_color: Color = Color.BLACK
	var edge_color: Color = Color.WHITE
	var points: PackedVector2Array = PackedVector2Array()

	func _draw() -> void:
		if points.size() < 3:
			return
		draw_colored_polygon(points, fill_color)
		draw_line(points[0], points[2], edge_color, 2.0)
		draw_line(points[1], points[2], edge_color, 2.0)
