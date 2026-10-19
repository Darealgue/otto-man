extends Control

@onready var health_bar = $HealthBar
@onready var delayed_bar = $DelayedBar
@onready var background = $Background
@onready var border_frame = $BorderFrame
@onready var fade_timer = $FadeTimer

const FADE_DELAY = 2.0  # Seconds before bar starts fading
const FADE_DURATION = 0.5  # How long the fade out takes
const DELAYED_BAR_SPEED = 0.8  # How fast delayed bar catches up
const _StatusBadge = preload("res://ui/status_badge.gd")
const STATUS_ICON_SIZE := 16
const LEVEL_FONT_SIZE := 10
const LEVEL_NUMBER_FONT_SIZE := 14
# Bar boyutu (ölçü sahnedeki 50x6'dan biraz büyütüldü; bar ortalı)
const BAR_HALF_WIDTH := 28.0
const BAR_HALF_HEIGHT := 4.0
const BAR_FILL_COLOR := Color(0.86, 0.13, 0.13, 1.0)
const BAR_BACK_COLOR := Color(0.07, 0.03, 0.03, 0.88)

var max_health: float = 100.0
var current_health: float = 100.0
var delayed_health: float = 100.0
var is_visible: bool = false

# Üst satır: solda Lv X, sağda yuvarlak debuff göstergeleri (içinde stack sayısı)
var _top_row: HBoxContainer = null
var _level_label: Label = null
var _level_number_label: Label = null
var _status_container: HBoxContainer = null
var _poison_icon: Control = null
var _burn_icon: Control = null
var _frost_icon: Control = null
var _lightning_icon: Control = null

# Kalkan Modu (affix) bar'ı: ana can barının hemen üstünde ince mavi bir şerit
var _shield_bg: ColorRect = null
var _shield_bar: ColorRect = null
const SHIELD_BAR_HEIGHT := 3.0
const SHIELD_BAR_Y_OFFSET := -7.0

func _ready() -> void:
	# Start invisible
	modulate.a = 0.0
	fade_timer.timeout.connect(_on_fade_timer_timeout)

	# Set pivot points for proper scaling
	health_bar.pivot_offset = Vector2(0, health_bar.size.y / 2)
	delayed_bar.pivot_offset = Vector2(0, delayed_bar.size.y / 2)

	_style_bar()
	_build_status_icons()
	_build_shield_bar()

## Barı biraz büyütür, koyu zemin + üstte ince parlak şerit (cam efekti) ile okunur yapar.
func _style_bar() -> void:
	offset_left = -BAR_HALF_WIDTH
	offset_right = BAR_HALF_WIDTH
	offset_top = -BAR_HALF_HEIGHT
	offset_bottom = BAR_HALF_HEIGHT
	health_bar.color = BAR_FILL_COLOR
	background.color = BAR_BACK_COLOR
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.28)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_child(shine)
	shine.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shine.offset_bottom = 2.0

func _build_shield_bar() -> void:
	_shield_bg = ColorRect.new()
	_shield_bg.position = Vector2(-BAR_HALF_WIDTH, SHIELD_BAR_Y_OFFSET)
	_shield_bg.size = Vector2(BAR_HALF_WIDTH * 2.0, SHIELD_BAR_HEIGHT)
	_shield_bg.color = Color(0, 0, 0, 0.8)
	_shield_bg.visible = false
	add_child(_shield_bg)

	_shield_bar = ColorRect.new()
	_shield_bar.position = Vector2(-BAR_HALF_WIDTH + 1.0, SHIELD_BAR_Y_OFFSET + 0.5)
	_shield_bar.size = Vector2(BAR_HALF_WIDTH * 2.0 - 2.0, SHIELD_BAR_HEIGHT - 1.0)
	_shield_bar.color = Color(0.35, 0.75, 1.0, 1.0)
	_shield_bar.pivot_offset = Vector2(0, 0)
	_shield_bar.visible = false
	add_child(_shield_bar)

