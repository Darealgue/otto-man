# dodge_zehiri.gd
# UNCOMMON - Dodge kullandığında arkanda zehir trail (bulut) bırakırsın

extends ItemEffect

const PoisonCloudScript = preload("res://effects/poison_cloud.gd")

var _player: CharacterBody2D = null

func _init():
	item_id = "dodge_zehiri"
	item_name = "Dodge Zehiri"
	description = "Dodge kullandığında arkanda zehir bulutu bırakırsın"
	flavor_text = "Zehirli kaçış"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["dodge_poison"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_dodged"):
		if not player.is_connected("player_dodged", _on_player_dodged):
			player.connect("player_dodged", _on_player_dodged)
	if player.has_signal("dash_started"):
		if not player.is_connected("dash_started", _on_dash_started):
			player.connect("dash_started", _on_dash_started)
	print("[Dodge Zehiri] ✅ Dodge/dash sonrası zehir bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		if _player.has_signal("player_dodged") and _player.is_connected("player_dodged", _on_player_dodged):
			_player.disconnect("player_dodged", _on_player_dodged)
		if _player.has_signal("dash_started") and _player.is_connected("dash_started", _on_dash_started):
			_player.disconnect("dash_started", _on_dash_started)
	_player = null
	print("[Dodge Zehiri] ❌ Kaldırıldı")

func _on_player_dodged(_direction: int, start_pos: Vector2, _end_pos: Vector2):
	_spawn_poison_at(start_pos)

func _on_dash_started():
	if _player and is_instance_valid(_player):
		_spawn_poison_at(_player.global_position)

func _spawn_poison_at(pos: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var cloud = Node2D.new()
	cloud.set_script(PoisonCloudScript)
	tree.current_scene.add_child(cloud)
	cloud.global_position = pos
