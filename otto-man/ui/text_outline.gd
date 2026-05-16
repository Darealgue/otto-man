class_name TextOutline
extends RefCounted
## Parşömen menüler: varsayılan koyu metin; durum renkleri siyah kontürlü.

const FONT_COLOR := Color(0.1, 0.08, 0.06, 1)
const FONT_COLOR_MUTED := Color(0.32, 0.28, 0.24, 1)
const OUTLINE_COLOR := Color(0, 0, 0, 1)
const OUTLINE_SIZE_LABEL := 3
const OUTLINE_SIZE_RICH := 3


static func font_color_with_alpha(alpha: float) -> Color:
	return Color(FONT_COLOR.r, FONT_COLOR.g, FONT_COLOR.b, alpha)


## Durum rengi (yeşil/sarı/kırmızı vb.) — parşömen üstünde okunması için siyah kontür.
static func apply_label_color(label: Label, color: Color) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE_LABEL)


## Varsayılan koyu metne dön (kontürsüz).
static func reset_label_color(label: Label) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", FONT_COLOR)
	if label.has_theme_color_override("font_outline_color"):
		label.remove_theme_color_override("font_outline_color")
	label.add_theme_constant_override("outline_size", 0)


static func apply_to_tree(root: Node) -> void:
	if root == null:
		return
	_apply_control(root)
	for child in root.get_children():
		apply_to_tree(child)


static func _is_gameplay_floating_text(label: Label) -> bool:
	var n: Node = label
	while n != null:
		match String(n.name):
			"GoldPickupPopup", "DamageNumber", "DamageRecoveryPickup":
				return true
		n = n.get_parent()
	return false


static func _apply_control(node: Node) -> void:
	if node is RichTextLabel:
		var rtl := node as RichTextLabel
		rtl.add_theme_color_override("default_color", FONT_COLOR)
		rtl.add_theme_constant_override("outline_size", 0)
	elif node is Label:
		var lbl := node as Label
		if lbl.label_settings != null:
			return
		if _is_gameplay_floating_text(lbl):
			return
		lbl.add_theme_color_override("font_color", FONT_COLOR)
		lbl.add_theme_constant_override("outline_size", 0)
	elif node is ItemList:
		var list := node as ItemList
		list.add_theme_color_override("font_color", FONT_COLOR)
		list.add_theme_constant_override("outline_size", 0)
