extends Area2D

const _UI_SCRIPT := preload("res://ui/InventorWorkshopUI.gd")

var _player_inside := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process_unhandled_input(true)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_open_ui()


func _open_ui() -> void:
	var existing := get_tree().get_first_node_in_group("inventor_workshop_ui")
	if is_instance_valid(existing):
		if existing.has_method("show_panel"):
			existing.show_panel()
		return
	var ui := Control.new()
	ui.set_script(_UI_SCRIPT)
	ui.add_to_group("inventor_workshop_ui")
	# get_tree().root'a çıplak eklenirse panel oyun dünyasının arkasında kalıp görünmez
	# oluyor — diğer popup'lar gibi yüksek katmanlı bir CanvasLayer'a sarmalıyoruz.
	var canvas := get_tree().root.get_node_or_null("PlotPopupCanvas") as CanvasLayer
	if not is_instance_valid(canvas):
		canvas = CanvasLayer.new()
		canvas.name = "PlotPopupCanvas"
		canvas.layer = 50
		canvas.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(canvas)
	canvas.add_child(ui)
	if ui.has_method("show_panel"):
		ui.show_panel()
