extends Node
class_name StatusEffectManager

## Manages status effects (burn, poison) on the player.
## Add as a child of the Player node.

var _player: CharacterBody2D
var _burn_timer: Timer
var _poison_timer: Timer

# Burn state
var burn_active: bool = false
var burn_remaining_ticks: int = 0
var burn_damage_per_tick: float = 3.0
const BURN_TICK_INTERVAL: float = 0.5
const BURN_TINT := Color(1.0, 0.4, 0.2, 1.0)

# Poison state
var poison_active: bool = false
var poison_remaining_ticks: int = 0
var poison_damage_per_tick: float = 2.0
const POISON_TICK_INTERVAL: float = 1.0
const POISON_TINT := Color(0.5, 1.0, 0.3, 1.0)

# Chill (soğuk) state: hareket hızını geçici yavaşlatır, hasar vermez
var chill_active: bool = false
var _chill_timer: Timer
const CHILL_TINT := Color(0.45, 0.75, 1.3, 1.0)

# Shock (şok) state: oyuncuyu süre boyunca sersemletir (Shock state'i), hasar vermez
var shock_active: bool = false
var _shock_timer: Timer
const SHOCK_TINT := Color(1.5, 1.4, 0.45, 1.0)

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if not _player:
		push_error("[StatusEffectManager] Must be a child of a CharacterBody2D (Player)")
		return

	_burn_timer = Timer.new()
	_burn_timer.wait_time = BURN_TICK_INTERVAL
	_burn_timer.timeout.connect(_on_burn_tick)
	add_child(_burn_timer)

	_poison_timer = Timer.new()
	_poison_timer.wait_time = POISON_TICK_INTERVAL
	_poison_timer.timeout.connect(_on_poison_tick)
	add_child(_poison_timer)

	_chill_timer = Timer.new()
	_chill_timer.one_shot = true
	_chill_timer.timeout.connect(_clear_chill)
	add_child(_chill_timer)

	_shock_timer = Timer.new()
	_shock_timer.one_shot = true
	_shock_timer.timeout.connect(_clear_shock)
	add_child(_shock_timer)

## Şok: oyuncu `duration` saniye sersemler (hareket/saldırı yok) ve sarı görünür.
## Ölü oyuncuya uygulanmaz. Yeniden uygulamak süreyi yeniler.
func apply_shock(duration: float = 1.0) -> void:
	if not _player or bool(_player.get("is_dead")) or bool(_player.get("pending_death")):
		return
	_player.shock_duration = duration
	var sm = _player.get("state_machine")
	if sm and sm.has_node("Shock"):
		sm.transition_to("Shock", true)
	shock_active = true
	_shock_timer.start(duration)
	_update_visual()

func _clear_shock() -> void:
	shock_active = false
	_update_visual()

## Soğuk: `duration` saniye boyunca hareket hızı `speed_mult` ile çarpılır. Yeniden uygulamak
## süreyi yeniler (üst üste binmez).
func apply_chill(duration: float = 3.0, speed_mult: float = 0.65) -> void:
	if not _player:
		return
	_player.status_speed_multiplier = speed_mult
	chill_active = true
	_chill_timer.start(duration)
	_update_visual()

func _clear_chill() -> void:
	chill_active = false
	if _player:
		_player.status_speed_multiplier = 1.0
	_update_visual()

func apply_burn(ticks: int = 6, damage_per_tick: float = 3.0) -> void:
	burn_damage_per_tick = damage_per_tick
	burn_remaining_ticks = maxi(burn_remaining_ticks, ticks)
	if not burn_active:
		burn_active = true
		_burn_timer.start()
	_update_visual()

func apply_poison(ticks: int = 5, damage_per_tick: float = 2.0) -> void:
	# Panzehir Derisi: zehir tuzaklarına ve bulutlarına tam bağışıklık
	var im = get_node_or_null("/root/ItemManager")
	if im and im.has_method("has_active_item") and im.has_active_item("panzehir_derisi"):
		return
	poison_damage_per_tick = damage_per_tick
	poison_remaining_ticks = maxi(poison_remaining_ticks, ticks)
	if not poison_active:
		poison_active = true
		_poison_timer.start()
	_update_visual()

func clear_all() -> void:
	_clear_burn()
	_clear_poison()
	_clear_chill()
	_clear_shock()

func _on_burn_tick() -> void:
	if burn_remaining_ticks <= 0:
		_clear_burn()
		return
	burn_remaining_ticks -= 1
	if _player and _player.has_method("take_damage"):
		_player.take_damage(burn_damage_per_tick, true, null)
	_flash_tint(BURN_TINT)

func _on_poison_tick() -> void:
	if poison_remaining_ticks <= 0:
		_clear_poison()
		return
	poison_remaining_ticks -= 1
	if _player and _player.has_method("take_damage"):
		_player.take_damage(poison_damage_per_tick, true, null)
	_flash_tint(POISON_TINT)

func _clear_burn() -> void:
	burn_active = false
	burn_remaining_ticks = 0
	_burn_timer.stop()
	_update_visual()

func _clear_poison() -> void:
	poison_active = false
	poison_remaining_ticks = 0
	_poison_timer.stop()
	_update_visual()

## Oyuncunun sprite'ı Sprite2D (AnimatedSprite2D değil). Eskiden yalnızca AnimatedSprite2D
## aranıyordu, bu yüzden yanma/zehir/soğuk renkleri oyuncuda hiç görünmüyordu.
func _get_sprite() -> CanvasItem:
	if not _player:
		return null
	var s := _player.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if s == null:
		s = _player.get_node_or_null("Sprite2D") as CanvasItem
	return s

## Durum rengi `self_modulate` ile verilir, `modulate` ile DEĞİL: hasar alınca kırmızı flaş ve
## Hurt state'i `sprite.modulate`'ı sürekli beyaza sıfırlıyor (hurt_state.gd, player.gd), bu yüzden
## modulate ile verilen renk vurulduğu anda siliniyordu. self_modulate'a kimse dokunmuyor;
## ikisi çarpılarak birleşir (hasar flaşı + mavi = mor gibi).
func _status_tint() -> Color:
	if shock_active:
		return SHOCK_TINT
	if burn_active:
		return BURN_TINT
	if poison_active:
		return POISON_TINT
	if chill_active:
		return CHILL_TINT
	return Color.WHITE

func _update_visual() -> void:
	var sprite = _get_sprite()
	if not sprite:
		return
	sprite.self_modulate = _status_tint()

func _flash_tint(color: Color) -> void:
	var sprite = _get_sprite()
	if not sprite:
		return
	# Tick'te kısa bir parlama, sonra durum rengine geri dön
	sprite.self_modulate = Color(1.4, 1.4, 1.4, 1.0)
	var tw = create_tween()
	tw.tween_property(sprite, "self_modulate", _status_tint(), 0.15)

func is_burning() -> bool:
	return burn_active

func is_poisoned() -> bool:
	return poison_active
