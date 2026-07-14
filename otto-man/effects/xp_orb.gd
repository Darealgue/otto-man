extends Node2D
## Ölen düşmandan oyuncuya doğru uçan küçük beyaz partikül (toplanan xp'nin görselleştirilmesi).
## Ulaştığında oyuncuda hafif bir beyaz parlama tetikler (bkz. Player.flash_xp_pulse) ve
## ItemManager'a haber verir (bkz. _on_xp_orb_collected) — xp bar'ı ve kart seçimi ancak bu anda güncellenir.

const CORE_RADIUS := 2.0
const GLOW_RADIUS := 5.0
const TRAIL_LENGTH := 6
## Oyuncunun global_position'u ayak hizasında; partikül gövdeye/göğüse doğru gelsin diye yukarı ofsetle.
const PLAYER_HIT_OFFSET := Vector2(0, -28)

var _target: Node
var _start := Vector2.ZERO
var _control := Vector2.ZERO
var _t := 0.0
var _duration := 0.5
var _trail: Array[Vector2] = []

func launch(from: Vector2, target_node: Node) -> void:
	_target = target_node
	_start = from
	global_position = from
	z_index = 500

	var to: Vector2 = _target_point() if is_instance_valid(target_node) else from
	var perp: Vector2 = (to - from).orthogonal().normalized()
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var arc: float = clampf(from.distance_to(to) * 0.3, 18.0, 80.0)
	# Düz bir çizgi yerine hafif kavisli, zarif bir uçuş yolu için tek kontrol noktalı (kuadratik) bezier
	_control = (from + to) * 0.5 + perp * side * arc - Vector2(0, randf_range(10.0, 25.0))
	_duration = randf_range(0.45, 0.65)

	set_process(true)

func _target_point() -> Vector2:
	return _target.global_position + PLAYER_HIT_OFFSET

func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	_t += delta / _duration
	if _t >= 1.0:
		_arrive()
		return

	var end_pos: Vector2 = _target_point()
	var eased: float = _t * _t * (3.0 - 2.0 * _t)  # smoothstep: yavaş başla, hızlı bitir
	var p1: Vector2 = _start.lerp(_control, eased)
	var p2: Vector2 = _control.lerp(end_pos, eased)
	global_position = p1.lerp(p2, eased)

	_trail.push_back(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	queue_redraw()

func _arrive() -> void:
	if is_instance_valid(_target) and _target.has_method("flash_xp_pulse"):
		_target.flash_xp_pulse()
	var im := get_node_or_null("/root/ItemManager")
	if im and im.has_method("_on_xp_orb_collected"):
		im._on_xp_orb_collected()
	queue_free()

func _draw() -> void:
	var n := _trail.size()
	for i in range(n):
		var local_pos: Vector2 = _trail[i] - global_position
		var a: float = float(i + 1) / float(n) * 0.35
		draw_circle(local_pos, CORE_RADIUS * 0.7, Color(1, 1, 1, a))
	draw_circle(Vector2.ZERO, GLOW_RADIUS, Color(1, 1, 1, 0.18))
	draw_circle(Vector2.ZERO, CORE_RADIUS, Color(1, 1, 1, 0.95))
