extends Control

const RECHARGE_RATE = 10.0  # Time in seconds to recharge one segment
const SEGMENTS = 3

var charges = [1.0, 1.0, 1.0]  # Current value of each charge (0.0 to 1.0)
var recharging_index = -1  # Which segment is currently recharging (-1 if none)

@onready var segments = [$Segments/Segment1, $Segments/Segment2, $Segments/Segment3]

func _ready():
	print("[DEBUG] Stamina bar _ready called")
	add_to_group("stamina_bar")
	update_segments()
	modulate.a = 0.0  # Start invisible
	print("[DEBUG] Stamina bar initialized with segments: ", segments.size())
	print("[DEBUG] Initial charges: ", charges)
	print("[DEBUG] Initial visibility: ", modulate.a)

func _process(delta):
	if recharging_index >= 0:
		charges[recharging_index] = min(charges[recharging_index] + delta / RECHARGE_RATE, 1.0)
		if charges[recharging_index] >= 1.0:
			if recharging_index < SEGMENTS - 1 and charges[recharging_index + 1] < 1.0:
				recharging_index += 1  # Move to next segment
			else:
				recharging_index = -1  # Done recharging
				hide_bar()  # Hide when fully recharged
		update_segments()

func use_charge():
	# Find rightmost full charge
	for i in range(SEGMENTS - 1, -1, -1):
		if charges[i] >= 1.0:
			charges[i] = 0.0
			if recharging_index == -1:  # Start recharging if not already
				recharging_index = i
			show_bar()  # Show when using charges
			update_segments()
			print("[DEBUG] Used charge ", i, ", remaining charges: ", charges)
			return true
	print("[DEBUG] No charges available")
	return false  # No charges available

func update_segments():
	for i in range(SEGMENTS):
		segments[i].value = charges[i]
		# Add glow effect when fully charged
		if charges[i] >= 1.0:
			segments[i].modulate = Color(1.0, 1.0, 1.0, 1.0)  # Full brightness
		else:
			segments[i].modulate = Color(0.7, 0.7, 0.7, 0.7)  # Dimmed when not full

func show_bar():
	modulate.a = 1.0

func hide_bar():
	modulate.a = 0.0  # Make fully invisible when not in use

func is_recharging():
	return recharging_index >= 0

func has_charges():
	for charge in charges:
		if charge >= 1.0:
			return true
	return false 