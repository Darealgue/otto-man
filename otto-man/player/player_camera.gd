extends Camera2D

# Horizontal look-ahead: shows a bit more of the direction the player is running towards.

@export var look_ahead_x: float = 140.0
## Aynı yönde hızlanıp ofset uzaklaşırken eski yavaş/yumuşak his (üstel yumuşatma).
@export var look_ahead_smooth_speed_extend: float = 1.6
## Oyuncu yön değiştirdiğinde (dönüşte) ofset bir uçtan diğer uca kaç saniyede gitsin.
## Üstel yumuşatma hedefe yaklaştıkça yavaşlayıp asla tam oturmuyordu, bu da pixel-art'ta
## titreme olarak görünüyordu — dönüşte move_toward ile SABİT hızda gidip hedefe tam oturuyor.
@export var look_ahead_full_swing_duration: float = 0.3

var _player: CharacterBody2D
var _offset_x: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var reference_speed: float = _player.speed if "speed" in _player else 400.0
	var target_x: float = 0.0
	if reference_speed > 0.0:
		target_x = clamp(_player.velocity.x / reference_speed, -1.0, 1.0) * look_ahead_x
	# Yön değişimini (dönüş) tespit et: hedef ile mevcut ofset ters işaretteyse hızlı/sabit geçiş uygula.
	var is_turning: bool = sign(target_x) != sign(_offset_x) and absf(target_x) > 0.001 and absf(_offset_x) > 0.001
	if is_turning:
		var rate: float = (2.0 * look_ahead_x) / maxf(look_ahead_full_swing_duration, 0.001)
		_offset_x = move_toward(_offset_x, target_x, rate * delta)
	else:
		var k: float = 1.0 - exp(-look_ahead_smooth_speed_extend * delta)
		_offset_x = lerp(_offset_x, target_x, clampf(k, 0.0, 1.0))
	offset.x = _offset_x
