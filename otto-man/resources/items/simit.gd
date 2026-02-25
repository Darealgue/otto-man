# simit.gd
# COMMON item - Stamina sıfırlanınca 5 saniye %100 (2x) stamina regen

extends ItemEffect

const BOOST_DURATION := 5.0  # saniye
const REGEN_MULTIPLIER := 2.0  # %100 = 2x regen

var _stamina_bar = null
var _boost_active := false
var _stored_recharge_rate := 5.0
var _boost_timer := 0.0

func _init():
	item_id = "simit"
	item_name = "Simit"
	description = "Stamina sıfırlanınca 5 sn %100 hızlı regen"
	flavor_text = "Simitçi geçti!"
	rarity = ItemRarity.COMMON
	category = ItemCategory.STAMINA
	affected_stats = ["stamina_regen"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if _stamina_bar:
		if !_stamina_bar.stamina_depleted.is_connected(_on_stamina_depleted):
			_stamina_bar.stamina_depleted.connect(_on_stamina_depleted)
		set_process(true)
		print("[Simit] ✅ Stamina sıfırlanınca 5 sn 2x regen aktif")

func deactivate(player: CharacterBody2D):
	set_process(false)
	_boost_active = false
	if _stamina_bar:
		if _stamina_bar.stamina_depleted.is_connected(_on_stamina_depleted):
			_stamina_bar.stamina_depleted.disconnect(_on_stamina_depleted)
		# Restore rate in case we're still in boost
		_stamina_bar.RECHARGE_RATE = _stored_recharge_rate
	_stamina_bar = null
	super.deactivate(player)
	print("[Simit] ❌ Simit kaldırıldı")

func _on_stamina_depleted():
	if _boost_active:
		return
	if !_stamina_bar:
		return
	_stored_recharge_rate = _stamina_bar.RECHARGE_RATE
	_stamina_bar.RECHARGE_RATE = _stored_recharge_rate / REGEN_MULTIPLIER
	_boost_active = true
	_boost_timer = BOOST_DURATION
	print("[Simit] Stamina sıfırlandı — 5 sn 2x regen başladı")

func _process(delta: float):
	if !_boost_active or !_stamina_bar:
		return
	_boost_timer -= delta
	if _boost_timer <= 0:
		_stamina_bar.RECHARGE_RATE = _stored_recharge_rate
		_boost_active = false
		print("[Simit] 5 sn 2x regen bitti")
