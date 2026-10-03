# zaman_durdurucu.gd
# RARE - Hasar bloklamak zamanı yavaşlatır; parry yavaşlama süresini 2 katına çıkarır.
# Oyuncu yavaşlamadan normal hızında hareket eder.
#   Blok  : 1 sn gerçek zamanlı yavaşlama
#   Parry : 2 sn
# Kum Saati itemi eklendiğinde: zaman 2x daha yavaş (0.25) ve süreler 2x (blok 2 sn, parry 4 sn).

extends ItemEffect

const TIME_SLOW_SCALE := 0.5
const BLOCK_SLOW_REAL_DURATION := 1.0
const PARRY_DURATION_MULT := 2.0
# Kum Saati varsa: scale 0.25, süreler 2x (ItemManager.has_active_item ile kontrol)

var _player: CharacterBody2D = null
var _time_slow_active := false
var _remaining_real := 0.0  # gerçek zamanlı kalan yavaşlama süresi

func _init():
	item_id = "zaman_durdurucu"
	item_name = tr("item.zaman_durdurucu.name")
	description = tr("item.zaman_durdurucu.description")
	flavor_text = "Zamanı kontrol et"
	rarity = ItemRarity.RARE
	category = ItemCategory.PARRY
	affected_stats = ["parry_time_slow"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("perfect_parry"):
		if not player.is_connected("perfect_parry", _on_perfect_parry):
			player.connect("perfect_parry", _on_perfect_parry)
	# _on_player_blocked ItemManager tarafından player_blocked sinyaline otomatik bağlanır
	print("[Zaman Durdurucu] ✅ Blok → zaman yavaşlar, parry → 2x süre (sen normal hız)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_time_slow_active = false
	_remaining_real = 0.0
	if _player:
		_player.time_slow_player_multiplier = 1.0
		var ap = _player.get_node_or_null("AnimationPlayer")
		if ap:
			ap.speed_scale = 1.0
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
	if _player and _player.has_signal("perfect_parry"):
		if _player.is_connected("perfect_parry", _on_perfect_parry):
			_player.disconnect("perfect_parry", _on_perfect_parry)
	_player = null
	print("[Zaman Durdurucu] ❌ Kaldırıldı")

func _has_kum_saati() -> bool:
	var im := get_node_or_null("/root/ItemManager")
	return im != null and im.has_active_item("kum_saati")

func _current_scale() -> float:
	return 0.25 if _has_kum_saati() else TIME_SLOW_SCALE

func _duration_for(is_parry: bool) -> float:
	var d: float = BLOCK_SLOW_REAL_DURATION
	if _has_kum_saati():
		d *= 2.0
	if is_parry:
		d *= PARRY_DURATION_MULT
	return d

func _set_player_speed(scale_to_use: float) -> void:
	var player_mult: float = 1.0 / scale_to_use
	if is_instance_valid(_player):
		_player.time_slow_player_multiplier = player_mult
		var ap = _player.get_node_or_null("AnimationPlayer")
		if ap:
			ap.speed_scale = player_mult

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if not _time_slow_active or not _player:
		return
	# Başka sistemler (hitstop vb.) time_scale’i sıfırlayabilir; her frame tekrar uygula
	var scale_to_use: float = _current_scale()
	Engine.time_scale = scale_to_use
	_set_player_speed(scale_to_use)
	_remaining_real -= delta / Engine.time_scale
	if _remaining_real <= 0.0:
		_time_slow_active = false
		_remaining_real = 0.0
		if is_instance_valid(_player):
			_player.time_slow_player_multiplier = 1.0
			var ap = _player.get_node_or_null("AnimationPlayer")
			if ap:
				ap.speed_scale = 1.0
		Engine.time_scale = 1.0

func _on_perfect_parry() -> void:
	_request_slow(true)

func _on_player_blocked(blocked_damage: float, _attacker: Node2D) -> void:
	if blocked_damage <= 0.0:
		return
	_request_slow(false)

func _request_slow(is_parry: bool) -> void:
	if not _player:
		return
	# Bir frame ertede uygula; aynı frame’te başka sistemler (hitstop vb.) time_scale’i sıfırlayabiliyor
	call_deferred("_apply_time_slow", is_parry)

func _apply_time_slow(is_parry: bool) -> void:
	if not is_instance_valid(_player):
		return
	# Zaten yavaşsa süreyi sıfırlama, sadece daha uzunsa uzat (blok parry'yi kısaltmasın)
	_remaining_real = maxf(_remaining_real, _duration_for(is_parry))
	_time_slow_active = true
	var scale_to_use: float = _current_scale()
	Engine.time_scale = scale_to_use
	_set_player_speed(scale_to_use)
