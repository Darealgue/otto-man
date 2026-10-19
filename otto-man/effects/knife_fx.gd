# Bıçak mermisinin görselleri (assets/player/items/dagger_projectile.png, 5 kare 37x47):
# 0 = uçan, 1-3 = kırılma, 4 = saplanmış. Sağa bakar, uç sağda.
#   spawn_stuck: düşmana saplanan bıçak (düşmanın child'ı, 1.5 sn sonra fade)
#   spawn_break: duvara/menzil sonuna çarpan bıçağın kırılma animasyonu
# Element rengi her üç formda tint olarak uygulanır (bkz. tint_for).
extends Node2D

const TEX := preload("res://assets/player/items/dagger_projectile.png")
const FRAME_W := 37
const FRAME_H := 47
const FRAME_FLY := 0
const FRAME_BREAK_FIRST := 1
const FRAME_BREAK_COUNT := 3
const FRAME_STUCK := 4

const MAX_STUCK_PER_ENEMY := 7
const STUCK_HOLD := 1.5
const STUCK_FADE := 0.5
const STUCK_FADE_ON_DEATH := 0.2
const HIT_SPREAD := 30.0
const HIT_Y_JITTER := 10.0
const TILT_JITTER := 0.4
const BREAK_TILT_JITTER := 0.5
## Bıçağın ucu sprite merkezinin bu kadar önünde; çarpışma merkezden değil uçtan test edilir.
const TIP_OFFSET := 16.0
## Bıçağın çizimi karenin ortasında değil ~5.5 px aşağıda; sprite bu kadar yukarı çizilir ki görsel,
## mermi konumu (çarpışma ve çıkış yüksekliği) ile aynı hizada olsun.
const VISUAL_Y := -5.5
const BREAK_FRAME_TIME := 0.09
const BREAK_FADE_TIME := 0.15

var _is_break := false
var _frame := FRAME_STUCK
var _tint := Color.WHITE
var _age := 0.0
var _fading := false

static func tint_for(element: String) -> Color:
	match element:
		"fire":
			return Color(1.0, 0.5, 0.25)
		"frost":
			return Color(0.45, 0.7, 1.0)
		"poison":
			return Color(0.6, 1.0, 0.35)
		"lightning":
			return Color(1.0, 0.95, 0.4)
	return Color.WHITE

static func frame_rect(frame: int) -> Rect2:
	return Rect2(frame * FRAME_W, 0, FRAME_W, FRAME_H)

## Uçan kare; canvas'ın rotation'ı yön açısı olduğundan sola giderken ters dönmesin diye dikey çevrilir.
static func draw_flying(canvas: CanvasItem, upright_flip: bool, element: String) -> void:
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, -1.0 if upright_flip else 1.0))
	canvas.draw_texture_rect_region(TEX, Rect2(-FRAME_W * 0.5, -FRAME_H * 0.5 + VISUAL_Y, FRAME_W, FRAME_H), frame_rect(FRAME_FLY), tint_for(element))

static func spawn_stuck(enemy: Node2D, hit_pos: Vector2, direction: Vector2, element: String) -> void:
	if not is_instance_valid(enemy):
		return
	var active: Array = []
	for k in enemy.get_meta("stuck_knives", []):
		if is_instance_valid(k) and not k._fading:
			active.append(k)
	while active.size() >= MAX_STUCK_PER_ENEMY:
		active.pop_front().fade_now()
	var fx := new()
	fx._frame = FRAME_STUCK
	fx._tint = tint_for(element)
	fx.z_as_relative = false
	fx.z_index = 6
	enemy.add_child(fx)
	var body := _body_rect(enemy)
	var tip: Vector2
	if body.has_area():
		# Uç, bıçağın geldiği yönün yüzeyinden hafif içeri; yükseklik gövde içinde rastgele
		var side := signf(direction.x) if absf(direction.x) > 0.1 else 0.0
		tip = Vector2(
			body.get_center().x - side * body.size.x * 0.5 + side * randf_range(2.0, 8.0),
			body.get_center().y + randf_range(-body.size.y * 0.3, body.size.y * 0.3))
		if side == 0.0:
			tip.x = body.get_center().x + randf_range(-body.size.x * 0.3, body.size.x * 0.3)
	else:
		var local := (hit_pos - enemy.global_position).limit_length(HIT_SPREAD)
		local.y += randf_range(-HIT_Y_JITTER, HIT_Y_JITTER)
		tip = enemy.global_position + local
	fx.global_position = tip - direction * 4.0
	fx._orient(direction, randf_range(-TILT_JITTER, TILT_JITTER))
	active.append(fx)
	enemy.set_meta("stuck_knives", active)

