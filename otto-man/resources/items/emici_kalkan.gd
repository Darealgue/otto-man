# emici_kalkan.gd
# UNCOMMON - Bloklanan hasarın %40'ı birikir; sıradaki saldırının hasarına düz
# bonus olarak eklenir. Savunma artık saf savunma değil, saldırıya dönüşen bir
# "Karşılık" biriktiricisi.

extends ItemEffect

const ABSORB_RATIO := 0.4

var _player: CharacterBody2D = null
var _hitbox: Node = null

func _init():
	item_id = "emici_kalkan"
	item_name = tr("item.emici_kalkan.name")
	description = tr("item.emici_kalkan.description")
	flavor_text = "Aldığın hasar sende kalır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.BLOCK
	affected_stats = ["block_damage_bank"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_hitbox = player.get_node_or_null("Hitbox")
	if player.has_signal("player_blocked"):
		if not player.is_connected("player_blocked", _on_player_blocked):
			player.connect("player_blocked", _on_player_blocked)
	print("[Emici Kalkan] ✅ Bloklanan hasar sıradaki vuruşa ekleniyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_blocked"):
		if _player.is_connected("player_blocked", _on_player_blocked):
			_player.disconnect("player_blocked", _on_player_blocked)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.pending_flat_damage_bonus = 0.0
	_player = null
	_hitbox = null
	print("[Emici Kalkan] ❌ Kaldırıldı")

func _on_player_blocked(blocked_damage: float, _attacker: Node2D) -> void:
	if blocked_damage <= 0.0 or not _hitbox or not is_instance_valid(_hitbox):
		return
	var im = get_node_or_null("/root/ItemManager")
	var specialist_mult: float = im.get_specialist_multiplier("savunma") if im else 1.0
	_hitbox.pending_flat_damage_bonus += blocked_damage * ABSORB_RATIO * specialist_mult
