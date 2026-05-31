extends Control

signal back_requested
signal settings_applied(settings: Dictionary)

const SETTINGS_PATH := "user://settings.cfg"
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

const DEFAULT_SETTINGS := {
	"audio": {
		"master_volume": 100,
		"music_volume": 80,
		"sfx_volume": 100,
	},
	"video": {
		"fullscreen": false,
		"vsync": true,
	},
	"game": {
		"show_damage_numbers": true,
		"show_fps": false,
		"camera_shake": true,
		"locale": "tr",
	},
	"controls": {
		"preset": InputManager.PRESET_WASD_NUMPAD,
	},
}

@onready var tab_container: TabContainer = $Panel/VBoxContainer/TabContainer
@onready var _title_label: Label = $Panel/VBoxContainer/Title
@onready var _hint_label: Label = $Panel/VBoxContainer/HintLabel

@onready var master_volume_label: Label = $Panel/VBoxContainer/TabContainer/AudioTab/MasterVolumeContainer/MasterVolumeLabel
@onready var master_volume_slider: HSlider = $Panel/VBoxContainer/TabContainer/AudioTab/MasterVolumeContainer/MasterVolumeSlider

@onready var music_volume_label: Label = $Panel/VBoxContainer/TabContainer/AudioTab/MusicVolumeContainer/MusicVolumeLabel
@onready var music_volume_slider: HSlider = $Panel/VBoxContainer/TabContainer/AudioTab/MusicVolumeContainer/MusicVolumeSlider

@onready var sfx_volume_label: Label = $Panel/VBoxContainer/TabContainer/AudioTab/SfxVolumeContainer/SfxVolumeLabel
@onready var sfx_volume_slider: HSlider = $Panel/VBoxContainer/TabContainer/AudioTab/SfxVolumeContainer/SfxVolumeSlider

@onready var fullscreen_checkbox: CheckBox = $Panel/VBoxContainer/TabContainer/VideoTab/FullscreenCheckBox
@onready var vsync_checkbox: CheckBox = $Panel/VBoxContainer/TabContainer/VideoTab/VSyncCheckBox

@onready var show_damage_checkbox: CheckBox = $Panel/VBoxContainer/TabContainer/GameTab/ShowDamageCheckBox
@onready var show_fps_checkbox: CheckBox = $Panel/VBoxContainer/TabContainer/GameTab/ShowFPSCheckBox
@onready var camera_shake_checkbox: CheckBox = $Panel/VBoxContainer/TabContainer/GameTab/CameraShakeCheckBox
@onready var _preset_label: Label = $Panel/VBoxContainer/TabContainer/ControlsTab/PresetLabel
@onready var preset_option: OptionButton = $Panel/VBoxContainer/TabContainer/ControlsTab/PresetOption
@onready var _preset_help_label: Label = $Panel/VBoxContainer/TabContainer/ControlsTab/PresetHelp

@onready var apply_button: Button = $Panel/VBoxContainer/ButtonContainer/ApplyButton
@onready var reset_button: Button = $Panel/VBoxContainer/ButtonContainer/ResetButton
@onready var back_button: Button = $Panel/VBoxContainer/ButtonContainer/BackButton

var _locale_option: OptionButton = null
var _locale_label: Label = null
var _current_settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)


func _ready() -> void:
	var panel := get_node_or_null("Panel") as Panel
	if panel:
		ParchmentTextures.apply_large_panel_style(panel, 14)
	TextOutline.apply_to_tree(self)
	_ensure_locale_controls()
	hide_menu()
	_connect_signals()
	_load_settings_from_disk()
	_apply_settings_to_controls()
	_apply_current_settings_to_runtime()
	set_process_unhandled_input(true)
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)
	_refresh_locale()


func _ensure_locale_controls() -> void:
	if _locale_option != null:
		return
	var game_tab: VBoxContainer = $Panel/VBoxContainer/TabContainer/GameTab
	var row := HBoxContainer.new()
	row.name = "LanguageRow"
	row.add_theme_constant_override("separation", 12)
	_locale_label = Label.new()
	_locale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_locale_label)
	_locale_option = OptionButton.new()
	_locale_option.focus_mode = Control.FOCUS_ALL
	_locale_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_locale_option.add_item("Türkçe", 0)
	_locale_option.set_item_metadata(0, "tr")
	_locale_option.add_item("English", 1)
	_locale_option.set_item_metadata(1, "en")
	row.add_child(_locale_option)
	game_tab.add_child(row)
	game_tab.move_child(row, 0)


