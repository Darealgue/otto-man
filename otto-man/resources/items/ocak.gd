# ocak.gd
# RARE - Yanarak ölen düşman yere 3 sn kalan bir kor bırakır:
# üstünden geçen düşman yanar, oyuncu geçerse stamina kazanır.
# Alan kontrolü; Leş Gazı / ceset ekonomisiyle sinerji.

extends ItemEffect

const OcakEmbersScript = preload("res://effects/ocak_embers.gd")

func _init():
	item_id = "ocak"
	item_name = tr("item.ocak.name")
	description = tr("item.ocak.description")
	flavor_text = "Sönmeyen ocak, sıcak tutar"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	tags = ["elemental_fire"]
	affected_stats = ["on_kill_ember"]

func on_enemy_killed(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var ticks = enemy.get("burn_remaining_ticks")
	if ticks == null or int(ticks) <= 0:
		return  # Sadece yanarak ölenler kor bırakır
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var embers := Node2D.new()
	embers.set_script(OcakEmbersScript)
	tree.current_scene.add_child(embers)
	embers.global_position = enemy.global_position
