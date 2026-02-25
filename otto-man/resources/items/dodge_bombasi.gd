# dodge_bombasi.gd
# UNCOMMON item - Dodge kullandığında arkanda bomba bırakır

extends ItemEffect

const BOMB_DAMAGE = 15.0
const BOMB_RADIUS = 100.0
const BOMB_DELAY = 0.5  # 0.5 saniye sonra patlar

func _init():
	item_id = "dodge_bombasi"
	item_name = "Dodge Bombası"
	description = "Dodge kullandığında arkanda bomba bırakır"
	flavor_text = "Patlayıcı kaçış"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["dodge_bomb"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Connect to player_dodged signal (dodge)
	if player.has_signal("player_dodged"):
		if not player.is_connected("player_dodged", _on_player_dodged):
			player.connect("player_dodged", _on_player_dodged)
	# Connect to dash_started signal (dash)
	if player.has_signal("dash_started"):
		if not player.is_connected("dash_started", _on_dash_started):
			player.connect("dash_started", _on_dash_started)
		print("[Dodge Bombası] ✅ Dodge/dash sonrası bomba bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# Disconnect signals
	if _player:
		if _player.has_signal("player_dodged") and _player.is_connected("player_dodged", _on_player_dodged):
			_player.disconnect("player_dodged", _on_player_dodged)
		if _player.has_signal("dash_started") and _player.is_connected("dash_started", _on_dash_started):
			_player.disconnect("dash_started", _on_dash_started)
	_player = null
	print("[Dodge Bombası] ❌ Dodge Bombası kaldırıldı")

func _on_player_dodged(direction: int, start_pos: Vector2, end_pos: Vector2):
	if not _player:
		return
	_spawn_bomb_at_position(start_pos)

func _on_dash_started():
	# Dash başlangıç pozisyonunu almak için dash state'den bilgi almalıyız
	# Ama daha iyi: player_dodged signal'i dash bitince emit edilecek (dash_state'de ekledik)
	# Bu yüzden burada bir şey yapmaya gerek yok
	pass

func _spawn_bomb_at_position(bomb_pos: Vector2):
	var tree = get_tree()
	if not tree:
		return
	
	var timer = tree.create_timer(BOMB_DELAY)
	if timer:
		timer.timeout.connect(_explode_bomb.bind(bomb_pos))

func _explode_bomb(bomb_position: Vector2):
	if not is_instance_valid(_player):
		return
	
	var tree = get_tree()
	if not tree:
		return
	
	# Spawn explosion visual effect (enemy hit effect as explosion)
	var explosion_scene = preload("res://effects/enemy_hit_effect.tscn")
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		var scene = tree.current_scene
		if scene:
			scene.add_child(explosion)
			# Wait one frame for _ready() to complete, then setup
			await tree.process_frame
			if is_instance_valid(explosion) and explosion.has_method("setup"):
				explosion.setup(Vector2.ZERO, 2.5, 2, bomb_position)  # Large scale, hit3 effect (biggest)
	
	# Find all enemies in radius and damage them
	var enemies = tree.get_nodes_in_group("enemies")
	var hit_count = 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var distance = bomb_position.distance_to(enemy.global_position)
		if distance <= BOMB_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(BOMB_DAMAGE)
				hit_count += 1
	
	if hit_count > 0:
		print("[Dodge Bombası] ✅ Bomba patladı! ", hit_count, " düşmana ", BOMB_DAMAGE, " hasar verildi")
	else:
		print("[Dodge Bombası] Bomba patladı ama yakında düşman yok")
