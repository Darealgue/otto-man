extends Control
class_name DarknessDebugPanel

# UI elementleri
var darkness_controller: DarknessController
var max_darkness_slider: HSlider
var light_radius_slider: HSlider
var ambient_light_slider: HSlider
var torch_boost_slider: HSlider
var wall_shadow_slider: HSlider

# Labels
var max_darkness_label: Label
var light_radius_label: Label
var ambient_light_label: Label
var torch_boost_label: Label
var wall_shadow_label: Label

func _ready() -> void:
    # Panel'i gizle
    visible = false
    
    # Darkness controller'ı bul
    find_darkness_controller()
    
    # UI oluştur
    create_ui()

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):  # ESC tuşu
        visible = !visible

func find_darkness_controller() -> void:
    # UnifiedTerrain'deki darkness controller'ı bul
    var unified_terrain = get_tree().get_first_node_in_group("unified_terrain")
    if unified_terrain and unified_terrain.has_method("get") and unified_terrain.get("darkness_controller"):
        darkness_controller = unified_terrain.darkness_controller
        print("[DarknessDebugPanel] Found darkness controller")
    else:
        print("[DarknessDebugPanel] Warning: No darkness controller found")

func create_ui() -> void:
    # Ana container
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # Başlık
    var title = Label.new()
    title.text = "Darkness Shader Debug Panel"
    title.add_theme_font_size_override("font_size", 16)
    vbox.add_child(title)
    
    # Max Darkness
    create_slider_control(vbox, "Max Darkness", 0.0, 1.0, 0.8, "max_darkness")
    
    # Light Radius
    create_slider_control(vbox, "Light Radius", 50.0, 500.0, 200.0, "light_radius")
    
    # Ambient Light
    create_slider_control(vbox, "Ambient Light", 0.0, 1.0, 0.2, "ambient_light")
    
    # Torch Boost
    create_slider_control(vbox, "Torch Boost", 0.0, 1.0, 0.3, "torch_boost")
    
    # Wall Shadow
    create_slider_control(vbox, "Wall Shadow", 0.0, 1.0, 0.2, "wall_shadow")
    
    # Reset button
    var reset_button = Button.new()
    reset_button.text = "Reset to Defaults"
    reset_button.pressed.connect(_on_reset_pressed)
    vbox.add_child(reset_button)

func create_slider_control(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, default_val: float, property: String) -> void:
    var hbox = HBoxContainer.new()
    parent.add_child(hbox)
    
    # Label
    var label = Label.new()
    label.text = label_text + ": "
    label.custom_minimum_size.x = 120
    hbox.add_child(label)
    
    # Value label
    var value_label = Label.new()
    value_label.text = str(default_val)
    value_label.custom_minimum_size.x = 60
    hbox.add_child(value_label)
    
    # Slider
    var slider = HSlider.new()
    slider.min_value = min_val
    slider.max_value = max_val
    slider.value = default_val
    slider.custom_minimum_size.x = 200
    hbox.add_child(slider)
    
    # Slider signal'ını bağla
    slider.value_changed.connect(func(value): _on_slider_changed(property, value, value_label))

func _on_slider_changed(property: String, value: float, label: Label) -> void:
    label.text = str(value)
    
    if darkness_controller:
        match property:
            "max_darkness":
                darkness_controller.set_max_darkness(value)
            "light_radius":
                darkness_controller.set_light_radius(value)
            "ambient_light":
                darkness_controller.set_ambient_light(value)
            "torch_boost":
                darkness_controller.torch_boost = value
                darkness_controller.update_shader_parameters()
            "wall_shadow":
                darkness_controller.wall_shadow = value
                darkness_controller.update_shader_parameters()

func _on_reset_pressed() -> void:
    if darkness_controller:
        darkness_controller.max_darkness = 0.8
        darkness_controller.light_radius = 200.0
        darkness_controller.ambient_light = 0.2
        darkness_controller.torch_boost = 0.3
        darkness_controller.wall_shadow = 0.2
        darkness_controller.update_shader_parameters()
        
        # UI'yi güncelle
        update_ui_values()

func update_ui_values() -> void:
    # Slider'ları güncelle
    if max_darkness_slider:
        max_darkness_slider.value = darkness_controller.max_darkness
    if light_radius_slider:
        light_radius_slider.value = darkness_controller.light_radius
    if ambient_light_slider:
        ambient_light_slider.value = darkness_controller.ambient_light
    if torch_boost_slider:
        torch_boost_slider.value = darkness_controller.torch_boost
    if wall_shadow_slider:
        wall_shadow_slider.value = darkness_controller.wall_shadow
