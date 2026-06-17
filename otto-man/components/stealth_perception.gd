class_name StealthPerception
extends Node2D
## Görüş konisi + LOS. Alarm modunda dairesel algılamaya düşer.

enum VisibilityLevel {
	NONE,
	SUSPICIOUS,
	DETECTED,
}

const CollisionLayers = preload("res://resources/CollisionLayers.gd")

@export var vision_angle_deg: float = 75.0
@export var vision_range: float = 240.0
@export var suspicion_threshold: float = 1.2
@export var suspicion_decay_rate: float = 2.5
@export var noise_suspicion_rate: float = 2.4
@export var noise_pulse_suspicion_bonus: float = 0.28
@export var eye_offset: Vector2 = Vector2(0.0, -18.0)

var visibility_level: VisibilityLevel = VisibilityLevel.NONE
var suspicion_time: float = 0.0
var watch_target: Node2D = null
var active: bool = true

var _owner_enemy: CharacterBody2D = null
var _heard_pulse_ids: Dictionary = {}


func setup(owner_enemy: CharacterBody2D) -> void:
	_owner_enemy = owner_enemy
	z_index = 50
	set_process(true)


func deactivate() -> void:
	active = false
	watch_target = null
	suspicion_time = 0.0
	_heard_pulse_ids.clear()
	visibility_level = VisibilityLevel.NONE
	set_process(false)
	visible = false
	queue_redraw()


func is_suspicious() -> bool:
	return active and visibility_level == VisibilityLevel.SUSPICIOUS


func get_watch_target() -> Node2D:
	return watch_target if is_instance_valid(watch_target) else null


func update_perception(delta: float) -> Node2D:
	if not active or not _is_owner_active():
		return null

	var sm: Node = get_node_or_null("/root/StealthManager")
	if not is_instance_valid(sm) or not sm.has_method("is_stealth_enabled") or not sm.is_stealth_enabled():
		return _fallback_circular_target()

	if sm.segment_alarm:
		visibility_level = VisibilityLevel.DETECTED
		watch_target = _owner_enemy.get_nearest_player()
		return _fallback_circular_target()

	var player: Node2D = _find_visible_player()
	var heard_player: Node2D = _find_noise_audible_player() if player == null else null
	var perceived_player: Node2D = player if player else heard_player
	if perceived_player:
		watch_target = perceived_player
		if player:
			suspicion_time += delta
		else:
			suspicion_time += delta * noise_suspicion_rate
			_apply_noise_pulse_bonus(heard_player)
		if suspicion_time >= suspicion_threshold:
			visibility_level = VisibilityLevel.DETECTED
			var alarm_reason: String = "spotted" if player else "noise"
			if sm.has_method("raise_alarm"):
				sm.raise_alarm(alarm_reason, String(_owner_enemy.get("enemy_id")))
			return perceived_player if player else null
		visibility_level = VisibilityLevel.SUSPICIOUS
		queue_redraw()
		return null

	suspicion_time = maxf(0.0, suspicion_time - delta * suspicion_decay_rate)
	watch_target = null
	visibility_level = VisibilityLevel.NONE if suspicion_time <= 0.0 else VisibilityLevel.SUSPICIOUS
	queue_redraw()
	return null


func _apply_noise_pulse_bonus(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	var emitter: Node = player.get_node_or_null("PlayerNoiseEmitter")
	if not is_instance_valid(emitter):
		return
	if not emitter.has_method("get_active_pulse_ids_for_listener"):
		return
	var pulse_ids: Array = emitter.get_active_pulse_ids_for_listener(_owner_enemy.global_position)
	for pulse_id in pulse_ids:
		var key: int = int(pulse_id)
		if _heard_pulse_ids.has(key):
			continue
		_heard_pulse_ids[key] = true
		suspicion_time += noise_pulse_suspicion_bonus


func _is_owner_active() -> bool:
	if not is_instance_valid(_owner_enemy):
		return false
	if not _owner_enemy.is_inside_tree():
		return false
	if String(_owner_enemy.get("current_behavior")) == "dead":
		return false
	var hp: Variant = _owner_enemy.get("health")
	if hp != null and float(hp) <= 0.0:
		return false
	return true


func _find_noise_audible_player() -> Node2D:
	if not _owner_enemy.has_method("get_nearest_player"):
		return null
	var player: Node2D = _owner_enemy.get_nearest_player()
	if not is_instance_valid(player):
		return null
	var emitter: Node = player.get_node_or_null("PlayerNoiseEmitter")
	if not is_instance_valid(emitter) or not emitter.has_method("is_audible_at"):
		return null
	if emitter.is_audible_at(_owner_enemy.global_position):
		return player
	return null


func _fallback_circular_target() -> Node2D:
	if not _is_owner_active():
		return null
	if _owner_enemy.has_method("get_nearest_player_in_range"):
		return _owner_enemy.get_nearest_player_in_range()
	return null


func _find_visible_player() -> Node2D:
	if not _owner_enemy.has_method("get_nearest_player"):
		return null
	var player: Node2D = _owner_enemy.get_nearest_player()
	if not is_instance_valid(player):
		return null
	if not _is_player_in_cone(player):
		return null
	if not _has_line_of_sight(player):
		return null
	return player


func _get_effective_vision_range() -> float:
	var effective: float = vision_range
	if not is_instance_valid(_owner_enemy) or not _owner_enemy.has_method("get_nearest_player"):
		return effective
	var player: Node2D = _owner_enemy.get_nearest_player()
	if not is_instance_valid(player):
		return effective
	var mult: float = float(player.get("stealth_enemy_vision_mult")) if player.get("stealth_enemy_vision_mult") else 1.0
	return effective * clampf(mult, 0.25, 1.5)


func _get_eye_global() -> Vector2:
	return _owner_enemy.global_position + eye_offset


func _get_forward_dir() -> Vector2:
	var facing: int = int(_owner_enemy.get("direction"))
	if facing == 0:
		facing = 1
	return Vector2(float(facing), 0.0)


func _is_player_in_cone(player: Node2D) -> bool:
	var eye := _get_eye_global()
	var rel := player.global_position + Vector2(0.0, -16.0) - eye
	var effective_range: float = _get_effective_vision_range()
	var dist_sq := rel.length_squared()
	if dist_sq > effective_range * effective_range:
		return false
	if dist_sq < 4.0:
		return true
	var forward := _get_forward_dir()
	if forward.dot(rel) <= 0.0:
		return false
	var half_angle_rad := deg_to_rad(vision_angle_deg * 0.5)
	return abs(forward.angle_to(rel)) <= half_angle_rad


func _has_line_of_sight(player: Node2D) -> bool:
	var eye := _get_eye_global()
	var target_pos := player.global_position + Vector2(0.0, -16.0)
	var space := _owner_enemy.get_world_2d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(eye, target_pos)
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_owner_enemy.get_rid()]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return true
	var hit_dist := eye.distance_to(result.position)
	var player_dist := eye.distance_to(target_pos)
	return hit_dist >= player_dist - 10.0


