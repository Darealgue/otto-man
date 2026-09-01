extends Control

## LoadGameMenu - Save slot seçim ekranı

signal slot_selected(slot_id: int)
signal delete_requested(slot_id: int)
signal back_requested()

@onready var slots_container: VBoxContainer = $Panel/Margin/VBoxContainer/SlotsContainer
@onready var title_label: Label = $Panel/Margin/VBoxContainer/Title
@onready var back_button: Button = $Panel/Margin/VBoxContainer/BackButton
@onready var status_label: Label = $Panel/Margin/VBoxContainer/StatusLabel
@onready var confirm_dialog: Control = $ConfirmDialog

const MAX_SLOTS: int = 5
const SaveSlotRow = preload("res://ui/save_slot_row.gd")
var _pending_delete_slot: int = -1
var slot_buttons: Array[Button] = []
var slot_labels: Array[Label] = []
var _delete_buttons: Array[Button] = []
var _autosave_label: Label = null
var _autosave_load_button: Button = null
var _autosave_row = null
var _slot_rows: Array = []


func _ready() -> void:
	var panel := get_node_or_null("Panel") as Panel
	if panel:
		ParchmentTextures.apply_large_panel_style(panel, 14)
	TextOutline.apply_to_tree(self)
	_ensure_nodes()
	_create_slot_ui()
	_refresh_slots()
	_setup_confirm_dialog()
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)
	_refresh_locale()
	_register_ui_font_scale()


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
	_delete_buttons.clear()
	_slot_rows.clear()

	# Otomatik kayıt satırı: Sil butonu yok, yerini görünmez dolgu koruyor ki Yükle
	# butonu alttaki satırlarla aynı sütunda kalsın.
	_autosave_row = SaveSlotRow.new()
	_autosave_row.name = "AutosaveRow"
	_autosave_row.hide_secondary_button()
	_autosave_load_button = _autosave_row.primary_button
	_autosave_load_button.name = "AutosaveLoadButton"
	_autosave_load_button.text = tr("slot.load_button")
	_autosave_load_button.pressed.connect(_on_slot_load_pressed.bind(SaveManager.AUTOSAVE_UI_SLOT_ID))
	_autosave_label = _autosave_row.sub_label
	slots_container.add_child(_autosave_row)

	for i in range(MAX_SLOTS):
		var slot_id = i + 1

		var row := SaveSlotRow.new()
		row.name = "Slot%dRow" % slot_id

		var load_button := row.primary_button
		load_button.name = "Slot%dLoadButton" % slot_id
		load_button.text = tr("slot.load_button")
		load_button.pressed.connect(_on_slot_load_pressed.bind(slot_id))

		var delete_button := row.secondary_button
		delete_button.name = "Slot%dDeleteButton" % slot_id
		delete_button.text = tr("slot.delete_button")
		delete_button.pressed.connect(_on_slot_delete_pressed.bind(slot_id))

		slots_container.add_child(row)

		_slot_rows.append(row)
		slot_buttons.append(load_button)
		slot_labels.append(row.sub_label)
		_delete_buttons.append(delete_button)


func _refresh_locale(_locale: String = "") -> void:
	if back_button:
		back_button.text = tr("common.back")
	if _autosave_load_button:
		_autosave_load_button.text = tr("slot.load_button")
	for btn in slot_buttons:
		btn.text = tr("slot.load_button")
	for btn in _delete_buttons:
		btn.text = tr("slot.delete_button")
	if visible and title_label and is_instance_valid(SaveManager) and SaveManager.has_method("get_active_profile_id"):
		title_label.text = tr("load.title") % int(SaveManager.get_active_profile_id())
	_refresh_slots()


