# Top mermisi: Ok Yağmuru'nun varsayılan ağır saldırı mermisi. Ok'tan yavaş, iri, isabette güçlü
# knockback ve çevresine alan (splash) hasarı verir. Ateş Bombası (player_fire_bomb_projectile.gd)
# bu script'ten türer ve aynı splash mantığını yeniden kullanır. Tüm mermi yükseltmeleri
# (Sürü Oku, Yansıyan Ok, Ruh Mermisi, element, echo...) light_attack_projectile.gd tabanından gelir.
extends "res://effects/light_attack_projectile.gd"

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
# Gülle görseli trap'in kendi sprite'ı (2 kare, 50x50); atış dumanı Canonman'ın 5 karelik sprite'ı (200x200).
const _BALL_TEX := preload("res://traps_v2/wall/Canon_proj.png")
const _BALL_FRAME := 50
const _BALL_FPS := 12.0
const _SMOKE_TEX := preload("res://assets/effects/enemy fx/cannon_smoke_launch.png")
const _SMOKE_FRAMES := 5
const _SMOKE_FPS := 16.0
const _SMOKE_SCALE := 0.5
const _SMOKE_FLAT_DROP := 9.0
const _SMOKE_MUZZLE_GAP := 10.0  # Kubbenin tabanı çıkış noktasından bu kadar ileride

var splash_radius: float = 70.0
var splash_ratio: float = 0.5
var splash_color: Color = Color(0.85, 0.8, 0.7, 0.8)
var splash_burn: bool = false
var cannon_knockback: float = 220.0
var cannon_knockback_up: float = 60.0

func setup(origin: Vector2, direction: Vector2, damage: float) -> void:
	super.setup(origin, direction, damage)
	_speed = 650.0
	_hit_radius = 64.0
	_ball_radius = 15.0
	_ball_color = Color(0.28, 0.25, 0.22)
	_knife_mode = false

func _draw() -> void:
	var frame := int(Time.get_ticks_msec() / 1000.0 * _BALL_FPS) % 2
	draw_texture_rect_region(_BALL_TEX, Rect2(-_BALL_FRAME * 0.5, -_BALL_FRAME * 0.5 - 2.5, _BALL_FRAME, _BALL_FRAME), Rect2(frame * _BALL_FRAME, 0, _BALL_FRAME, _BALL_FRAME))

## Heavy atışta namluda çıkan duman (Canonman launch smoke). Puff karenin altında durduğu için yukarı kaydırılır.
static func spawn_muzzle_smoke(scene_root: Node, origin: Vector2, direction: Vector2) -> void:
	if not is_instance_valid(scene_root):
		return
	var frame_w := int(_SMOKE_TEX.get_width() / _SMOKE_FRAMES)
	var frame_h := _SMOKE_TEX.get_height()
	var frames := SpriteFrames.new()
	frames.add_animation("smoke")
	frames.set_animation_loop("smoke", false)
	frames.set_animation_speed("smoke", _SMOKE_FPS)
	for i in _SMOKE_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = _SMOKE_TEX
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame("smoke", atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * _SMOKE_SCALE
	sprite.z_as_relative = false
	sprite.z_index = 11
	scene_root.add_child(sprite)
	# Sprite yukarı doğru kabaran bir kubbe (tabanı karenin altında); namlu yönüne kabarsın diye
	# ileri bakarken saat yönünde 90°, geriye bakarken ters yönde çevrilir. Taban namluya oturur.
	var dir := direction.normalized()
	sprite.rotation = dir.angle() + PI * 0.5
	sprite.global_position = origin + dir * (_SMOKE_MUZZLE_GAP + frame_h * 0.5 * _SMOKE_SCALE)
	if absf(dir.y) < 0.1:
		sprite.global_position.y += _SMOKE_FLAT_DROP  # Yatay atışta duman yüksek kalıyordu; yukarı atış zaten oturuyor
	sprite.play("smoke")
	sprite.animation_finished.connect(sprite.queue_free)

func _on_hit(node: Node, world_pos: Vector2) -> void:
	# Ağır Mermi daha yüksek bir değer verdiyse o korunur
	knockback_force = maxf(knockback_force, cannon_knockback)
	knockback_up_force = maxf(knockback_up_force, cannon_knockback_up)
	if splash_burn and is_instance_valid(node) and node.has_method("add_burn_stack"):
		node.add_burn_stack()
	_splash(node, world_pos)
	super._on_hit(node, world_pos)

## world_pos çevresindeki (primary hariç) canlı düşmanlara splash_ratio x hasar verir, projectile'ın
## taşıdığı elementi uygular ve tek bir player_attack_landed("ranged") olayı yayınlar (element
## kaynağı item'ları patlamadan etkilenen herkese uygulansın diye). primary null olabilir.
func _splash(primary: Node, world_pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var victims: Array = []
	var splash_damage: float = _damage * splash_ratio
	for n in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(n) or n == primary or n.get("current_behavior") == "dead":
			continue
		if world_pos.distance_to(n.global_position) > splash_radius or not n.has_method("take_damage"):
			continue
		n.take_damage(splash_damage, 140.0, 70.0, true)
		_apply_element(n)
		if splash_burn and n.has_method("add_burn_stack"):
			n.add_burn_stack()
		victims.append(n)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		ring.setup(world_pos, splash_radius, splash_color)
	if not victims.is_empty():
		var p = tree.get_first_node_in_group("player")
		if p and p.has_signal("player_attack_landed"):
			p.emit_signal("player_attack_landed", "ranged", splash_damage, victims, world_pos, "all")
