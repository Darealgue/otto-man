extends Control

const RECHARGE_RATE = 5.0  # Time in seconds to recharge one segment
const MAX_SEGMENTS = 6  # Maximum number of segments we can show

var charges = [1.0, 1.0, 1.0]  # Current value of each charge (0.0 to 1.0)
var recharging_index = -1  # Which segment is currently recharging (-1 if none)
var player_stats = null
var segments = []  # Dynamic segments array

func _ready():
	add_to_group("stamina_bar")
	
	# Initialize segments array with existing segments
	segments = [$Segments/Segment1, $Segments/Segment2, $Segments/Segment3]
	
	# Connect to PlayerStats
	player_stats = get_node("/root/PlayerStats")
	if player_stats:
		player_stats.stat_changed.connect(_on_stat_changed)
		# Wait one frame to ensure PlayerStats is fully initialized
		await get_tree().process_frame
		_sync_with_player_stats()
	
	update_segments()
	show()
	modulate.a = 1.0  # Start visible

func _process(delta):
	if !visible:
		show()
		modulate.a = 1.0
		return
		
	if recharging_index >= 0 and recharging_index < charges.size():
		charges[recharging_index] = min(charges[recharging_index] + delta / RECHARGE_RATE, 1.0)
		if charges[recharging_index] >= 1.0:
			# Find next empty segment to recharge (starting from the beginning)
			recharging_index = -1
			var block_charges = int(player_stats.get_stat("block_charges")) if player_stats else 3
			var visible_segments = min(block_charges, segments.size())
			
			for i in range(visible_segments):
				if i < charges.size() and charges[i] < 1.0:
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
	var block_charges = int(player_stats.get_stat("block_charges")) if player_stats else 3
	var visible_segments = min(block_charges, segments.size())
	
	for i in range(visible_segments - 1, -1, -1):
		if i < charges.size() and charges[i] >= 1.0:
			charges[i] = 0.0
			# Start recharging from leftmost empty segment if not already recharging
			if recharging_index == -1:
				for j in range(visible_segments):
					if j < charges.size() and charges[j] < 1.0:
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
	for i in range(charges.size()):
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
	for i in range(charges.size()):
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
	var block_charges = int(player_stats.get_stat("block_charges")) if player_stats else 3
	var visible_segments = min(block_charges, segments.size())
	
	for i in range(segments.size()):
		if i < visible_segments:
			segments[i].show()
			segments[i].value = charges[i] if i < charges.size() else 0.0
			# Add glow effect when fully charged
			if i < charges.size() and charges[i] >= 1.0:
				segments[i].modulate = Color(1.0, 1.0, 1.0, 1.0)  # Full brightness
			else:
				segments[i].modulate = Color(0.7, 0.7, 0.7, 0.7)  # Dimmed when not full
		else:
			segments[i].hide()

func is_recharging():
	return recharging_index >= 0

func has_charges():
	var block_charges = int(player_stats.get_stat("block_charges")) if player_stats else 3
	var visible_segments = min(block_charges, segments.size())
	
	for i in range(visible_segments):
		if i < charges.size() and charges[i] >= 1.0:
			return true
	return false

func _on_stat_changed(stat_name: String, _old_value: float, new_value: float) -> void:
	if stat_name == "block_charges":
		_sync_with_player_stats()

func _sync_with_player_stats() -> void:
	if !player_stats:
		return
	
	var block_charges = int(player_stats.get_stat("block_charges"))
	var new_segments = max(1, block_charges)  # Minimum 1 segment
	
	print("[StaminaBar] Syncing with PlayerStats - block_charges: " + str(block_charges) + ", new_segments: " + str(new_segments))
	
	# Resize charges array if needed
	if charges.size() != new_segments:
		var old_charges = charges.duplicate()
		charges.resize(new_segments)
		
		# Copy existing values and fill new ones
		for i in range(charges.size()):
			if i < old_charges.size():
				charges[i] = old_charges[i]  # Keep existing values
			else:
				charges[i] = 1.0  # New segments start full
	
	# Update segments UI
	_update_segments_ui()
	update_segments()
	
	print("[StaminaBar] Sync complete - charges: " + str(charges))

func _update_segments_ui() -> void:
	# Hide/show segments based on block_charges
	var block_charges = int(player_stats.get_stat("block_charges")) if player_stats else 3
	var needed_segments = min(block_charges, MAX_SEGMENTS)
	
	# Create additional segments if needed
	while segments.size() < needed_segments:
		_create_segment()
	
	# Show/hide segments based on block_charges
	for i in range(segments.size()):
		if i < block_charges:
			segments[i].show()
		else:
			segments[i].hide()

func _create_segment() -> void:
	var segments_container = $Segments
	if !segments_container:
		return
	
	# Create new segment
	var new_segment = ProgressBar.new()
	new_segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_segment.size_flags_vertical = Control.SIZE_EXPAND_FILL
	new_segment.max_value = 1.0
	new_segment.value = 1.0
	new_segment.show_percentage = false
	
	# Apply the same styling as existing segments
	var style_bg = segments[0].get_theme_stylebox("background").duplicate()
	var style_fill = segments[0].get_theme_stylebox("fill").duplicate()
	new_segment.add_theme_stylebox_override("background", style_bg)
	new_segment.add_theme_stylebox_override("fill", style_fill)
	
	# Add to container
	segments_container.add_child(new_segment)
	segments.append(new_segment)
	
	print("[StaminaBar] Created new segment, total: " + str(segments.size())) 
