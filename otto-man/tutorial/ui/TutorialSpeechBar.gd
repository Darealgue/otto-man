extends CanvasLayer
## Ekran altı tutorial metni (RichText BBCode).

@onready var _panel: PanelContainer = $Panel
@onready var _rich: RichTextLabel = %SpeechRichText


func _ready() -> void:
	layer = 95
	if is_instance_valid(_rich):
		_rich.bbcode_enabled = true
	_apply_visibility()


func set_speech_bbcode(bbcode: String) -> void:
	if is_instance_valid(_rich):
		_rich.text = bbcode
	_apply_visibility()


func clear_speech() -> void:
	set_speech_bbcode("")


func _apply_visibility() -> void:
	var has_text := false
	if is_instance_valid(_rich):
		has_text = not String(_rich.text).strip_edges().is_empty()
	if is_instance_valid(_panel):
		_panel.visible = has_text
