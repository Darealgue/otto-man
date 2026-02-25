extends Control

@onready var health_bar = $HealthBar
@onready var delayed_bar = $DelayedBar
@onready var background = $Background
@onready var border_frame = $BorderFrame
@onready var fade_timer = $FadeTimer

const FADE_DELAY = 2.0  # Seconds before bar starts fading
const FADE_DURATION = 0.5  # How long the fade out takes
const DELAYED_BAR_SPEED = 0.8  # How fast delayed bar catches up
const STATUS_ICON_SIZE := 10
const STATUS_FONT_SIZE := 8
const LEVEL_FONT_SIZE := 8
const LEVEL_NUMBER_FONT_SIZE := 12

var max_health: float = 100.0
var current_health: float = 100.0
var delayed_health: float = 100.0
var is_visible: bool = false

# Üst satır: solda Lv X, sağda debuff ikonları
var _top_row: HBoxContainer = null
var _level_label: Label = null
var _level_number_label: Label = null
var _status_container: HBoxContainer = null
var _poison_icon: Control = null
var _burn_icon: Control = null
var _frost_icon: Control = null

func _ready() -> void:
	# Start invisible
	modulate.a = 0.0
	fade_timer.timeout.connect(_on_fade_timer_timeout)
	
	# Set pivot points for proper scaling
	health_bar.pivot_offset = Vector2(0, health_bar.size.y / 2)
	delayed_bar.pivot_offset = Vector2(0, delayed_bar.size.y / 2)
	
	_build_status_icons()

func _build_status_icons() -> void:
	# Üst satır: solda Lv X, sağda debuff ikonları
	_top_row = HBoxContainer.new()
	_top_row.position = Vector2(-28, -STATUS_ICON_SIZE - 5)
	_top_row.add_theme_constant_override("separation", 4)
	add_child(_top_row)
	
	# Sol: seviye yazısı (Lv + sayı; sayı daha büyük)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", LEVEL_FONT_SIZE)
	_level_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_level_label.add_theme_constant_override("outline_size", 1)
	_level_label.text = "Lv "
	_top_row.add_child(_level_label)
	_level_number_label = Label.new()
	_level_number_label.add_theme_font_size_override("font_size", LEVEL_NUMBER_FONT_SIZE)
	_level_number_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_level_number_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_level_number_label.add_theme_constant_override("outline_size", 1)
	_level_number_label.text = "1"
	_top_row.add_child(_level_number_label)
	
	# Sağ: debuff ikonları
	_status_container = HBoxContainer.new()
	_status_container.add_theme_constant_override("separation", 2)
	_poison_icon = _make_status_icon(Color(0.2, 0.9, 0.3))
	_burn_icon = _make_status_icon(Color(1.0, 0.4, 0.1))
	_frost_icon = _make_status_icon(Color(0.5, 0.8, 1.0))
	_status_container.add_child(_poison_icon)
	_status_container.add_child(_burn_icon)
	_status_container.add_child(_frost_icon)
	_top_row.add_child(_status_container)
	
	set_level(1)
	update_status_effects(0, 0, 0)
	# Lv satırı debuff olmasa da her zaman görünsün (bar görünür olduğunda)
	_top_row.visible = true

func _make_status_icon(icon_color: Color) -> Control:
	var wrap = Control.new()
	wrap.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	wrap.size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	
	var rect = ColorRect.new()
	rect.size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	rect.position = Vector2.ZERO
	rect.color = icon_color
	rect.name = "Icon"
	wrap.add_child(rect)
	
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 1)
	label.position = Vector2(STATUS_ICON_SIZE - 6, -3)
	label.size = Vector2(10, 8)
	label.text = ""
	label.name = "Count"
	wrap.add_child(label)
	return wrap

func _get_status_label(icon_control: Control) -> Label:
	var c = icon_control.get_node_or_null("Count")
	return c as Label if c else null

func set_level(level: int) -> void:
	if _level_number_label:
		_level_number_label.text = str(level)

func update_status_effects(poison_stacks: int, burn_remaining_ticks: int, frost_stacks: int) -> void:
	if _status_container == null:
		return
	
	var burn_stacks := int(ceil(min(burn_remaining_ticks, 9) / 3.0))
	var has_debuff := poison_stacks > 0 or burn_stacks > 0 or frost_stacks > 0
	if has_debuff:
		show_bar()
	
	var p_label = _get_status_label(_poison_icon)
	var b_label = _get_status_label(_burn_icon)
	var f_label = _get_status_label(_frost_icon)
	
	if p_label:
		_poison_icon.visible = poison_stacks > 0
		p_label.text = str(poison_stacks) if poison_stacks > 0 else ""
	if b_label:
		_burn_icon.visible = burn_stacks > 0
		b_label.text = str(burn_stacks) if burn_stacks > 0 else ""
	if f_label:
		_frost_icon.visible = frost_stacks > 0
		f_label.text = str(frost_stacks) if frost_stacks > 0 else ""
	
	_status_container.visible = has_debuff
	# Üst satır her zaman görünsün (en azından Lv yazısı için)
	if _top_row:
		_top_row.visible = true

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