# buzlu_kilic.gd
# UNCOMMON - Light attack'lar yavaşlatır: 1-5 stack %20, 6-10 %40, 11-15 %60; her saniye 1 stack azalır

extends ItemEffect

func _init():
	item_id = "buzlu_kilic"
	item_name = "Buzlu Kılıç"
	description = "Light attack'lar yavaşlatır (1-5 stack %%20, 6-10 %%40, 11-15 %%60; 1/s decay)"
	flavor_text = "Buzlu dokunuş"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["frost_slow"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
		print("[Buzlu Kılıç] ✅ Light attack'lar yavaşlatır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Buzlu Kılıç] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, position: Vector2, effect_filter: String = "all"):
	if effect_filter == "physical_only":
		return  # Hacivat gölgesi: sadece elemental; buz uygulanmasın
	if not _player or attack_type != "normal":
		return
	for target in targets:
		if not is_instance_valid(target):
			continue
		var enemy = target
		if not target.has_method("add_frost_stack"):
			enemy = target.get_parent() if target.get_parent() and target.get_parent().has_method("add_frost_stack") else null
		if enemy and is_instance_valid(enemy) and enemy.has_method("add_frost_stack"):
			enemy.add_frost_stack(1)
