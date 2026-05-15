class_name TextOutline
extends RefCounted
## Beyaz/açık menü yazılarına siyah kontür (parşömen üstünde okunurluk).

const COLOR := Color(0, 0, 0, 1)
const SIZE_LABEL := 3
const SIZE_BUTTON := 2
const SIZE_RICH := 3


static func apply_to_tree(root: Node, label_size: int = SIZE_LABEL) -> void:
	if root == null:
		return
	_apply_control(root, label_size)
	for child in root.get_children():
		apply_to_tree(child, label_size)


static func _apply_control(node: Node, label_size: int) -> void:
	if node is RichTextLabel:
		var rtl := node as RichTextLabel
		rtl.add_theme_color_override("font_outline_color", COLOR)
		rtl.add_theme_constant_override("outline_size", SIZE_RICH)
	elif node is Label:
		var lbl := node as Label
		lbl.add_theme_color_override("font_outline_color", COLOR)
		lbl.add_theme_constant_override("outline_size", label_size)
	elif node is Button:
		var btn := node as Button
		btn.add_theme_color_override("font_outline_color", COLOR)
		btn.add_theme_constant_override("outline_size", SIZE_BUTTON)
	elif node is ItemList:
		var list := node as ItemList
		list.add_theme_color_override("font_outline_color", COLOR)
		list.add_theme_constant_override("outline_size", SIZE_BUTTON)
