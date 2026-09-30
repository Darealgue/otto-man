# refleks.gd
# LEGENDARY - Rundan 1 kez: hasar aldığında refleksle geri kazanılır (hasar iade
# edilir + kısa dokunulmazlık). Teknik not: gerçek bir "hasar gelmeden önce
# tahmin et" hook'u yok, bu yüzden hasar önlenmiyor, ANINDA telafi ediliyor —
# oyuncuya "ölümden döndüm" hissi aynı, mekanizma "önle" değil "iade et".

extends ItemEffect

const IFRAME_DURATION := 0.3

var _player: CharacterBody2D = null
var _used := false

func _init():
	item_id = "refleks"
	item_name = tr("item.refleks.name")
	description = tr("item.refleks.description")
	flavor_text = "Beden düşünmeden tepki verir"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.DODGE
	affected_stats = ["reflex_save"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_took_damage"):
		if not player.is_connected("player_took_damage", _on_player_took_damage):
			player.connect("player_took_damage", _on_player_took_damage)
	print("[Refleks] ✅ Rundan 1 kez hasar iade edilir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_took_damage"):
		if _player.is_connected("player_took_damage", _on_player_took_damage):
			_player.disconnect("player_took_damage", _on_player_took_damage)
	_player = null
	print("[Refleks] ❌ Kaldırıldı")

func _on_player_took_damage(amount: float, _attacker: Node2D) -> void:
	if _used or amount <= 0.0 or not is_instance_valid(_player):
		return
	_used = true
	if _player.has_method("heal"):
		_player.heal(amount)
	if _player.hurtbox and _player.hurtbox.has_method("set_invincible"):
		_player.hurtbox.set_invincible(IFRAME_DURATION)
	print("[Refleks] ⚡ Refleks tetiklendi, hasar iade edildi")
