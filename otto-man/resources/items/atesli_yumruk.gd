# atesli_yumruk.gd
# UNCOMMON - Light attack'lar yakar: saniyede 1 hasar, 3 tick, max 3 stack (3x3=9 tick)

extends ItemEffect

func _init():
	item_id = "atesli_yumruk"
	item_name = "Ateşli Yumruk"
	description = "Light attack'lar yakar (1 hasar/sn, 3 tick, max 3 stack)"
	flavor_text = "Ateşli yumruk"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["burn_dot"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
		print("[Ateşli Yumruk] ✅ Light attack'lar yakar")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Ateşli Yumruk] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, position: Vector2, effect_filter: String = "all"):
	if effect_filter == "physical_only":
		return  # Hacivat gölgesi: sadece elemental; yanık uygulanmasın
	if not _player or attack_type != "normal":
		return
	for target in targets:
		if not is_instance_valid(target):
			continue
		var enemy = target
		if not target.has_method("add_burn_stack"):
			enemy = target.get_parent() if target.get_parent() and target.get_parent().has_method("add_burn_stack") else null
		if enemy and is_instance_valid(enemy) and enemy.has_method("add_burn_stack"):
			enemy.add_burn_stack()
