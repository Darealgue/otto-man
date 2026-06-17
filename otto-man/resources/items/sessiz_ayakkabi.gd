# sessiz_ayakkabi.gd
# COMMON - Koşu ve hareket gürültüsü -%50

extends ItemEffect

const NOISE_REDUCTION: float = 0.5

var _player: CharacterBody2D = null
var _original_noise_mult: float = 1.0

func _init():
	item_id = "sessiz_ayakkabi"
	item_name = "Sessiz Ayakkabı"
	description = "Hareket gürültüsü -%50"
	flavor_text = "Adımlar yumuşak"
	rarity = ItemRarity.COMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["stealth_noise"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	var emitter: Node = player.get_node_or_null("PlayerNoiseEmitter")
	if emitter and emitter.has_method("get_noise_multiplier"):
		_original_noise_mult = float(emitter.get_noise_multiplier())
		emitter.set_noise_multiplier(_original_noise_mult * (1.0 - NOISE_REDUCTION))
		print("[Sessiz Ayakkabı] Gürültü -%d%%" % int(NOISE_REDUCTION * 100.0))

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	var emitter: Node = player.get_node_or_null("PlayerNoiseEmitter") if is_instance_valid(player) else null
	if emitter and emitter.has_method("set_noise_multiplier"):
		emitter.set_noise_multiplier(_original_noise_mult)
	_player = null
