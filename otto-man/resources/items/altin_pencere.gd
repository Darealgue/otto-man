# altin_pencere.gd
# RARE - Her başarılı parry, parry penceresini %15 uzatır (en fazla 3 kat).
# Hasar alınca çarpan sıfırlanır. Çarpan player.parry_window_mult üzerinde, Block state ve
# Kalkan Küresi okur.

extends ItemEffect

const STEP := 0.15
const MAX_MULT := 3.0

var _player: CharacterBody2D = null

func _init():
	item_id = "altin_pencere"
	item_name = tr("item.altin_pencere.name")
	description = tr("item.altin_pencere.description")
	flavor_text = "Ustalık zamanı genişletir"
	rarity = ItemRarity.RARE
	category = ItemCategory.PARRY
	affected_stats = ["parry_window_stack"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	player.parry_window_mult = 1.0
	print("[Altın Pencere] ✅ Her parry pencereyi %15 uzatır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if is_instance_valid(player):
		player.parry_window_mult = 1.0
	_player = null
	print("[Altın Pencere] ❌ Kaldırıldı")

func _on_perfect_parry() -> void:
	if is_instance_valid(_player):
		_player.parry_window_mult = minf(_player.parry_window_mult + STEP, MAX_MULT)

func _on_player_took_damage(amount: float, _attacker: Node2D) -> void:
	if amount > 0.0 and is_instance_valid(_player):
		_player.parry_window_mult = 1.0