func _process(_delta: float) -> void:
	if not active or not _is_owner_active():
		return
	var sm: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(sm) and sm.has_method("should_draw_perception") and sm.should_draw_perception():
		queue_redraw()


func _draw() -> void:
	if not active or not _is_owner_active():
		return
	var sm: Node = get_node_or_null("/root/StealthManager")
	if not is_instance_valid(sm) or not sm.has_method("should_draw_perception") or not sm.should_draw_perception():
		return
	if not is_instance_valid(_owner_enemy):
		return

	var alpha_mult: float = 1.0
	if sm.has_method("get_perception_draw_alpha"):
		alpha_mult = float(sm.get_perception_draw_alpha())
	if alpha_mult <= 0.01:
		return

	var alarm: bool = bool(sm.get("segment_alarm"))
	var facing: int = int(_owner_enemy.get("direction"))
	if facing == 0:
		facing = 1

	if alarm:
		var det_range: float = 300.0
		if _owner_enemy.get("stats"):
			var enemy_stats: Variant = _owner_enemy.get("stats")
			if enemy_stats and enemy_stats.get("detection_range"):
				det_range = float(enemy_stats.detection_range)
		draw_circle(Vector2.ZERO, det_range, Color(1.0, 0.15, 0.15, 0.12 * alpha_mult))
		draw_arc(Vector2.ZERO, det_range, 0.0, TAU, 48, Color(1.0, 0.2, 0.2, 0.55 * alpha_mult), 2.0)
		return

	var half_angle := deg_to_rad(vision_angle_deg * 0.5)
	var rot := 0.0 if facing > 0 else PI
	var start_angle := rot - half_angle
	var end_angle := rot + half_angle
	var cone_color := Color(0.2, 0.9, 0.35, 0.14 * alpha_mult)
	var outline_color := Color(0.25, 0.95, 0.4, 0.55 * alpha_mult)
	if visibility_level == VisibilityLevel.SUSPICIOUS:
		cone_color = Color(0.95, 0.85, 0.15, 0.18 * alpha_mult)
		outline_color = Color(1.0, 0.9, 0.2, 0.7 * alpha_mult)
	elif visibility_level == VisibilityLevel.DETECTED:
		cone_color = Color(0.95, 0.2, 0.2, 0.2 * alpha_mult)
		outline_color = Color(1.0, 0.25, 0.25, 0.8 * alpha_mult)

	var apex := eye_offset
	var points: PackedVector2Array = [apex]
	var steps := 16
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var ang := lerpf(start_angle, end_angle, t)
		points.append(apex + Vector2(cos(ang), sin(ang)) * _get_effective_vision_range())
	draw_colored_polygon(points, cone_color)
	for i in range(1, points.size()):
		draw_line(points[i - 1], points[i], outline_color, 1.5)

	if visibility_level == VisibilityLevel.SUSPICIOUS:
		var mark_pos := eye_offset + Vector2(0.0, -22.0)
		draw_circle(mark_pos, 5.0, Color(1.0, 0.9, 0.15, 0.95 * alpha_mult))
		draw_line(mark_pos + Vector2(0.0, -7.0), mark_pos + Vector2(0.0, 2.0), Color(0.15, 0.1, 0.0, 0.9 * alpha_mult), 2.0)
		draw_circle(mark_pos + Vector2(0.0, 6.0), 1.5, Color(0.15, 0.1, 0.0, 0.9 * alpha_mult))
