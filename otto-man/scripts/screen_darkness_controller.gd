extends CanvasModulate
class_name ScreenDarknessController

# Shader material referansı
var shader_material: ShaderMaterial
var shader: Shader

# Player referansı
var player: Node2D
var camera: Camera2D

# Shader parametreleri
@export var max_darkness: float = 0.8
@export var light_radius: float = 200.0
@export var ambient_light: float = 0.2
@export var torch_boost: float = 0.3

# Update sıklığı
@export var update_frequency: float = 60.0  # FPS
var update_timer: float = 0.0
var debug_counter: int = 0  # Debug mesajları için ayrı sayaç

func _ready() -> void:
	print("[ScreenDarknessController] _ready() called")
	print("[ScreenDarknessController] Node path: ", get_path())
	print("[ScreenDarknessController] Parent: ", get_parent())
	print("[ScreenDarknessController] Scene tree: ", get_tree())
	
	# DEBUG: CanvasModulate'in temel özelliklerini kontrol et
	print("[ScreenDarknessController] DEBUG: CanvasModulate properties:")
	print("  - get_class(): ", get_class())
	print("  - is_inside_tree(): ", is_inside_tree())
	print("  - get_viewport(): ", get_viewport())
	print("  - get_process_mode(): ", get_process_mode())
	print("  - modulate: ", modulate)
	print("  - visible: ", visible)
	
	# Shader'ı yükle
	shader = load("res://shaders/screen_darkness.gdshader")
	if not shader:
		push_error("Screen darkness shader could not be loaded!")
		return
	
	print("[ScreenDarknessController] Shader loaded successfully: ", shader.resource_path)
	
	# Shader material oluştur
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Parametreleri ayarla
	update_shader_parameters()
	
	# Player'ı bul
	find_player()
	
	# Camera'yı bul
	find_camera()
	
	# TEST: Try EXTREME color modulation to see if CanvasModulate works at all
	modulate = Color(0.0, 0.0, 0.0, 1.0)  # BLACK - should make everything black
	
	# TEST: Remove material to test basic modulate only
	material = null
	
	# TEST: Farklı renklerle test et
	call_deferred("test_different_colors")
	
	# DEBUG: CanvasModulate'in son durumunu kontrol et
	print("[ScreenDarknessController] DEBUG: Final CanvasModulate state:")
	print("  - modulate: ", modulate)
	print("  - material: ", material)
	print("  - visible: ", visible)
	print("  - position: ", position)
	print("  - global_position: ", global_position)
	print("  - is_inside_tree(): ", is_inside_tree())
	print("  - get_viewport(): ", get_viewport())
	
	# DEBUG: Parent'ın özelliklerini kontrol et
	if get_parent():
		print("[ScreenDarknessController] DEBUG: Parent properties:")
		print("  - parent class: ", get_parent().get_class())
		print("  - parent name: ", get_parent().name)
		print("  - parent children count: ", get_parent().get_child_count())
		print("  - parent is inside tree: ", get_parent().is_inside_tree())
		
		# Parent'ın tüm çocuklarını listele
		print("[ScreenDarknessController] DEBUG: Parent children:")
		for i in range(get_parent().get_child_count()):
			var child = get_parent().get_child(i)
			print("  - child[", i, "]: ", child.name, " (", child.get_class(), ")")
	
	print("[ScreenDarknessController] TEST: Set modulate to bright green: ", modulate)

func _process(delta: float) -> void:
	update_timer += delta
	
	# DEBUG: Her 5 saniyede bir CanvasModulate durumunu kontrol et
	if debug_counter < 3 and update_timer > 5.0:
		print("[ScreenDarknessController] DEBUG: 5 second check - CanvasModulate still active?")
		print("  - modulate: ", modulate)
		print("  - visible: ", visible)
		print("  - is_inside_tree(): ", is_inside_tree())
		print("  - get_viewport(): ", get_viewport())
		debug_counter += 1
		update_timer = 0.0
	
	# Belirli sıklıkta güncelle
	if update_timer >= 1.0 / update_frequency:
		update_timer = 0.0
		update_player_position()

