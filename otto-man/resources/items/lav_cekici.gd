# lav_cekici.gd
# UNCOMMON - Heavy attack dümdüz fırlayan alev topu; düşmana çarparsa yanma (burn stack)

extends ItemEffect

const FireballScript = preload("res://effects/fireball_projectile.gd")

var _player: CharacterBody2D = null

func _init():
	item_id = "lav_cekici"
	item_name = tr("item.lav_cekici.name")
	description = tr("item.lav_cekici.description")
	flavor_text = "Ateşli top"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.HEAVY_ATTACK
	tags = ["elemental_fire"]
	affected_stats = ["heavy_fire"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Lav Çekici] ✅ Heavy attack alev topu fırlatır (1 stamina hücresi)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Lav Çekici] ❌ Kaldırıldı")

func _on_heavy_attack_impact(attack_name: String) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if not stamina_bar or not stamina_bar.use_charge():
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var facing: float = _player.facing_direction if _player.facing_direction != 0 else (1.0 if not _player.sprite.flip_h else -1.0)
	var dir: Vector2
	if attack_name == "up_heavy":
		dir = Vector2(facing, -1.0).normalized()
	elif attack_name == "down_heavy":
		dir = Vector2(facing, 1.0).normalized()
	else:
		dir = Vector2(facing, 0.0)
	# Spawn hitbox merkezinden; böylece alt kenardan değil ortadan çıkar
	var spawn_center: Vector2 = _player.global_position + dir * 32.0
	var hitbox = _player.get_node_or_null("Hitbox")
	if hitbox:
		var cs = hitbox.get_node_or_null("CollisionShape2D")
		if cs:
			spawn_center = hitbox.to_global(cs.position)
	var nudge := dir * 14.0
	var ball = Node2D.new()
	ball.set_script(FireballScript)
	tree.current_scene.add_child(ball)
	ball.setup(spawn_center + nudge, dir)
