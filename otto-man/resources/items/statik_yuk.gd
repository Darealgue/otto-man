# statik_yuk.gd
# UNCOMMON - Light attack isabeti düşmana 1 şimşek stack'i yükler (Buzlu Kılıç / Zehirli Tırnak gibi element kaynağı).
# Düşman 5 stack'e ulaşınca stack'ler sıfırlanır ve 1 stack yakındaki düşmanlara sıçrar (bkz. base_enemy.add_lightning_stack).

extends ItemEffect

func _init():
	item_id = "statik_yuk"
	item_name = tr("item.statik_yuk.name")
	description = tr("item.statik_yuk.description")
	flavor_text = "Havada elektrik var"
	category = ItemCategory.LIGHT_ATTACK
	tags = ["elemental_lightning"]
	affected_stats = ["lightning_stack"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null

func _on_player_attack_landed(attack_type: String, _damage: float, targets: Array, _position: Vector2, effect_filter: String = "all"):
	if effect_filter == "physical_only":
		return  # Hacivat gölgesi: sadece elemental; şimşek uygulanmasın
	if not _player or (attack_type != "normal" and attack_type != "ranged"):
		return
	# Şimşek sıçramasında komşular zaten +1 şimşek stack alıyor; burada ikinci kez verme
	var im_guard = get_node_or_null("/root/ItemManager")
	if im_guard and im_guard.get("is_reflecting_hit"):
		return
	for target in targets:
		if not is_instance_valid(target):
			continue
		var enemy = target
		if not target.has_method("add_lightning_stack"):
			enemy = target.get_parent() if target.get_parent() and target.get_parent().has_method("add_lightning_stack") else null
		if enemy and is_instance_valid(enemy) and enemy.has_method("add_lightning_stack"):
			enemy.add_lightning_stack()
			var im = get_node_or_null("/root/ItemManager")
			if im and im.has_method("spawn_element_hit_flash"):
				im.spawn_element_hit_flash(enemy, "lightning")
