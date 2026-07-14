# UNCOMMON - Dodge, sende aktif olan elementin zemin izini bırakır (Ateşli/Buzlu Kayma deseniyle, dodge'a bağlı)
extends ItemEffect

const FirePatchScene = preload("res://effects/ground_fire_patch.tscn")
const IcePatchScene = preload("res://effects/ground_ice_patch.tscn")
const PoisonCloudScript = preload("res://effects/poison_cloud.gd")

var _player: CharacterBody2D = null

func _init():
	item_id = "element_izi"
	item_name = "Element İzi"
	description = "Dodge, aktif elementinin zemin izini bırakır"
	flavor_text = "Yürüdüğün yol seni hatırlar"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["dodge_element_trail"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Element İzi] ✅ Dodge element izi bırakıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Element İzi] ❌ Kaldırıldı")

func _on_player_dodged(_direction: int, start_pos: Vector2, end_pos: Vector2) -> void:
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	if im.has_active_item("atesli_yumruk"):
		var patch = FirePatchScene.instantiate()
		tree.current_scene.add_child(patch)
		patch.global_position = end_pos
	elif im.has_active_item("buzlu_kilic"):
		var patch = IcePatchScene.instantiate()
		tree.current_scene.add_child(patch)
		patch.global_position = end_pos
	elif im.has_active_item("zehirli_tirnak") or im.has_active_item("zehirli_dev"):
		var cloud = Node2D.new()
		cloud.set_script(PoisonCloudScript)
		tree.current_scene.add_child(cloud)
		cloud.global_position = end_pos