func _connect_signals() -> void:
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

	apply_button.pressed.connect(_on_apply_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	preset_option.item_selected.connect(_on_preset_selected)


func show_menu() -> void:
	visible = true
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	_load_settings_from_disk()
	_apply_settings_to_controls()
	_refresh_locale()
	call_deferred("_focus_first_control")


func hide_menu() -> void:
	visible = false
	set_process_mode(Node.PROCESS_MODE_DISABLED)


func _focus_first_control() -> void:
	var tab_control := tab_container.get_current_tab_control()
	if tab_control:
		var focus_target := _find_first_focusable(tab_control)
		if focus_target:
			focus_target.grab_focus()
			return
	back_button.grab_focus()


func _find_first_focusable(node: Node) -> Control:
	if node is Control:
		var ctrl := node as Control
		if ctrl.focus_mode != Control.FOCUS_NONE:
			return ctrl
	for child in node.get_children():
		var result := _find_first_focusable(child)
		if result:
			return result
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	get_viewport().set_input_as_handled()

	if InputManager.is_ui_cancel_just_pressed():
		_on_back_pressed()
		return

	if InputManager.is_ui_page_left_just_pressed():
		_select_previous_tab()
		return
	elif InputManager.is_ui_page_right_just_pressed():
		_select_next_tab()
		return


func _select_previous_tab() -> void:
	var new_index := tab_container.current_tab - 1
	if new_index < 0:
		new_index = tab_container.get_tab_count() - 1
	tab_container.current_tab = new_index
	call_deferred("_focus_first_control")


func _select_next_tab() -> void:
	var new_index := (tab_container.current_tab + 1) % tab_container.get_tab_count()
	tab_container.current_tab = new_index
	call_deferred("_focus_first_control")


func _on_master_volume_changed(value: float) -> void:
	_update_volume_label(master_volume_label, tr("settings.audio.master"), value)


func _on_music_volume_changed(value: float) -> void:
	_update_volume_label(music_volume_label, tr("settings.audio.music"), value)


func _on_sfx_volume_changed(value: float) -> void:
	_update_volume_label(sfx_volume_label, tr("settings.audio.sfx"), value)


func _update_volume_label(label: Label, prefix: String, value: float) -> void:
	label.text = tr("settings.volume_format") % [prefix, int(value)]


func _on_apply_pressed() -> void:
	_apply_controls_to_settings()
	_apply_current_settings_to_runtime()
	_save_settings_to_disk()
	settings_applied.emit(_current_settings.duplicate(true))


func _on_reset_pressed() -> void:
	_current_settings = DEFAULT_SETTINGS.duplicate(true)
	_apply_settings_to_controls()
	call_deferred("_focus_first_control")


func _on_back_pressed() -> void:
	hide_menu()
	back_requested.emit()


func _apply_settings_to_controls() -> void:
	master_volume_slider.value = _current_settings["audio"]["master_volume"]
	music_volume_slider.value = _current_settings["audio"]["music_volume"]
	sfx_volume_slider.value = _current_settings["audio"]["sfx_volume"]

	fullscreen_checkbox.button_pressed = _current_settings["video"]["fullscreen"]
	vsync_checkbox.button_pressed = _current_settings["video"]["vsync"]

	show_damage_checkbox.button_pressed = _current_settings["game"]["show_damage_numbers"]
	show_fps_checkbox.button_pressed = _current_settings["game"]["show_fps"]
	camera_shake_checkbox.button_pressed = _current_settings["game"]["camera_shake"]
	_select_locale_option(String(_current_settings["game"]["locale"]))
	_populate_preset_option()
	_select_preset_option(_current_settings["controls"]["preset"])
	_refresh_volume_labels()


func _apply_controls_to_settings() -> void:
	_current_settings["audio"]["master_volume"] = int(master_volume_slider.value)
	_current_settings["audio"]["music_volume"] = int(music_volume_slider.value)
	_current_settings["audio"]["sfx_volume"] = int(sfx_volume_slider.value)

	_current_settings["video"]["fullscreen"] = fullscreen_checkbox.button_pressed
	_current_settings["video"]["vsync"] = vsync_checkbox.button_pressed

	_current_settings["game"]["show_damage_numbers"] = show_damage_checkbox.button_pressed
	_current_settings["game"]["show_fps"] = show_fps_checkbox.button_pressed
	_current_settings["game"]["camera_shake"] = camera_shake_checkbox.button_pressed
	_current_settings["game"]["locale"] = _get_selected_locale()
	_current_settings["controls"]["preset"] = _get_preset_name(preset_option.selected)


func _apply_current_settings_to_runtime() -> void:
	_apply_audio_volume(MASTER_BUS, _current_settings["audio"]["master_volume"])
	_apply_audio_volume(MUSIC_BUS, _current_settings["audio"]["music_volume"])
	_apply_audio_volume(SFX_BUS, _current_settings["audio"]["sfx_volume"])

	_apply_fullscreen(_current_settings["video"]["fullscreen"])
	_apply_vsync(_current_settings["video"]["vsync"])
	InputManager.apply_keyboard_preset(_current_settings["controls"]["preset"])
	LocaleManager.set_locale(String(_current_settings["game"]["locale"]))


func _apply_audio_volume(bus_name: String, percent: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var clamped: int = clamp(percent, 0, 100)
	var linear: float = clamped / 100.0
	var db := -80.0
	if linear > 0.0:
		db = linear_to_db(linear)
	AudioServer.set_bus_volume_db(bus_index, db)


func _apply_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _apply_vsync(enabled: bool) -> void:
	var vsync_mode: int = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)


func _refresh_locale(_locale: String = "") -> void:
	if _title_label:
		_title_label.text = tr("settings.title")
	if _hint_label:
		_hint_label.text = tr("settings.hint")
	if _locale_label:
		_locale_label.text = tr("settings.game.language")
	if fullscreen_checkbox:
		fullscreen_checkbox.text = tr("settings.video.fullscreen")
	if vsync_checkbox:
		vsync_checkbox.text = tr("settings.video.vsync")
	if show_damage_checkbox:
		show_damage_checkbox.text = tr("settings.game.show_damage")
	if show_fps_checkbox:
		show_fps_checkbox.text = tr("settings.game.show_fps")
	if camera_shake_checkbox:
		camera_shake_checkbox.text = tr("settings.game.camera_shake")
	if _preset_label:
		_preset_label.text = tr("settings.controls.preset_label")
	if _preset_help_label:
		_preset_help_label.text = tr("settings.controls.preset_help")
	if apply_button:
		apply_button.text = tr("settings.apply")
	if reset_button:
		reset_button.text = tr("settings.reset")
	if back_button:
		back_button.text = tr("settings.back")
	_set_tab_titles()
	_refresh_volume_labels()
	_refresh_preset_option_labels()


func _refresh_volume_labels() -> void:
	if master_volume_label:
		_update_volume_label(master_volume_label, tr("settings.audio.master"), master_volume_slider.value)
	if music_volume_label:
		_update_volume_label(music_volume_label, tr("settings.audio.music"), music_volume_slider.value)
	if sfx_volume_label:
		_update_volume_label(sfx_volume_label, tr("settings.audio.sfx"), sfx_volume_slider.value)


func _set_tab_titles() -> void:
	if tab_container.get_tab_count() >= 1:
		tab_container.set_tab_title(0, tr("settings.tab.audio"))
	if tab_container.get_tab_count() >= 2:
		tab_container.set_tab_title(1, tr("settings.tab.video"))
	if tab_container.get_tab_count() >= 3:
		tab_container.set_tab_title(2, tr("settings.tab.game"))
	if tab_container.get_tab_count() >= 4:
		tab_container.set_tab_title(3, tr("settings.tab.controls"))


func _load_settings_from_disk() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		_current_settings = DEFAULT_SETTINGS.duplicate(true)
		return

	_current_settings = DEFAULT_SETTINGS.duplicate(true)

	_current_settings["audio"]["master_volume"] = config.get_value("audio", "master_volume", DEFAULT_SETTINGS["audio"]["master_volume"])
	_current_settings["audio"]["music_volume"] = config.get_value("audio", "music_volume", DEFAULT_SETTINGS["audio"]["music_volume"])
	_current_settings["audio"]["sfx_volume"] = config.get_value("audio", "sfx_volume", DEFAULT_SETTINGS["audio"]["sfx_volume"])

	_current_settings["video"]["fullscreen"] = config.get_value("video", "fullscreen", DEFAULT_SETTINGS["video"]["fullscreen"])
	_current_settings["video"]["vsync"] = config.get_value("video", "vsync", DEFAULT_SETTINGS["video"]["vsync"])

	_current_settings["game"]["show_damage_numbers"] = config.get_value("game", "show_damage_numbers", DEFAULT_SETTINGS["game"]["show_damage_numbers"])
	_current_settings["game"]["show_fps"] = config.get_value("game", "show_fps", DEFAULT_SETTINGS["game"]["show_fps"])
	_current_settings["game"]["camera_shake"] = config.get_value("game", "camera_shake", DEFAULT_SETTINGS["game"]["camera_shake"])
	_current_settings["game"]["locale"] = config.get_value("game", "locale", DEFAULT_SETTINGS["game"]["locale"])
	_current_settings["controls"]["preset"] = config.get_value("controls", "preset", DEFAULT_SETTINGS["controls"]["preset"])


func _save_settings_to_disk() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "master_volume", _current_settings["audio"]["master_volume"])
	config.set_value("audio", "music_volume", _current_settings["audio"]["music_volume"])
	config.set_value("audio", "sfx_volume", _current_settings["audio"]["sfx_volume"])
	config.set_value("video", "fullscreen", _current_settings["video"]["fullscreen"])
	config.set_value("video", "vsync", _current_settings["video"]["vsync"])
	config.set_value("game", "show_damage_numbers", _current_settings["game"]["show_damage_numbers"])
	config.set_value("game", "show_fps", _current_settings["game"]["show_fps"])
	config.set_value("game", "camera_shake", _current_settings["game"]["camera_shake"])
	config.set_value("game", "locale", _current_settings["game"]["locale"])
	config.set_value("controls", "preset", _current_settings["controls"]["preset"])
	config.save(SETTINGS_PATH)