## Kalkan durumunu göster/güncelle. max_shield <= 0 ise bar'ı gizler.
func set_shield(current: float, max_shield: float) -> void:
	if _shield_bg == null or _shield_bar == null:
		return
	var has_shield := max_shield > 0.0
	_shield_bg.visible = has_shield
	_shield_bar.visible = has_shield
	if has_shield:
		show_bar()
		_shield_bar.scale.x = clampf(current / max_shield, 0.0, 1.0)

func hide_shield() -> void:
	if _shield_bg:
		_shield_bg.visible = false
	if _shield_bar:
		_shield_bar.visible = false

func _build_status_icons() -> void:
	# Üst satır: solda Lv X, sağda debuff ikonları
	_top_row = HBoxContainer.new()
	_top_row.position = Vector2(-BAR_HALF_WIDTH, -STATUS_ICON_SIZE - 9)
	_top_row.add_theme_constant_override("separation", 7)
	add_child(_top_row)

	# Sol: seviye çipi (koyu yuvarlak köşeli zemin üstünde "Lv" + büyük sayı)
	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.05, 0.04, 0.04, 0.78)
	chip_style.border_color = Color(0.0, 0.0, 0.0, 0.9)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(5)
	chip_style.content_margin_left = 5
	chip_style.content_margin_right = 5
	chip_style.content_margin_top = 0
	chip_style.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 2)
	chip.add_child(chip_row)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", LEVEL_FONT_SIZE)
	_level_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_level_label.add_theme_constant_override("outline_size", 2)
	_level_label.text = "Lv"
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip_row.add_child(_level_label)
	_level_number_label = Label.new()
	_level_number_label.add_theme_font_size_override("font_size", LEVEL_NUMBER_FONT_SIZE)
	_level_number_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	_level_number_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_level_number_label.add_theme_constant_override("outline_size", 3)
	_level_number_label.text = "1"
	_level_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip_row.add_child(_level_number_label)
	_top_row.add_child(chip)

	# Sağ: yuvarlak debuff göstergeleri (sadece aktif olanlar görünür, satır kendini daraltır)
	_status_container = HBoxContainer.new()
	_status_container.add_theme_constant_override("separation", 3)
	_poison_icon = _make_status_icon(Color(0.2, 0.75, 0.3))
	_burn_icon = _make_status_icon(Color(0.95, 0.4, 0.1))
	_frost_icon = _make_status_icon(Color(0.35, 0.65, 0.95))
	_lightning_icon = _make_status_icon(Color(0.85, 0.7, 0.1))
	_status_container.add_child(_poison_icon)
	_status_container.add_child(_burn_icon)
	_status_container.add_child(_frost_icon)
	_status_container.add_child(_lightning_icon)
	_top_row.add_child(_status_container)

	set_level(1)
	update_status_effects(0, 0, 0)
	# Lv satırı debuff olmasa da her zaman görünsün (bar görünür olduğunda)
	_top_row.visible = true

func _make_status_icon(icon_color: Color) -> Control:
	var badge: Control = _StatusBadge.new()
	badge.setup(icon_color)
	badge.visible = false
	return badge

func set_level(level: int) -> void:
	if _level_number_label:
		_level_number_label.text = str(level)

