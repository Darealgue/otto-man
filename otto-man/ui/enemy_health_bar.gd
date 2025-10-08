extends Control

@onready var health_bar = $HealthBar
@onready var delayed_bar = $DelayedBar
@onready var background = $Background
@onready var border_frame = $BorderFrame
@onready var fade_timer = $FadeTimer

const FADE_DELAY = 2.0  # Seconds before bar starts fading
const FADE_DURATION = 0.5  # How long the fade out takes
const DELAYED_BAR_SPEED = 0.8  # How fast delayed bar catches up

var max_health: float = 100.0
var current_health: float = 100.0
var delayed_health: float = 100.0
var is_visible: bool = false

func _ready() -> void:
	# Start invisible
	modulate.a = 0.0
	fade_timer.timeout.connect(_on_fade_timer_timeout)
	
	# Set pivot points for proper scaling
	health_bar.pivot_offset = Vector2(0, health_bar.size.y / 2)
	delayed_bar.pivot_offset = Vector2(0, delayed_bar.size.y / 2)

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
	is_visible = true
	
	# Tüm elementlerin rengini sıfırla
	if health_bar:
		health_bar.modulate = Color(1, 1, 1, 1.0)
	if delayed_bar:
		delayed_bar.modulate = Color(1, 1, 1, 1.0)
	if background:
		background.modulate = Color(1, 1, 1, 1.0)
	if border_frame:
		border_frame.modulate = Color(1, 1, 1, 1.0)
	
	# Create fade in tween
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Reset fade timer
	fade_timer.start(FADE_DELAY)

func hide_bar() -> void:
	is_visible = false
	
	# Stop fade timer
	fade_timer.stop()
	
	# Anında gizle ve tüm alt elementleri de gizle (tween olmadan)
	modulate = Color(1, 1, 1, 0.0)  # Ana container'ı şeffaf yap
	
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