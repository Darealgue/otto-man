extends Control

@onready var health_label = $BarContainer/HealthLabel
@onready var health_bar = $BarContainer/HealthBar
@onready var delayed_bar = $BarContainer/DelayedHealthBar
@onready var player = get_tree().get_first_node_in_group("player")

const DELAYED_BAR_SPEED = 0.3  # How fast the delayed bar catches up (units per second)
const HIT_SEQUENCE_WINDOW = 1.0  # Time to wait after last hit before starting slide
const INITIAL_SLIDE_DELAY = 0.3  # Small delay before starting slide after hit sequence

var delayed_health: float = 100.0
var time_since_last_hit: float = 0.0
var is_hit_sequence_active: bool = false
var slide_delay_active: bool = false

func _ready():
	if !health_label or !health_bar or !delayed_bar:
		push_error("Required nodes not found! Make sure all nodes exist as children of BarContainer.")
		return
		
	if !player:
		push_error("Player not found! Make sure the player is in the 'player' group.")
		return
		
	player.health_changed.connect(_on_player_health_changed)
	update_health_display(player.health)

func _process(delta: float):
	if is_hit_sequence_active:
		time_since_last_hit += delta
		
		# Check if hit sequence has ended
		if time_since_last_hit >= HIT_SEQUENCE_WINDOW:
			is_hit_sequence_active = false
			slide_delay_active = true
			time_since_last_hit = 0.0
	elif slide_delay_active:
		time_since_last_hit += delta
		if time_since_last_hit >= INITIAL_SLIDE_DELAY:
			slide_delay_active = false
	# Only update delayed bar if not in hit sequence and delay is over
	elif delayed_health > health_bar.value:
		delayed_health = move_toward(delayed_health, health_bar.value, player.max_health * DELAYED_BAR_SPEED * delta)
		delayed_bar.value = delayed_health

func _on_player_health_changed(new_health: float):
	update_health_display(new_health)

func update_health_display(current_health: float):
	if health_label and health_bar and delayed_bar:
		# Update text
		health_label.text = "%d/%d" % [current_health, player.max_health]
		
		# Update bars
		health_bar.max_value = player.max_health
		delayed_bar.max_value = player.max_health
		health_bar.value = current_health
		
		# Handle hit sequence
		if current_health < delayed_bar.value:
			# If this is the first hit or we're outside the hit sequence window
			if !is_hit_sequence_active:
				delayed_health = delayed_bar.value  # Store the pre-hit health
			
			# Reset hit sequence timer and activate sequence
			time_since_last_hit = 0.0
			is_hit_sequence_active = true
		elif current_health > delayed_bar.value:
			# If health increased (healing), update delayed bar immediately
			delayed_health = current_health
			delayed_bar.value = current_health
			is_hit_sequence_active = false
			slide_delay_active = false
		
		# Update bar color based on health percentage
		var health_percent = current_health / player.max_health
		var bar_style = health_bar.get_theme_stylebox("fill")
		
		if health_percent <= 0.2:  # Below 20% health
			bar_style.bg_color = Color(0.8, 0.0, 0.0, 1.0)  # Bright red
			bar_style.border_color = Color(1.0, 0.2, 0.2, 1.0)
		elif health_percent <= 0.5:  # Below 50% health
			bar_style.bg_color = Color(0.8, 0.4, 0.0, 1.0)  # Orange
			bar_style.border_color = Color(1.0, 0.6, 0.2, 1.0)
		else:  # Above 50% health
			bar_style.bg_color = Color(0.8, 0.2, 0.2, 1.0)  # Normal red
			bar_style.border_color = Color(1.0, 0.4, 0.4, 1.0)
