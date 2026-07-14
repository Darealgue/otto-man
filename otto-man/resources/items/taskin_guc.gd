# UNCOMMON - Stamina barı tamamen doluyken tüm saldırılar +%30 hasar
extends ItemEffect

const FULL_STAMINA_MULT := 1.3

var _player: CharacterBody2D = null

func _init():
	item_id = "taskin_guc"
	item_name = "Taşkın Güç"
	description = "Stamina tamamen doluyken saldırılar +%30 hasar verir"
	flavor_text = "Dolu kadeh en sert çarpar"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.STAMINA
	affected_stats = ["full_stamina_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Taşkın Güç] ✅ Dolu staminada +%30 hasar")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if is_instance_valid(_player):
		_player.taskin_guc_mult = 1.0
	_player = null
	print("[Taşkın Güç] ❌ Kaldırıldı")

func process(player: CharacterBody2D, _delta: float) -> void:
	if not is_instance_valid(player):
		return
	player.taskin_guc_mult = FULL_STAMINA_MULT if _is_stamina_full() else 1.0

func _is_stamina_full() -> bool:
	var bar = get_tree().get_first_node_in_group("stamina_bar")
	if not bar or not "charges" in bar:
		return false
	var charges: Array = bar.charges
	if charges.is_empty():
		return false
	for c in charges:
		if float(c) < 1.0:
			return false
	return true
