# ruh_avcisi.gd
# UNCOMMON - Öldürdüğün düşmandan kısa süreli hayalet minion çıkar

extends ItemEffect

const GhostMinionScript = preload("res://effects/ghost_minion.gd")

func _init():
	item_id = "ruh_avcisi"
	item_name = "Ruh Avcısı"
	description = "Öldürdüğün düşmandan kısa süreli hayalet minion çıkar"
	flavor_text = "Ruh ordusu"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["on_kill_ghost"]

func on_enemy_killed(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var pos = enemy.global_position
	var ghost = Node2D.new()
	ghost.set_script(GhostMinionScript)
	tree.current_scene.add_child(ghost)
	ghost.global_position = pos
