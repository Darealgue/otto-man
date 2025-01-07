extends Control

const RECHARGE_RATE = 5.0  # Time in seconds to recharge one segment
const SEGMENTS = 3

var charges = [1.0, 1.0, 1.0]  # Current value of each charge (0.0 to 1.0)
var recharging_index = -1  # Which segment is currently recharging (-1 if none)

@onready var segments = [$Segments/Segment1, $Segments/Segment2, $Segments/Segment3]

func _ready():
	print("[StaminaBar] Initializing...")
	add_to_group("stamina_bar")
	update_segments()
	show()
	modulate.a = 1.0  # Start visible
	print("[StaminaBar] Ready - Visible:", visible, " Modulate:", modulate)

func _process(delta):
	if !visible:
		show()
		modulate.a = 1.0
		return
		
	if recharging_index >= 0:
		charges[recharging_index] = min(charges[recharging_index] + delta / RECHARGE_RATE, 1.0)
		if charges[recharging_index] >= 1.0:
			# Find next empty segment to recharge (starting from the beginning)
			recharging_index = -1
			for i in range(SEGMENTS):
				if charges[i] < 1.0:
					recharging_index = i
					break
		update_segments()

func show_bar():
	show()
	modulate.a = 1.0

func hide_bar():
	modulate.a = 0.5  # Keep slightly visible when full

func use_charge():
	# Find rightmost full charge
	for i in range(SEGMENTS - 1, -1, -1):
		if charges[i] >= 1.0:
			charges[i] = 0.0
			# Start recharging from leftmost empty segment if not already recharging
			if recharging_index == -1:
				for j in range(SEGMENTS):
					if charges[j] < 1.0:
						recharging_index = j
						break
			show_bar()
			update_segments()
			return true
	return false

func get_segment_priority(value: float) -> int:
	if value >= 1.0:  # Full
		return 0
	elif value > 0.0:  # Charging
		return 1
	else:  # Empty
		return 2

func sort_segments():
	# Create array of indices and values
	var segment_data = []
	for i in range(SEGMENTS):
		segment_data.append({"index": i, "value": charges[i]})
	
	# Sort based on priority
	segment_data.sort_custom(func(a, b):
		var priority_a = get_segment_priority(a.value)
		var priority_b = get_segment_priority(b.value)
		if priority_a == priority_b:
			# If same priority, higher value comes first
			return a.value > b.value
		return priority_a < priority_b
	)
	
	# Create new arrays with sorted values
	var new_charges = []
	var new_recharging_index = -1
	for i in range(SEGMENTS):
		var old_index = segment_data[i].index
		new_charges.append(charges[old_index])
		if old_index == recharging_index:
			new_recharging_index = i
	
	# Update the arrays
	charges = new_charges
	recharging_index = new_recharging_index

func update_segments():
	# Sort segments based on priority
	sort_segments()
	
	# Update visual segments
	for i in range(SEGMENTS):
		segments[i].value = charges[i]
		# Add glow effect when fully charged
		if charges[i] >= 1.0:
			segments[i].modulate = Color(1.0, 1.0, 1.0, 1.0)  # Full brightness
		else:
			segments[i].modulate = Color(0.7, 0.7, 0.7, 0.7)  # Dimmed when not full

func is_recharging():
	return recharging_index >= 0

func has_charges():
	for charge in charges:
		if charge >= 1.0:
			return true
	return false 
