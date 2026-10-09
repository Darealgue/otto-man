# ac_gozlu_toksin.gd
# RARE - Normal saldırıların hedefteki her zehir katmanı için ek hasar verir. Zehir sadece DoT
# olmaktan çıkar, anlık hasarın önkoşulu olur. Gölge vuruşları da (oyuncu vuruşu sayıldığı için) çalışır.

extends ItemEffect

const BONUS_DAMAGE_PER_STACK := 1.5

func _init():
	item_id = "ac_gozlu_toksin"
	item_name = tr("item.ac_gozlu_toksin.name")
	description = tr("item.ac_gozlu_toksin.description")
	flavor_text = "Zehir doyurur"
	rarity = ItemRarity.RARE
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["poison_bonus_damage"]

func _on_player_attack_landed(attack_type: String, _damage: float, targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	# Light saldırı ve onun mermi hali (Uzun Menzil)
	if attack_type != "normal" and attack_type != "ranged":
		return
	var im := get_node_or_null("/root/ItemManager")
	for target in targets:
		var enemy := resolve_enemy_target(target)
		if enemy == null or enemy.get("poison_stacks") == null:
			continue
		var stacks: int = int(enemy.poison_stacks)
		if stacks <= 0:
			continue
		enemy.take_damage(float(stacks) * BONUS_DAMAGE_PER_STACK, 0.0, 0.0, true)
		if im:
			im.spawn_element_hit_flash(enemy, "poison")
