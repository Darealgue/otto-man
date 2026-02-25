# simsek_kalkani.gd
# RARE - Block başarılı → bloklanan hasarın %80'i şimşek olarak saldırgana (blok süresi yok, basılı tutuluyor)

extends ItemEffect

const REFLECT_PERCENTAGE := 0.80  # %80 şimşek yansıması

var _player: CharacterBody2D = null

func _init():
	item_id = "simsek_kalkani"
	item_name = "Şimşek Kalkanı"
	description = "Block sırasında gelen hasarın %80'i saldırgana şimşek olarak yansır"
	flavor_text = "Elektrikli savunma"
	rarity = ItemRarity.RARE
	category = ItemCategory.BLOCK
	affected_stats = ["lightning_reflect"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_blocked"):
		if not player.is_connected("player_blocked", _on_player_blocked):
			player.connect("player_blocked", _on_player_blocked)
		print("[Şimşek Kalkanı] ✅ Block → %80 şimşek yansıması")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_blocked"):
		if _player.is_connected("player_blocked", _on_player_blocked):
			_player.disconnect("player_blocked", _on_player_blocked)
	_player = null
	print("[Şimşek Kalkanı] ❌ Kaldırıldı")

func _on_player_blocked(blocked_damage: float, attacker: Node2D):
	if blocked_damage <= 0 or not is_instance_valid(attacker):
		return
	var lightning_damage = blocked_damage * REFLECT_PERCENTAGE
	# Saldırgan düşman (veya hurtbox parent'ı)
	var target = attacker
	if not attacker.has_method("take_damage") and attacker.get_parent():
		target = attacker.get_parent()
	if target and target.has_method("take_damage"):
		target.take_damage(lightning_damage, 0.0, 0.0, false)
