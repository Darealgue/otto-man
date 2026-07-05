extends Control

@onready var _landscape: Control = $Landscape
@onready var _menu_dimmer: ColorRect = $MenuDimmer
@onready var _intro_fade: ColorRect = $IntroFade
@onready var _press_prompt: Label = $PressPrompt
@onready var _menu_root: CenterContainer = $CenterContainer
@onready var _new_game_button: Button = $CenterContainer/Menu/Buttons/NewGameButton
@onready var _load_game_button: Button = $CenterContainer/Menu/Buttons/LoadGameButton
@onready var _settings_button: Button = $CenterContainer/Menu/Buttons/SettingsButton
@onready var _quit_button: Button = $CenterContainer/Menu/Buttons/QuitButton
@onready var _subtitle_label: Label = $CenterContainer/Menu/Subtitle
@onready var _load_game_menu: Control = $LoadGameMenu
var _settings_menu: Control = null
var _profile_menu: Control = null
var _tutorial_prompt: Control = null
## Hangi akıştan profil menüsü açıldı (geri dönüşte odak için)
var _profile_opened_for_new_game: bool = true
var _intro_dismissed: bool = false
var _intro_tween: Tween = null
var _cold_start_fading: bool = false

const INTRO_REVEAL_DURATION: float = 0.55
const COLD_START_FADE_DURATION: float = 4.8

func _ready() -> void:
	if not _validate_nodes():
		return
	
	# Ensure game is not paused (use GameState if available)
	if is_instance_valid(GameState) and GameState.has_method("resume"):
		GameState.resume()
	else:
		get_tree().paused = false
	
	print("[MainMenu] ready, intro landscape active")
	_connect_signals()
	_setup_load_game_menu()
	_setup_settings_menu()
	_setup_profile_select_menu()
	_setup_new_game_tutorial_prompt()
	_setup_intro_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)
	_refresh_locale()
	_apply_startup_audio_settings()
	await _play_startup_fade_if_needed()


func _setup_intro_state() -> void:
	_intro_dismissed = false
	if _menu_root:
		_menu_root.modulate.a = 0.0
		_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _menu_dimmer:
		_menu_dimmer.modulate.a = 0.0
	if _press_prompt:
		_press_prompt.show()
		if _should_play_cold_start_fade():
			_press_prompt.modulate.a = 0.0
	_disable_main_menu_focus()


func _should_play_cold_start_fade() -> bool:
	if not is_instance_valid(SceneManager):
		return true
	return SceneManager.previous_scene_path.is_empty()


func _play_startup_fade_if_needed() -> void:
	if not _should_play_cold_start_fade():
		_clear_intro_fade()
		return
	if not is_instance_valid(_intro_fade):
		return

	_cold_start_fading = true
	_intro_fade.show()
	_intro_fade.color = Color(0, 0, 0, 1)
	_intro_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_intro_fade, "color:a", 0.0, COLD_START_FADE_DURATION)
	if _press_prompt:
		tween.parallel().tween_property(_press_prompt, "modulate:a", 1.0, COLD_START_FADE_DURATION)
	await tween.finished

	_clear_intro_fade()
	_cold_start_fading = false


func _clear_intro_fade() -> void:
	if not is_instance_valid(_intro_fade):
		return
	_intro_fade.color = Color(0, 0, 0, 0)
	_intro_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_fade.hide()


func _process(_delta: float) -> void:
	if _cold_start_fading or _intro_dismissed or not is_instance_valid(_press_prompt) or not _press_prompt.visible:
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.004)
	_press_prompt.modulate.a = pulse


func _unhandled_input(event: InputEvent) -> void:
	if _cold_start_fading or _intro_dismissed:
		return
	if _is_intro_dismiss_input(event):
		get_viewport().set_input_as_handled()
		_dismiss_intro()


func _is_intro_dismiss_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


func _dismiss_intro() -> void:
	if _intro_dismissed:
		return
	_intro_dismissed = true
	if _press_prompt:
		_press_prompt.hide()
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.set_ease(Tween.EASE_OUT)
	_intro_tween.set_trans(Tween.TRANS_CUBIC)
	if _menu_dimmer:
		_intro_tween.tween_property(_menu_dimmer, "modulate:a", 1.0, INTRO_REVEAL_DURATION)
	if _menu_root:
		_intro_tween.tween_property(_menu_root, "modulate:a", 1.0, INTRO_REVEAL_DURATION)
	_intro_tween.finished.connect(_on_intro_reveal_finished)