## Göstergeler: yuvarlak + içinde stack sayısı. pulses = {"poison"/"fire"/"frost"/"lightning": bool}:
## o elementin 5 stack etkisi sürerken gösterge büyüyüp parlar (stack sayısı sıfırlansa bile görünür kalır).
## burn_hits >= 0 ise ateş sayısı olarak o gösterilir (5'te kalkan erir), değilse yanma tikinden türetilir.
func update_status_effects(poison_stacks: int, burn_remaining_ticks: int, frost_stacks: int, lightning_stacks: int = 0, pulses: Dictionary = {}, burn_hits: int = -1) -> void:
	if _status_container == null:
		return

	var burn_count := burn_hits if burn_hits >= 0 else int(ceil(min(burn_remaining_ticks, 9) / 3.0))
	var burning := burn_remaining_ticks > 0
	var pulse_poison: bool = pulses.get("poison", false)
	var pulse_fire: bool = pulses.get("fire", false)
	var pulse_frost: bool = pulses.get("frost", false)
	var pulse_lightning: bool = pulses.get("lightning", false)

	var show_poison := poison_stacks > 0 or pulse_poison
	var show_burn := burning or pulse_fire
	var show_frost := frost_stacks > 0 or pulse_frost
	var show_lightning := lightning_stacks > 0 or pulse_lightning
	var has_debuff := show_poison or show_burn or show_frost or show_lightning
	if has_debuff:
		show_bar()

	_apply_badge(_poison_icon, show_poison, poison_stacks, pulse_poison)
	_apply_badge(_burn_icon, show_burn, burn_count, pulse_fire)
	_apply_badge(_frost_icon, show_frost, frost_stacks, pulse_frost)
	_apply_badge(_lightning_icon, show_lightning, lightning_stacks, pulse_lightning)

	_status_container.visible = has_debuff
	# Üst satır her zaman görünsün (en azından Lv yazısı için)
	if _top_row:
		_top_row.visible = true

func _apply_badge(badge: Control, shown: bool, count: int, pulse: bool) -> void:
	if badge == null:
		return
	badge.visible = shown
	badge.set_count(count)
	badge.set_pulse(pulse and shown)

func _process(delta: float) -> void:
	if !is_visible:
		return

	# Update delayed bar
	if delayed_health > current_health:
		delayed_health = move_toward(delayed_health, current_health, max_health * DELAYED_BAR_SPEED * delta)
		_update_bars()

func setup(initial_health: float) -> void:
	max_health = initial_health
	current_health = initial_health
	delayed_health = initial_health
	_update_bars()

func update_health(new_health: float) -> void:
	if new_health < current_health:
		# Show bar when damaged
		show_bar()

	current_health = new_health
	_update_bars()

func _update_bars() -> void:
	var health_ratio = current_health / max_health
	var delayed_ratio = delayed_health / max_health

	# Update bar sizes from left to right
	health_bar.scale.x = max(0, health_ratio)
	delayed_bar.scale.x = max(0, delayed_ratio)

	# Keep original height
	health_bar.scale.y = 1.0
	delayed_bar.scale.y = 1.0

func show_bar() -> void:
	var was_visible = is_visible and modulate.a >= 0.99
	is_visible = true
	visible = true
	if _top_row:
		_top_row.visible = true

	# Reset fade timer (debuff varken her frame çağrılabilir; timer yenilensin)
	fade_timer.start(FADE_DELAY)

	if was_visible:
		return
	# İlk gösterimde renk + tween
	if health_bar:
		health_bar.modulate = Color(1, 1, 1, 1.0)
	if delayed_bar:
		delayed_bar.modulate = Color(1, 1, 1, 1.0)
	if background:
		background.modulate = Color(1, 1, 1, 1.0)
	if border_frame:
		border_frame.modulate = Color(1, 1, 1, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_bar() -> void:
	is_visible = false

	# Stop fade timer
	fade_timer.stop()

	# Lv + debuff satırını da gizle (ölünce ortada kalmasın)
	if _top_row:
		_top_row.visible = false

	# Ana node'u tamamen gizle
	visible = false
	modulate = Color(1, 1, 1, 0.0)

	# Tüm elementleri gizle
	if health_bar:
		health_bar.modulate = Color(1, 1, 1, 0.0)
	if delayed_bar:
		delayed_bar.modulate = Color(1, 1, 1, 0.0)
	if background:
		background.modulate = Color(1, 1, 1, 0.0)
	if border_frame:
		border_frame.modulate = Color(1, 1, 1, 0.0)

func _on_fade_timer_timeout() -> void:
	# Create fade out tween
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func(): is_visible = false)
