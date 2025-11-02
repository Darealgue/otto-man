extends Control

@onready var _new_game_button: Button = $CenterContainer/Menu/Buttons/NewGameButton
@onready var _load_game_button: Button = $CenterContainer/Menu/Buttons/LoadGameButton
@onready var _settings_button: Button = $CenterContainer/Menu/Buttons/SettingsButton
@onready var _quit_button: Button = $CenterContainer/Menu/Buttons/QuitButton
@onready var _load_game_menu: Control = $LoadGameMenu

func _ready() -> void:
    if not _validate_nodes():
        return
    get_tree().paused = false
    print("[MainMenu] ready, setting focus")
    _new_game_button.grab_focus()
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    _connect_signals()
    _setup_load_game_menu()

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
    if is_instance_valid(SceneManager) and SceneManager.has_method("open_settings"):
        SceneManager.open_settings()
    else:
        push_warning("SceneManager.open_settings henüz uygulanmadı")

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

func _on_load_game_slot_selected(slot_id: int) -> void:
    print("[MainMenu] Loading game from slot %d..." % slot_id)
    if is_instance_valid(SaveManager):
        if SaveManager.load_game(slot_id):
            print("[MainMenu] ✅ Game loaded successfully")
        else:
            push_error("[MainMenu] Failed to load game from slot %d" % slot_id)
    else:
        push_error("[MainMenu] SaveManager not available!")

func _on_load_game_back() -> void:
    if _load_game_menu and _load_game_menu.has_method("hide_menu"):
        _load_game_menu.hide_menu()
    _new_game_button.grab_focus()

func _play_click() -> void:
    if is_instance_valid(SoundManager) and SoundManager.has_method("play_ui"):
        SoundManager.play_ui("click")

