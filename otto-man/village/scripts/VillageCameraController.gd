extends Camera2D
class_name VillageCameraController

## Sol sınır (X pozisyonu) - Oyuncu bu noktanın soluna geçerse kamera takibi durur
@export var left_limit: float = -2000.0

## Sağ sınır (X pozisyonu) - Oyuncu bu noktanın sağına geçerse kamera takibi durur
@export var right_limit: float = 2000.0

## Kamera takip hızı (smooth follow için)
@export var follow_speed: float = 10.0

var player: Node2D = null
var is_following: bool = true

func _ready() -> void:
	# Camera2D'nin position smoothing'ini devre dışı bırak (kendi kontrolümüzü kullanacağız)
	position_smoothing_enabled = false
	
	# Process callback'lerini hemen etkinleştir
	set_process(true)
	set_physics_process(true)
	# print("[VillageCameraController] _ready: Processes enabled: process=", is_processing(), " physics_process=", is_physics_processing())
	
	# Script runtime'da eklendiğinde player henüz hazır olmayabilir, bu yüzden deferred call kullan
	call_deferred("_initialize_player")

func _enter_tree() -> void:
	# Script runtime'da eklendiğinde _ready() çağrılmaz, bu yüzden _enter_tree() kullanıyoruz
	position_smoothing_enabled = false
	set_process(true)
	set_physics_process(true)
	# print("[VillageCameraController] _enter_tree: Processes enabled: process=", is_processing(), " physics_process=", is_physics_processing())
	call_deferred("_initialize_player")

func _initialize_player() -> void:
	# Oyuncuyu bul - Camera2D player'ın child'ı olduğu için parent'ı bul
	player = get_parent()  # Camera2D'nin parent'ı Player olmalı
	if not player or not player.is_in_group("player"):
		# Alternatif: Player node'unu bul
		player = get_tree().get_first_node_in_group("player")
		if not player:
			player = get_tree().get_first_node_in_group("Player")
		if not player:
			# Son çare: sahne ağacında "Player" isimli node'u bul
			var scene_root = get_tree().current_scene
			if scene_root:
				player = scene_root.get_node_or_null("Player")
	
	if not player:
		print("[VillageCameraController] Warning: Player not found!")
		return
	
	# Position smoothing'i tekrar kontrol et (başka bir script tarafından tekrar aktif edilmiş olabilir)
	position_smoothing_enabled = false
	
	# Process callback'lerini tekrar etkinleştir (runtime'da script eklendiğinde gerekli)
	set_process(true)
	set_physics_process(true)
	
	# print("[VillageCameraController] Initialized with limits: left=", left_limit, " right=", right_limit, " player=", player.name, " smoothing=", position_smoothing_enabled, " process=", is_processing(), " physics_process=", is_physics_processing())

func _update_camera(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	
	# Position smoothing'i sürekli kontrol et (başka bir script tarafından tekrar aktif edilmiş olabilir)
	if position_smoothing_enabled:
		position_smoothing_enabled = false
	
	var player_x = player.global_position.x
	# Camera2D player'ın child'ı olduğu için, kameranın global pozisyonu = player'ın global pozisyonu + kameranın local pozisyonu
	# Bu yüzden kameranın local pozisyonunu (position) kontrol ediyoruz
	var current_camera_local_x = position.x
	
	# Oyuncu sınırlar içindeyse takip et
	if player_x >= left_limit and player_x <= right_limit:
		if not is_following:
			is_following = true
			# print("[VillageCameraController] Player returned to bounds, resuming follow at x=", player_x)
		
		# Smooth takip - kamerayı player'ın X pozisyonuna getir (local pozisyon olarak)
		var target_x = 0.0  # Player'ın child'ı olduğu için local pozisyon 0 olmalı (player'ın merkezinde)
		current_camera_local_x = lerp(current_camera_local_x, target_x, follow_speed * delta)
		position.x = current_camera_local_x
	else:
		# Oyuncu sınırlar dışındaysa kamerayı sınırda tut
		if is_following:
			is_following = false
			# print("[VillageCameraController] Player left bounds at x=", player_x, ", stopping camera at limit")
		
		# Kamerayı sınırda tut - player'ın global pozisyonuna göre local pozisyonu ayarla
		if player_x < left_limit:
			# Oyuncu sol sınırın dışında - kamerayı sol sınırda tut
			var target_local_x = left_limit - player_x
			current_camera_local_x = lerp(current_camera_local_x, target_local_x, follow_speed * delta)
			position.x = current_camera_local_x
		elif player_x > right_limit:
			# Oyuncu sağ sınırın dışında - kamerayı sağ sınırda tut
			var target_local_x = right_limit - player_x
			current_camera_local_x = lerp(current_camera_local_x, target_local_x, follow_speed * delta)
			position.x = current_camera_local_x

func _process(delta: float) -> void:
	# print("[VillageCameraController] _process called")
	_update_camera(delta)

func _physics_process(delta: float) -> void:
	# print("[VillageCameraController] _physics_process called")
	_update_camera(delta)

