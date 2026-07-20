extends Control
## Üst şeridin ortasındaki cam fanus — köy moralini sıvı seviyesiyle gösterir.
## Sıvı dolum seviyesi VillageManager.get_morale() (0-100) değerinden gelir.

@onready var liquid_rect: TextureRect = %LiquidRect
@onready var value_label: Label = %ValueLabel

const POLL_INTERVAL := 0.5
const FILL_LERP_SPEED := 2.5
const StatChangeFX = preload("res://ui/stat_change_fx.gd")

var _shader_material: ShaderMaterial
var _displayed_fill: float = 1.0
var _target_fill: float = 1.0
var _poll_accum: float = 0.0
## Zindandan dönünce moralin arka planda değiştiğini fark edebilmek için,
## gösterilen tam sayı değişince StatChangeFX ile sallanma + popup oynatılır.
var _prev_morale_int: int = -1


func _ready() -> void:
	TextOutline.apply_to_tree(self)
	_shader_material = liquid_rect.material as ShaderMaterial
	if VillageManager.has_signal("village_data_changed"):
		VillageManager.village_data_changed.connect(_refresh_target)
	_refresh_target()
	_displayed_fill = _target_fill
	_apply_shader_fill()


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL:
		_poll_accum = 0.0
		_refresh_target()
	if not is_equal_approx(_displayed_fill, _target_fill):
		_displayed_fill = move_toward(_displayed_fill, _target_fill, delta * FILL_LERP_SPEED)
		_apply_shader_fill()


func _refresh_target() -> void:
	var m: float = VillageManager.get_morale()
	_target_fill = clampf(m / 100.0, 0.0, 1.0)
	if is_instance_valid(value_label):
		var m_int := int(round(m))
		value_label.text = "%d/100" % m_int
		if _prev_morale_int >= 0 and m_int != _prev_morale_int:
			StatChangeFX.bump(value_label, m_int - _prev_morale_int)
		_prev_morale_int = m_int


func _apply_shader_fill() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("fill_level", _displayed_fill)