func _on_intro_reveal_finished() -> void:
	if _menu_root:
		_menu_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_enable_main_menu_focus()
	if _new_game_button:
		_new_game_button.grab_focus()

func _validate_nodes() -> bool:
	if not is_instance_valid(_new_game_button):
		push_error("MainMenu: NewGameButton bulunamadı; node path kontrol et")
		return false
	if not is_instance_valid(_load_game_button):
		push_error("MainMenu: LoadGameButton bulunamadı")
		return false
	if not is_instance_valid(_settings_button):
		push_error("MainMenu: SettingsButton bulunamadı")
		return false
	if not is_instance_valid(_quit_button):
		push_error("MainMenu: QuitButton bulunamadı")
		return false
	return true

func _connect_signals() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_game_button.pressed.connect(_on_load_game_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _refresh_locale(_locale: String = "") -> void:
	if _press_prompt:
		_press_prompt.text = tr("menu.press_any_button")
	if _subtitle_label:
		_subtitle_label.text = tr("menu.subtitle")
	if _new_game_button:
		_new_game_button.text = tr("menu.new_game")
	if _load_game_button:
		_load_game_button.text = tr("menu.load_game")
	if _settings_button:
		_settings_button.text = tr("menu.settings")
	if _quit_button:
		_quit_button.text = tr("menu.quit")

func _on_new_game_pressed() -> void:
	_play_click()
	_profile_opened_for_new_game = true
	_open_profile_menu(ProfileSelectMenu.MenuIntent.NEW_GAME)

func _on_load_game_pressed() -> void:
	_play_click()
	_profile_opened_for_new_game = false
	_open_profile_menu(ProfileSelectMenu.MenuIntent.LOAD)

func _on_settings_pressed() -> void:
	_play_click()
	if _settings_menu and _settings_menu.has_method("show_menu"):
		# Disable focus on main menu buttons while settings is open
		_disable_main_menu_focus()
		_settings_menu.show_menu()
		if _settings_menu.has_method("set_process_mode"):
			_settings_menu.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	else:
		push_warning("SettingsMenu not available")

func _on_quit_pressed() -> void:
	_play_click()
	get_tree().quit()

func _setup_load_game_menu() -> void:
	if not _load_game_menu:
		push_warning("[MainMenu] LoadGameMenu node not found, creating instance...")
		var load_menu_scene = load("res://ui/LoadGameMenu.tscn")
		if load_menu_scene:
			_load_game_menu = load_menu_scene.instantiate()
			_load_game_menu.name = "LoadGameMenu"
			add_child(_load_game_menu)
		else:
			push_error("[MainMenu] Failed to load LoadGameMenu scene!")
			return
	
	if _load_game_menu.has_signal("slot_selected"):
		_load_game_menu.slot_selected.connect(_on_load_game_slot_selected)
	if _load_game_menu.has_signal("back_requested"):
		_load_game_menu.back_requested.connect(_on_load_game_back)
	
	if _load_game_menu.has_method("hide_menu"):
		_load_game_menu.hide_menu()

func _setup_new_game_tutorial_prompt() -> void:
	if _tutorial_prompt:
		return
	var sc: PackedScene = load("res://tutorial/ui/NewGameTutorialPrompt.tscn") as PackedScene
	if not sc:
		push_error("[MainMenu] NewGameTutorialPrompt.tscn yüklenemedi")
		return
	_tutorial_prompt = sc.instantiate()
	_tutorial_prompt.name = "NewGameTutorialPrompt"
	add_child(_tutorial_prompt)
	if _tutorial_prompt.has_signal("tutorial_chosen"):
		_tutorial_prompt.tutorial_chosen.connect(_on_new_game_tutorial_play)
	if _tutorial_prompt.has_signal("skip_tutorial_chosen"):
		_tutorial_prompt.skip_tutorial_chosen.connect(_on_new_game_tutorial_skip)
	if _tutorial_prompt.has_signal("back_requested"):
		_tutorial_prompt.back_requested.connect(_on_new_game_tutorial_back)


func _show_new_game_tutorial_choice() -> void:
	if _tutorial_prompt and _tutorial_prompt.has_method("show_prompt"):
		move_child(_tutorial_prompt, maxi(0, get_child_count() - 1))
		_tutorial_prompt.show_prompt()
	elif is_instance_valid(SceneManager) and SceneManager.has_method("start_new_game"):
		SceneManager.start_new_game(false)


func _on_new_game_tutorial_play() -> void:
	_play_click()
	if _tutorial_prompt and _tutorial_prompt.has_method("hide_prompt"):
		_tutorial_prompt.hide_prompt()
	if is_instance_valid(SceneManager) and SceneManager.has_method("start_new_game"):
		SceneManager.start_new_game(true)


func _on_new_game_tutorial_skip() -> void:
	_play_click()
	if _tutorial_prompt and _tutorial_prompt.has_method("hide_prompt"):
		_tutorial_prompt.hide_prompt()
	if is_instance_valid(SceneManager) and SceneManager.has_method("start_new_game"):
		SceneManager.start_new_game(false)


func _on_new_game_tutorial_back() -> void:
	_play_click()
	if _tutorial_prompt and _tutorial_prompt.has_method("hide_prompt"):
		_tutorial_prompt.hide_prompt()
	_open_profile_menu(ProfileSelectMenu.MenuIntent.NEW_GAME)


func _setup_profile_select_menu() -> void:
	if _profile_menu:
		return
	var sc: PackedScene = load("res://ui/ProfileSelectMenu.tscn") as PackedScene
	if not sc:
		push_error("[MainMenu] ProfileSelectMenu.tscn yüklenemedi")
		return
	_profile_menu = sc.instantiate()
	_profile_menu.name = "ProfileSelectMenu"
	add_child(_profile_menu)
	if _profile_menu.has_signal("profile_chosen"):
		_profile_menu.profile_chosen.connect(_on_profile_chosen)
	if _profile_menu.has_signal("back_requested"):
		_profile_menu.back_requested.connect(_on_profile_menu_back)
	if _profile_menu.has_method("hide_menu"):
		_profile_menu.hide_menu()


func _open_profile_menu(intent: ProfileSelectMenu.MenuIntent) -> void:
	if _profile_menu and _profile_menu.has_method("show_menu"):
		_disable_main_menu_focus()
		move_child(_profile_menu, maxi(0, get_child_count() - 1))
		_profile_menu.show_menu(intent)
	else:
		push_warning("[MainMenu] Profil menüsü yok — doğrudan devam")
		if intent == ProfileSelectMenu.MenuIntent.NEW_GAME and is_instance_valid(SceneManager):
			_show_new_game_tutorial_choice()
		elif intent == ProfileSelectMenu.MenuIntent.LOAD and _load_game_menu and _load_game_menu.has_method("show_menu"):
			_load_game_menu.show_menu()


func _on_profile_chosen(profile_id: int) -> void:
	if is_instance_valid(SaveManager) and SaveManager.has_method("set_active_profile"):
		SaveManager.set_active_profile(profile_id)
	if _profile_menu and _profile_menu.has_method("hide_menu"):
		_profile_menu.hide_menu()
	if _profile_opened_for_new_game:
		_show_new_game_tutorial_choice()
	else:
		if _load_game_menu and _load_game_menu.has_method("show_menu"):
			_load_game_menu.show_menu()
			if _load_game_menu.has_method("set_process_mode"):
				_load_game_menu.set_process_mode(Node.PROCESS_MODE_ALWAYS)
		# Yükleme ekranı açıkken ana menü butonları kapalı kalsın; Load geri de enable eder


func _on_profile_menu_back() -> void:
	if _profile_menu and _profile_menu.has_method("hide_menu"):
		_profile_menu.hide_menu()
	_enable_main_menu_focus()
	if _profile_opened_for_new_game:
		if _new_game_button:
			_new_game_button.grab_focus()
	else:
		if _load_game_button:
			_load_game_button.grab_focus()


func _setup_settings_menu() -> void:
	if not _settings_menu:
		push_warning("[MainMenu] SettingsMenu node not found, creating instance...")
		var settings_menu_scene = load("res://ui/SettingsMenu.tscn")
		if settings_menu_scene:
			_settings_menu = settings_menu_scene.instantiate()
			_settings_menu.name = "SettingsMenu"
			add_child(_settings_menu)
		else:
			push_error("[MainMenu] Failed to load SettingsMenu scene!")
			return
	
	if _settings_menu.has_signal("back_requested"):
		_settings_menu.back_requested.connect(_on_settings_back)
	if _settings_menu.has_signal("settings_applied"):
		_settings_menu.settings_applied.connect(_on_settings_applied)
	
	if _settings_menu.has_method("hide_menu"):
		_settings_menu.hide_menu()

func _on_settings_back() -> void:
	if _settings_menu and _settings_menu.has_method("hide_menu"):
		_settings_menu.hide_menu()
	_enable_main_menu_focus()
	_new_game_button.grab_focus()


func _on_settings_applied(_settings: Dictionary) -> void:
	_refresh_locale()

func _disable_main_menu_focus() -> void:
	# Disable focus on all buttons so they can't be navigated to while settings is open
	if _new_game_button:
		_new_game_button.focus_mode = Control.FOCUS_NONE
	if _load_game_button:
		_load_game_button.focus_mode = Control.FOCUS_NONE
	if _settings_button:
		_settings_button.focus_mode = Control.FOCUS_NONE
	if _quit_button:
		_quit_button.focus_mode = Control.FOCUS_NONE

func _enable_main_menu_focus() -> void:
	# Re-enable focus on all buttons
	if _new_game_button:
		_new_game_button.focus_mode = Control.FOCUS_ALL
	if _load_game_button:
		_load_game_button.focus_mode = Control.FOCUS_ALL
	if _settings_button:
		_settings_button.focus_mode = Control.FOCUS_ALL
	if _quit_button:
		_quit_button.focus_mode = Control.FOCUS_ALL

func _on_load_game_slot_selected(slot_id: int) -> void:
	print("[MainMenu] Loading game from slot %d..." % slot_id)
	if is_instance_valid(SaveManager):
		# Connect to error signals if not already connected
		if SaveManager.has_signal("error_occurred"):
			if not SaveManager.error_occurred.is_connected(_on_save_manager_error):
				SaveManager.error_occurred.connect(_on_save_manager_error)
		if SaveManager.has_signal("load_completed"):
			if not SaveManager.load_completed.is_connected(_on_load_completed):
				SaveManager.load_completed.connect(_on_load_completed)
		
		var loaded_ok: bool = false
		if slot_id == SaveManager.AUTOSAVE_UI_SLOT_ID:
			loaded_ok = SaveManager.load_autosave()
		else:
			loaded_ok = SaveManager.load_game(slot_id)
		if loaded_ok:
			print("[MainMenu] ✅ Game loaded successfully")
		else:
			push_error("[MainMenu] Failed to load game from slot %d" % slot_id)
			_show_error(tr("error.load_failed_title"), tr("error.load_failed_message"))
	else:
		push_error("[MainMenu] SaveManager not available!")
		_show_error(tr("error.title"), tr("error.save_manager_missing"))

func _on_load_completed(slot_id: int, success: bool) -> void:
	if not success:
		_show_error(tr("error.load_failed_title"), tr("error.load_failed_corrupt"))


func _on_save_manager_error(error_message: String, error_type: String) -> void:
	if error_type == "load" or error_type == "validation":
		_show_error(tr("error.load_error_title"), error_message)

func _show_error(title: String, message: String) -> void:
	"""Show error dialog"""
	var error_dialog_scene = load("res://ui/ErrorDialog.tscn")
	if error_dialog_scene:
		var error_dialog = error_dialog_scene.instantiate()
		get_tree().root.add_child(error_dialog)
		if error_dialog.has_method("show_error"):
			error_dialog.show_error(title, message)

func _on_load_game_back() -> void:
	if _load_game_menu and _load_game_menu.has_method("hide_menu"):
		_load_game_menu.hide_menu()
	_enable_main_menu_focus()
	if _new_game_button:
		_new_game_button.grab_focus()

func _play_click() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_ui"):
		SoundManager.play_ui("click")


func _apply_startup_audio_settings() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("_apply_saved_volume_from_settings"):
		SoundManager._apply_saved_volume_from_settings()
