extends Node2D
class_name BuildingSlot

signal slot_selected
signal slot_deselected
signal building_slot_selected(slot_node: Node2D)

@export var slot_position_index: int = 0  # Köydeki konumunu belirler (sağ/sol)
@export var interaction_radius: float = 60.0
@export var allowed_building_types: Array[String] = ["house", "farm", "lumberjack", "well", "mine", "blacksmith", "tower", "quarry"]

var is_occupied: bool = false
var is_player_in_range: bool = false
var has_building: bool = false
var current_building_type: String = ""
var current_building_id: int = -1
var building_instance = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	# Gruba ekle
	add_to_group("building_slots")
	
	print("------------ BuildingSlot BAŞLATILIYOR: ", name, " ------------")
	print("  Global pozisyon: ", global_position)
	print("  Interaction radius: ", interaction_radius)
	
	# Etkileşim alanını initialize et
	_init_interaction_area()
	
	# Görsel ayarları
	if sprite:
		# Görsel ayarlar
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.5) # Yarı saydam
	
	print("------------ BuildingSlot BAŞLATILDI: ", name, " ------------")

func _init_interaction_area() -> void:
	# Önce InteractionArea'yı bulmayı deneyelim
	interaction_area = get_node_or_null("InteractionArea")
	
	# InteractionArea yoksa Area2D'yi deneyelim
	if not interaction_area:
		interaction_area = get_node_or_null("Area2D")
		if interaction_area:
			print("  'InteractionArea' bulunamadı, bunun yerine 'Area2D' kullanılıyor")
			# Area2D'nin adını değiştirmek sorunları önleyebilir
			interaction_area.name = "InteractionArea"
	
	# Hala interaction_area bulunamadıysa, yeni bir Area2D oluşturalım
	if not interaction_area:
		print("  UYARI: Ne InteractionArea ne de Area2D bulunamadı! Yeni bir Area2D oluşturuluyor.")
		interaction_area = Area2D.new()
		interaction_area.name = "InteractionArea"
		add_child(interaction_area)
		
		# Yeni oluşturulan Area2D için CollisionShape2D ekleyelim
		var collision_shape = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = interaction_radius
		collision_shape.shape = circle_shape
		interaction_area.add_child(collision_shape)
	
	# Etkileşim alanı ayarlama
	if interaction_area:
		var collision_shape = interaction_area.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = interaction_radius
			print("  CollisionShape radius ayarlandı: ", interaction_radius)
		elif collision_shape:
			print("  UYARI: CollisionShape CircleShape2D değil!")
		else:
			print("  HATA: CollisionShape bulunamadı!")
		
		# Collision layer ve mask'ı doğru şekilde ayarla
		# Layer 4 = building slot, Mask 2 = player
		interaction_area.collision_layer = 4  # Layer 3 (building slot) 
		interaction_area.collision_mask = 2   # Layer 2 (player)
		
		# Etkileşim alanı için çok önemli ayarlar
		interaction_area.monitoring = true     # Alanı izleme özelliğini aktifleştir 
		interaction_area.monitorable = true    # Alanın izlenebilir olmasını sağla
		
		print("  InteractionArea ayarları:")
		print("    - Node adı: ", interaction_area.name)
		print("    - Collision layer: ", interaction_area.collision_layer)
		print("    - Collision mask: ", interaction_area.collision_mask)
		print("    - Monitoring: ", interaction_area.monitoring)
		print("    - Monitorable: ", interaction_area.monitorable)
		
		# Sinyalleri bağla
		# Önceden bağlanmış olabilecek sinyalleri kaldır, çift bağlantıyı önle
		if interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
			interaction_area.body_entered.disconnect(_on_interaction_area_body_entered)
		
		if interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
			interaction_area.body_exited.disconnect(_on_interaction_area_body_exited)
			
		if interaction_area.area_entered.is_connected(_on_interaction_area_entered):
			interaction_area.area_entered.disconnect(_on_interaction_area_entered)
			
		if interaction_area.area_exited.is_connected(_on_interaction_area_exited):
			interaction_area.area_exited.disconnect(_on_interaction_area_exited)
		
		# Yeni bağlantıları ekle
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
		interaction_area.area_entered.connect(_on_interaction_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_exited)
		print("  InteractionArea sinyalleri bağlandı")
	else:
		print("  HATA: InteractionArea oluşturulamadı! Bu BuildingSlot çalışmayacak!")

func _process(_delta: float) -> void:
	# Doğrudan mesafe kontrolü ile etkileşimi zorla etkinleştir
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var player = player_nodes[0]
		var distance = global_position.distance_to(player.global_position)
		
		# Mesafeye göre oyuncunun yeterince yakında olup olmadığını kontrol et
		if distance <= interaction_radius and !is_player_in_range:
			is_player_in_range = true
			
			# Oyuncuya etkileşim ipucu göster
			if !has_building:
				if player.has_method("show_interaction_prompt"):
					player.show_interaction_prompt("Bina inşa etmek için Space tuşuna bas")
		
		# Eğer oyuncu uzaklaştıysa ve hala etkileşimde görünüyorsa
		elif distance > interaction_radius and is_player_in_range:
			is_player_in_range = false
			
			# Oyuncudan etkileşim ipucunu kaldır
			if player.has_method("hide_interaction_prompt"):
				player.hide_interaction_prompt()
	
	# Oyuncu etkileşimini kontrol et
	if is_player_in_range:
		if Input.is_action_just_pressed("jump"):
			if !has_building:
				_show_building_selection_ui()
			else:
				print("Bu slotta zaten bir bina var:", current_building_type)

