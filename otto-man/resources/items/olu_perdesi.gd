# olu_perdesi.gd
# UNCOMMON - Gölge Hasadı'nın doğurduğu her gölge, ölen düşmanın yerinde zehirli bir bulut da
# bırakır (Leş Gazı / Element İzi'nin zehir bulutuyla aynı efekt). Ön koşul: Gölge Hasadı.

extends ItemEffect

const _PoisonCloudScript = preload("res://effects/poison_cloud.gd")

func _init():
	item_id = "olu_perdesi"
	item_name = tr("item.olu_perdesi.name")
	description = tr("item.olu_perdesi.description")
	flavor_text = "Ölünün gölgesi nefes de zehirler"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["harvest_cloud"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Ölü Perdesi] ✅ Hasat gölgesi zehir bulutu bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Ölü Perdesi] ❌ Kaldırıldı")

# golge_hasadi.gd -> ItemManager.notify_item_event
func _on_harvest_shadow_spawned(pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var cloud := Node2D.new()
	cloud.set_script(_PoisonCloudScript)
	tree.current_scene.add_child(cloud)
	cloud.global_position = pos
