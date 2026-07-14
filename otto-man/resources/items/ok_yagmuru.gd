# RARE - Ağır saldırı ayrıca ileri doğru bir projectile fırlatır (Uzun Menzil'in ağır karşılığı)
extends ItemEffect

const LightAttackProjectileScript = preload("res://effects/light_attack_projectile.gd")
const DAMAGE_RATIO := 0.5
const PROJECTILE_RANGE := 180.0

var _player: CharacterBody2D = null

func _init():
	item_id = "ok_yagmuru"
	item_name = "Ok Yağmuru"
	description = "Ağır saldırı ayrıca ileri projectile fırlatır"
	flavor_text = "Gökten ok yağar"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_attack_ranged"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Ok Yağmuru] ✅ Ağır saldırı projectile fırlatır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Ok Yağmuru] ❌ Kaldırıldı")

func _on_heavy_attack_impact(_attack_name: String) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tree = _player.get_tree()
	if not tree or not tree.current_scene:
		return
	var direction := Vector2(_player.facing_direction, 0.0)
	var damage: float = _player.hitbox.damage * DAMAGE_RATIO if _player.hitbox else 10.0
	var proj = Node2D.new()
	proj.set_script(LightAttackProjectileScript)
	tree.current_scene.add_child(proj)
	var spawn_pos: Vector2 = _player.global_position + Vector2(direction.x * 20.0, -22.0)
	proj.setup(spawn_pos, direction, damage)
	proj.max_distance = PROJECTILE_RANGE
	_apply_projectile_upgrades(proj)

## Yansıyan Ok / Rüzgârın Nişanı / Yankı Oku / Kartal Bakışı bu mermiyi de yükseltir.
func _apply_projectile_upgrades(proj: Node) -> void:
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	if im.has_active_item("yansiyan_ok"):
		proj.bounce_remaining = 1
	if im.has_active_item("ruzgarin_nisani"):
		var RuzgarinNisani = load("res://resources/items/ruzgarin_nisani.gd")
		proj.element = RuzgarinNisani.detect_active_element(im)
	if im.has_active_item("yanki_oku"):
		proj.echo = true
	if im.has_active_item("kartal_bakisi"):
		proj.unlimited_range = true
		proj.max_distance = PROJECTILE_RANGE  # kartal_bakisi ile de gerçek limit unlimited_range bayrağıyla aşılır
