# ghost_minion.gd - Ruh Avcısı: ölen düşmandan çıkan kısa süreli hayalet, en yakın düşmana gidip hasar verir
# Sadık Gölge aktifse: hayalet kalıcı olur (max 2), her vuruştan sonra kısa bekleyip yeni hedef arar
extends Node2D

const SPEED := 220.0
const HIT_RADIUS := 28.0
const DAMAGE := 4.0
const LIFETIME := 4.5
const TICK := 0.05
const MAX_PERSISTENT_GHOSTS := 2
const RETARGET_COOLDOWN := 1.2

var _age := 0.0
var _hit_enemies: Dictionary = {}  # id -> true
var persistent := false
var _retarget_timer := 0.0

func _ready() -> void:
	var im = get_node_or_null("/root/ItemManager")
	if im and im.has_method("has_active_item") and im.has_active_item("sadik_golge"):
		if get_tree().get_nodes_in_group("persistent_ghosts").size() < MAX_PERSISTENT_GHOSTS:
			persistent = true
			add_to_group("persistent_ghosts")

func _physics_process(delta: float) -> void:
	_age += delta
	if not persistent and _age >= LIFETIME:
		queue_free()
		return
	if _retarget_timer > 0.0:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_hit_enemies.clear()
		return
	var tree = get_tree()
	if not tree:
		return
	var enemies = tree.get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := 9999.0
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		var d = global_position.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	if nearest and nearest_dist <= HIT_RADIUS:
		if nearest.has_method("take_damage") and not _hit_enemies.get(nearest.get_instance_id(), false):
			_hit_enemies[nearest.get_instance_id()] = true
			nearest.take_damage(DAMAGE, 40.0, -30.0, true)
		if persistent:
			_retarget_timer = RETARGET_COOLDOWN
		else:
			queue_free()
		return
	if nearest:
		var dir = (nearest.global_position - global_position).normalized()
		global_position += dir * SPEED * delta

func _draw() -> void:
	# Basit hayalet görseli: yarı saydam daire (kalıcılar hafif altın tonlu)
	var color := Color(1.0, 0.92, 0.7, 0.7) if persistent else Color(0.9, 0.95, 1.0, 0.6)
	draw_circle(Vector2.ZERO, 10, color)

func _process(_delta: float) -> void:
	queue_redraw()
