# RARE - Light attack yapıldığında ileri doğru projectile fırlatır (ilk düşmana hasar)
extends ItemEffect

var _player: CharacterBody2D = null

func _init():
	item_id = "uzun_menzil"
	item_name = tr("item.uzun_menzil.name")
	description = tr("item.uzun_menzil.description")
	flavor_text = "Uzaktan da vurur"
	rarity = ItemRarity.RARE
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_ranged"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Uzun Menzil] ✅ Light attack projectile fırlatır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Uzun Menzil] ❌ Kaldırıldı")

func _on_player_light_attack_performed(direction: Vector2, position: Vector2, damage: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tree = _player.get_tree()
	if not tree or not tree.current_scene:
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	# Spawn: gelen position zaten oyuncuya yakın; hafif ek offset ile çıkış
	var spawn_offset := direction * 10.0
	im.spawn_upgraded_projectile(tree.current_scene, position + spawn_offset, direction, damage * 0.7, -1.0, "ok", true)
