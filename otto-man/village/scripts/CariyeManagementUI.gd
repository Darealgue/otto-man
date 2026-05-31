extends PanelContainer

# --- UI Element References ---
var cariye_item_list: ItemList
var mission_item_list: ItemList
var assign_button: Button
var close_button: Button
var treat_button: Button
var weekly_info_label: Label
var _title_label: Label = null
var _cariye_title_label: Label = null
var _mission_title_label: Label = null

var selected_cariye_id: int = -1
var selected_gorev_id: int = -1


func _ready() -> void:
	ParchmentTextures.apply_compact_panel_style(self, 10)
	TextOutline.apply_to_tree(self)
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)


func populate_cariye_list() -> void:
	cariye_item_list.clear()
	var cariyeler: Dictionary = VillageManager.cariyeler
	for id in cariyeler:
		var cariye: Dictionary = cariyeler[id]
		var cariye_name = cariye.get("isim", tr("cariye.unnamed"))
		var cariye_level = cariye.get("seviye", 0)
		var cariye_status = cariye.get("durum", tr("cariye.unknown"))
		var cariye_text: String = tr("cariye.item_format") % [cariye_name, cariye_level, cariye_status]
		cariye_item_list.add_item(cariye_text)
		cariye_item_list.set_item_metadata(cariye_item_list.item_count - 1, id)


func populate_mission_list() -> void:
	mission_item_list.clear()
	var gorevler: Dictionary = VillageManager.gorevler
	for id in gorevler:
		var gorev: Dictionary = gorevler[id]
		var assignment_text: String = ""
		var is_assigned = false
		var assigned_cariye_name = ""
		for cariye_id_in_mission in VillageManager.active_missions:
			if VillageManager.active_missions[cariye_id_in_mission].get("gorev_id") == id:
				is_assigned = true
				var assigned_c = VillageManager.cariyeler.get(cariye_id_in_mission)
				if assigned_c:
					assigned_cariye_name = assigned_c.get("isim", tr("cariye.unknown"))
				break

		if is_assigned:
			assignment_text = tr("cariye.assigned_suffix") % assigned_cariye_name

		var gorev_name = gorev.get("isim", tr("cariye.unnamed_mission"))
		var gorev_difficulty = gorev.get("zorluk", tr("cariye.unknown"))
		var gorev_text: String = tr("cariye.mission_format") % [gorev_name, gorev_difficulty] + assignment_text
		mission_item_list.add_item(gorev_text)
		mission_item_list.set_item_metadata(mission_item_list.item_count - 1, id)


func _on_cariye_item_selected(index: int) -> void:
	selected_cariye_id = cariye_item_list.get_item_metadata(index)
	_update_assign_button_state()
	_update_treat_button_state()


func _on_mission_item_selected(index: int) -> void:
	var metadata = mission_item_list.get_item_metadata(index)
	if typeof(metadata) == TYPE_INT:
		selected_gorev_id = metadata
	else:
		selected_gorev_id = -1
	_update_assign_button_state()
	_update_treat_button_state()


func _on_assign_button_pressed() -> void:
	if selected_cariye_id != -1 and selected_gorev_id != -1:
		var result = VillageManager.assign_cariye_to_mission(selected_cariye_id, selected_gorev_id)
		if result:
			cariye_item_list.deselect_all()
			mission_item_list.deselect_all()
			selected_cariye_id = -1
			selected_gorev_id = -1
			_update_assign_button_state()
			_update_treat_button_state()


func _on_close_button_pressed() -> void:
	hide()


func _on_treat_button_pressed() -> void:
	if selected_cariye_id == -1:
		return
	if not VillageManager.has_method("try_healer_concubine_treatment"):
		return
	VillageManager.try_healer_concubine_treatment(selected_cariye_id)
	populate_cariye_list()
	_update_assign_button_state()
	_update_treat_button_state()


func _update_assign_button_state() -> void:
	if selected_cariye_id != -1 and selected_gorev_id != -1:
		var gorev = VillageManager.gorevler.get(selected_gorev_id)
		var cariye = VillageManager.cariyeler.get(selected_cariye_id)
		if gorev and cariye:
			var is_mission_available = true
			for cariye_id_in_mission in VillageManager.active_missions:
				if VillageManager.active_missions[cariye_id_in_mission].get("gorev_id") == selected_gorev_id:
					is_mission_available = false
					break
			if is_mission_available and cariye.get("durum", "") == "boşta":
				assign_button.disabled = false
			else:
				assign_button.disabled = true
		else:
			assign_button.disabled = true
	else:
		assign_button.disabled = true


func _update_treat_button_state() -> void:
	if treat_button == null:
		return
	if selected_cariye_id == -1:
		treat_button.disabled = true
		return
	if VillageManager.has_method("can_healer_concubine_treat"):
		treat_button.disabled = not bool(VillageManager.can_healer_concubine_treat(selected_cariye_id))
	else:
		treat_button.disabled = true


