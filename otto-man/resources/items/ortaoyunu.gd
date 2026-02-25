# ortaoyunu.gd
# LEGENDARY - Dodge/dash basıldığı anda arkada gölge kopya (decoy) bırakır.
# Düşmanlar gölgeyi hedef alır ama gölge hasar almaz. 3 saniye sonra yok olur.

extends ItemEffect

const DecoyScene = preload("res://effects/player_decoy.tscn")

var _player: CharacterBody2D = null

func _init():
	item_id = "ortaoyunu"
	item_name = "Ortaoyunu"
	description = "Dodge veya dash bastığında arkanda gölge bir kopya bırakırsın. Düşmanlar ona saldırabilir ama hasar almaz. 3 sn sonra kaybolur."
	flavor_text = "Gölge oyunu"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.DODGE
	affected_stats = ["dodge_decoy"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Gölge dodge/dash basıldığı anda (state girişinde) çıksın, bitince değil
	if player.has_signal("dodge_started"):
		if not player.is_connected("dodge_started", _on_dodge_started):
			player.connect("dodge_started", _on_dodge_started)
	if player.has_signal("dash_started"):
		if not player.is_connected("dash_started", _on_dash_started):
			player.connect("dash_started", _on_dash_started)
	print("[Ortaoyunu] Dodge/dash basıldığında gölge decoy bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		if _player.has_signal("dodge_started") and _player.is_connected("dodge_started", _on_dodge_started):
			_player.disconnect("dodge_started", _on_dodge_started)
		if _player.has_signal("dash_started") and _player.is_connected("dash_started", _on_dash_started):
			_player.disconnect("dash_started", _on_dash_started)
		_player = null

func _on_dodge_started() -> void:
	if _player and is_instance_valid(_player):
		_spawn_decoy_at(_player.global_position)

func _on_dash_started() -> void:
	if _player and is_instance_valid(_player):
		_spawn_decoy_at(_player.global_position)

func _spawn_decoy_at(pos: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var decoy = DecoyScene.instantiate()
	tree.current_scene.add_child(decoy)
	var flip = _player.sprite.flip_h if _player and _player.get_node_or_null("Sprite2D") else false
	decoy.setup(pos, flip, _player)
