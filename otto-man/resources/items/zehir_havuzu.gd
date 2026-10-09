# zehir_havuzu.gd
# RARE - Zehirli düşmana yaptığın düşme saldırısı vurduğun yere zehir havuzu açar. Havuz düşmandaki
# zehir katmanı sayısıyla büyür. Kazık Darbesi (zehirli düşmanı yere çak) ile birleşir.

extends ItemEffect

const PoisonCloudScript = preload("res://effects/poison_cloud.gd")
const BASE_RADIUS := 60.0
const RADIUS_PER_STACK := 20.0
const POOL_DURATION := 5.0

func _init():
	item_id = "zehir_havuzu"
	item_name = tr("item.zehir_havuzu.name")
	description = tr("item.zehir_havuzu.description")
	flavor_text = "Düştüğü yer zehir olur"
	rarity = ItemRarity.RARE
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_poison_pool"]

func _on_player_attack_landed(attack_type: String, _damage: float, targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	if attack_type != "fall":
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	for target in targets:
		var enemy := resolve_enemy_target(target)
		if enemy == null or enemy.get("poison_stacks") == null:
			continue
		var stacks: int = int(enemy.poison_stacks)
		if stacks <= 0:
			continue
		var pool := Node2D.new()
		pool.set_script(PoisonCloudScript)
		pool.radius = BASE_RADIUS + RADIUS_PER_STACK * float(stacks)
		pool.duration = POOL_DURATION
		tree.current_scene.add_child(pool)
		pool.global_position = enemy.global_position
