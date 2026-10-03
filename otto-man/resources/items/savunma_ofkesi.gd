# savunma_ofkesi.gd
# UNCOMMON - Savunma saldırıyı besler.
#   Blok  : bir sonraki vuruşun hasarı 2x.
#   Parry : sonraki 3 saniye boyunca tüm vuruşlar 2x.
# Çarpan player.guard_empower_mult üzerinde tutulur, DamageModifiers uygular.

extends ItemEffect

const BONUS_MULT := 2.0
const PARRY_DURATION_MSEC := 3000

var _player: CharacterBody2D = null
var _expire_msec := 0  # >0 ise süreli (parry) mod aktif

func _init():
	item_id = "savunma_ofkesi"
	item_name = tr("item.savunma_ofkesi.name")
	description = tr("item.savunma_ofkesi.description")
	flavor_text = "Her darbe, bir sonrakinin öfkesi"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.BLOCK
	affected_stats = ["guard_empower"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Savunma Öfkesi] ✅ Blok: sonraki vuruş 2x, Parry: 3 sn 2x")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_clear()
	_player = null
	print("[Savunma Öfkesi] ❌ Kaldırıldı")

func process(_player_ref: CharacterBody2D, _delta: float) -> void:
	# Süre gerçek zamanla ölçülür (Zaman Durdurucu yavaşlatması 3 sn'yi uzatmasın)
	if _expire_msec > 0 and Time.get_ticks_msec() >= _expire_msec:
		_clear()

func _on_player_blocked(blocked_damage: float, _attacker: Node2D) -> void:
	if blocked_damage <= 0.0 or not is_instance_valid(_player):
		return
	# Süreli parry bonusu zaten aktifse onu bozma (aynı çarpan)
	if _expire_msec > 0:
		return
	_player.guard_empower_mult = BONUS_MULT
	_player.guard_empower_consume = true
	_flash()

func _on_perfect_parry() -> void:
	if not is_instance_valid(_player):
		return
	_player.guard_empower_mult = BONUS_MULT
	_player.guard_empower_consume = false
	_expire_msec = Time.get_ticks_msec() + PARRY_DURATION_MSEC
	_flash()

func _clear() -> void:
	_expire_msec = 0
	if is_instance_valid(_player):
		_player.guard_empower_mult = 1.0
		_player.guard_empower_consume = false

func _flash() -> void:
	var spr = _player.get("sprite")
	if spr:
		spr.modulate = Color(1.5, 0.8, 0.5, 1.0)
		_player.create_tween().tween_property(spr, "modulate", Color(1, 1, 1, 1), 0.25)
