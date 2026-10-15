extends BaseChunk

const DEBUG_DUNGEON_CHUNK: bool = false

func _ready() -> void:
	chunk_type = "dungeon"  # Set this as a dungeon chunk
	if DEBUG_DUNGEON_CHUNK:
		pass
	super._ready()  # Call parent _ready to initialize spawn manager
	
	# Add black background for dungeon sections
	_add_dungeon_background()

func _add_dungeon_background() -> void:
	if DEBUG_DUNGEON_CHUNK:
		pass
	
	# Kamerayı bul
	var camera = get_viewport().get_camera_2d()
	if DEBUG_DUNGEON_CHUNK:
		print("[DungeonChunk] DEBUG: Camera found: ", camera != null)
	if camera:
		if DEBUG_DUNGEON_CHUNK:
			pass
	
	# Viewport bilgileri
	var viewport_size = get_viewport().get_visible_rect().size
	if DEBUG_DUNGEON_CHUNK:
		pass
	
	# Siyah arkaplan ekle
	var background = ColorRect.new()
	background.color = Color.BLACK
	background.name = "DungeonBackground"
	if DEBUG_DUNGEON_CHUNK:
		pass
	
	if camera:
		# Kameraya ekle
		camera.add_child(background)
		if DEBUG_DUNGEON_CHUNK:
			pass
		
		# Z-index'i en arkaya ayarla
		background.z_index = -1000
		if DEBUG_DUNGEON_CHUNK:
			pass
		
		# Kameranın zoom'una göre boyutu ayarla
		var zoom_factor = camera.zoom.x
		background.size = viewport_size / zoom_factor
		if DEBUG_DUNGEON_CHUNK:
			pass
		
		# Pozisyonu kameranın merkezine göre ayarla
		background.position = -background.size / 2
		if DEBUG_DUNGEON_CHUNK:
			pass
		
		# Final durum
		if DEBUG_DUNGEON_CHUNK:
			pass
			
	else:
		if DEBUG_DUNGEON_CHUNK:
			print("[DungeonChunk] DEBUG: Camera not found, background not added")

# Override to add special dungeon behavior
func start_spawning(interval: float = 5.0) -> void:
	if spawn_manager:
		# Dungeons might want more frequent spawning for challenge
		spawn_manager.start_all_spawning(interval * 0.8)  # 20% faster spawning
