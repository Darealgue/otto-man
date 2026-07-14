# explosion_modifiers.gd
# Barut Zırhı (patlama bağışıklığı) ve Kara Barut (yarıçap +%30, tepme hasarı) için
# tüm patlama efektlerinin başvurduğu ortak yardımcı.
class_name ExplosionModifiers

static func _item_manager() -> Node:
	var tree := Engine.get_main_loop()
	if not tree or not (tree is SceneTree):
		return null
	return (tree as SceneTree).root.get_node_or_null("ItemManager")

static func player_immune_to_explosions() -> bool:
	var im := _item_manager()
	return im != null and im.has_method("has_active_item") and im.has_active_item("barut_zirhi")

static func radius_mult() -> float:
	var im := _item_manager()
	if im and im.has_method("has_active_item") and im.has_active_item("kara_barut"):
		return 1.3
	return 1.0

## Kara Barut'un tepme hasarı: Barut Zırhı aktifse hiç uygulanmaz.
static func apply_recoil(player: Node) -> void:
	if not is_instance_valid(player):
		return
	var im := _item_manager()
	if not im or not im.has_method("has_active_item") or not im.has_active_item("kara_barut"):
		return
	if player_immune_to_explosions():
		return
	var stats := im.get_tree().root.get_node_or_null("PlayerStats")
	if stats and stats.has_method("get_max_health") and stats.has_method("set_current_health") and stats.has_method("get_current_health"):
		var cost = max(1.0, stats.get_max_health() * 0.03)
		stats.set_current_health(stats.get_current_health() - cost, false)