func _on_visibility_changed() -> void:
	if visible:
		pass
	else:
		if cariye_item_list != null:
			cariye_item_list.deselect_all()
		if mission_item_list != null:
			mission_item_list.deselect_all()
		selected_cariye_id = -1
		selected_gorev_id = -1
		_update_treat_button_state()


func _refresh_locale(_locale: String = "") -> void:
	if _title_label:
		_title_label.text = tr("cariye.title")
	if _cariye_title_label:
		_cariye_title_label.text = tr("cariye.available")
	if _mission_title_label:
		_mission_title_label.text = tr("cariye.missions")
	if assign_button:
		assign_button.text = tr("cariye.assign")
	if close_button:
		close_button.text = tr("cariye.close")
	if treat_button:
		treat_button.text = tr("cariye.treat")
	_update_weekly_info()
	if visible and cariye_item_list and mission_item_list:
		populate_cariye_list()
		populate_mission_list()


func show_centered() -> void:
	visible = true
	await get_tree().process_frame

	cariye_item_list = get_node_or_null("MarginContainer/MainVBox/ContentHBox/CariyeVBox/CariyeItemList")
	if cariye_item_list == null:
		printerr("ERROR (show_centered): CariyeItemList node not found!")
		return

	mission_item_list = get_node_or_null("MarginContainer/MainVBox/ContentHBox/MissionVBox/MissionItemList")
	if mission_item_list == null:
		printerr("ERROR (show_centered): MissionItemList node not found!")
		return

	assign_button = get_node_or_null("MarginContainer/MainVBox/ActionHBox/AssignButton")
	if assign_button == null:
		printerr("ERROR (show_centered): AssignButton node not found!")
		return

	close_button = get_node_or_null("MarginContainer/MainVBox/ActionHBox/CloseButton")
	if close_button == null:
		printerr("ERROR (show_centered): CloseButton node not found!")
		return

	_title_label = get_node_or_null("MarginContainer/MainVBox/TitleLabel")
	_cariye_title_label = get_node_or_null("MarginContainer/MainVBox/ContentHBox/CariyeVBox/CariyeTitleLabel")
	_mission_title_label = get_node_or_null("MarginContainer/MainVBox/ContentHBox/MissionVBox/MissionTitleLabel")

	var action_hbox = get_node_or_null("MarginContainer/MainVBox/ActionHBox")
	if action_hbox == null:
		printerr("ERROR (show_centered): ActionHBox node not found!")
		return
	treat_button = action_hbox.get_node_or_null("TreatButton")
	if treat_button == null:
		treat_button = Button.new()
		treat_button.name = "TreatButton"
		action_hbox.add_child(treat_button)

	weekly_info_label = get_node_or_null("MarginContainer/MainVBox/WeeklyInfoLabel")
	if weekly_info_label == null:
		weekly_info_label = Label.new()
		weekly_info_label.name = "WeeklyInfoLabel"
		get_node("MarginContainer/MainVBox").add_child(weekly_info_label)

	if not cariye_item_list.is_connected("item_selected", Callable(self, "_on_cariye_item_selected")):
		cariye_item_list.item_selected.connect(_on_cariye_item_selected)
	if not mission_item_list.is_connected("item_selected", Callable(self, "_on_mission_item_selected")):
		mission_item_list.item_selected.connect(_on_mission_item_selected)
	if not assign_button.is_connected("pressed", Callable(self, "_on_assign_button_pressed")):
		assign_button.pressed.connect(_on_assign_button_pressed)
	if not close_button.is_connected("pressed", Callable(self, "_on_close_button_pressed")):
		close_button.pressed.connect(_on_close_button_pressed)
	if not treat_button.is_connected("pressed", Callable(self, "_on_treat_button_pressed")):
		treat_button.pressed.connect(_on_treat_button_pressed)

	if VillageManager.has_signal("cariye_data_changed") and not VillageManager.is_connected("cariye_data_changed", Callable(self, "populate_cariye_list")):
		VillageManager.cariye_data_changed.connect(populate_cariye_list)
	if VillageManager.has_signal("gorev_data_changed") and not VillageManager.is_connected("gorev_data_changed", Callable(self, "populate_mission_list")):
		VillageManager.gorev_data_changed.connect(populate_mission_list)

	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = size
	position = (viewport_size - panel_size) / 2

	_refresh_locale()
	populate_cariye_list()
	populate_mission_list()
	_update_assign_button_state()
	_update_treat_button_state()
	_update_weekly_info()


func _update_weekly_info() -> void:
	if not weekly_info_label:
		return
	var days_left := VillageManager.get_days_until_weekly_cariye_needs()
	if days_left == 0:
		weekly_info_label.text = tr("cariye.weekly_today")
	else:
		weekly_info_label.text = tr("cariye.weekly_days") % days_left
