# Lağımcı: kayarken yere bırakılan barut izi.
# 3 sn sonra ya da bir düşman değince patlar; patlama oyuncuyu da yakar.
# Kara Barut yarıçapı büyütür + tepme ekler, Barut Zırhı kendi hasarını iptal eder
# (ortak altyapı: effects/explosion_modifiers.gd).
extends Node2D

const FUSE_TIME := 3.0
const TRIGGER_RADIUS := 26.0
const BLAST_RADIUS := 80.0
const BLAST_DAMAGE := 14.0
const SELF_DAMAGE := 4.0
const POWDER_COLOR := Color(0.18, 0.16, 0.14, 0.9)
const SIZE := Vector2(18, 8)

var _timer := 0.0
var _exploded := false

func _ready() -> void:
	z_index = 1

func _process(delta: float) -> void:
	if _exploded:
		return
	_timer += delta
	queue_redraw()
	var tree := get_tree()
	if not tree:
		return
	if _timer >= FUSE_TIME:
		_explode(tree)
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if global_position.distance_to(node.global_position) <= TRIGGER_RADIUS:
			_explode(tree)
			return

func _explode(tree: SceneTree) -> void:
	if _exploded:
		return
	_exploded = true
	var radius: float = BLAST_RADIUS * ExplosionModifiers.radius_mult()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if not node.has_method("take_damage"):
			continue
		if global_position.distance_to(node.global_position) <= radius:
			node.take_damage(BLAST_DAMAGE, 0.0, 0.0, false)
	# Kendi barutun seni de yakar — Barut Zırhı bağışıklık verir
	var player := tree.get_first_node_in_group("player")
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= radius:
		if not ExplosionModifiers.player_immune_to_explosions() and player.has_method("take_damage"):
			player.take_damage(SELF_DAMAGE, false, null)
		ExplosionModifiers.apply_recoil(player)
	queue_free()

func _draw() -> void:
	if _exploded:
		return
	# Fitil yandıkça koyulaşan barut lekesi
	var t: float = clampf(_timer / FUSE_TIME, 0.0, 1.0)
	var col := POWDER_COLOR.lerp(Color(0.9, 0.35, 0.1, 0.95), t)
	draw_rect(Rect2(-SIZE * 0.5, SIZE), col, true)
