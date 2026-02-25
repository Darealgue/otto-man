# zaman_durdurucu.gd
# RARE - Perfect parry sonrası zaman yavaşlar; oyuncu normal hızında hareket eder.
# Kum Saati itemi eklendiğinde: zaman 2x daha yavaş (0.25) ve 4 sn süre kullanılacak.

extends ItemEffect

const TIME_SLOW_SCALE := 0.5
const TIME_SLOW_REAL_DURATION := 2.0
# Kum Saati varsa: scale 0.25, duration 4.0 (process içinde ItemManager.has_active_item ile kontrol)

var _player: CharacterBody2D = null
var _time_slow_active := false
var _time_slow_accumulator := 0.0

func _init():
	item_id = "zaman_durdurucu"
	item_name = "Zaman Durdurucu"
	description = "Perfect parry sonrası zaman yavaşlar; sen normal hızında hareket edersin"
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
		print("[Zaman Durdurucu] ✅ Perfect parry → zaman yavaşlar (sen normal hız)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_time_slow_active = false
	_time_slow_accumulator = 0.0
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

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if not _time_slow_active or not _player:
		return
	# Başka sistemler (hitstop vb.) time_scale’i sıfırlayabilir; her frame tekrar uygula
	var scale_to_use: float = TIME_SLOW_SCALE
	var duration_to_use: float = TIME_SLOW_REAL_DURATION
	if ItemManager and ItemManager.has_active_item("kum_saati"):
		scale_to_use = 0.25
		duration_to_use = 4.0
	Engine.time_scale = scale_to_use
	var player_mult: float = 1.0 / scale_to_use
	if is_instance_valid(_player):
		_player.time_slow_player_multiplier = player_mult
		var ap = _player.get_node_or_null("AnimationPlayer")
		if ap:
			ap.speed_scale = player_mult
	_time_slow_accumulator += delta / Engine.time_scale
	if _time_slow_accumulator >= duration_to_use:
		_time_slow_active = false
		_time_slow_accumulator = 0.0
		if is_instance_valid(_player):
			_player.time_slow_player_multiplier = 1.0
			var ap = _player.get_node_or_null("AnimationPlayer")
			if ap:
				ap.speed_scale = 1.0
		Engine.time_scale = 1.0

func _on_perfect_parry() -> void:
	if not _player or _time_slow_active:
		return
	# Bir frame ertede uygula; aynı frame’te başka sistemler (hitstop vb.) time_scale’i sıfırlayabiliyor
	call_deferred("_apply_time_slow")

func _apply_time_slow() -> void:
	if not is_instance_valid(_player) or _time_slow_active:
		return
	_time_slow_active = true
	_time_slow_accumulator = 0.0
	var scale_to_use: float = TIME_SLOW_SCALE
	if ItemManager and ItemManager.has_active_item("kum_saati"):
		scale_to_use = 0.25
	Engine.time_scale = scale_to_use
	var player_mult: float = 1.0 / scale_to_use
	_player.time_slow_player_multiplier = player_mult
	var ap = _player.get_node_or_null("AnimationPlayer")
	if ap:
		ap.speed_scale = player_mult
