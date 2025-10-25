extends ColorRect

# Siyah arkaplan dikdörtgeni - kamerayı takip eder
func _ready() -> void:
	# Kamerayı bul
	var camera = get_viewport().get_camera_2d()
	if camera:
		print("[DungeonBackground] Background created, following camera")
	else:
		print("[DungeonBackground] Camera not found!")

func _process(delta: float) -> void:
	# Kamerayı takip et
	var camera = get_viewport().get_camera_2d()
	if camera:
		var viewport_size = get_viewport().get_visible_rect().size
		global_position = camera.global_position - viewport_size / 2
