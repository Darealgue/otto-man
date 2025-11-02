extends Control

## LoadGameMenu - Save slot seçim ekranı
## Beta Yol Haritası FAZ 2.3: Load Game UI

signal slot_selected(slot_id: int)
signal delete_requested(slot_id: int)
signal back_requested()

@onready var slots_container: VBoxContainer = $Panel/VBoxContainer/SlotsContainer
@onready var back_button: Button = $Panel/VBoxContainer/BackButton
@onready var confirm_dialog: Control = $ConfirmDialog

const MAX_SLOTS: int = 5
var _pending_delete_slot: int = -1
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
		push_error("[LoadGameMenu] SlotsContainer not found!")
	if not back_button:
		push_error("[LoadGameMenu] BackButton not found!")

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
		
		# Load button
		var load_button = Button.new()
		load_button.name = "Slot%dLoadButton" % slot_id
		load_button.text = "Yükle"
		load_button.pressed.connect(_on_slot_load_pressed.bind(slot_id))
		
		# Delete button
		var delete_button = Button.new()
		delete_button.name = "Slot%dDeleteButton" % slot_id
		delete_button.text = "Sil"
		delete_button.pressed.connect(_on_slot_delete_pressed.bind(slot_id))
		
		slot_container.add_child(label)
		slot_container.add_child(load_button)
		slot_container.add_child(delete_button)
		
		slots_container.add_child(slot_container)
		
		slot_buttons.append(load_button)
		slot_labels.append(label)

func _refresh_slots() -> void:
	if not is_instance_valid(SaveManager):
		push_error("[LoadGameMenu] SaveManager not available!")
		return
	
	for i in range(MAX_SLOTS):
		var slot_id = i + 1
		var metadata = SaveManager.get_save_metadata(slot_id)
		var label = slot_labels[i]
		var load_button = slot_buttons[i]
		
		if metadata.is_empty():
			# Empty slot
			label.text = "Slot %d: (Boş)" % slot_id
			load_button.disabled = true
		else:
			# Populated slot
			var save_date = metadata.get("save_date", "")
			var playtime = metadata.get("playtime_seconds", 0)
			var scene = metadata.get("scene", "")
			var scene_name = _get_scene_name(scene)
			
			var playtime_str = _format_playtime(playtime)
			label.text = "Slot %d: %s\nSahne: %s | Süre: %s" % [slot_id, save_date, scene_name, playtime_str]
			load_button.disabled = false

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

func _on_slot_load_pressed(slot_id: int) -> void:
	if not is_instance_valid(SaveManager):
		push_error("[LoadGameMenu] SaveManager not available!")
		return
	
	var metadata = SaveManager.get_save_metadata(slot_id)
	if metadata.is_empty():
		push_warning("[LoadGameMenu] Slot %d is empty!" % slot_id)
		return
	
	print("[LoadGameMenu] Loading slot %d..." % slot_id)
	slot_selected.emit(slot_id)

func _setup_confirm_dialog() -> void:
	if not confirm_dialog:
		push_warning("[LoadGameMenu] ConfirmDialog not found!")
		return
	
	if confirm_dialog.has_signal("confirmed"):
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	if confirm_dialog.has_signal("cancelled"):
		confirm_dialog.cancelled.connect(_on_confirm_dialog_cancelled)

func _on_slot_delete_pressed(slot_id: int) -> void:
	if not is_instance_valid(SaveManager):
		push_error("[LoadGameMenu] SaveManager not available!")
		return
	
	var metadata = SaveManager.get_save_metadata(slot_id)
	if metadata.is_empty():
		push_warning("[LoadGameMenu] Slot %d is already empty!" % slot_id)
		return
	
	# Show confirmation dialog
	_pending_delete_slot = slot_id
	if confirm_dialog and confirm_dialog.has_method("show_dialog"):
		confirm_dialog.show_dialog("Kayıt Sil", "Slot %d'yı silmek istediğinizden emin misiniz?" % slot_id, true)
	else:
		# Fallback: proceed with delete
		_do_delete_slot(slot_id)

func _do_delete_slot(slot_id: int) -> void:
	if SaveManager.delete_save(slot_id):
		print("[LoadGameMenu] ✅ Deleted slot %d" % slot_id)
		_refresh_slots()
	else:
		push_error("[LoadGameMenu] Failed to delete slot %d" % slot_id)

func _on_confirm_dialog_confirmed() -> void:
	if _pending_delete_slot >= 0:
		var slot_id = _pending_delete_slot
		_pending_delete_slot = -1
		_do_delete_slot(slot_id)

func _on_confirm_dialog_cancelled() -> void:
	_pending_delete_slot = -1

func _on_back_pressed() -> void:
	back_requested.emit()

func show_menu() -> void:
	visible = true
	_refresh_slots()
	if slot_buttons.size() > 0 and not slot_buttons[0].disabled:
		slot_buttons[0].grab_focus()

func hide_menu() -> void:
	visible = false
