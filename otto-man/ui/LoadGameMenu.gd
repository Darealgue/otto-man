extends Control

## LoadGameMenu - Save slot seçim ekranı
## Beta Yol Haritası FAZ 2.3: Load Game UI

signal slot_selected(slot_id: int)
signal delete_requested(slot_id: int)
signal back_requested()

@onready var slots_container: VBoxContainer = $Panel/VBoxContainer/SlotsContainer
@onready var back_button: Button = $Panel/VBoxContainer/BackButton
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
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
		var validation = SaveManager.validate_save_file(slot_id)
		var label = slot_labels[i]
		var load_button = slot_buttons[i]
		
		if not validation["valid"]:
			# Invalid or empty slot
			var metadata = SaveManager.get_save_metadata(slot_id)
			if metadata.is_empty():
				label.text = "Slot %d: (Boş)" % slot_id
			else:
				# File exists but is invalid
				label.text = "Slot %d: (Hatalı - Yüklenemez)" % slot_id
			load_button.disabled = true
		else:
			# Valid slot
			var metadata = validation["metadata"]
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
		_show_error("Hata", "Kayıt yöneticisi bulunamadı.")
		return
	
	# Validate save file before loading
	var validation = SaveManager.validate_save_file(slot_id)
	if not validation["valid"]:
		_show_error("Kayıt Dosyası Hatalı", validation.get("error", "Bilinmeyen hata."))
		return
	
	var metadata = SaveManager.get_save_metadata(slot_id)
	if metadata.is_empty():
		push_warning("[LoadGameMenu] Slot %d is empty!" % slot_id)
		_show_error("Boş Kayıt", "Bu kayıt slotu boş.")
		return
	
	# Show loading message
	_set_status("Yükleniyor...", true)
	
	print("[LoadGameMenu] Loading slot %d..." % slot_id)
	
	# Connect to error signal if not already connected
	if SaveManager.has_signal("error_occurred"):
		if not SaveManager.error_occurred.is_connected(_on_save_error):
			SaveManager.error_occurred.connect(_on_save_error)
	
	# Connect to load completed to handle errors
	if SaveManager.has_signal("load_completed"):
		if not SaveManager.load_completed.is_connected(_on_load_completed):
			SaveManager.load_completed.connect(_on_load_completed)
	
	slot_selected.emit(slot_id)

func _on_load_completed(slot_id: int, success: bool) -> void:
	if not success:
		_set_status("Yükleme başarısız!", false)
		_show_error("Yükleme Başarısız", "Kayıt yüklenemedi. Dosya bozulmuş olabilir.")
	else:
		_set_status("Yükleme tamamlandı!", true)
		# Clear status after a delay
		await get_tree().create_timer(1.0).timeout
		_set_status("", false)

func _on_save_error(error_message: String, error_type: String) -> void:
	if error_type == "load" or error_type == "validation":
		_show_error("Yükleme Hatası", error_message)

func _set_status(message: String, is_loading: bool = false) -> void:
	"""Set status label message"""
	if status_label:
		status_label.text = message
		if is_loading:
			status_label.modulate = Color(1, 1, 1, 1)
		else:
			status_label.modulate = Color(1, 0.843, 0, 1)

func _show_error(title: String, message: String) -> void:
	"""Show error dialog"""
	_set_status("", false)  # Clear status on error
	var error_dialog_scene = load("res://ui/ErrorDialog.tscn")
	if error_dialog_scene:
		var error_dialog = error_dialog_scene.instantiate()
		get_tree().root.add_child(error_dialog)
		if error_dialog.has_method("show_error"):
			error_dialog.show_error(title, message)

func _setup_confirm_dialog() -> void:
	if not confirm_dialog:
		push_warning("[LoadGameMenu] ConfirmDialog not found!")
		return
	
	print("[LoadGameMenu] Setting up confirm dialog...")
	if confirm_dialog.has_signal("confirmed"):
		if not confirm_dialog.confirmed.is_connected(_on_confirm_dialog_confirmed):
			confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
			print("[LoadGameMenu] ✅ Connected confirmed signal")
		else:
			print("[LoadGameMenu] ⚠️ confirmed signal already connected")
	else:
		push_error("[LoadGameMenu] ConfirmDialog has no 'confirmed' signal!")
	
	if confirm_dialog.has_signal("cancelled"):
		if not confirm_dialog.cancelled.is_connected(_on_confirm_dialog_cancelled):
			confirm_dialog.cancelled.connect(_on_confirm_dialog_cancelled)
			print("[LoadGameMenu] ✅ Connected cancelled signal")
		else:
			print("[LoadGameMenu] ⚠️ cancelled signal already connected")
	else:
		push_error("[LoadGameMenu] ConfirmDialog has no 'cancelled' signal!")

