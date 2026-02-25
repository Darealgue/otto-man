# gok_gurultusu.gd
# UNCOMMON - Heavy attack şimşek indirir

extends ItemEffect

const COOLDOWN_DURATION := 8.0
const LIGHTNING_RADIUS := 100.0
const LIGHTNING_DAMAGE := 6.0
const LightningFlashScript = preload("res://effects/lightning_flash.gd")

var _player: CharacterBody2D = null
var _cooldown := 0.0

func _init():
	item_id = "gok_gurultusu"
	item_name = "Gök Gürültüsü"
	description = "Heavy attack şimşek indirir (8 sn cooldown)"
	flavor_text = "Gök gürültüsü"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_lightning"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_cooldown = 0.0
	print("[Gök Gürültüsü] ✅ Heavy attack şimşek (8 sn cooldown)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Gök Gürültüsü] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta

func _on_heavy_attack_impact(_attack_name: String = "") -> void:
	if not _player or not is_instance_valid(_player) or _cooldown > 0:
		return
	_cooldown = COOLDOWN_DURATION
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var pos: Vector2 = _player.global_position + Vector2(_player.facing_direction * 40, 0)
	var hitbox = _player.get_node_or_null("Hitbox")
	if hitbox:
		var cs = hitbox.get_node_or_null("CollisionShape2D")
		if cs:
			pos = hitbox.to_global(cs.position)
	var flash = Node2D.new()
	flash.set_script(LightningFlashScript)
	tree.current_scene.add_child(flash)
	flash.global_position = pos
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if pos.distance_to(node.global_position) <= LIGHTNING_RADIUS and node.has_method("take_damage"):
			node.take_damage(LIGHTNING_DAMAGE, 0.0, 0.0, true)
