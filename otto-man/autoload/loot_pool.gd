extends Node

const COIN_TYPE := "coin"
const POUCH_TYPE := "pouch"

## Godot: Autoload (Loots) seçili → Inspector’da işaretle veya kodda `Loots.debug_loot_lifecycle = true` (repro sırasında).
## Konsolda [LootLifecycle] … breakable altını kim/hangi nedenle havuza döndüğünü gösterir.
@export var debug_loot_lifecycle: bool = false

var _loot_spawn_seq: int = 0

@export var prewarm_coin: int = 24
@export var prewarm_pouch: int = 12
@export var active_cap: int = 40

var _free_coins: Array[RigidBody2D] = []
var _free_pouches: Array[RigidBody2D] = []
var _active: Array[RigidBody2D] = []

func _ready() -> void:
	_prewarm()


func loot_log(msg: String) -> void:
	if debug_loot_lifecycle:
		print("[LootLifecycle] ", msg)


## Havuzdan çıkan / iade edilen loot üzerinde kalan Timer'lar (despawn, ground_sleep, enable vb.)
## bir sonraki kullanımda tetiklenip parayı görünmez yapıyordu; oyuncu toplamadan kayboluyordu.
func _clear_loot_timers(body: Node) -> void:
	if not body or not is_instance_valid(body):
		return
	var to_free: Array[Node] = []
	for c in body.get_children():
		if c is Timer:
			to_free.append(c)
	for c in to_free:
		if not is_instance_valid(c):
			continue
		if debug_loot_lifecycle and c is Timer:
			var tm := c as Timer
			loot_log("timer_clear name=%s wait=%.3f left=%.3f on=%s id=%s" % [
				tm.name, tm.wait_time, tm.time_left, body.name, str(body.get_meta("loot_spawn_id", -1))
			])
		c.queue_free()

func _prewarm() -> void:
	for i in range(prewarm_coin):
		_free_coins.append(_make_loot(false))
	for i in range(prewarm_pouch):
		_free_pouches.append(_make_loot(true))

func acquire(is_pouch: bool) -> RigidBody2D:
	var arr := _free_pouches if is_pouch else _free_coins
	var body: RigidBody2D = null
	
	# Clean up invalid instances from array first
	var valid_items: Array[RigidBody2D] = []
	for item in arr:
		if is_instance_valid(item):
			valid_items.append(item)
	arr.clear()
	arr.append_array(valid_items)
	
	# Try to get a valid body from the pool
	while arr.size() > 0:
		body = arr.pop_back()
		if is_instance_valid(body):
			break
		body = null
	
	# If no valid body found, create a new one
	if body == null:
		body = _make_loot(is_pouch)
	
	_active.append(body)
	_clear_loot_timers(body)
	_loot_spawn_seq += 1
	body.set_meta("loot_spawn_id", _loot_spawn_seq)
	loot_log("acquire id=%s iid=%s pouch=%s in_tree=%s timers_cleared_above pos=%s" % [
		str(_loot_spawn_seq), str(body.get_instance_id()), str(is_pouch), str(body.is_inside_tree()), str(body.global_position)
	])
	body.visible = true
	body.freeze = false
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.angular_damp = 1.0
	# Don't enforce cap here - let the caller add it to scene first
	# This prevents newly spawned loot from being immediately released
	return body

