extends Node

@export var return_target: String = "village"

func _ready() -> void:
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if event is InputEventKey:
			event.accept()
		_return_to_target()

func return_to_village(payload: Dictionary = {}) -> void:
	return_target = "village"
	_return_to_target(payload)

func return_to_menu() -> void:
	return_target = "menu"
	_return_to_target()

func _return_to_target(payload: Dictionary = {}) -> void:
	if not Engine.has_singleton("SceneManager"):
		push_warning("SceneManager autoload bulunamadı")
		return
	var scene_path := ""
	var current := get_tree().current_scene
	if current:
		scene_path = current.scene_file_path
	match return_target:
		"village":
			var data := payload.duplicate(true)
			data["from_scene"] = scene_path
			SceneManager.change_to_village(data)
		"menu":
			SceneManager.return_to_main_menu()
		_:
			var fallback := payload.duplicate(true)
			fallback["target"] = return_target
			fallback["from_scene"] = scene_path
			SceneManager.change_to_village(fallback)
