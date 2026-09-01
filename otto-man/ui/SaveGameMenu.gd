extends Control

## SaveGameMenu - Save slot seçim ekranı

signal slot_selected(slot_id: int)
signal back_requested()

@onready var slots_container: VBoxContainer = $Panel/Margin/VBoxContainer/SlotsContainer
@onready var title_label: Label = $Panel/Margin/VBoxContainer/Title
@onready var back_button: Button = $Panel/Margin/VBoxContainer/BackButton
@onready var status_label: Label = $Panel/Margin/VBoxContainer/StatusLabel
@onready var confirm_dialog: Control = $ConfirmDialog

const MAX_SLOTS: int = 5
const SaveSlotRow = preload("res://ui/save_slot_row.gd")
var _pending_save_slot: int = -1
var slot_buttons: Array[Button] = []
var slot_labels: Array[Label] = []
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
		push_error("[SaveGameMenu] SlotsContainer not found!")
	if not back_button:
		push_error("[SaveGameMenu] BackButton not found!")


func _create_slot_ui() -> void:
	if not slots_container:
		return

	slot_buttons.clear()
	slot_labels.clear()
	_slot_rows.clear()

	for i in range(MAX_SLOTS):
		var slot_id = i + 1

		# Yükle ekranıyla aynı satır bileşeni. Burada ikinci buton (Sil) yok, yerini
		# görünmez dolgu koruyor; böylece iki ekranın sütunları da aynı hizada.
		var row := SaveSlotRow.new()
		row.name = "Slot%dRow" % slot_id
		row.hide_secondary_button(false)

		var save_button := row.primary_button
		save_button.name = "Slot%dSaveButton" % slot_id
		save_button.text = tr("slot.save_button")
		save_button.pressed.connect(_on_slot_save_pressed.bind(slot_id))

		slots_container.add_child(row)

		_slot_rows.append(row)
		slot_buttons.append(save_button)
		slot_labels.append(row.sub_label)


func _refresh_locale(_locale: String = "") -> void:
	if back_button:
		back_button.text = tr("common.back")
	for btn in slot_buttons:
		btn.text = tr("slot.save_button")
	if visible and title_label and is_instance_valid(SaveManager) and SaveManager.has_method("get_active_profile_id"):
		title_label.text = tr("save.title") % int(SaveManager.get_active_profile_id())
	_refresh_slots()


func _refresh_slots() -> void:
	if not is_instance_valid(SaveManager):
		push_error("[SaveGameMenu] SaveManager not available!")
		return

	for i in range(MAX_SLOTS):
		var slot_id = i + 1
		var metadata = SaveManager.get_save_metadata(slot_id)
		var row = _slot_rows[i]
		var slot_title: String = tr("slot.title") % slot_id

		if metadata.is_empty():
			row.set_placeholder(slot_title, tr("slot.state_empty"))
		else:
			var playtime_str = LocaleManager.format_playtime_slot(int(metadata.get("playtime_seconds", 0)))
			# Dolu slota kaydetmek üzerine yazmak demek; alt satırda uyarı olarak belirtilir.
			var subtitle: String = "%s%s · %s" % [
				playtime_str,
				SaveSlotRow.location_suffix(str(metadata.get("scene", ""))),
				tr("slot.state_overwrite")
			]
			row.set_filled(
				slot_title,
				subtitle,
				LocaleManager.format_save_date(str(metadata.get("save_date", "")))
			)


func _setup_confirm_dialog() -> void:
	if not confirm_dialog:
		push_warning("[SaveGameMenu] ConfirmDialog not found!")
		return

	if confirm_dialog.has_signal("confirmed"):
		confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	if confirm_dialog.has_signal("cancelled"):
		confirm_dialog.cancelled.connect(_on_confirm_dialog_cancelled)


func _on_slot_save_pressed(slot_id: int) -> void:
	if SaveManager.has_signal("error_occurred"):
		if not SaveManager.error_occurred.is_connected(_on_save_error):
			SaveManager.error_occurred.connect(_on_save_error)

	if SaveManager.has_signal("save_completed"):
		if not SaveManager.save_completed.is_connected(_on_save_completed):
			SaveManager.save_completed.connect(_on_save_completed)
	if not is_instance_valid(SaveManager):
		push_error("[SaveGameMenu] SaveManager not available!")
		return

	var metadata = SaveManager.get_save_metadata(slot_id)
	if not metadata.is_empty():
		var save_date = metadata.get("save_date", "")
		var message = tr("save.overwrite_message") % [slot_id, save_date]
		_pending_save_slot = slot_id
		var current_focus = get_viewport().gui_get_focus_owner()
		if current_focus:
			current_focus.release_focus()
		if confirm_dialog and confirm_dialog.has_method("show_dialog"):
			confirm_dialog.show_dialog(tr("save.overwrite_title"), message, true)
		else:
			_do_save_slot(slot_id)
	else:
		_do_save_slot(slot_id)


func _do_save_slot(slot_id: int) -> void:
	_set_status(tr("save.status_saving"), true)
	slot_selected.emit(slot_id)


func _on_save_completed(slot_id: int, success: bool) -> void:
	if not success:
		_set_status(tr("save.status_failed"), false)
		_show_error(tr("save.error_title"), tr("save.error_message"))
	else:
		_set_status(tr("save.status_complete"), true)
		_refresh_slots()
		await get_tree().create_timer(1.0).timeout
		_set_status("", false)


func _on_save_error(error_message: String, error_type: String) -> void:
	if error_type == "save":
		_set_status("", false)
		_show_error(tr("save.error_dialog_title"), error_message)


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


func _on_confirm_dialog_confirmed() -> void:
	if _pending_save_slot >= 0:
		var slot_id = _pending_save_slot
		_pending_save_slot = -1
		_do_save_slot(slot_id)


func _on_confirm_dialog_cancelled() -> void:
	_pending_save_slot = -1
	call_deferred("_set_save_menu_focus")


func _on_back_pressed() -> void:
	back_requested.emit()


func show_menu() -> void:
	visible = true
	_refresh_locale()
	if slot_buttons.size() > 0:
		call_deferred("_set_save_menu_focus")


func _set_save_menu_focus() -> void:
	if slot_buttons.size() > 0:
		var first_button = slot_buttons[0]
		if first_button and first_button.visible and first_button.focus_mode != Control.FOCUS_NONE:
			first_button.grab_focus()


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
