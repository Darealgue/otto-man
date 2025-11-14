class_name MinigameBase
extends CanvasLayer

signal completed(success: bool, payload: Dictionary)

var context := {}
@export var pause_game: bool = true
@export var capture_mouse: bool = false
@export var auto_follow_viewport: bool = false
@export var default_layer: int = 100

var _is_finished := false

func _ready() -> void:
	layer = default_layer
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED if pause_game else Node.PROCESS_MODE_ALWAYS
	follow_viewport_enabled = auto_follow_viewport
	offset = Vector2.ZERO
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_on_minigame_ready()

func _on_minigame_ready() -> void:
	# Override in subclasses for setup.
	pass

func finish(success: bool, payload: Dictionary = {}) -> void:
	if _is_finished:
		return
	_is_finished = true
	emit_signal("completed", success, payload)

func is_finished() -> bool:
	return _is_finished

func get_context_value(key: String, default_value = null):
	if typeof(context) != TYPE_DICTIONARY:
		return default_value
	return context.get(key, default_value)

func _exit_tree() -> void:
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
