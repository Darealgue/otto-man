extends Control

@onready var _new_game_button: Button = $CenterContainer/Menu/Buttons/NewGameButton
@onready var _load_game_button: Button = $CenterContainer/Menu/Buttons/LoadGameButton
@onready var _settings_button: Button = $CenterContainer/Menu/Buttons/SettingsButton
@onready var _quit_button: Button = $CenterContainer/Menu/Buttons/QuitButton
@onready var _load_game_menu: Control = $LoadGameMenu
var _settings_menu: Control = null

func _ready() -> void:
    if not _validate_nodes():
        return
    
    # Ensure game is not paused (use GameState if available)
    if is_instance_valid(GameState) and GameState.has_method("resume"):
        GameState.resume()
    else:
        get_tree().paused = false
    
    print("[MainMenu] ready, setting focus")
    _new_game_button.grab_focus()
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    _connect_signals()
    _setup_load_game_menu()
    _setup_settings_menu()

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

func _on_new_game_pressed() -> void:
    _play_click()
    if is_instance_valid(SceneManager) and SceneManager.has_method("start_new_game"):
        SceneManager.start_new_game()
    else:
        push_warning("SceneManager.start_new_game bulunamadı")

func _on_load_game_pressed() -> void:
    _play_click()
    if _load_game_menu and _load_game_menu.has_method("show_menu"):
        _load_game_menu.show_menu()
        if _load_game_menu.has_method("set_process_mode"):
            _load_game_menu.set_process_mode(Node.PROCESS_MODE_ALWAYS)
    else:
        push_warning("LoadGameMenu not available")

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
    
    if _settings_menu.has_method("hide_menu"):
        _settings_menu.hide_menu()

func _on_settings_back() -> void:
    if _settings_menu and _settings_menu.has_method("hide_menu"):
        _settings_menu.hide_menu()
    # Re-enable focus on main menu buttons
    _enable_main_menu_focus()
    _new_game_button.grab_focus()

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
        
        if SaveManager.load_game(slot_id):
            print("[MainMenu] ✅ Game loaded successfully")
        else:
            push_error("[MainMenu] Failed to load game from slot %d" % slot_id)
            _show_error("Yükleme Başarısız", "Kayıt yüklenemedi.")
    else:
        push_error("[MainMenu] SaveManager not available!")
        _show_error("Hata", "Kayıt yöneticisi bulunamadı.")

func _on_load_completed(slot_id: int, success: bool) -> void:
    if not success:
        _show_error("Yükleme Başarısız", "Kayıt yüklenemedi. Dosya bozulmuş olabilir.")

func _on_save_manager_error(error_message: String, error_type: String) -> void:
    if error_type == "load" or error_type == "validation":
        _show_error("Yükleme Hatası", error_message)

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
    _new_game_button.grab_focus()

func _play_click() -> void:
    if is_instance_valid(SoundManager) and SoundManager.has_method("play_ui"):
        SoundManager.play_ui("click")

