class_name ResourceDropPickup
extends RigidBody2D
## Sökülen kaynağın yere düşen parçası. Oyuncu dokununca taşınan kaynağa eklenir.
## Zaman sınırı YOKTUR: alınana kadar yerinde durur (hasar sonrası düşen "recovery" pickup'larının
## aksine yaşam süresi sayacı yok).

const COLLECT_ARM_DELAY: float = 0.35
const COLLECT_RADIUS: float = 32.0
const BODY_RADIUS: float = 12.0
## Minigame'lerdeki parça çizimleri (odun 20x20, meyve 15x16, taş 50x50) ormanda ekranda çok küçük
## kalıyordu; odun 2.2x (44 px), taş 1x (50 px), meyve 1.4x (21 px).
const PIECE_ART: Dictionary = {
	"wood": {"path": "res://ui/minigames/wood/wood_piece.png", "scale": 2.2},
	"food": {"path": "res://ui/minigames/food/berry.png", "scale": 1.4},
	"stone": {"path": "res://ui/minigames/stone/rock_piece.png", "scale": 1.0},
}
## Parça çizimi yoksa ikon (25x25) bu boya sığdırılır.
const ICON_SIZE: float = 16.0
const LAUNCH_X: float = 90.0
const LAUNCH_UP_MIN: float = 220.0
const LAUNCH_UP_MAX: float = 320.0

var resource_type: String = "wood"
var amount: int = 1

var _collected: bool = false
var _collect_area: Area2D = null


## `parent`ın altına düşer; `world_pos` küresel konum.
static func spawn(parent: Node, world_pos: Vector2, type: String, count: int = 1) -> ResourceDropPickup:
	var drop := ResourceDropPickup.new()
	drop.name = "ResourceDrop_%s" % type
	drop.resource_type = type
	drop.amount = count
	if parent is Node2D:
		drop.position = (parent as Node2D).to_local(world_pos)
	else:
		drop.position = world_pos
	parent.add_child(drop)
	return drop


func _ready() -> void:
	collision_layer = CollisionLayers.ITEM
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	gravity_scale = 0.9
	linear_damp = 0.15
	angular_damp = 0.5
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.6
	physics_material_override = pm

	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	body_shape.shape = circle
	add_child(body_shape)

	_build_visual()

	_collect_area = Area2D.new()
	_collect_area.name = "CollectArea"
	_collect_area.collision_layer = CollisionLayers.NONE
	_collect_area.collision_mask = CollisionLayers.PLAYER
	_collect_area.monitoring = false
	var collect_shape := CollisionShape2D.new()
	var collect_circle := CircleShape2D.new()
	collect_circle.radius = COLLECT_RADIUS
	collect_shape.shape = collect_circle
	_collect_area.add_child(collect_shape)
	add_child(_collect_area)
	_collect_area.body_entered.connect(_on_collect_body_entered)

	var side: float = -1.0 if randf() < 0.5 else 1.0
	apply_impulse(Vector2(side * randf_range(LAUNCH_X * 0.4, LAUNCH_X), -randf_range(LAUNCH_UP_MIN, LAUNCH_UP_MAX)))
	get_tree().create_timer(COLLECT_ARM_DELAY).timeout.connect(_arm_collect)


func _arm_collect() -> void:
	if is_instance_valid(self) and _collect_area != null and is_instance_valid(_collect_area):
		_collect_area.monitoring = true


func _build_visual() -> void:
	var art: Dictionary = PIECE_ART.get(resource_type, {})
	var art_path: String = String(art.get("path", ""))
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		var piece := Sprite2D.new()
		piece.name = "Icon"
		piece.texture = load(art_path) as Texture2D
		piece.scale = Vector2.ONE * float(art.get("scale", 1.0))
		piece.z_index = 10
		add_child(piece)
		return
	var icon_path := "res://assets/Icons/%s_icon.png" % resource_type
	if ResourceLoader.exists(icon_path):
		var sprite := Sprite2D.new()
		sprite.name = "Icon"
		var tex := load(icon_path) as Texture2D
		sprite.texture = tex
		if tex != null:
			var longest: float = maxf(float(tex.get_width()), float(tex.get_height()))
			if longest > 0.0:
				sprite.scale = Vector2.ONE * (ICON_SIZE / longest)
		sprite.z_index = 5
		add_child(sprite)
		return
	# İkon yoksa renkli küre + harf.
	var label := Label.new()
	label.name = "Icon"
	label.text = _fallback_letter()
	label.position = Vector2(-8.0, -14.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 5
	add_child(label)


func _fallback_letter() -> String:
	match resource_type:
		"wood":
			return "O"
		"stone":
			return "T"
		"food":
			return "Y"
	return "?"


func _on_collect_body_entered(body: Node) -> void:
	if _collected or body == null or not body.is_in_group("player"):
		return
	_collected = true
	var stats: Node = get_node_or_null("/root/PlayerStats")
	if stats != null and stats.has_method("add_carried_resource"):
		stats.add_carried_resource(resource_type, amount)
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("pickup", global_position)
	if body is Node2D:
		ResourceGainPopup.show_gain(body as Node2D, resource_type, amount)
	queue_free()
