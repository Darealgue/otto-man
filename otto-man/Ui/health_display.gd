extends Control

@onready var health_label = $BarContainer/HealthLabel
@onready var health_bar = $BarContainer/HealthBar
@onready var delayed_bar = $BarContainer/DelayedHealthBar

const DELAYED_BAR_SPEED = 2.0  # Speed at which delayed bar catches up
const FLASH_DURATION = 0.1     # Duration of flash effect
const FLASH_INTENSITY = 1.5    # Intensity of flash effect

var delayed_health: float = 100.0
var player_stats: Node

func _ready() -> void:
	
	# Force visibility
	show()
	modulate.a = 1.0
	
	
	# Verify UI components
	
	if !health_label or !health_bar or !delayed_bar:
		push_error("[HealthDisplay] Missing UI components!")
		return
		
	# Get PlayerStats singleton
	player_stats = get_node("/root/PlayerStats")
	
	if !player_stats:
		push_error("[HealthDisplay] PlayerStats singleton not found!")
		return
		
	# Initialize values from PlayerStats
	var current_health = player_stats.get_current_health()
	var max_health = player_stats.get_max_health()
	
	update_health_display(current_health, max_health)
	
	# Connect to PlayerStats signals
	if !player_stats.health_changed.is_connected(_on_health_changed):
		player_stats.health_changed.connect(_on_health_changed, CONNECT_DEFERRED)
	if !player_stats.stat_changed.is_connected(_on_stat_changed):
		player_stats.stat_changed.connect(_on_stat_changed, CONNECT_DEFERRED)

func _process(delta: float) -> void:
	if !visible:
		show()
		modulate.a = 1.0
		return
		
	if !health_bar or !delayed_bar:
		return
		
	# Update delayed bar
	if delayed_health > health_bar.value:
		delayed_health = move_toward(delayed_health, health_bar.value, player_stats.get_max_health() * DELAYED_BAR_SPEED * delta)
		delayed_bar.value = delayed_health

func _on_health_changed(new_health: float) -> void:
	if player_stats:
		update_health_display(new_health, player_stats.get_max_health())

func _on_stat_changed(stat_name: String, _old_value: float, new_value: float) -> void:
	if stat_name == "max_health" and player_stats:
		update_health_display(player_stats.get_current_health(), new_value)

func update_health_display(current_health: float, max_health: float) -> void:
	
	if !health_label or !health_bar or !delayed_bar:
		push_error("[HealthDisplay] Missing UI components during update!")
		return
		
	# Update label
	health_label.text = "%d/%d" % [current_health, max_health]
	
	# Update progress bars
	health_bar.max_value = max_health
	delayed_bar.max_value = max_health
	health_bar.value = current_health
	
	# Handle delayed bar updates
	if current_health < delayed_bar.value:
		delayed_health = delayed_bar.value
		modulate = Color(FLASH_INTENSITY, 1, 1)
		create_tween().tween_property(self, "modulate", Color.WHITE, FLASH_DURATION)
	elif current_health > delayed_bar.value:
		delayed_health = current_health
		delayed_bar.value = current_health
		modulate = Color(1, FLASH_INTENSITY, 1)
		create_tween().tween_property(self, "modulate", Color.WHITE, FLASH_DURATION)
	
	# Update bar color based on health percentage
	var health_percent = current_health / max_health
	var bar_style = health_bar.get_theme_stylebox("fill")
	
	if health_percent <= 0.2:
		bar_style.bg_color = Color(0.8, 0.0, 0.0)  # Red
	elif health_percent <= 0.5:
		bar_style.bg_color = Color(0.8, 0.4, 0.0)  # Orange
	else:
		bar_style.bg_color = Color(0.0, 0.8, 0.0)  # Green
