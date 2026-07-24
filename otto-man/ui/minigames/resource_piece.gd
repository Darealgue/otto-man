extends Node2D
class_name ResourcePiece
## Ağaç/taş minigame'lerinde fırlayan, oyuncunun fiziksel olarak dokunup toplaması gereken
## kaynak parçası (odun/taş) — ui/minigames/food/Fruit.gd'deki toplama desenini yansıtır.
## RigidBody2D fırlama fiziğini korur; toplama için RigidBody2D'ye bağlı bir Area2D kullanır.

const CollisionLayers = preload("res://resources/CollisionLayers.gd")

const PICKUP_RADIUS: float = 18.0
const MAX_LIFETIME: float = 8.0
## Fırlama anında oyuncıya çok yakınsa anında toplanmasın diye kısa bir gecikme.
const COLLECTION_ENABLE_DELAY: float = 0.35

const _GAIN_ICON_PATHS := {
	"wood": "res://assets/Icons/wood_icon.png",
	"stone": "res://assets/Icons/stone_icon.png",
	"food": "res://assets/Icons/food_icon.png",
}

var resource_type: String = "wood"

var _minigame_ref: Node = null
var _is_collected: bool = false
var _life_timer: float = 0.0
var _rigid_body: RigidBody2D = null
var _pickup_area: Area2D = null


func _ready() -> void:
	print("[ResourcePiece] _ready() type=", resource_type, " pos=", global_position, " visible=", visible, " modulate=", modulate)
	_rigid_body = get_node_or_null("RigidBody2D")
	if _rigid_body == null:
		print("[ResourcePiece] ERROR: RigidBody2D child not found")
		return
	_pickup_area = _rigid_body.get_node_or_null("PickupArea") as Area2D
	if _pickup_area == null:
		_pickup_area = Area2D.new()
		_pickup_area.name = "PickupArea"
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = PICKUP_RADIUS
		shape.shape = circle
		_pickup_area.add_child(shape)
		_rigid_body.add_child(_pickup_area)
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask = CollisionLayers.PLAYER
	_pickup_area.monitoring = false
	_pickup_area.monitorable = false
	if not _pickup_area.body_entered.is_connected(_on_body_entered):
		_pickup_area.body_entered.connect(_on_body_entered)
	set_process(true)
	call_deferred("_enable_pickup_after_delay")


func set_minigame_ref(minigame: Node) -> void:
	_minigame_ref = minigame


func _enable_pickup_after_delay() -> void:
	await get_tree().create_timer(COLLECTION_ENABLE_DELAY).timeout
	if _is_collected or not is_instance_valid(self) or not is_instance_valid(_pickup_area):
		return
	_pickup_area.monitoring = true


func _process(delta: float) -> void:
	if _is_collected:
		return
	_life_timer += delta
	if _life_timer >= MAX_LIFETIME:
		_expire()


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if not body.is_in_group("player"):
		return
	collect()


func can_be_collected() -> bool:
	return not _is_collected


## Ödül doğrudan burada verilir (minigame'in hayatta kalmasına bağlı değil) — oyuncu ağacı
## devirdikten sonra uzaklaşıp minigame kapansa bile, yerde kalan parçaları sonra toplayabilir.
func collect() -> void:
	if _is_collected:
		return
	_is_collected = true
	if is_instance_valid(_pickup_area):
		_pickup_area.monitoring = false
	var player_stats := get_node_or_null("/root/PlayerStats")
	if player_stats and player_stats.has_method("add_carried_resources"):
		player_stats.add_carried_resources({resource_type: 1})
	if _minigame_ref != null and is_instance_valid(_minigame_ref) and _minigame_ref.has_method("_on_resource_piece_collected"):
		_minigame_ref._on_resource_piece_collected(self)
	_show_pickup_popup()
	_play_collect_effect()


## Toplandığı NOKTADA (ağacın/taşın değil) ikon + "+1" gösteren yükselip solan yazı.
func _show_pickup_popup() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		return
	var popup := Node2D.new()
	popup.global_position = global_position + Vector2(0, -20.0)
	popup.z_index = 100000
	parent.add_child(popup)

	var icon_path: String = _GAIN_ICON_PATHS.get(resource_type, "")
	var label_x := -10.0
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(18, 18)
		icon.size = Vector2(18, 18)
		icon.position = Vector2(-26, -9)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(icon)
		label_x = -2.0

	var label := Label.new()
	label.text = "+1"
	label.position = Vector2(label_x, -13)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 5)
	popup.add_child(label)

	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 60.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)


## Süresi dolan (oyuncunun kaçırdığı) parça sessizce kaybolur; minigame bunu "toplanmadı" sayar.
func _expire() -> void:
	if _is_collected:
		return
	_is_collected = true
	if is_instance_valid(_pickup_area):
		_pickup_area.monitoring = false
	if _minigame_ref != null and is_instance_valid(_minigame_ref) and _minigame_ref.has_method("_on_resource_piece_expired"):
		_minigame_ref._on_resource_piece_expired(self)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.4)
	fade.tween_callback(queue_free)


func _play_collect_effect() -> void:
	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", scale * 1.4, 0.12)
	scale_tween.tween_property(self, "scale", Vector2.ZERO, 0.1)
	var mod_tween := create_tween()
	mod_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	mod_tween.tween_callback(queue_free)
