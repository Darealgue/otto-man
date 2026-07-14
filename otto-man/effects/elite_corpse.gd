# elite_corpse.gd
# Elit düşman öldüğünde ItemManager tarafından spawn edilir (Leş Gazı veya Ceset Tekmesi aktifken).
# Leş Gazı: darbe alınca zehirli gaz bulutu patlar, ceset tükenir.
# Ceset Tekmesi: dodge güzergâhı keserse fırlar, ilk çarptığı düşmana hasar verip yere düşer
# (yeniden tekmelenebilir — Panzehir/Barut Zırhı gibi kalıcı bir "tüketildi" bayrağı yok).
extends Node2D

const LIFETIME := 20.0
const HIT_CHECK_RADIUS := 40.0
const KICK_CHECK_RADIUS := 36.0
const KICK_SPEED := 900.0
const KICK_DAMAGE := 12.0
const KICK_HIT_RADIUS := 30.0
const GAS_RADIUS := 100.0
const KICK_COOLDOWN := 0.3  # Fırlatıldıktan sonra hemen tekrar tekmelenmesin

var _age := 0.0
var _consumed := false
var _kicked := false
var _kick_velocity := Vector2.ZERO
var _kick_cooldown := 0.0
var _hit_enemy_ids: Dictionary = {}
var _player: Node = null

func _ready() -> void:
	add_to_group("elite_corpses")
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		if _player.has_signal("player_attack_landed") and not _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.connect("player_attack_landed", _on_player_attack_landed)
		if _player.has_signal("player_dodged") and not _player.is_connected("player_dodged", _on_player_dodged):
			_player.connect("player_dodged", _on_player_dodged)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_age += delta
	if _kick_cooldown > 0.0:
		_kick_cooldown -= delta
	if _age >= LIFETIME and not _kicked:
		queue_free()
		return
	if _kicked:
		global_position += _kick_velocity * delta
		_check_kick_hit()

func _on_player_attack_landed(_attack_type: String, _damage: float, _targets: Array, position: Vector2, _filter: String) -> void:
	if _consumed or _kicked or not is_inside_tree():
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im or not im.has_active_item("les_gazi"):
		return
	if position.distance_to(global_position) > HIT_CHECK_RADIUS:
		return
	_consumed = true
	_spawn_gas()
	queue_free()

func _spawn_gas() -> void:
	var tree = get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if global_position.distance_to(node.global_position) <= GAS_RADIUS and node.has_method("add_poison_stack"):
			node.add_poison_stack(5, 2.0, 1.0)
	queue_redraw()

func _on_player_dodged(_direction: int, start_pos: Vector2, end_pos: Vector2) -> void:
	if _consumed or _kicked or _kick_cooldown > 0.0 or not is_inside_tree():
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im or not im.has_active_item("ceset_tekmesi"):
		return
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(global_position, start_pos, end_pos)
	if global_position.distance_to(closest) > KICK_CHECK_RADIUS:
		return
	var dir: Vector2 = (end_pos - start_pos)
	dir = dir.normalized() if dir.length_squared() > 0.01 else Vector2.RIGHT
	_kicked = true
	_kick_velocity = dir * KICK_SPEED
	_hit_enemy_ids.clear()

func _check_kick_hit() -> void:
	var tree = get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		var id := node.get_instance_id()
		if _hit_enemy_ids.has(id):
			continue
		if global_position.distance_to(node.global_position) <= KICK_HIT_RADIUS:
			_hit_enemy_ids[id] = true
			if node.has_method("take_damage"):
				node.take_damage(KICK_DAMAGE, 200.0, 60.0, true)
			_kicked = false
			_kick_velocity = Vector2.ZERO
			_kick_cooldown = KICK_COOLDOWN
			return

func _draw() -> void:
	# Basit ceset görseli: koyu, yayvan bir siluet (yerde yatan düşman izlenimi)
	draw_ellipse(Vector2(0, 4), Vector2(22, 10), Color(0.15, 0.12, 0.14, 0.85))

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	var seg := 16
	for i in range(seg + 1):
		var a := TAU * float(i) / float(seg)
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_polygon(points, PackedColorArray([color]))
