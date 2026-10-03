# geri_tepme.gd
# UNCOMMON - Bloklanan saldırının sahibi geri itilir.

extends ItemEffect

const KNOCKBACK_FORCE := 320.0
const KNOCKBACK_UP := 80.0

func _init():
	item_id = "geri_tepme"
	item_name = tr("item.geri_tepme.name")
	description = tr("item.geri_tepme.description")
	flavor_text = "Kalkanına çarpan geri döner"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.BLOCK
	affected_stats = ["block_knockback"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Geri Tepme] ✅ Bloklanan düşman geri itilir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Geri Tepme] ❌ Kaldırıldı")

func _on_player_blocked(blocked_damage: float, attacker: Node2D) -> void:
	if blocked_damage <= 0.0 or not is_instance_valid(attacker):
		return
	var target: Node = attacker
	if not target.has_method("take_damage") and target.get_parent():
		target = target.get_parent()
	if target and is_instance_valid(target) and target.has_method("take_damage") and target.is_in_group("enemies"):
		target.take_damage(0.0, KNOCKBACK_FORCE, KNOCKBACK_UP, true)
