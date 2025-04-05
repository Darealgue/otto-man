extends Node2D
class_name ResourceNode

@export var resource_type: String = "wood" # wood, water, food, stone, metal
@export var visual_range: float = 50.0 # İşçilerin bu kaynağa ne kadar yaklaşması gerektiği
@export var max_workers: int = 3 # Aynı anda çalışabilecek maksimum işçi sayısı
@export var respawn_time: float = 10.0 # Tükenirse yeniden oluşma süresi

var current_workers: Array = []
var is_active: bool = true
var current_respawn_timer: float = 0.0
var node_position: Vector2 # İşçilerin çalışacağı konum

@onready var sprite: Sprite2D = $Sprite
@onready var worker_positions: Node2D = $WorkerPositions # Çalışan işçilerin pozisyonları

func _ready() -> void:
	# Konum ayarla
	node_position = global_position
	
	# Görselleştirmeyi ayarla
	_update_visual()

func _process(delta: float) -> void:
	# Kaynak tükenmişse yenileme kontrolü
	if !is_active:
		current_respawn_timer += delta
		if current_respawn_timer >= respawn_time:
			_respawn()

func _update_visual() -> void:
	# Kaynak tipine göre görüntüyü ayarla
	match resource_type:
		"wood":
			# Örnek: sprite.texture = load("res://assets/resources/tree.png")
			# Şimdilik farklı renk olarak ayarlayalım
			if sprite:
				sprite.modulate = Color(0.2, 0.5, 0.2) # Koyu yeşil
		"water":
			if sprite:
				sprite.modulate = Color(0.2, 0.2, 0.8) # Mavi
		"food":
			if sprite:
				sprite.modulate = Color(0.8, 0.6, 0.2) # Kahverengi
		"stone":
			if sprite:
				sprite.modulate = Color(0.5, 0.5, 0.5) # Gri
		"metal":
			if sprite:
				sprite.modulate = Color(0.7, 0.7, 0.8) # Açık gri/gümüş

func can_add_worker() -> bool:
	return is_active and current_workers.size() < max_workers

func add_worker(worker: Worker) -> bool:
	if !can_add_worker():
		return false
	
	current_workers.append(worker)
	return true

func remove_worker(worker: Worker) -> void:
	if current_workers.has(worker):
		current_workers.erase(worker)

func deplete() -> void:
	# Kaynağı tüket
	is_active = false
	current_respawn_timer = 0.0
	
	# Görselleştirmeyi değiştir
	if sprite:
		sprite.modulate.a = 0.5 # Yarı saydam yap
	
	# Çalışan işçileri gönder
	for worker in current_workers:
		worker.resource_depleted()
	
	current_workers.clear()

func _respawn() -> void:
	# Kaynağı yeniden aktif et
	is_active = true
	current_respawn_timer = 0.0
	
	# Görselleştirmeyi güncelle
	if sprite:
		sprite.modulate.a = 1.0 # Tam görünür yap
	
	_update_visual()

func get_available_position() -> Vector2:
	# İşçiler için çalışma konumu belirle
	# İlk başta basitçe kaynağın etrafına konumlandıralım
	
	if worker_positions and worker_positions.get_child_count() > 0:
		# İşçi pozisyonlarını kullan, mevcutsa
		var available_positions = worker_positions.get_children()
		for pos in available_positions:
			# Bu pozisyonda bir işçi yoksa
			var is_position_available = true
			for worker in current_workers:
				if worker.global_position.distance_to(pos.global_position) < 5.0:
					is_position_available = false
					break
			
			if is_position_available:
				return pos.global_position
	
	# Alternatif olarak, node'un etrafında rastgele bir konum döndür
	var random_angle = randf() * 2 * PI
	var random_distance = randf_range(20.0, visual_range)
	return global_position + Vector2(cos(random_angle), sin(random_angle)) * random_distance 
