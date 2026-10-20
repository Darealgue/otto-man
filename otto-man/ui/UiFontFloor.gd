class_name UiFontFloor
extends Node
## Köy popup'larında 9-16 puntoluk açık yazı boyutlarını okunur seviyeye çeker (1920x1080'de Grenze küçük görünür).
## Kullanım: popup'ın _ready'sinde `UiFontFloor.attach(self)`. Kök altına sonradan eklenen düğümler de
## (kart listeleri sık yeniden kurulur) otomatik düzeltilir. Yalnız AÇIKÇA verilmiş boyutlara dokunur;
## tema varsayılanı (20) zaten okunur. Her düğüm bir kez işlenir (meta işareti), yani tekrar çağrı güvenli.

## eski boyut -> yeni boyut. Grenze 1920x1080'de 20 puntodan aşağısında zor okunuyor; 20 ve üstü (tema varsayılanı)
## ve 20'nin üzerindeki başlıklar olduğu gibi kalır.
const STEP: Dictionary = {
	8: 17, 9: 17, 10: 18, 11: 18, 12: 19, 13: 20, 14: 21, 15: 22, 16: 23, 17: 24, 18: 24, 19: 25,
	# Başlıklar da aynı oranda büyür ki ara başlıklar ana başlığı geçmesin
	24: 28, 26: 30, 28: 34, 30: 36,
}
const _RICH_KEYS: Array[String] = ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]
const _DONE_META := "_ui_font_floor_done"

var _root: Node = null


static func attach(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child is UiFontFloor:
			return
	var floor_node := UiFontFloor.new()
	floor_node.name = "UiFontFloor"
	root.add_child(floor_node)


func _ready() -> void:
	_root = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _root == null:
		return
	_fix_tree(_root)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if _root == null or not is_instance_valid(_root) or node == self:
		return
	if _root.is_ancestor_of(node):
		# Boyut genelde düğüm ağaca girdikten hemen sonra verilir; bir kare bekleyip düzelt
		call_deferred("_fix_node", node)


func _fix_tree(node: Node) -> void:
	_fix_node(node)
	for child in node.get_children():
		_fix_tree(child)


func _fix_node(node: Node) -> void:
	if not is_instance_valid(node) or not (node is Control):
		return
	if node.has_meta(_DONE_META):
		return
	var c := node as Control
	var touched := false
	if c is RichTextLabel:
		for key in _RICH_KEYS:
			touched = _raise(c, key) or touched
	elif c is Label or c is BaseButton or c is LineEdit or c is TextEdit:
		touched = _raise(c, "font_size") or touched
	if touched:
		c.set_meta(_DONE_META, true)


func _raise(c: Control, key: String) -> bool:
	if not c.has_theme_font_size_override(key):
		return false
	var cur: int = c.get_theme_font_size(key)
	if STEP.has(cur):
		c.add_theme_font_size_override(key, int(STEP[cur]))
		return true
	return false
