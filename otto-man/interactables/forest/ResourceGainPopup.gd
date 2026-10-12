class_name ResourceGainPopup
extends Node2D
## Kaynak toplandığında oyuncunun başında beliren "+N" ve kaynak ikonu. Kısa süre içinde aynı türden
## birden fazla toplanırsa yeni yazı açılmaz, mevcut sayı büyür (+1 +1 +1 yerine +3). Farklı
## türlerin yazıları üst üste dizilir. Son toplamadan HOLD_SECONDS sonra yukarı süzülüp solar.

const HOLD_SECONDS: float = 0.9
const FADE_SECONDS: float = 0.35
const RISE_PX: float = 26.0
const HEAD_OFFSET: Vector2 = Vector2(0.0, -120.0)
const SLOT_SPACING: float = 34.0
const FONT_SIZE: int = 24
const ICON_PATH := "res://assets/Icons/%s_icon.png"
const ICON_SCALE: float = 1.3
const TEXT_COLOR: Color = Color(1.0, 0.92, 0.25, 1.0)

## tür -> yaşayan popup. Biten popup kayıttan düşer.
static var _active: Dictionary = {}

var resource_type: String = ""
var _amount: int = 0
var _idle: float = 0.0
var _ending: bool = false
var _slot: int = 0
var _follow: Node2D = null
var _label: Label = null
var _content: Node2D = null
var _punch: Tween = null


## Oyuncunun (veya takip edilecek herhangi bir Node2D'nin) başında `amount` kaynak kazanımı gösterir.
static func show_gain(target: Node2D, type: String, amount: int) -> void:
	if target == null or not is_instance_valid(target) or amount == 0:
		return
	var existing: Variant = _active.get(type, null)
	if existing != null and is_instance_valid(existing) and not (existing as ResourceGainPopup)._ending:
		(existing as ResourceGainPopup).add(amount)
		return
	var tree := target.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var popup := ResourceGainPopup.new()
	popup.resource_type = type
	popup._follow = target
	popup._slot = _count_live()
	_active[type] = popup
	tree.current_scene.add_child(popup)
	popup.add(amount)


static func _count_live() -> int:
	var n := 0
	for key in _active.keys():
		var p: Variant = _active[key]
		if p != null and is_instance_valid(p) and not (p as ResourceGainPopup)._ending:
			n += 1
	return n


func _ready() -> void:
	z_index = 200
	_content = Node2D.new()
	add_child(_content)
	var icon_path: String = ICON_PATH % resource_type
	var icon_w: float = 0.0
	if ResourceLoader.exists(icon_path):
		var icon := Sprite2D.new()
		icon.texture = load(icon_path) as Texture2D
		icon.scale = Vector2.ONE * ICON_SCALE
		if icon.texture != null:
			icon_w = float(icon.texture.get_width()) * ICON_SCALE
		icon.position = Vector2(-icon_w * 0.5 - 4.0, 0.0)
		_content.add_child(icon)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(4.0, -FONT_SIZE * 0.75)
	_label.text = "+%d" % _amount
	_content.add_child(_label)
	_update_position()


func add(amount: int) -> void:
	_amount += amount
	_idle = 0.0
	if _label != null:
		_label.text = "+%d" % _amount
	# Her eklemede küçük bir "vurgu" sıçraması.
	if _content != null:
		if _punch != null and _punch.is_valid():
			_punch.kill()
		_content.scale = Vector2(1.3, 1.3)
		_punch = create_tween()
		_punch.tween_property(_content, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _follow == null or not is_instance_valid(_follow):
		_finish()
		return
	_update_position()
	if _ending:
		return
	_idle += delta
	if _idle >= HOLD_SECONDS:
		_begin_fade()


func _update_position() -> void:
	if _follow == null or not is_instance_valid(_follow):
		return
	global_position = _follow.global_position + HEAD_OFFSET + Vector2(0.0, -float(_slot) * SLOT_SPACING)


func _begin_fade() -> void:
	_ending = true
	if _active.get(resource_type, null) == self:
		_active.erase(resource_type)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_content, "position:y", -RISE_PX, FADE_SECONDS)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _finish() -> void:
	if _active.get(resource_type, null) == self:
		_active.erase(resource_type)
	queue_free()
