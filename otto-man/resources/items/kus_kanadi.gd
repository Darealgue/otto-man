# kus_kanadi.gd
# COMMON item - Triple jump, air kontrolü %75 azalır

extends ItemEffect

const AIR_CONTROL_REDUCTION = 0.75  # %75 azalma

func _init():
	item_id = "kus_kanadi"
	item_name = "Kuş Kanadı"
	description = "Triple jump, air kontrolü %75 azalır"
	flavor_text = "Kuş gibi zıplama"
	rarity = ItemRarity.COMMON
	category = ItemCategory.JUMP
	affected_stats = ["jump_count", "air_control"]

var _player: CharacterBody2D = null
var _original_air_control: float = 0.5

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Store original air control
	_original_air_control = player.air_control_multiplier
	
	# Reduce air control by 75% (multiply by 0.25)
	player.air_control_multiplier = _original_air_control * (1.0 - AIR_CONTROL_REDUCTION)
	
	# Set meta on player to enable triple jump
	player.set_meta("kus_kanadi_active", true)
	player.set_meta("kus_kanadi_jump_count", 0)
	print("[Kuş Kanadı] ✅ Triple jump aktif, air kontrolü %75 azaldı (", player.air_control_multiplier, ")")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# Restore air control
	if _player:
		_player.air_control_multiplier = _original_air_control
		if _player.has_meta("kus_kanadi_active"):
			_player.remove_meta("kus_kanadi_active")
		if _player.has_meta("kus_kanadi_jump_count"):
			_player.remove_meta("kus_kanadi_jump_count")
		if _player.has_meta("kus_kanadi_third_jump"):
			_player.remove_meta("kus_kanadi_third_jump")
	_player = null
	print("[Kuş Kanadı] ❌ Kuş Kanadı kaldırıldı")