func _refresh_slots() -> void:
	if not is_instance_valid(SaveManager):
		push_error("[LoadGameMenu] SaveManager not available!")
		return

	_refresh_autosave_slot()

	for i in range(MAX_SLOTS):
		var slot_id = i + 1
		var row = _slot_rows[i]
		var validation = SaveManager.validate_save_file(slot_id)
		var load_button = slot_buttons[i]
		var delete_button: Button = _delete_buttons[i]
		var slot_title: String = tr("slot.title") % slot_id

		if not validation["valid"]:
			var metadata = SaveManager.get_save_metadata(slot_id)
			var is_broken: bool = not metadata.is_empty()
			row.set_placeholder(
				slot_title,
				tr("slot.state_invalid") if is_broken else tr("slot.state_empty"),
				is_broken
			)
			load_button.disabled = true
			delete_button.disabled = not is_broken
		else:
			var metadata = validation["metadata"]
			var playtime_str = LocaleManager.format_playtime_slot(int(metadata.get("playtime_seconds", 0)))
			row.set_filled(
				slot_title,
				playtime_str + SaveSlotRow.location_suffix(str(metadata.get("scene", ""))),
				LocaleManager.format_save_date(str(metadata.get("save_date", "")))
			)
			load_button.disabled = false
			delete_button.disabled = false


func _refresh_autosave_slot() -> void:
	if _autosave_row == null or _autosave_load_button == null:
		return
	var validation: Dictionary = SaveManager.validate_autosave_file()
	if not validation["valid"]:
		_autosave_row.set_placeholder(tr("autosave.title"), tr("autosave.state_none"))
		_autosave_load_button.disabled = true
		return
	var metadata: Dictionary = validation["metadata"]
	var playtime_str: String = LocaleManager.format_playtime_slot(int(metadata.get("playtime_seconds", 0)))
	_autosave_row.set_filled(
		tr("autosave.title"),
		playtime_str + SaveSlotRow.location_suffix(str(metadata.get("scene", ""))),
		LocaleManager.format_save_date(str(metadata.get("save_date", "")))
	)
	_autosave_load_button.disabled = false


func _on_slot_load_pressed(slot_id: int) -> void:
	if not is_instance_valid(SaveManager):
		push_error("[LoadGameMenu] SaveManager not available!")
		_show_error(tr("error.title"), tr("error.save_manager_missing"))
		return

	if slot_id == SaveManager.AUTOSAVE_UI_SLOT_ID:
		var v_auto: Dictionary = SaveManager.validate_autosave_file()
		if not v_auto["valid"]:
			_show_error(tr("error.no_autosave_title"), tr("error.no_autosave"))
			return
		_set_status(tr("load.status_loading"), true)
		if SaveManager.has_signal("error_occurred"):
			if not SaveManager.error_occurred.is_connected(_on_save_error):
				SaveManager.error_occurred.connect(_on_save_error)
		if SaveManager.has_signal("load_completed"):
			if not SaveManager.load_completed.is_connected(_on_load_completed):
				SaveManager.load_completed.connect(_on_load_completed)
		slot_selected.emit(slot_id)
		return

	var validation = SaveManager.validate_save_file(slot_id)
	if not validation["valid"]:
		_show_error(tr("error.invalid_file_title"), validation.get("error", tr("error.unknown")))
		return

	var metadata = SaveManager.get_save_metadata(slot_id)
	if metadata.is_empty():
		_show_error(tr("error.empty_slot_title"), tr("error.empty_slot"))
		return

	_set_status(tr("load.status_loading"), true)

	if SaveManager.has_signal("error_occurred"):
		if not SaveManager.error_occurred.is_connected(_on_save_error):
			SaveManager.error_occurred.connect(_on_save_error)

	if SaveManager.has_signal("load_completed"):
		if not SaveManager.load_completed.is_connected(_on_load_completed):
			SaveManager.load_completed.connect(_on_load_completed)

	slot_selected.emit(slot_id)


func _on_load_completed(slot_id: int, success: bool) -> void:
	if not success:
		_set_status(tr("load.status_failed"), false)
		_show_error(tr("error.load_failed_title"), tr("error.load_failed_corrupt"))
	else:
		_set_status(tr("load.status_complete"), true)
		await get_tree().create_timer(1.0).timeout
		_set_status("", false)


