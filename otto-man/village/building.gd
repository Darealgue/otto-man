extends Node2D
class_name Building

signal building_upgraded(new_level: int)
signal building_selected
signal building_deselected

@export var building_type: String = "house" # ev, kuyu, maden, kule vs.
@export var building_name: String = "Building"
@export var max_level: int = 3
@export var interaction_radius: float = 50.0

# Bina özellikleri
var building_id: int = -1
var current_level: int = 1
var is_player_in_range: bool = false
var position_index: int = 0 # Köydeki konum indeksi

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D = $InteractionArea

func _ready() -> void:
	# Etkileşim alanını ayarla
	if interaction_area:
		var collision_shape = interaction_area.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = interaction_radius
		
		# Sinyalleri bağla
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	
	# Görselleştirmeyi güncelle
	_update_visuals()

func _process(_delta: float) -> void:
	# Eğer oyuncu yakındaysa ve etkileşim tuşuna basarsa
	if is_player_in_range and Input.is_action_just_pressed("jump"):
		_show_building_ui()

func upgrade() -> bool:
	if current_level < max_level:
		var wood_cost = current_level * 30
		var stone_cost = current_level * 15
		
		# Kaynak kontrolü - bina tipine göre özelleştirilebilir
		if VillageManager.get_resource("wood") >= wood_cost and VillageManager.get_resource("stone") >= stone_cost:
			VillageManager.use_resource("wood", wood_cost)
			VillageManager.use_resource("stone", stone_cost)
			
			current_level += 1
			_update_visuals()
			
			building_upgraded.emit(current_level)
			return true
	
	return false

func _update_visuals() -> void:
	# Görünümü seviyeye göre güncelle (örneğin, bina büyür)
	if sprite:
		# Görsel geliştirmeler (örneğin: binayı büyültmek)
		var scale_factor = 1.0 + (current_level - 1) * 0.1
		sprite.scale = Vector2(scale_factor, scale_factor)
		
		# Seviyeye göre renk veya efekt
		match current_level:
			1:
				sprite.modulate = Color(1.0, 1.0, 1.0)  # Normal
			2:
				sprite.modulate = Color(1.1, 1.1, 0.9)  # Hafif sarımsı
			3:
				sprite.modulate = Color(1.2, 1.2, 0.8)  # Daha parlak
			_:
				sprite.modulate = Color(1.0, 1.0, 1.0)

func _show_building_ui() -> void:
	# Binanın yönetim UI'ını göster
	building_selected.emit()
	
	# Bu kısım daha sonra ekleme yapılacak
	# Örneğin: VillageManager.show_building_ui(building_type, building_id)

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		# Etkileşim ipucunu göster

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = false
		# Etkileşim ipucunu gizle
		
		# Eğer bina UI'ı açıksa kapat
		building_deselected.emit() 