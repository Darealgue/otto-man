# poison_cloud.gd - Zehir bulutu / havuzu (alan hasarı). Zehirli Düşüş, Zehirli Yem, Zehir Havuzu kullanır.
extends Node2D

const TICK_INTERVAL := 1.0
const CLOUD_DURATION := 4.0
const CLOUD_RADIUS := 120.0
const POISON_STACKS_PER_TICK := 1
const MAX_POISON_STACKS := 5
const POISON_DAMAGE_PER_STACK := 1.0

## Çağıran add_child'dan ÖNCE değiştirebilir (varsayılanlar eskisiyle aynı).
var radius: float = CLOUD_RADIUS
var duration: float = CLOUD_DURATION

var _tick_timer := 0.0
var _duration_left: float

func _ready() -> void:
	_duration_left = duration

func _process(delta: float) -> void:
	_duration_left -= delta
	if _duration_left <= 0:
		queue_free()
		return
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer = 0.0
		_apply_poison_to_nearby()
	queue_redraw()

func _draw() -> void:
	# Basit placeholder: sabit bir yeşil bulut, ömrünün sonuna doğru soluyor.
	var alpha: float = clampf(_duration_left / duration, 0.0, 1.0)
	var col := Color(0.35, 0.85, 0.25, 0.28 * alpha)
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.45, 0.95, 0.35, 0.5 * alpha), 3.0)

func _apply_poison_to_nearby() -> void:
	var tree = get_tree()
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("current_behavior") == "dead":
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= radius and enemy.has_method("add_poison_stack"):
			enemy.add_poison_stack(MAX_POISON_STACKS, POISON_DAMAGE_PER_STACK, 2.0)