func find_player() -> void:
	# Player'ı bul
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("[ScreenDarknessController] Player found: ", player.name)
	else:
		print("[ScreenDarknessController] Warning: No player found in 'player' group")

func find_camera() -> void:
	# Camera'yı bul
	if player and player.has_node("Camera2D"):
		camera = player.get_node("Camera2D")
		print("[ScreenDarknessController] Camera found: ", camera.name)
	else:
		print("[ScreenDarknessController] Warning: No camera found")

func update_player_position() -> void:
	if not shader_material:
		return
	if not player:
		return
	if not camera:
		return
	
	# Player'ın screen pozisyonunu doğru şekilde hesapla
	var viewport = get_viewport()
	var player_world_pos = player.global_position
	
	# For screen-space shader, the player is always at the center of the screen
	# since the camera follows the player. We'll use the viewport center.
	var viewport_size = viewport.get_visible_rect().size
	var player_screen_pos = viewport_size / 2.0
	
	# Debug: Pozisyon hesaplamasını kontrol et
	if debug_counter < 10:  # İlk 10 güncellemede debug mesajı göster
		print("[ScreenDarknessController] DEBUG - player_world_pos: ", player_world_pos)
		print("[ScreenDarknessController] DEBUG - player_screen_pos: ", player_screen_pos)
		print("[ScreenDarknessController] DEBUG - viewport_size: ", viewport_size)
		print("[ScreenDarknessController] DEBUG - camera.position: ", camera.position)
		debug_counter += 1
	
	# Shader'a gönder
	shader_material.set_shader_parameter("player_screen_position", player_screen_pos)
	
	# Debug mesajı (sadece ilk birkaç kez)
	if debug_counter < 10:  # İlk 10 güncellemede debug mesajı göster
		print("[ScreenDarknessController] Updated player screen position: ", player_screen_pos, " (world: ", player_world_pos, ")")

func update_shader_parameters() -> void:
	if not shader_material:
		return
	
	shader_material.set_shader_parameter("max_darkness", max_darkness)
	shader_material.set_shader_parameter("light_radius", light_radius)
	shader_material.set_shader_parameter("ambient_light", ambient_light)
	shader_material.set_shader_parameter("torch_boost", torch_boost)

# Parametreleri runtime'da değiştirmek için
func set_max_darkness(value: float) -> void:
	max_darkness = clamp(value, 0.0, 1.0)
	update_shader_parameters()

func set_light_radius(value: float) -> void:
	light_radius = clamp(value, 50.0, 500.0)
	update_shader_parameters()

func set_ambient_light(value: float) -> void:
	ambient_light = clamp(value, 0.0, 1.0)
	update_shader_parameters()

# TEST: Farklı renklerle CanvasModulate'i test et
func test_different_colors() -> void:
	print("[ScreenDarknessController] TEST: Starting color test sequence...")
	
	# 2 saniye sonra kırmızı yap
	await get_tree().create_timer(2.0).timeout
	modulate = Color(1.0, 0.0, 0.0, 1.0)  # Red
	print("[ScreenDarknessController] TEST: Changed to RED")
	
	# 2 saniye sonra mavi yap
	await get_tree().create_timer(2.0).timeout
	modulate = Color(0.0, 0.0, 1.0, 1.0)  # Blue
	print("[ScreenDarknessController] TEST: Changed to BLUE")
	
	# 2 saniye sonra sarı yap
	await get_tree().create_timer(2.0).timeout
	modulate = Color(1.0, 1.0, 0.0, 1.0)  # Yellow
	print("[ScreenDarknessController] TEST: Changed to YELLOW")
	
	# 2 saniye sonra yeşile geri dön
	await get_tree().create_timer(2.0).timeout
	modulate = Color(0.0, 1.0, 0.0, 1.0)  # Green
	print("[ScreenDarknessController] TEST: Changed back to GREEN")
	
	print("[ScreenDarknessController] TEST: Color test sequence completed")
