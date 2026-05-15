class_name ParchmentFrame
extends Control
## NinePatch parşömen + içerik. Büyük menü / küçük balon için texture + margin export.

@export var parchment_texture: Texture2D
@export_range(0, 128) var patch_margin: int = 28
## -1 = patch_margin kullan. İnce HUD çubukları için üst/alt küçük tut.
@export_range(-1, 128) var patch_margin_left: int = -1
@export_range(-1, 128) var patch_margin_top: int = -1
@export_range(-1, 128) var patch_margin_right: int = -1
@export_range(-1, 128) var patch_margin_bottom: int = -1
@export_range(0, 128) var content_margin: int = 36
## Açıkken konsola ölçü yazar + yeşil/kırmızı overlay (tutorial balonda F9).
@export var debug_layout: bool = false:
	set(value):
		debug_layout = value
		queue_redraw()
		if debug_layout:
			call_deferred("_log_layout")

@onready var _patch: NinePatchRect = $NinePatch
@onready var _margin: MarginContainer = $Margin

var _last_logged_size := Vector2(-1, -1)


func _ready() -> void:
	_apply_style()
	if debug_layout:
		call_deferred("_log_layout")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and debug_layout:
		var sz := size
		if sz.distance_to(_last_logged_size) > 0.5:
			_log_layout()


func apply_style_now() -> void:
	if not _patch:
		_patch = get_node_or_null("NinePatch") as NinePatchRect
	if not _margin:
		_margin = get_node_or_null("Margin") as MarginContainer
	_apply_style()


func get_patch_margins() -> Vector4i:
	var m := patch_margin
	var l := patch_margin_left if patch_margin_left >= 0 else m
	var t := patch_margin_top if patch_margin_top >= 0 else m
	var r := patch_margin_right if patch_margin_right >= 0 else m
	var b := patch_margin_bottom if patch_margin_bottom >= 0 else m
	return Vector4i(l, t, r, b)


func _apply_style() -> void:
	if _patch:
		_patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if parchment_texture:
			_patch.texture = parchment_texture
		var pm := get_patch_margins()
		_patch.patch_margin_left = pm.x
		_patch.patch_margin_top = pm.y
		_patch.patch_margin_right = pm.z
		_patch.patch_margin_bottom = pm.w
	if _margin:
		var c := content_margin
		_margin.add_theme_constant_override("margin_left", c)
		_margin.add_theme_constant_override("margin_top", c)
		_margin.add_theme_constant_override("margin_right", c)
		_margin.add_theme_constant_override("margin_bottom", c)
	if debug_layout:
		queue_redraw()


func get_content_slot() -> MarginContainer:
	if _margin:
		return _margin
	return get_node_or_null("Margin") as MarginContainer


const _SCENE := preload("res://ui/parchment/parchment_frame.tscn")


## PanelContainer'ın tek çocuğunu parşömen içine alır (Godot panelde yalnızca 1 çocuk olmalı).
static func wrap_panel_container(
	panel: PanelContainer,
	patch_margin: int = 40,
	content_margin: int = -1
) -> ParchmentFrame:
	if panel.get_child_count() == 0:
		push_warning("ParchmentFrame.wrap_panel_container: '%s' has no children" % panel.name)
		return null
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var content: Control = panel.get_child(0) as Control
	var content_h_flags := content.size_flags_horizontal
	var content_v_flags := content.size_flags_vertical
	panel.remove_child(content)
	var pf: ParchmentFrame = _SCENE.instantiate() as ParchmentFrame
	pf.patch_margin = patch_margin
	if content_margin >= 0:
		pf.content_margin = content_margin
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(pf)
	pf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pf.apply_style_now()
	var slot := pf.get_content_slot()
	if slot == null:
		push_error("ParchmentFrame.wrap_panel_container: Margin slot missing on '%s'" % pf.name)
		panel.remove_child(pf)
		panel.add_child(content)
		return null
	slot.add_child(content)
	content.size_flags_horizontal = content_h_flags
	content.size_flags_vertical = content_v_flags
	return pf


## Eski API — wrap_panel_container ile aynı.
static func apply_panel_backing(panel: PanelContainer, patch_margin: int = 40) -> ParchmentFrame:
	return wrap_panel_container(panel, patch_margin, 0)


