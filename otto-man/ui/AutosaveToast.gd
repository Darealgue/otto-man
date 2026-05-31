extends CanvasLayer
## Sağ üstte kısa “otomatik kaydedildi” bildirimi.


func _ready() -> void:
	layer = 120
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel: PanelContainer = get_node_or_null("PanelContainer")
	if panel:
		panel.modulate.a = 0.0


func show_toast(message: String = "") -> void:
	if message.is_empty():
		message = tr("autosave.toast_default")
	var panel: PanelContainer = get_node_or_null("PanelContainer") as PanelContainer
	var label: Label = get_node_or_null("PanelContainer/MarginContainer/Label") as Label
	if label:
		label.text = message
	visible = true
	if panel == null:
		return
	var tw: Tween = create_tween()
	tw.set_parallel(false)
	panel.modulate.a = 0.0
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	tw.tween_interval(1.65)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	await tw.finished
	visible = false
