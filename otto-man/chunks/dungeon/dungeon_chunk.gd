extends BaseChunk

func _ready() -> void:
	chunk_type = "dungeon"  # Set this as a dungeon chunk
	print("[DungeonChunk] Setting chunk_type to: ", chunk_type)
	super._ready()  # Call parent _ready to initialize spawn manager
	
	# Add black background for dungeon sections
	_add_dungeon_background()

func _add_dungeon_background() -> void:
	print("[DungeonChunk] === DEBUG: Starting background creation ===")
	
	# Kamerayı bul
	var camera = get_viewport().get_camera_2d()
	print("[DungeonChunk] DEBUG: Camera found: ", camera != null)
	if camera:
		print("[DungeonChunk] DEBUG: Camera position: ", camera.global_position)
		print("[DungeonChunk] DEBUG: Camera zoom: ", camera.zoom)
	
	# Viewport bilgileri
	var viewport_size = get_viewport().get_visible_rect().size
	print("[DungeonChunk] DEBUG: Viewport size: ", viewport_size)
	
	# Siyah arkaplan ekle
	var background = ColorRect.new()
	background.color = Color.BLACK
	background.name = "DungeonBackground"
	print("[DungeonChunk] DEBUG: Background created")
	
	if camera:
		# Kameraya ekle
		camera.add_child(background)
		print("[DungeonChunk] DEBUG: Background added to camera")
		
		# Z-index'i en arkaya ayarla
		background.z_index = -1000
		print("[DungeonChunk] DEBUG: Z-index set to: ", background.z_index)
		
		# Kameranın zoom'una göre boyutu ayarla
		var zoom_factor = camera.zoom.x
		background.size = viewport_size / zoom_factor
		print("[DungeonChunk] DEBUG: Size set to: ", background.size)
		print("[DungeonChunk] DEBUG: Zoom factor: ", zoom_factor)
		
		# Pozisyonu kameranın merkezine göre ayarla
		background.position = -background.size / 2
		print("[DungeonChunk] DEBUG: Position set to: ", background.position)
		
		# Final durum
		print("[DungeonChunk] DEBUG: Final background state:")
		print("  - Position: ", background.position)
		print("  - Size: ", background.size)
		print("  - Z-index: ", background.z_index)
		print("  - Color: ", background.color)
		print("  - Visible: ", background.visible)
		print("  - Parent: ", background.get_parent())
		
		print("[DungeonChunk] === DEBUG: Background creation complete ===")
	else:
		print("[DungeonChunk] DEBUG: Camera not found, background not added")

# Override to add special dungeon behavior
func start_spawning(interval: float = 5.0) -> void:
	if spawn_manager:
		# Dungeons might want more frequent spawning for challenge
		spawn_manager.start_all_spawning(interval * 0.8)  # 20% faster spawning
