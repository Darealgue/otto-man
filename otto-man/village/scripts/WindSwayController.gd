extends Node
## Köy sahnesindeki tüm ağaç ve çalı sprite'larını bulup sallanma script'i ekler.

const SWAYABLE_SCRIPT = preload("res://village/scripts/Swayable.gd")

# Sallanacak sprite isimleri (pattern matching)
var _swayable_patterns: Array[String] = [
	"TreesFront",
	"Bush",
	"BushFront",
	"Grass"
]

# Sallanmayacak sprite isimleri (taşlar vb.)
var _excluded_patterns: Array[String] = [
	"Rock",
	"Trunk"  # Gövde sprite'ları sallanmaz
]

func _ready() -> void:
	# Sahne yüklendikten sonra tüm sprite'ları bul ve script ekle
	call_deferred("_setup_swayable_sprites")

var _found_count: int = 0  # Class variable

func _setup_swayable_sprites() -> void:
	var scene_root = get_tree().current_scene
	if not scene_root:
		push_warning("[WindSwayController] Scene root bulunamadı")
		return
	
	_found_count = 0
	
	# ParallaxBackground altındaki tüm Sprite2D node'larını bul
	_find_and_setup_sprites_recursive(scene_root)
	
	print("[WindSwayController] %d sprite'a sallanma script'i eklendi" % _found_count)

func _find_and_setup_sprites_recursive(node: Node) -> void:
	# Sprite2D node'larını kontrol et
	if node is Sprite2D:
		var sprite = node as Sprite2D
		var node_name = sprite.name
		
		# Excluded pattern kontrolü
		var is_excluded = false
		for pattern in _excluded_patterns:
			if pattern in node_name:
				is_excluded = true
				break
		
		if is_excluded:
			return
		
		# Swayable pattern kontrolü
		var should_sway = false
		for pattern in _swayable_patterns:
			if pattern in node_name:
				should_sway = true
				break
		
		if should_sway:
			# Eğer zaten script yoksa ekle
			if sprite.get_script() == null:
				sprite.set_script(SWAYABLE_SCRIPT)
				# Runtime'da script eklendiğinde _ready() otomatik çağrılmaz, deferred olarak çağırmalıyız
				sprite.call_deferred("_ready")
				_found_count += 1
				print("[WindSwayController] ✅ Script eklendi: %s (parent: %s)" % [node_name, sprite.get_parent().name if sprite.get_parent() else "null"])
			else:
				print("[WindSwayController] ⚠️ Script zaten var: %s" % node_name)
	
	# Child node'ları recursive olarak kontrol et
	for child in node.get_children():
		_find_and_setup_sprites_recursive(child)
