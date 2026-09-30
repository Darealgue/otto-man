# sarsici_darbe.gd
# UNCOMMON - Her 3. isabetli vuruşta (saldırı tipi fark etmez) etrafına küçük
# bir şok dalgası yayılır — combo yaparken pasif bir alan hasarı.

extends ItemEffect

const SHOCKWAVE_INTERVAL := 3
const SHOCKWAVE_RADIUS := 70.0
const SHOCKWAVE_DAMAGE := 6.0

var _player: CharacterBody2D = null
var _hit_counter := 0

func _init():
	item_id = "sarsici_darbe"
	item_name = tr("item.sarsici_darbe.name")
	description = tr("item.sarsici_darbe.description")
	flavor_text = "Üçüncü vuruş yer sarsar"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["shockwave_combo"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_hit_counter = 0
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
	print("[Sarsıcı Darbe] ✅ Her 3. vuruşta şok dalgası")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Sarsıcı Darbe] ❌ Kaldırıldı")

func _on_player_attack_landed(_attack_type: String, _damage: float, _targets: Array, position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only" or not is_instance_valid(_player):
		return
	_hit_counter += 1
	if _hit_counter < SHOCKWAVE_INTERVAL:
		return
	_hit_counter = 0
	var tree = get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if position.distance_to(node.global_position) > SHOCKWAVE_RADIUS:
			continue
		if node.has_method("take_damage"):
			node.take_damage(SHOCKWAVE_DAMAGE, 100.0, 40.0, true)
