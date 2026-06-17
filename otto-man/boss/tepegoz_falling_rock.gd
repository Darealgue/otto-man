extends EnemyHitbox
class_name TepegozFallingRock
## Oda tavanından zemine düşen kaya — gölge telegraph, gecikmeli spawn.

const SHADOW_COLOR := Color(0.08, 0.05, 0.04, 0.5)
const ROCK_COLOR := Color(0.42, 0.36, 0.30, 1.0)

@export var fall_speed: float = 700.0
@export var rock_radius: float = 18.0

var _floor_y: float = 0.0
var _falling: bool = false
var _shadow: Polygon2D
var _rock_visual: Polygon2D


static func drop(
	container: Node,
	x: float,
	floor_y: float,
	ceiling_y: float,
	damage: float,
	spawn_delay: float = 0.0,
	warning_time: float = 0.45
) -> void:
	if container == null:
		return
	var rock := TepegozFallingRock.new()
	rock.damage = damage
	rock.name = "TepegozRock"
	container.add_child(rock)
	rock._run_drop(x, floor_y, ceiling_y, spawn_delay, warning_time)


func _run_drop(x: float, floor_y: float, ceiling_y: float, spawn_delay: float, warning_time: float) -> void:
	if not is_inside_tree():
		queue_free()
		return
	_floor_y = floor_y
	setup_attack("tepegoz_rock", false, 0.0)
	disable()

	_shadow = Polygon2D.new()
	_shadow.color = SHADOW_COLOR
	_shadow.polygon = _circle(rock_radius * 1.2, 12)
	_shadow.global_position = Vector2(x, floor_y)
	_shadow.z_index = 4
	get_parent().add_child(_shadow)

	if spawn_delay > 0.0:
		await get_tree().create_timer(spawn_delay).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	if warning_time > 0.0:
		if is_instance_valid(_shadow):
			var pulse := _shadow.create_tween()
			pulse.set_loops(2)
			pulse.tween_property(_shadow, "modulate:a", 0.85, warning_time * 0.45)
			pulse.tween_property(_shadow, "modulate:a", 0.35, warning_time * 0.45)
		await get_tree().create_timer(warning_time).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	_rock_visual = Polygon2D.new()
	_rock_visual.color = ROCK_COLOR
	_rock_visual.polygon = _circle(rock_radius, 10)
	add_child(_rock_visual)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = rock_radius
	shape.shape = circle
	add_child(shape)

	global_position = Vector2(x, ceiling_y)
	_falling = true
	enable()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _falling:
		return
	global_position.y += fall_speed * delta
	if global_position.y >= _floor_y:
		global_position.y = _floor_y
		_falling = false
		_on_landed()


func _on_landed() -> void:
	if is_instance_valid(_shadow):
		_shadow.queue_free()
		_shadow = null
	var sfx := get_node_or_null("/root/ScreenEffects")
	if sfx and sfx.has_method("shake"):
		sfx.shake(0.1, 3.5)
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(self):
		return
	disable()
	queue_free()


func _circle(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
