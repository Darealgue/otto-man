extends CanvasLayer

signal loading_complete
signal fade_out_complete

@onready var root_control: Control = $Root
@onready var loading_label: Label = $Root/VBoxContainer/LoadingLabel
@onready var progress_bar: ProgressBar = $Root/VBoxContainer/ProgressBar
@onready var fade_rect: ColorRect = $Root/FadeRect

var _is_loading: bool = false
var _fade_duration: float = 0.3
var _fade_tween: Tween = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	if is_instance_valid(root_control):
		root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Initialize fade rect
	if is_instance_valid(fade_rect):
		fade_rect.color = Color(0, 0, 0, 0)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Initialize progress bar
	if is_instance_valid(progress_bar):
		progress_bar.value = 0.0
		progress_bar.show_percentage = false
		progress_bar.modulate.a = 0.0
	
	if is_instance_valid(loading_label):
		loading_label.modulate.a = 0.0

func show_loading(text: String = "Yükleniyor...") -> void:
	if _is_loading:
		set_loading_text(text)
		return
	
	_is_loading = true
	visible = true
	if is_instance_valid(root_control):
		root_control.visible = true
	
	# Update text
	if loading_label:
		loading_label.text = text
	
	# Reset progress
	if progress_bar:
		progress_bar.value = 0.0
	
	# Fade in
	_fade_in()

func hide_loading() -> void:
	if not _is_loading:
		return
	
	# Fade out first, then hide
	_fade_out()

func set_progress(value: float) -> void:
	if progress_bar:
		progress_bar.value = clamp(value, 0.0, 100.0)

func set_loading_text(text: String) -> void:
	if loading_label:
		loading_label.text = text

func _fade_in() -> void:
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	
	fade_rect.color = Color(0, 0, 0, 0)
	_fade_tween.tween_property(fade_rect, "color:a", 1.0, _fade_duration)
	
	# Fade in content
	if loading_label:
		loading_label.modulate.a = 0.0
		_fade_tween.parallel().tween_property(loading_label, "modulate:a", 1.0, _fade_duration)
	
	if progress_bar:
		progress_bar.modulate.a = 0.0
		_fade_tween.parallel().tween_property(progress_bar, "modulate:a", 1.0, _fade_duration)

func _fade_out() -> void:
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade out content first
	if loading_label:
		_fade_tween.tween_property(loading_label, "modulate:a", 0.0, _fade_duration * 0.5)
	if progress_bar:
		_fade_tween.parallel().tween_property(progress_bar, "modulate:a", 0.0, _fade_duration * 0.5)
	
	# Then fade out background
	_fade_tween.tween_property(fade_rect, "color:a", 0.0, _fade_duration * 0.5)
	_fade_tween.tween_callback(_on_fade_out_complete)

func _on_fade_out_complete() -> void:
	visible = false
	_is_loading = false
	fade_out_complete.emit()
	if is_instance_valid(root_control):
		root_control.visible = false

func _input(event: InputEvent) -> void:
	# Block input while loading
	if _is_loading and visible:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()

