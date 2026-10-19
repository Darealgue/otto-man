extends Node

# Ev ve dükkân gibi dikdörtgen binaların arkasına otomatik olarak BuildingDepthSlab (kalınlık katmanı) ekler.
# Kaynak binaları, kışla, depo gibi şekli düzgün olmayan yapılar listede olmadığı için etkilenmez.

const SLAB_SCRIPT = preload("res://village/scripts/BuildingDepthSlab.gd")

# Kalınlık verilecek bina sahneleri (dosya adıyla). Yeni dükkân eklemek için buraya yaz.
const ALLOWED_SCENES: Array[String] = [
	"House.tscn", "Bakery.tscn", "Blacksmith.tscn", "Gunsmith.tscn",
	"Herbalist.tscn", "Tailor.tscn", "TeaHouse.tscn", "Weaver.tscn", "SoapMaker.tscn",
]

const VISIT_EXTENSION_NODE: String = "ResidentialHousingExtension"

# Katmanın z değeri: bina sprite'larının (z 0) arkasında, ama sahnenin zemin resminin üstünde olmalı.
var slab_z_index: int = -2

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for group_name in ["Housing", "WorkBuildings", "visit_house", "visit_building"]:
		for n in get_tree().get_nodes_in_group(group_name):
			_try_attach(n)

func _on_node_added(node: Node) -> void:
	if node is Node2D and _is_allowed(node):
		_try_attach.call_deferred(node)

# Oyuncu köyünde: izin listesindeki bina sahneleri. Ziyaret köyünde: betiksiz ev kökleri ("visit_house" grubu,
# üstüne ev katı için eklenen extension düğümü hariç) ve yine listedeki dükkân sahneleri.
func _is_allowed(node: Node) -> bool:
	if node.scene_file_path != "" and ALLOWED_SCENES.has(node.scene_file_path.get_file()):
		return true
	return node.is_in_group("visit_house") and node.name != VISIT_EXTENSION_NODE

func _try_attach(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or not (node is Node2D):
		return
	if not _is_allowed(node) or node.get_node_or_null("DepthSlab") != null:
		return
	# Dükkanın üstüne eklenen ev (extension) dükkanın katmanına dahil olur, ayrıca katman almaz.
	var p: Node = node.get_parent()
	while p != null:
		if p is Node2D and _is_allowed(p):
			return
		p = p.get_parent()
	var slab := Node2D.new()
	slab.set_script(SLAB_SCRIPT)
	slab.set("z_override", slab_z_index)
	node.add_child(slab)
