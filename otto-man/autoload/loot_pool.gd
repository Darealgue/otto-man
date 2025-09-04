extends Node

const COIN_TYPE := "coin"
const POUCH_TYPE := "pouch"

@export var prewarm_coin: int = 24
@export var prewarm_pouch: int = 12
@export var active_cap: int = 40

var _free_coins: Array[RigidBody2D] = []
var _free_pouches: Array[RigidBody2D] = []
var _active: Array[RigidBody2D] = []

func _ready() -> void:
	_prewarm()

func _prewarm() -> void:
	for i in range(prewarm_coin):
		_free_coins.append(_make_loot(false))
	for i in range(prewarm_pouch):
		_free_pouches.append(_make_loot(true))

func acquire(is_pouch: bool) -> RigidBody2D:
	var arr := _free_pouches if is_pouch else _free_coins
	var body: RigidBody2D = null
	if arr.size() > 0:
		body = arr.pop_back()
	else:
		body = _make_loot(is_pouch)
	_active.append(body)
	body.visible = true
	body.freeze = false
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.angular_damp = 1.0
	_enforce_cap()
	return body

func release(body: RigidBody2D) -> void:
	if not body:
		return
	if _active.has(body):
		_active.erase(body)
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.visible = false
	body.global_position = Vector2(-10000, -10000)
	var is_pouch: bool = int(body.get_meta("gold_value", 1)) > 5
	if is_pouch:
		_free_pouches.append(body)
	else:
		_free_coins.append(body)

func active_count() -> int:
	return _active.size()

func schedule_despawn(body: RigidBody2D, seconds: float) -> void:
	if not body:
		return
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = max(0.1, seconds)
	body.add_child(t)
	t.timeout.connect(func():
		if is_instance_valid(body):
			release(body)
	)
	t.start()

func schedule_ground_sleep(body: RigidBody2D, delay: float) -> void:
	if not body:
		return
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = max(0.05, delay)
	body.add_child(t)
	t.timeout.connect(func():
		if is_instance_valid(body):
			# Do NOT sleep; keep physics active to avoid mid-air freeze
			body.linear_velocity = Vector2.ZERO
			body.angular_velocity = 0.0
			body.sleeping = false
			body.freeze = false
			body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	)
	t.start()

func _enforce_cap() -> void:
	if active_cap <= 0:
		return
	while _active.size() > active_cap:
		var victim := _active[0]
		release(victim)

func _make_loot(is_pouch: bool) -> RigidBody2D:
	var rb := RigidBody2D.new()
	rb.name = ("PouchLoot" if is_pouch else "CoinLoot")
	rb.gravity_scale = 1.0
	# Slightly stronger gravity to ensure falling
	rb.gravity_scale = 1.2
	rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	rb.linear_damp = 1.0
	rb.angular_damp = 1.0
	# Prevent tunneling when launched fast
	rb.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	rb.contact_monitor = true
	rb.max_contacts_reported = 4
	# Coins/pouches should NOT block the player. Put them on ITEM layer,
	# but let them collide with WORLD/PLATFORM so they can bounce/settle.
	rb.collision_layer = CollisionLayers.ITEM
	rb.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM

	var pm := PhysicsMaterial.new()
	pm.bounce = 0.05
	pm.friction = 1.2
	rb.physics_material_override = pm

	var rb_shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 8
	rb_shape.shape = circ
	# Physics shape stays centered; we keep sprite bottom-center using visual offset
	rb_shape.position = Vector2.ZERO
	rb.add_child(rb_shape)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	# Center visuals by default
	sprite.centered = true
	sprite.position = Vector2.ZERO
	rb.add_child(sprite)

	var collect := Area2D.new()
	collect.name = "CollectArea"
	var collect_col := CollisionShape2D.new()
	var collect_shape := CircleShape2D.new()
	collect_shape.radius = 22
	collect_col.shape = collect_shape
	# Center the collect area around the body center
	collect_col.position = Vector2.ZERO
	collect.add_child(collect_col)
	collect.collision_layer = CollisionLayers.NONE
	# Detect everything; handler will filter by player group
	collect.collision_mask = CollisionLayers.ALL
	collect.monitoring = true
	collect.monitorable = true
	rb.add_child(collect)

	# Signals are expected to be connected by caller (DecorationSpawner)
	rb.visible = false
	# Debug print disabled to reduce console spam
	# print("[LootPool] Created loot '", rb.name, "' layer=", rb.collision_layer, " mask=", rb.collision_mask)
	return rb
