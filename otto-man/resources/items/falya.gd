# falya.gd
# COMMON - Topun ateşleme deliği. Heavy attack "just" penceresini (60ms mükemmel zamanlama)
# tutturursa vuruşa küçük bir patlama eklenir. Zamanlamayı ıskalarsan patlama yok.
# Hızlı Charge ile sinerji (şarj hızlanır, pencere yakalamak kolaylaşır);
# Patlama Topuzu bunun büyük kardeşi.

extends ItemEffect

const EXPLOSION_DAMAGE := 12.0
const EXPLOSION_RADIUS := 90.0
const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const EXPLOSION_COLOR := Color(1.0, 0.5, 0.15, 0.85)

var _player: CharacterBody2D = null

func _init():
	item_id = "falya"
	item_name = tr("item.falya.name")
	description = tr("item.falya.description")
	flavor_text = "Doğru anda tutuşan barut"
	rarity = ItemRarity.COMMON
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_just_explosion"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Falya] ✅ Tam zamanlı heavy → küçük patlama")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Falya] ❌ Kaldırıldı")

func _on_heavy_attack_impact(_attack_name: String) -> void:
	if not is_instance_valid(_player):
		return
	if not bool(_player.get("last_heavy_just_bonus")):
		return  # Zamanlama tutmadı, patlama yok
	var tree = _player.get_tree()
	if not tree:
		return
	var facing: float = _player.get_facing_direction() if _player.has_method("get_facing_direction") else 1.0
	var origin: Vector2 = _player.global_position + Vector2(facing * 40.0, 0.0)
	var hit := 0
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if not node.has_method("take_damage"):
			continue
		if origin.distance_to(node.global_position) <= EXPLOSION_RADIUS:
			node.take_damage(EXPLOSION_DAMAGE, 0.0, 0.0, false)
			hit += 1
	if tree.current_scene:
		var burst = Node2D.new()
		burst.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(burst)
		burst.setup(origin, EXPLOSION_RADIUS, EXPLOSION_COLOR)
	if hit > 0:
		print("[Falya] 💥 Tam zamanlı patlama — %d düşman" % hit)
