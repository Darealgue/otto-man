extends RigidBody2D
class_name DungeonPhysicalLootDrop
## Altın gibi fırlayıp yere düşen sefer loot / zindan anahtarı pickup'ı.

const _ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")

const DESPAWN_SEC := 90.0
const COLLECT_ENABLE_DELAY := 0.22

enum Kind { EXPEDITION, DUNGEON_KEY }

var _collected := false
var _kind: Kind = Kind.EXPEDITION
var _expedition_loot_type: String = ""
var _expedition_amount: int = 1
var _dungeon_key_id: String = ""


static func spawn_expedition_loot(world_pos: Vector2, loot_type: String, amount: int = 1) -> DungeonPhysicalLootDrop:
	var drop := DungeonPhysicalLootDrop.new()
	drop._kind = Kind.EXPEDITION
	drop._expedition_loot_type = loot_type
	drop._expedition_amount = maxi(1, amount)
	drop.name = "ExpeditionLootDrop_%s" % loot_type
	drop._finish_spawn(world_pos)
	return drop


static func spawn_dungeon_key(world_pos: Vector2, key_id: String) -> DungeonPhysicalLootDrop:
	var drop := DungeonPhysicalLootDrop.new()
	drop._kind = Kind.DUNGEON_KEY
	drop._dungeon_key_id = key_id
	drop.name = "DungeonKeyDrop"
	drop._finish_spawn(world_pos)
	return drop


func _ready() -> void:
	add_to_group("dungeon_physical_loot")
	gravity_scale = 1.2
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	linear_damp = 1.0
	angular_damp = 1.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = CollisionLayers.ITEM
	collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.05
	pm.friction = 1.2
	physics_material_override = pm
	_build_physics()
	_build_visual()
	_wire_collect_area()


func _build_physics() -> void:
	var rb_shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 10.0
	rb_shape.shape = circ
	add_child(rb_shape)


func _build_visual() -> void:
	var emoji: String
	if _kind == Kind.DUNGEON_KEY:
		emoji = _ExpeditionLootType.dungeon_key_emoji()
	else:
		emoji = _ExpeditionLootType.placeholder_emoji(_expedition_loot_type)
	var lbl := _ExpeditionLootType.make_emoji_label(emoji, 22)
	lbl.name = "EmojiVisual"
	add_child(lbl)


func _wire_collect_area() -> void:
	var collect := Area2D.new()
	collect.name = "CollectArea"
	var collect_col := CollisionShape2D.new()
	var collect_shape := CircleShape2D.new()
	collect_shape.radius = 24.0
	collect_col.shape = collect_shape
	collect.add_child(collect_col)
	collect.collision_layer = CollisionLayers.NONE
	collect.collision_mask = CollisionLayers.ALL
	collect.monitoring = false
	collect.monitorable = true
	add_child(collect)
	collect.body_entered.connect(_on_collect_body_entered)
	collect.area_entered.connect(_on_collect_area_entered)


func _finish_spawn(world_pos: Vector2) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var spawn_offset := Vector2(randf_range(-16.0, 16.0), randf_range(-12.0, 4.0))
	global_position = world_pos + spawn_offset
	tree.current_scene.add_child(self)
	var spread := randf_range(-0.55, 0.55)
	var ang := -PI * 0.5 + spread
	var mag := randf_range(260.0, 420.0)
	var launch := Vector2(cos(ang), sin(ang)) * mag
	launch.x += randf_range(-22.0, 22.0)
	angular_damp = 0.8
	freeze = false
	apply_impulse(launch)
	z_index = 6
	var collect: Area2D = get_node_or_null("CollectArea") as Area2D
	if collect:
		get_tree().create_timer(COLLECT_ENABLE_DELAY).timeout.connect(func() -> void:
			if is_instance_valid(collect):
				collect.monitoring = true
		)
	get_tree().create_timer(DESPAWN_SEC).timeout.connect(func() -> void:
		if is_instance_valid(self) and not _collected:
			queue_free()
	)


func _on_collect_body_entered(body: Node2D) -> void:
	if _collected or body == null:
		return
	if body.is_in_group("player") or (body.get_parent() and body.get_parent().is_in_group("player")):
		_collect(body if body.is_in_group("player") else body.get_parent() as Node2D)


func _on_collect_area_entered(area: Area2D) -> void:
	if _collected or area == null:
		return
	var owner := area.get_parent()
	if owner and owner.is_in_group("player"):
		_collect(owner as Node2D)


func _collect(_player: Node2D) -> void:
	if _collected:
		return
	_collected = true
	match _kind:
		Kind.EXPEDITION:
			var ps := get_node_or_null("/root/PlayerStats")
			if ps and ps.has_method("add_carried_expedition_loot"):
				ps.add_carried_expedition_loot(_expedition_loot_type, _expedition_amount)
		Kind.DUNGEON_KEY:
			var drs := get_node_or_null("/root/DungeonRunState")
			if drs == null or not drs.has_method("add_dungeon_key"):
				queue_free()
				return
			if not drs.add_dungeon_key(_dungeon_key_id):
				queue_free()
				return
			if drs.has_method("notify_segment_exit_key_obtained"):
				drs.call("notify_segment_exit_key_obtained")
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("coin_pickup", global_position)
	queue_free()
