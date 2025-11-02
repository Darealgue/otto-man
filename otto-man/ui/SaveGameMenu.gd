extends Control

## SaveGameMenu - Save slot seçim ekranı

signal slot_selected(slot_id: int)
signal back_requested()

@onready var slots_container: VBoxContainer = $Panel/VBoxContainer/SlotsContainer
@onready var back_button: Button = $Panel/VBoxContainer/BackButton
@onready var confirm_dialog: Control = $ConfirmDialog

const MAX_SLOTS: int = 5
var _pending_save_slot: int = -1
var slot_buttons: Array[Button] = []
var slot_labels: Array[Label] = []

func _ready() -> void:
	_ensure_nodes()
	_create_slot_ui()
	_refresh_slots()
	_setup_confirm_dialog()
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _ensure_nodes() -> void:
	if not slots_container:
		push_error("[SaveGameMenu] SlotsContainer not found!")
	if not back_button:
		push_error("[SaveGameMenu] BackButton not found!")

func _create_slot_ui() -> void:
	if not slots_container:
		return
	
	slot_buttons.clear()
	slot_labels.clear()
	
	for i in range(MAX_SLOTS):
		var slot_id = i + 1
		
		# Container for each slot
		var slot_container = HBoxContainer.new()
		slot_container.name = "Slot%dContainer" % slot_id
		
		# Label for slot info
		var label = Label.new()
		label.name = "Slot%dLabel" % slot_id
		label.text = "Slot %d: (Boş)" % slot_id
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Save button (always enabled, can overwrite existing saves)
		var save_button = Button.new()
		save_button.name = "Slot%dSaveButton" % slot_id
		save_button.text = "Kaydet"
		save_button.pressed.connect(_on_slot_save_pressed.bind(slot_id))
		
		slot_container.add_child(label)
		slot_container.add_child(save_button)
		
		slots_container.add_child(slot_container)
		
		slot_buttons.append(save_button)
		slot_labels.append(label)

func _refresh_slots() -> void:
	if not is_instance_valid(SaveManager):
		push_error("[SaveGameMenu] SaveManager not available!")
		return
	
	for i in range(MAX_SLOTS):
		var slot_id = i + 1
		var metadata = SaveManager.get_save_metadata(slot_id)
		var label = slot_labels[i]
		
		if metadata.is_empty():
			# Empty slot
			label.text = "Slot %d: (Boş)" % slot_id
		else:
			# Populated slot (show info, but still allow save/overwrite)
			var save_date = metadata.get("save_date", "")
			var playtime = metadata.get("playtime_seconds", 0)
			var scene = metadata.get("scene", "")
			var scene_name = _get_scene_name(scene)
			
			var playtime_str = _format_playtime(playtime)
			label.text = "Slot %d: %s\nSahne: %s | Süre: %s\n(Üzerine kaydedilecek)" % [slot_id, save_date, scene_name, playtime_str]

func _format_playtime(seconds: int) -> String:
	var hours = seconds / 3600
	var minutes = (seconds % 3600) / 60
	if hours > 0:
		return "%d:%02d saat" % [hours, minutes]
	else:
		return "%d dakika" % minutes

func _get_scene_name(scene_path: String) -> String:
	if scene_path.contains("Village"):
		return "Köy"
	elif scene_path.contains("Dungeon") or scene_path.contains("test_level"):
		return "Zindan"
	elif scene_path.contains("Forest"):
		return "Orman"
	elif scene_path.contains("MainMenu"):
		return "Ana Menü"
	else:
		return "Bilinmeyen"

func _setup_confirm_dialog() -> void:
	if not confirm_dialog:
		push_warning("[SaveGameMenu] ConfirmDialog not found!")
		return
	
	if confirm_dialog.has_signal("confirmed"):
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	if confirm_dialog.has_signal("cancelled"):
		confirm_dialog.cancelled.connect(_on_confirm_dialog_cancelled)

func _on_slot_save_pressed(slot_id: int) -> void:
	if not is_instance_valid(SaveManager):
		push_error("[SaveGameMenu] SaveManager not available!")
		return
	
	# Check if slot already has a save
	var metadata = SaveManager.get_save_metadata(slot_id)
	if not metadata.is_empty():
		# Show confirmation for overwrite
		var save_date = metadata.get("save_date", "")
		var message = "Slot %d'de zaten bir kayıt var:\n%s\n\nÜzerine kaydetmek istediğinizden emin misiniz?" % [slot_id, save_date]
		_pending_save_slot = slot_id
		if confirm_dialog and confirm_dialog.has_method("show_dialog"):
			confirm_dialog.show_dialog("Kayıt Üzerine Yaz", message, true)
		else:
			# Fallback: proceed with save
			_do_save_slot(slot_id)
	else:
		# Empty slot, save directly
		_do_save_slot(slot_id)

func _do_save_slot(slot_id: int) -> void:
	print("[SaveGameMenu] Saving to slot %d..." % slot_id)
	slot_selected.emit(slot_id)

func _on_confirm_dialog_confirmed() -> void:
	if _pending_save_slot >= 0:
		var slot_id = _pending_save_slot
		_pending_save_slot = -1
		_do_save_slot(slot_id)

func _on_confirm_dialog_cancelled() -> void:
	_pending_save_slot = -1

func _on_back_pressed() -> void:
	back_requested.emit()

func show_menu() -> void:
	visible = true
	_refresh_slots()
	if slot_buttons.size() > 0:
		slot_buttons[0].grab_focus()

func hide_menu() -> void:
	visible = false

