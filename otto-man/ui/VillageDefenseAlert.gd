class_name VillageDefenseAlert
extends CanvasLayer
## Köyde bekleyen saldırıları sağ üstte (saat göstergesinin altında) küçük, tek satırlık bir
## rozet olarak gösterir. Savunma tamamen text-based/otomatik çözülür — burada bir "savaşa
## katıl" butonu yok, sadece bilgilendirme.

var _panel: PanelContainer
var _vbox: VBoxContainer
var _line_labels: Array[RichTextLabel] = []


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	var wm: Node = get_node_or_null("/root/WorldManager")
	var tm: Node = get_node_or_null("/root/TimeManager")
	if wm and wm.has_signal("pending_attacks_changed"):
		if not wm.pending_attacks_changed.is_connected(refresh):
			wm.pending_attacks_changed.connect(refresh)
	if tm and tm.has_signal("minute_changed"):
		if not tm.minute_changed.is_connected(_on_minute_changed):
			tm.minute_changed.connect(_on_minute_changed)
	refresh()


func _on_minute_changed(_new_minute: int) -> void:
	refresh()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DefenseAlertPanel"
	# Sağ üst köşe, saat göstergesinin (TimeDisplayUI) altında — sol üstteki oyuncu
	# portresinden ve üst-orta kaynak panelinden uzak, kompakt bir rozet.
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = 30.0
	_panel.offset_right = -8.0
	_panel.offset_left = -220.0
	_panel.offset_bottom = 30.0 + 70.0
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 2)
	margin.add_child(_vbox)

	visible = false


## Saldırıya kalan süreye göre uyarı rengini belirler: uzak = sakin sarı, yakın = turuncu, çok yakın = kırmızı.
func _urgency_color(minutes_left: int) -> String:
	if minutes_left <= 240:
		return "#ff5c5c"
	if minutes_left <= 720:
		return "#ffb066"
	return "#ffe9b8"


## "5 sa" / "40 dk" gibi kaba (detaysız) bir kalan-süre metni.
func _compact_time_text(minutes_left: int) -> String:
	if minutes_left <= 0:
		return "şimdi"
	var hours: int = int(round(float(minutes_left) / 60.0))
	if hours <= 0:
		return "%d dk" % minutes_left
	return "%d sa" % hours


func _get_or_create_line_label(index: int) -> RichTextLabel:
	while _line_labels.size() <= index:
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.scroll_active = false
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.add_theme_font_size_override("normal_font_size", 15)
		_vbox.add_child(lbl)
		_line_labels.append(lbl)
	return _line_labels[index]


func refresh() -> void:
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm == null or not wm.has_method("get_pending_attacks_ui_summaries"):
		visible = false
		return
	var summaries: Array = wm.call("get_pending_attacks_ui_summaries")
	if summaries.is_empty():
		visible = false
		return
	var shown: int = 0
	for summary in summaries:
		if not (summary is Dictionary):
			continue
		var s: Dictionary = summary
		var attacker: String = String(s.get("attacker", "?"))
		var minutes_left: int = int(s.get("minutes_left", 999999))
		var urgency_color: String = _urgency_color(minutes_left)
		var time_text: String = _compact_time_text(minutes_left)
		var lbl := _get_or_create_line_label(shown)
		lbl.text = "[color=%s]⚠ %s — %s[/color]" % [urgency_color, attacker, time_text]
		lbl.visible = true
		shown += 1
	# Fazla kalan (önceki karede gösterilmiş ama artık gerekmeyen) satırları gizle.
	for i in range(shown, _line_labels.size()):
		_line_labels[i].visible = false
	visible = true