func _on_slot_delete_pressed(slot_id: int) -> void:
	print("[LoadGameMenu] 🔴 DELETE BUTTON PRESSED for slot %d" % slot_id)
	
	if not is_instance_valid(SaveManager):
		push_error("[LoadGameMenu] SaveManager not available!")
		_show_error("Hata", "Kayıt yöneticisi bulunamadı.")
		return
	
	var metadata = SaveManager.get_save_metadata(slot_id)
	if metadata.is_empty():
		push_warning("[LoadGameMenu] Slot %d is already empty!" % slot_id)
		_set_status("Slot %d zaten boş!" % slot_id, false)
		await get_tree().create_timer(1.0).timeout
		_set_status("", false)
		return
	
	# Show confirmation dialog
	_pending_delete_slot = slot_id
	print("[LoadGameMenu] Showing confirm dialog for slot %d" % slot_id)
	# Release focus from any button before showing dialog
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus:
		current_focus.release_focus()
		print("[LoadGameMenu] Released focus from: %s" % current_focus.name)
	if confirm_dialog and confirm_dialog.has_method("show_dialog"):
		confirm_dialog.show_dialog("Kayıt Sil", "Slot %d'yı silmek istediğinizden emin misiniz?" % slot_id, true)
		print("[LoadGameMenu] Confirm dialog shown")
	else:
		print("[LoadGameMenu] ⚠️ ConfirmDialog not available, proceeding with delete directly")
		# Fallback: proceed with delete
		_do_delete_slot(slot_id)

func _do_delete_slot(slot_id: int) -> void:
	print("[LoadGameMenu] Attempting to delete slot %d..." % slot_id)
	if SaveManager.delete_save(slot_id):
		print("[LoadGameMenu] ✅ Deleted slot %d" % slot_id)
		_set_status("Slot %d silindi!" % slot_id, false)
		_refresh_slots()
		# Clear status after a delay
		await get_tree().create_timer(1.5).timeout
		_set_status("", false)
	else:
		var error_msg = "Slot %d silinemedi. Dosya kilitli olabilir veya izin hatası olabilir." % slot_id
		push_error("[LoadGameMenu] Failed to delete slot %d" % slot_id)
		_show_error("Silme Başarısız", error_msg)

func _on_confirm_dialog_confirmed() -> void:
	print("[LoadGameMenu] ✅ Confirm dialog confirmed!")
	if _pending_delete_slot >= 0:
		var slot_id = _pending_delete_slot
		_pending_delete_slot = -1
		print("[LoadGameMenu] Proceeding to delete slot %d" % slot_id)
		_do_delete_slot(slot_id)
		# Delete işlemi sonrası focus'u geri ver
		call_deferred("_set_load_menu_focus")
	else:
		print("[LoadGameMenu] ⚠️ No pending delete slot!")
		# Yine de focus'u geri ver
		call_deferred("_set_load_menu_focus")

func _on_confirm_dialog_cancelled() -> void:
	_pending_delete_slot = -1
	# GENEL ÇÖZÜM: Confirm dialog cancelled olduğunda LoadGameMenu'ye focus'u geri ver
	call_deferred("_set_load_menu_focus")

func _on_back_pressed() -> void:
	back_requested.emit()

func show_menu() -> void:
	visible = true
	_refresh_slots()
	# Use call_deferred to ensure UI is ready before grabbing focus
	call_deferred("_set_load_menu_focus")

func _set_load_menu_focus() -> void:
	# Set focus to first enabled slot button when menu is ready
	for button in slot_buttons:
		if button and button.visible and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			print("[LoadGameMenu] ✅ Focus set to first enabled slot button")
			return
	# If no enabled button, focus back button
	if back_button and back_button.visible and back_button.focus_mode != Control.FOCUS_NONE:
		back_button.grab_focus()
		print("[LoadGameMenu] ✅ Focus set to back button")

func hide_menu() -> void:
	visible = false
