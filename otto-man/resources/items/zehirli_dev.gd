# zehirli_dev.gd
# UNCOMMON - Heavy attack zehir püskürtür (yay çizen damlalar, değen zehirlenir)

extends ItemEffect

const PoisonArcScript = preload("res://effects/poison_arc.gd")

var _player: CharacterBody2D = null

func _init():
	item_id = "zehirli_dev"
	item_name = "Zehirli Dev"
	description = "Heavy attack zehir püskürtür (yay çizen damlalar)"
	flavor_text = "Zehirli patlama"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_poison_arc"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Kendi bağlantılarımız: register_player / sahne değişiminde de doğru oyuncuya bağlı kalır
	if player.has_signal("heavy_attack_impact"):
		if not player.is_connected("heavy_attack_impact", _on_heavy_attack_impact):
			player.connect("heavy_attack_impact", _on_heavy_attack_impact)
	if player.has_signal("decoy_heavy_attack_impact"):
		if not player.is_connected("decoy_heavy_attack_impact", _on_decoy_heavy_attack_impact):
			player.connect("decoy_heavy_attack_impact", _on_decoy_heavy_attack_impact)
	print("[Zehirli Dev] ✅ Heavy attack hasar karesinde zehir damlaları fırlar (vursa da vurmasa da)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		if _player.has_signal("heavy_attack_impact") and _player.is_connected("heavy_attack_impact", _on_heavy_attack_impact):
			_player.disconnect("heavy_attack_impact", _on_heavy_attack_impact)
		if _player.has_signal("decoy_heavy_attack_impact") and _player.is_connected("decoy_heavy_attack_impact", _on_decoy_heavy_attack_impact):
			_player.disconnect("decoy_heavy_attack_impact", _on_decoy_heavy_attack_impact)
	_player = null
	print("[Zehirli Dev] ❌ Kaldırıldı")

func _on_heavy_attack_impact(attack_name: String) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var facing: float = _player.facing_direction if _player.facing_direction != 0 else (1.0 if not _player.sprite.flip_h else -1.0)
	var spawn_center: Vector2 = _player.global_position + Vector2(facing * 24, -12)
	var hitbox = _player.get_node_or_null("Hitbox")
	if hitbox:
		var cs = hitbox.get_node_or_null("CollisionShape2D")
		if cs:
			# Zehiri hitbox ortası yerine oyuncuya yakın kenardan spawn et
			var shape_center_local: Vector2 = cs.position
			var player_local: Vector2 = hitbox.to_local(_player.global_position)
			var to_player_local: Vector2 = (player_local - shape_center_local).normalized()
			const HALF_X := 52.375
			const HALF_Y := 24.5
			var face_offset: Vector2
			if abs(to_player_local.x) >= abs(to_player_local.y):
				face_offset = Vector2(HALF_X * sign(to_player_local.x), 0.0)
			else:
				face_offset = Vector2(0.0, HALF_Y * sign(to_player_local.y))
			spawn_center = hitbox.to_global(shape_center_local + face_offset)
	var arc = Node2D.new()
	arc.set_script(PoisonArcScript)
	tree.current_scene.add_child(arc)
	arc.setup(spawn_center, facing, attack_name)

func _on_decoy_heavy_attack_impact(position: Vector2, attack_name: String, facing: float) -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var arc = Node2D.new()
	arc.set_script(PoisonArcScript)
	tree.current_scene.add_child(arc)
	arc.setup(position, facing, attack_name)