func _on_save_error(error_message: String, error_type: String) -> void:
	if error_type == "load" or error_type == "validation":
		_show_error(tr("error.load_error_title"), error_message)


func _set_status(message: String, is_loading: bool = false) -> void:
	if status_label:
		status_label.text = message
		if is_loading:
			status_label.modulate = Color(1, 1, 1, 1)
		else:
			status_label.modulate = Color(1, 0.843, 0, 1)


func _show_error(title: String, message: String) -> void:
	_set_status("", false)
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

	if confirm_dialog.has_signal("confirmed"):
		if not confirm_dialog.confirmed.is_connected(_on_confirm_dialog_confirmed):
			confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	if confirm_dialog.has_signal("cancelled"):
		if not confirm_dialog.cancelled.is_connected(_on_confirm_dialog_cancelled):
			confirm_dialog.cancelled.connect(_on_confirm_dialog_cancelled)


func _on_slot_delete_pressed(slot_id: int) -> void:
	if slot_id == SaveManager.AUTOSAVE_UI_SLOT_ID:
		return

	if not is_instance_valid(SaveManager):
		_show_error(tr("error.title"), tr("error.save_manager_missing"))
		return

	var metadata = SaveManager.get_save_metadata(slot_id)
	if metadata.is_empty():
		_set_status(tr("load.slot_empty_status") % slot_id, false)
		await get_tree().create_timer(1.0).timeout
		_set_status("", false)
		return

	_pending_delete_slot = slot_id
	var current_focus = get_viewport().gui_get_focus_owner()
	if current_focus:
		current_focus.release_focus()
	if confirm_dialog and confirm_dialog.has_method("show_dialog"):
		confirm_dialog.show_dialog(tr("load.delete_title"), tr("load.delete_confirm") % slot_id, true)
	else:
		_do_delete_slot(slot_id)


func _do_delete_slot(slot_id: int) -> void:
	if SaveManager.delete_save(slot_id):
		_set_status(tr("load.status_deleted") % slot_id, false)
		_refresh_slots()
		await get_tree().create_timer(1.5).timeout
		_set_status("", false)
	else:
		_show_error(tr("load.delete_failed_title"), tr("load.delete_failed_message") % slot_id)


func _on_confirm_dialog_confirmed() -> void:
	if _pending_delete_slot >= 0:
		var slot_id = _pending_delete_slot
		_pending_delete_slot = -1
		_do_delete_slot(slot_id)
		call_deferred("_set_load_menu_focus")
	else:
		call_deferred("_set_load_menu_focus")


func _on_confirm_dialog_cancelled() -> void:
	_pending_delete_slot = -1
	call_deferred("_set_load_menu_focus")


func _on_back_pressed() -> void:
	back_requested.emit()


func show_menu() -> void:
	visible = true
	_refresh_locale()
	call_deferred("_set_load_menu_focus")


func _set_load_menu_focus() -> void:
	if _autosave_load_button and _autosave_load_button.visible and not _autosave_load_button.disabled and _autosave_load_button.focus_mode != Control.FOCUS_NONE:
		_autosave_load_button.grab_focus()
		return
	for button in slot_buttons:
		if button and button.visible and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return
	if back_button and back_button.visible and back_button.focus_mode != Control.FOCUS_NONE:
		back_button.grab_focus()


func hide_menu() -> void:
	visible = false


## Menü yazı boyutu ayarı (Ayarlar > Görüntü > Arayüz Boyutu). register() bu kökü kapsama alır:
## şimdi bir kez uygular, sonra ölçek her değiştiğinde yeniden uygular. Autoload'a node yoluyla
## erişiyoruz ki dosya --check-only ile tek başına doğrulanabilsin (bkz. CLAUDE.md).
## İkinci argüman panelin kendisi: yazılar büyüyünce sabit boyutlu kutu da büyümeli.
func _register_ui_font_scale() -> void:
	var scaler := get_node_or_null("/root/UiFontScale")
	if scaler != null and scaler.has_method("register"):
		scaler.call("register", self, get_node_or_null("Panel"))
