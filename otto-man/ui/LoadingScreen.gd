extends CanvasLayer

signal loading_complete
signal fade_out_complete

@export var custom_indicator_scene: PackedScene

@onready var root_control: Control = $Root
@onready var fade_rect: ColorRect = $Root/FadeRect
@onready var content_anchor: CenterContainer = $Root/ContentAnchor
@onready var loading_indicator: Control = $Root/ContentAnchor/LoadingIndicator

var _is_loading: bool = false
var _fade_tween: Tween = null

const FADE_TO_BLACK_DURATION: float = 0.38
const CONTENT_FADE_DURATION: float = 0.28
const FADE_FROM_BLACK_DURATION: float = 0.5


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = HudCanvasLayers.TRANSITION
	if is_instance_valid(root_control):
		root_control.mouse_filter = Control.MOUSE_FILTER_STOP

	if is_instance_valid(fade_rect):
		fade_rect.color = Color(0, 0, 0, 0)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_indicator()
	_set_indicator_alpha(0.0)


func _setup_indicator() -> void:
	if custom_indicator_scene == null or not is_instance_valid(content_anchor):
		return
	if is_instance_valid(loading_indicator):
		loading_indicator.queue_free()
	loading_indicator = custom_indicator_scene.instantiate()
	loading_indicator.name = "LoadingIndicator"
	content_anchor.add_child(loading_indicator)


func show_loading(_text: String = "") -> void:
	if _is_loading:
		return

	_is_loading = true
	visible = true
	if is_instance_valid(root_control):
		root_control.visible = true

	_set_indicator_alpha(0.0)
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 0)

	await _fade_to_black()
	await _fade_in_content()


func hide_loading() -> void:
	if not _is_loading:
		return

	await _fade_out_content()
	await _fade_from_black()
	_on_transition_complete()


func set_progress(_value: float) -> void:
	pass


func set_loading_text(_text: String) -> void:
	pass


func set_custom_indicator(scene: PackedScene) -> void:
	custom_indicator_scene = scene
	if is_inside_tree():
		_setup_indicator()


func _set_indicator_alpha(alpha: float) -> void:
	if is_instance_valid(loading_indicator):
		loading_indicator.modulate.a = alpha


func _fade_to_black() -> void:
	_kill_fade_tween()
	if not is_instance_valid(fade_rect):
		return

	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.tween_property(fade_rect, "color:a", 1.0, FADE_TO_BLACK_DURATION)
	await _fade_tween.finished


func _fade_in_content() -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)

	if is_instance_valid(loading_indicator):
		_fade_tween.tween_property(loading_indicator, "modulate:a", 1.0, CONTENT_FADE_DURATION)

	await _fade_tween.finished


func _fade_out_content() -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)

	if is_instance_valid(loading_indicator):
		_fade_tween.tween_property(loading_indicator, "modulate:a", 0.0, CONTENT_FADE_DURATION)

	await _fade_tween.finished

	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)


func _fade_from_black() -> void:
	_kill_fade_tween()
	if not is_instance_valid(fade_rect):
		return

	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.tween_property(fade_rect, "color:a", 0.0, FADE_FROM_BLACK_DURATION)
	await _fade_tween.finished


func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _on_transition_complete() -> void:
	visible = false
	_is_loading = false
	if is_instance_valid(root_control):
		root_control.visible = false
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 0)
	_set_indicator_alpha(0.0)
	fade_out_complete.emit()


func _input(event: InputEvent) -> void:
	if _is_loading and visible:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