func build_building(building_type: String) -> bool:
	if is_occupied or !allowed_building_types.has(building_type):
		return false
	
	if VillageManager.build(building_type, self):
		# İnşa işlemi başarılı
		is_occupied = true
		has_building = true
		current_building_type = building_type
		
		# Burada bir sahne yükleme ve gösterme işlemi yapılabilir
		var building_scene = load("res://village/buildings/" + building_type + ".tscn")
		if building_scene:
			building_instance = building_scene.instantiate()
			# ResourceBuilding sınıfında position_index yok, bu nedenle global değişken olarak ayarlıyoruz
			if has_method("set_position_index"):
				building_instance.set_position_index(slot_position_index)
			elif "position_index" in building_instance:
				building_instance.position_index = slot_position_index
			else:
				# Özellik yoksa global değişken olarak ayarla
				building_instance.set("slot_index", slot_position_index)
				
			building_instance.building_type = building_type
			add_child(building_instance)
			
			# Kaynak binaları için gruba ekle
			if _is_resource_building(building_type):
				if !building_instance.is_in_group("resource_buildings"):
					building_instance.add_to_group("resource_buildings")
				print("Bina resource_buildings grubuna eklendi: ", building_type)
			
			# Bina ID'sini VillageManager'dan al ve kaydet
			current_building_id = _register_building(building_instance, building_type)
			
			# Görünürlüğü ayarla
			if sprite:
				sprite.visible = false
			
			print("Bina başarıyla inşa edildi: ", building_type)
			return true
	
	return false

# Binanın kaynak binası olup olmadığını kontrol et
func _is_resource_building(building_type: String) -> bool:
	var resource_building_types = ["lumberjack", "quarry", "well", "farm", "mine"]
	return resource_building_types.has(building_type)

func _register_building(building_instance, building_type: String) -> int:
	# Binayı VillageManager'a kaydet
	if building_type == "house":
		return VillageManager.register_house(building_instance)
	elif _is_resource_building(building_type):
		# Kaynak tipini belirle
		var resource_type = ""
		match building_type:
			"lumberjack": resource_type = "wood"
			"quarry": resource_type = "stone"
			"well": resource_type = "water"
			"farm": resource_type = "food"
			"mine": resource_type = "metal"
		
		# Eğer resource_type özelliği yoksa ekle
		if !("resource_type" in building_instance):
			building_instance.set("resource_type", resource_type)
		
		# Resource building olarak kaydet
		if building_instance.has_method("set_resource_type"):
			building_instance.set_resource_type(resource_type)
		
		print("Kaynak binası kaydedildi. Tür: ", building_type, ", Kaynak: ", resource_type)
		return VillageManager.register_building(building_instance, building_type)
	else:
		return VillageManager.register_building(building_instance, building_type)

func remove_building() -> bool:
	if !has_building:
		return false
	
	# Binayı kaldır
	if building_instance:
		building_instance.queue_free()
		building_instance = null
	
	is_occupied = false
	has_building = false
	current_building_type = ""
	current_building_id = -1
	
	# Slotu görünür yap
	if sprite:
		sprite.visible = true
	
	return true

func _show_building_selection_ui() -> void:
	# Bina seçim ekranını göster
	slot_selected.emit()

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		
		# Etkileşim ipucunu göster
		if !has_building:
			# İnşaat ipucu göster
			if body.has_method("show_interaction_prompt"):
				body.show_interaction_prompt("Bina inşa etmek için Space tuşuna bas")

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = false
		
		# Etkileşim ipucunu kaldır
		if body.has_method("hide_interaction_prompt"):
			body.hide_interaction_prompt()
		
		# Eğer UI açıksa kapat
		slot_deselected.emit()

func _on_interaction_area_entered(area):
	# Ebeveyn node'u kontrol et
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		is_player_in_range = true
		# Sinyal gönder
		emit_signal("building_slot_selected", self)

func _on_interaction_area_exited(area):
	# Ebeveyn node'u kontrol et
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		is_player_in_range = false
		# Eğer UI açıksa kapat
		slot_deselected.emit()

# Bir bina yerleştir
func place_building(building_scene, type: String) -> bool:
	if is_occupied:
		return false
	
	# Yeni binayı oluştur
	var instance = building_scene.instantiate()
	add_child(instance)
	
	# Bina bilgilerini güncelle
	current_building_type = type
	is_occupied = true
	has_building = true
	building_instance = instance
	
	return true 
