# yildirim_adimi.gd
# UNCOMMON item - Dodge/dash sonrası kısa süreli speed boost

extends ItemEffect

const SPEED_BOOST_MULTIPLIER = 1.5  # %50 hız artışı
const BOOST_DURATION = 2.0  # 2 saniye

func _init():
	item_id = "yildirim_adimi"
	item_name = "Yıldırım Adımı"
	description = "Dodge/dash sonrası kısa süreli hız bonusu"
	flavor_text = "Şimşek hızı"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["speed_boost"]

var _player: CharacterBody2D = null
var _speed_boost_timer: float = 0.0
var _original_speed: float = 400.0

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_original_speed = player.speed
	# Connect to dodge/dash signals
	if player.has_signal("player_dodged"):
		if not player.is_connected("player_dodged", _on_player_dodged):
			player.connect("player_dodged", _on_player_dodged)
	if player.has_signal("dash_started"):
		if not player.is_connected("dash_started", _on_dash_started):
			player.connect("dash_started", _on_dash_started)
	print("[Yıldırım Adımı] ✅ Dodge/dash sonrası hız bonusu aktif")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# Remove speed boost if active
	if _player:
		_player.speed = _original_speed
	# Disconnect signals
	if _player:
		if _player.has_signal("player_dodged") and _player.is_connected("player_dodged", _on_player_dodged):
			_player.disconnect("player_dodged", _on_player_dodged)
		if _player.has_signal("dash_started") and _player.is_connected("dash_started", _on_dash_started):
			_player.disconnect("dash_started", _on_dash_started)
	_player = null
	_speed_boost_timer = 0.0
	print("[Yıldırım Adımı] ❌ Yıldırım Adımı kaldırıldı")

func _on_player_dodged(direction: int, start_pos: Vector2, end_pos: Vector2):
	if not _player:
		return
	_apply_speed_boost()

func _on_dash_started():
	if not _player:
		return
	_apply_speed_boost()

func _apply_speed_boost():
	if not _player:
		return
	_player.speed = _original_speed * SPEED_BOOST_MULTIPLIER
	_speed_boost_timer = BOOST_DURATION
	print("[Yıldırım Adımı] Hız bonusu aktif (", _player.speed, ")")

func process(player: CharacterBody2D, delta: float):
	if not _player or _speed_boost_timer <= 0.0:
		return
	
	_speed_boost_timer -= delta
	if _speed_boost_timer <= 0.0:
		# Restore original speed
		_player.speed = _original_speed
		print("[Yıldırım Adımı] Hız bonusu bitti")