func _populate_preset_option() -> void:
	if preset_option.item_count == 0:
		preset_option.add_item(tr("settings.controls.preset_wasd"))
		preset_option.set_item_metadata(0, InputManager.PRESET_WASD_NUMPAD)
		preset_option.add_item(tr("settings.controls.preset_arrows"))
		preset_option.set_item_metadata(1, InputManager.PRESET_ARROWS_QWEASD)


func _refresh_preset_option_labels() -> void:
	if preset_option.item_count < 2:
		return
	preset_option.set_item_text(0, tr("settings.controls.preset_wasd"))
	preset_option.set_item_text(1, tr("settings.controls.preset_arrows"))


func _select_preset_option(preset_name: StringName) -> void:
	for i in range(preset_option.item_count):
		var metadata = preset_option.get_item_metadata(i)
		if metadata == preset_name:
			preset_option.select(i)
			return


func _get_preset_name(selected_index: int) -> StringName:
	if selected_index < 0 or selected_index >= preset_option.item_count:
		return InputManager.PRESET_WASD_NUMPAD
	var metadata = preset_option.get_item_metadata(selected_index)
	var metadata_type := typeof(metadata)
	if metadata_type == TYPE_STRING_NAME:
		return metadata
	if metadata_type == TYPE_STRING:
		return StringName(metadata)
	return InputManager.PRESET_WASD_NUMPAD


func _get_selected_locale() -> String:
	if _locale_option == null:
		return LocaleManager.DEFAULT_LOCALE
	var metadata = _locale_option.get_item_metadata(_locale_option.selected)
	return String(metadata) if metadata != null else LocaleManager.DEFAULT_LOCALE


func _select_locale_option(locale_code: String) -> void:
	if _locale_option == null:
		return
	for i in range(_locale_option.item_count):
		if String(_locale_option.get_item_metadata(i)) == locale_code:
			_locale_option.select(i)
			return
	_locale_option.select(0)


func _on_preset_selected(index: int) -> void:
	_current_settings["controls"]["preset"] = _get_preset_name(index)
