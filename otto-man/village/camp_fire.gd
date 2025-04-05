extends Node2D
class_name CampFire

signal interaction_started
signal interaction_ended

@export var interaction_radius: float = 50.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D = $InteractionArea
@onready var sprite: Sprite2D = $Sprite2D

# UI referansı
var village_ui: VillageUI = null
var village_ui_scene = preload("res://village/village_ui/village_ui.tscn")
var is_player_in_range: bool = false
var current_player = null

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	
	# İnteraksiyon alanı ayarla (circle shape gerekliyse)
	var collision_shape = interaction_area.get_node("CollisionShape2D")
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = interaction_radius

func _process(_delta: float) -> void:
	# Oyuncu etkileşim alanındaysa ve etkileşime geçtiyse
	if is_player_in_range and current_player:
		if Input.is_action_just_pressed("up") or Input.is_action_just_pressed("attack"):
			_start_interaction()

func _start_interaction() -> void:
	# Köy yönetim ekranını göster
	interaction_started.emit()
	
	# UI yüklenmemişse yükle
	if not village_ui:
		village_ui = village_ui_scene.instantiate()
		get_tree().root.add_child(village_ui)
	
	# UI'ı göster
	village_ui.show_ui()
	
	# UI kapatıldığında etkileşimi sonlandır
	if not village_ui.ui_closed.is_connected(_end_interaction):
		village_ui.ui_closed.connect(_end_interaction)

func _end_interaction() -> void:
	interaction_ended.emit()

func _on_interaction_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		current_player = body
		
		# Etkileşim ipucunu göster
		if current_player.has_method("show_interaction_prompt"):
			current_player.show_interaction_prompt("Kamp Ateşi: Köy yönetimi için W veya E tuşuna bas")

func _on_interaction_area_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body == current_player:
		is_player_in_range = false
		
		# Etkileşim ipucunu gizle
		if current_player.has_method("hide_interaction_prompt"):
			current_player.hide_interaction_prompt()
		
		current_player = null

func get_interaction_text() -> String:
	return "Kamp Ateşi: Köy yönetimi için W veya E tuşuna bas" 