## Düşmanın hurtbox'ının (yoksa ilk CollisionShape2D'nin) dünya koordinatındaki gövde dikdörtgeni; bulunamazsa boş Rect2.
static func _body_rect(enemy: Node2D) -> Rect2:
	var holder: Node = enemy.get("hurtbox") if enemy.get("hurtbox") != null else enemy
	var cs: CollisionShape2D = null
	for child in holder.get_children():
		if child is CollisionShape2D:
			cs = child
			break
	if cs == null or cs.shape == null:
		return Rect2()
	var half := Vector2.ZERO
	if cs.shape is RectangleShape2D:
		half = cs.shape.size * 0.5
	elif cs.shape is CapsuleShape2D:
		half = Vector2(cs.shape.radius, cs.shape.height * 0.5)
	elif cs.shape is CircleShape2D:
		half = Vector2.ONE * cs.shape.radius
	else:
		return Rect2()
	var sc := cs.global_transform.get_scale().abs()
	half *= sc
	return Rect2(cs.global_position - half, half * 2.0)

static func spawn_break(scene_root: Node, pos: Vector2, direction: Vector2, element: String) -> void:
	if not is_instance_valid(scene_root):
		return
	var fx := new()
	fx._is_break = true
	fx._frame = FRAME_BREAK_FIRST
	fx._tint = tint_for(element)
	fx.z_as_relative = false
	fx.z_index = 10
	scene_root.add_child(fx)
	fx.global_position = pos - direction * 6.0
	fx._orient(direction, randf_range(-BREAK_TILT_JITTER, BREAK_TILT_JITTER))
	# Aynı 3 karelik çizim farklı varyasyon gibi görünsün: rastgele dikey/yatay çevirme
	if randf() < 0.5:
		fx.scale.y *= -1.0
	if randf() < 0.5:
		fx.scale.x *= -1.0

func _orient(direction: Vector2, tilt: float) -> void:
	var angle := direction.angle()
	global_rotation = angle + (-tilt if direction.x < 0.0 else tilt)
	if direction.x < 0.0:
		scale.y = -1.0

func fade_now() -> void:
	_start_fade(STUCK_FADE_ON_DEATH)

func _start_fade(duration: float) -> void:
	if _fading:
		return
	_fading = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	_age += delta
	if _is_break:
		_frame = FRAME_BREAK_FIRST + mini(int(_age / BREAK_FRAME_TIME), FRAME_BREAK_COUNT - 1)
		var end := BREAK_FRAME_TIME * FRAME_BREAK_COUNT
		modulate.a = 1.0 - clampf((_age - end) / BREAK_FADE_TIME, 0.0, 1.0)
		if _age >= end + BREAK_FADE_TIME:
			queue_free()
		queue_redraw()
		return
	if _fading:
		return
	var host := get_parent()
	if host and host.get("current_behavior") == "dead":
		_start_fade(STUCK_FADE_ON_DEATH)
	elif _age >= STUCK_HOLD:
		_start_fade(STUCK_FADE)

func _draw() -> void:
	draw_texture_rect_region(TEX, Rect2(-FRAME_W * 0.5, -FRAME_H * 0.5 + VISUAL_Y, FRAME_W, FRAME_H), frame_rect(_frame), _tint)