func release(body: RigidBody2D, reason: String = "") -> void:
	if not body:
		return
	if not is_instance_valid(body):
		return
	# Çift release aynı gövdeyi _free listesinde iki kez tutar → acquire aynı RigidBody'yi iki kez verir.
	if not _active.has(body) and (_free_coins.has(body) or _free_pouches.has(body)):
		loot_log("release DUPLICATE_ignored reason=%s id=%s" % [reason, str(body.get_meta("loot_spawn_id", -1))])
		return
	var sid := str(body.get_meta("loot_spawn_id", -1))
	var vis := body.visible
	var col := bool(body.get_meta("collected", false))
	var in_active := _active.has(body)
	loot_log("release BEGIN reason=%s id=%s visible=%s collected=%s in_active=%s pos=%s gv=%s" % [
		reason, sid, str(vis), str(col), str(in_active), str(body.global_position), str(body.get_meta("gold_value", 0))
	])
	_clear_loot_timers(body)
	# Eski çağrılar reason vermez; gerçek repro'da bu satır işe yarar.
	if vis and not col and reason == "":
		push_warning("[LootPool] release without reason (legacy call?) id=%s pos=%s" % [sid, str(body.global_position)])
	if _active.has(body):
		_active.erase(body)
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.visible = false
	body.global_position = Vector2(-10000, -10000)
	if body.is_in_group("collectible_gold"):
		body.remove_from_group("collectible_gold")
	var coin_anim := body.get_node_or_null("CoinAnimDriver")
	if coin_anim:
		coin_anim.queue_free()
	# Reset collected flag for reuse
	body.set_meta("collected", false)
	var is_pouch: bool = int(body.get_meta("gold_value", 1)) >= 5
	if is_pouch:
		if not _free_pouches.has(body):
			_free_pouches.append(body)
	else:
		if not _free_coins.has(body):
			_free_coins.append(body)
		loot_log("release END reason=%s id=%s -> pool (free coin=%s)" % [reason, sid, str(int(body.get_meta("gold_value", 1)) < 5)])

func active_count() -> int:
	return _active.size()


func is_loot_in_active(body: RigidBody2D) -> bool:
	return body != null and is_instance_valid(body) and _active.has(body)

func schedule_despawn(body: RigidBody2D, seconds: float) -> void:
	if not body:
		return
	var t := Timer.new()
	t.one_shot = true
	# max(0.1, 0) = 0.1 sn → parça anında havuza dönüyordu; anlamlı bir taban kullan
	var wt: float = maxf(10.0, maxf(0.0, seconds))
	t.wait_time = wt
	t.name = "DespawnTimer"
	body.add_child(t)
	loot_log("schedule_despawn id=%s wait=%.2fs" % [str(body.get_meta("loot_spawn_id", -1)), wt])
	t.timeout.connect(func():
		if is_instance_valid(body):
			release(body, "despawn_timer")
	)
	t.start()

func schedule_ground_sleep(body: RigidBody2D, delay: float) -> void:
	if not body:
		return
	var t := Timer.new()
	t.name = "GroundSleepTimer"
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
	# DISABLED: This was causing newly spawned loot to disappear immediately
	# Let despawn timers handle cleanup instead
	# Only release loot that has been spawned for at least 5 seconds
	# This prevents newly spawned loot from being immediately released
	var to_release := []
	for i in range(_active.size()):
		if i >= active_cap:
			var victim := _active[i]
			if not is_instance_valid(victim):
				continue
			# Check if loot has been in scene for at least 5 seconds
			# by checking if it has a despawn timer with elapsed time >= 5 seconds
			var has_despawn_timer := false
			var timer_age := 0.0
			if victim.is_inside_tree():
				for child in victim.get_children():
					if child is Timer and child.one_shot:
						# Check if this is the despawn timer (should have wait_time around 60s)
						if child.wait_time > 10.0:  # Despawn timer is usually 60s
							has_despawn_timer = true
							timer_age = child.wait_time - child.time_left
							break
			# If it doesn't have a despawn timer yet, or timer is too new (< 5 seconds), skip it
			if not has_despawn_timer or timer_age < 5.0:
				continue
			to_release.append(victim)
	
	for victim in to_release:
		if is_instance_valid(victim):
			print("[LootPool] _enforce_cap releasing old loot at ", victim.global_position)
			release(victim, "enforce_cap")

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
	# #print("[LootPool] Created loot '", rb.name, "' layer=", rb.collision_layer, " mask=", rb.collision_mask)
	return rb
