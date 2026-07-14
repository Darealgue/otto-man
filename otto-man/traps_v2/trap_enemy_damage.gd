# trap_enemy_damage.gd
# Tuzak Fısıldayan itemi aktifken zindan tuzaklarının düşmanlara da hasar vermesini sağlayan
# ortak yardımcı. Fiziksel collision mask'lere dokunmamak için grup+mesafe taraması kullanır
# (tuzakların hepsi zaten "enemies" grubunu ve global_position mesafesini bu şekilde kontrol eder).
class_name TrapEnemyDamage

static func is_active() -> bool:
	var tree := Engine.get_main_loop()
	if not tree or not (tree is SceneTree):
		return false
	var im = (tree as SceneTree).root.get_node_or_null("ItemManager")
	return im != null and im.has_method("has_active_item") and im.has_active_item("tuzak_fisildayan")

## status: "" | "burn" | "poison" | "frost"
static func damage_enemies_in_radius(tree: SceneTree, pos: Vector2, radius: float, damage: float, status: String = "") -> void:
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if pos.distance_to(node.global_position) > radius:
			continue
		if damage > 0.0 and node.has_method("take_damage"):
			node.take_damage(damage, 0.0, 0.0, false)
		match status:
			"burn":
				if node.has_method("add_burn_stack"):
					node.add_burn_stack()
			"poison":
				if node.has_method("add_poison_stack"):
					node.add_poison_stack(5, 2.0, 1.0)
			"frost":
				if node.has_method("add_frost_stack"):
					node.add_frost_stack(1)
