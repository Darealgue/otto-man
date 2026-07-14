# RARE - Light attack yapıldığında ileri doğru projectile fırlatır (ilk düşmana hasar)
extends ItemEffect

const LightAttackProjectileScript = preload("res://effects/light_attack_projectile.gd")

var _player: CharacterBody2D = null

func _init():
	item_id = "uzun_menzil"
	item_name = "Uzun Menzil"
	description = "Light attack ayrıca ileri projectile fırlatır"
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
	var proj = Node2D.new()
	proj.set_script(LightAttackProjectileScript)
	tree.current_scene.add_child(proj)
	# Spawn: gelen position zaten oyuncuya yakın; hafif ek offset ile çıkış
	var spawn_offset := direction * 10.0
	proj.setup(position + spawn_offset, direction, damage * 0.7)
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
