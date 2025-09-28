extends Node2D
class_name DarknessController

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
@export var wall_shadow: float = 0.2

# Update sıklığı
@export var update_frequency: float = 60.0  # FPS
var update_timer: float = 0.0

func _ready() -> void:
	# Shader'ı yükle
	shader = load("res://shaders/distance_darkness.gdshader")
	if not shader:
		push_error("Distance darkness shader could not be loaded!")
		return
	
	# Shader material oluştur
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Parametreleri ayarla
	update_shader_parameters()
	
	# Player'ı bul
	find_player()
	
	# Camera'yı bul
	find_camera()

func _process(delta: float) -> void:
	update_timer += delta
	
	# Belirli sıklıkta güncelle
	if update_timer >= 1.0 / update_frequency:
		update_timer = 0.0
		update_player_position()

func find_player() -> void:
	# Player'ı bul
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		push_warning("No player found in 'player' group")

func find_camera() -> void:
	# Camera'yı bul
	if player and player.has_node("Camera2D"):
		camera = player.get_node("Camera2D")
	else:
		push_warning("No camera found")

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
	
	# Camera'nın zoom ve offset'ini dikkate alarak screen pozisyonunu hesapla
	var camera_pos = camera.global_position
	var camera_zoom = camera.zoom
	var viewport_size = viewport.get_visible_rect().size
	
	# World pozisyonunu screen pozisyonuna çevir
	var relative_pos = player_world_pos - camera_pos
	var player_screen_pos = (relative_pos * camera_zoom) + viewport_size / 2.0
	
	# Shader'a gönder
	shader_material.set_shader_parameter("player_position", player_screen_pos)

func update_shader_parameters() -> void:
	if not shader_material:
		return
	
	shader_material.set_shader_parameter("max_darkness", max_darkness)
	shader_material.set_shader_parameter("light_radius", light_radius)
	shader_material.set_shader_parameter("ambient_light", ambient_light)
	shader_material.set_shader_parameter("torch_boost", torch_boost)
	shader_material.set_shader_parameter("wall_shadow", wall_shadow)

func apply_to_tilemap(tilemap: TileMap) -> void:
	if not shader_material:
		push_error("Shader material not initialized!")
		return
	
	tilemap.material = shader_material

func remove_from_tilemap(tilemap: TileMap) -> void:
	tilemap.material = null

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
