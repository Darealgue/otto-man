extends Control
class_name TimeUI

@onready var time_label: Label = $TimeLabel if has_node("TimeLabel") else null
@onready var day_label: Label = $DayLabel if has_node("DayLabel") else null
@onready var period_label: Label = $PeriodLabel if has_node("PeriodLabel") else null

func _ready() -> void:
	print("TimeUI initialized")
	
	# Connect to TimeManager signals if available
	if get_node_or_null("/root/TimeManager"):
		if TimeManager.has_signal("time_advanced"):
			TimeManager.time_advanced.connect(_on_time_advanced)
		if TimeManager.has_signal("day_advanced"):
			TimeManager.day_advanced.connect(_on_day_advanced)
		if TimeManager.has_signal("period_changed"):
			TimeManager.period_changed.connect(_on_period_changed)
		
		# Initialize UI with current values
		update_time()
	else:
		print("ERROR: TimeManager not found")

func update_time() -> void:
	if not get_node_or_null("/root/TimeManager"):
		print("ERROR: TimeManager not available for time update")
		return
		
	var time_string = TimeManager.get_time_string()
	var day_string = TimeManager.get_day_string()
	var period_string = TimeManager.get_period_string()
	
	if time_label:
		time_label.text = time_string
	
	if day_label:
		day_label.text = day_string
	
	if period_label:
		period_label.text = period_string
		
		# Update period label color
		if TimeManager.has_method("get_period_color"):
			period_label.modulate = TimeManager.get_period_color()
		else:
			# Fallback to manually setting colors
			match period_string:
				"Morning":
					period_label.modulate = Color(1.0, 0.8, 0.6) # Orange-yellow
				"Noon":
					period_label.modulate = Color(1.0, 1.0, 1.0) # White
				"Evening":
					period_label.modulate = Color(1.0, 0.6, 0.4) # Orange-red
				"Night":
					period_label.modulate = Color(0.3, 0.3, 0.6) # Dark blue
				"Sabah":
					period_label.modulate = Color(1.0, 0.8, 0.4) # Yellow for Turkish
				"Öğle":
					period_label.modulate = Color(1.0, 1.0, 0.8) # White for Turkish
				"Akşam":
					period_label.modulate = Color(1.0, 0.6, 0.4) # Orange for Turkish
				"Gece":
					period_label.modulate = Color(0.5, 0.5, 0.8) # Blue for Turkish

func _on_time_advanced(hour, minute, day, period) -> void:
	update_time()

func _on_day_advanced(day) -> void:
	if day_label:
		day_label.text = TimeManager.get_day_string()
		
		# Add visual effect for day change
		var tween = create_tween()
		tween.tween_property(day_label, "modulate", Color(1, 1, 0.5), 0.3)
		tween.tween_property(day_label, "modulate", Color(1, 1, 1), 0.3)

func _on_period_changed(period) -> void:
	if period_label:
		period_label.text = period
		
		# Update color
		if TimeManager.has_method("get_period_color"):
			period_label.modulate = TimeManager.get_period_color()
		
		# Add visual effect for period change
		var tween = create_tween()
		tween.tween_property(period_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(period_label, "scale", Vector2(1.0, 1.0), 0.3) 