func _log_layout() -> void:
	_last_logged_size = size
	var pm := get_patch_margins()
	var pl := pm.x
	var pt := pm.y
	var pr := pm.z
	var pb := pm.w
	if _patch:
		pl = _patch.patch_margin_left
		pt = _patch.patch_margin_top
		pr = _patch.patch_margin_right
		pb = _patch.patch_margin_bottom
	var center_w := size.x - float(pl + pr)
	var center_h := size.y - float(pt + pb)
	var tex_name := "?"
	if parchment_texture:
		tex_name = parchment_texture.resource_path.get_file()
	elif _patch and _patch.texture:
		tex_name = _patch.texture.resource_path.get_file()
	var grect := get_global_rect()
	var lines: PackedStringArray = PackedStringArray([
		"========== ParchmentFrame DEBUG ==========",
		"node: %s" % name,
		"path: %s" % get_path(),
		"texture: %s" % tex_name,
		"control size: %.0f x %.0f" % [size.x, size.y],
		"global rect: pos %.0f,%.0f  size %.0f x %.0f" % [grect.position.x, grect.position.y, grect.size.x, grect.size.y],
		"patch margin (L,T,R,B): %d, %d, %d, %d" % [pl, pt, pr, pb],
		"ninepatch STRETCH center: %.0f x %.0f px" % [center_w, center_h],
		"content margin: %d" % content_margin,
	])
	if center_w < 48.0 or center_h < 32.0:
		lines.append("UYARI: Orta alan çok küçük → kenarlar ezilir / bozulur görünür.")
	if size.x < float(pl + pr + 8) or size.y < float(pt + pb + 8):
		lines.append("UYARI: Panel, patch margin'den küçük → NinePatch bozulur.")
	var tex_sz := Vector2.ZERO
	var tex: Texture2D = parchment_texture if parchment_texture else (_patch.texture if _patch else null)
	if tex:
		tex_sz = Vector2(tex.get_width(), tex.get_height())
	if tex_sz != Vector2.ZERO:
		lines.append("texture kaynak boyutu: %.0f x %.0f" % [tex_sz.x, tex_sz.y])
		var src_center_w := tex_sz.x - float(pl + pr)
		var src_center_h := tex_sz.y - float(pt + pb)
		if src_center_w > 1.0:
			var stretch_x := center_w / src_center_w
			lines.append("yatay esneme: %.2fx (ideal < 2.5)" % stretch_x)
			if stretch_x > 2.5:
				lines.append("UYARI: Cok genis — daralt veya buyuk texture kullan.")
		if src_center_h > 1.0:
			var stretch_y := center_h / src_center_h
			lines.append("dikey esneme: %.2fx (ideal ~1.0, <%1 sikisir)" % stretch_y)
			if stretch_y < 0.85:
				lines.append("UYARI: Dikey sikisma — ince HUD icin menu_ninepatchrect_hud_bar.png (512x56) kullan.")
			if stretch_y > 1.35:
				lines.append("UYARI: Dikey gerilme — daha kisa texture veya panel yuksekligini azalt.")
	lines.append("==========================================")
	print("\n".join(lines))


func _draw() -> void:
	if not debug_layout:
		return
	var pm := get_patch_margins()
	var pl := pm.x
	var pt := pm.y
	var pr := pm.z
	var pb := pm.w
	if _patch:
		pl = _patch.patch_margin_left
		pt = _patch.patch_margin_top
		pr = _patch.patch_margin_right
		pb = _patch.patch_margin_bottom
	var w := size.x
	var h := size.y
	# Kenar şeritleri (kırmızı) — sabit piksel, uzamaz
	draw_rect(Rect2(0, 0, pl, h), Color(1, 0.2, 0.2, 0.35))
	draw_rect(Rect2(w - pr, 0, pr, h), Color(1, 0.2, 0.2, 0.35))
	draw_rect(Rect2(0, 0, w, pt), Color(1, 0.2, 0.2, 0.35))
	draw_rect(Rect2(0, h - pb, w, pb), Color(1, 0.2, 0.2, 0.35))
	# Orta (yeşil) — burası esner
	var cx := pl
	var cy := pt
	var cw := maxf(0.0, w - pl - pr)
	var ch := maxf(0.0, h - pt - pb)
	draw_rect(Rect2(cx, cy, cw, ch), Color(0.2, 1, 0.3, 0.25))
	# İçerik alanı (mavi)
	var cl := float(content_margin)
	draw_rect(
		Rect2(cl, cl, maxf(0.0, w - cl * 2.0), maxf(0.0, h - cl * 2.0)),
		Color(0.2, 0.5, 1, 0.2)
	)
