# agirliksiz.gd
# UNCOMMON - Havadaki düşmana vurunca kendi yerçekimin normalden daha da azalır
# ve asılı kalma penceresi uzar — Havaya Fırlatma boru hattının juggle süresini
# derinleştiren item (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.4).

extends ItemEffect

const GRAVITY_SCALE_MULT := 0.5  # air_combo_gravity_scale yarıya iner (daha uzun asılı kalma)
const FLOAT_DURATION_MULT := 1.6  # air_combo_float_duration %60 uzar

var _player: CharacterBody2D = null
var _original_gravity_scale: float = 0.12
var _original_float_duration: float = 0.35

func _init():
	item_id = "agirliksiz"
	item_name = tr("item.agirliksiz.name")
	description = tr("item.agirliksiz.description")
	flavor_text = "Havada zaman yavaşlar"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["air_combo_float"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_original_gravity_scale = player.air_combo_gravity_scale
	_original_float_duration = player.air_combo_float_duration
	player.air_combo_gravity_scale = _original_gravity_scale * GRAVITY_SCALE_MULT
	player.air_combo_float_duration = _original_float_duration * FLOAT_DURATION_MULT
	print("[Ağırlıksız] ✅ Juggle penceresi uzadı")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and is_instance_valid(_player):
		_player.air_combo_gravity_scale = _original_gravity_scale
		_player.air_combo_float_duration = _original_float_duration
	_player = null
	print("[Ağırlıksız] ❌ Kaldırıldı")
