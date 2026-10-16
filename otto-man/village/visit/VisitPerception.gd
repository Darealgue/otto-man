class_name VisitPerception
extends StealthPerception
## Ziyaret köyündeki nöbetçinin görüş konisi. Mantık StealthPerception ile aynı (koni, çatı/duvar engeli,
## ses, şüphe birikimi) ama zindan koşusuna (StealthManager / DungeonRunState) bağlı değil: alarm ve
## "nöbetçiler uyanık mı" bilgisi köy sahnesinden gelir (VillageVisitScene).

var scene_ref: Node = null


func update_perception(delta: float) -> Node2D:
	if not active or not _is_owner_active():
		return null
	if scene_ref == null or not bool(scene_ref.call("guards_alert")):
		# Dost köyde gündüz: nöbetçiler barışçıl, koni yok, şüphe sıfırlanır.
		suspicion_time = 0.0
		watch_target = null
		visibility_level = VisibilityLevel.NONE
		queue_redraw()
		return null
	if bool(scene_ref.get("alarm_active")):
		visibility_level = VisibilityLevel.DETECTED
		queue_redraw()
		return null
	var player: Node2D = _find_visible_player()
	var heard_player: Node2D = _find_noise_audible_player() if player == null else null
	var perceived: Node2D = player if player else heard_player
	if perceived:
		watch_target = perceived
		if player:
			suspicion_time += delta
		else:
			suspicion_time += delta * noise_suspicion_rate
			_apply_noise_pulse_bonus(heard_player)
		if suspicion_time >= suspicion_threshold:
			visibility_level = VisibilityLevel.DETECTED
			scene_ref.call("raise_alarm", "spotted" if player else "noise")
			queue_redraw()
			return perceived if player else null
		visibility_level = VisibilityLevel.SUSPICIOUS
		queue_redraw()
		return null
	suspicion_time = maxf(0.0, suspicion_time - delta * suspicion_decay_rate)
	watch_target = null
	visibility_level = VisibilityLevel.NONE if suspicion_time <= 0.0 else VisibilityLevel.SUSPICIOUS
	queue_redraw()
	return null


func _draw() -> void:
	if not active or scene_ref == null or not is_instance_valid(_owner_enemy):
		return
	if not bool(scene_ref.call("guards_alert")):
		return
	var facing: int = int(_owner_enemy.get("direction"))
	if facing == 0:
		facing = 1
	if bool(scene_ref.get("alarm_active")):
		draw_circle(Vector2.ZERO, 320.0, Color(1.0, 0.15, 0.15, 0.12))
		draw_arc(Vector2.ZERO, 320.0, 0.0, TAU, 48, Color(1.0, 0.2, 0.2, 0.55), 2.0)
		return
	var half_angle: float = deg_to_rad(vision_angle_deg * 0.5)
	var rot: float = 0.0 if facing > 0 else PI
	var cone_color := Color(0.2, 0.9, 0.35, 0.14)
	var outline_color := Color(0.25, 0.95, 0.4, 0.55)
	if visibility_level == VisibilityLevel.SUSPICIOUS:
		cone_color = Color(0.95, 0.85, 0.15, 0.18)
		outline_color = Color(1.0, 0.9, 0.2, 0.7)
	elif visibility_level == VisibilityLevel.DETECTED:
		cone_color = Color(0.95, 0.2, 0.2, 0.2)
		outline_color = Color(1.0, 0.25, 0.25, 0.8)
	var points: PackedVector2Array = _build_wall_clipped_cone_points(eye_offset, rot - half_angle, rot + half_angle, _get_effective_vision_range(), CONE_DRAW_RAY_STEPS)
	if points.size() < 3:
		return
	draw_colored_polygon(points, cone_color)
	draw_line(points[0], points[1], outline_color, 1.5)
	draw_line(points[0], points[points.size() - 1], outline_color, 1.5)
	for i in range(2, points.size()):
		draw_line(points[i - 1], points[i], outline_color, 2.0)
	if visibility_level == VisibilityLevel.SUSPICIOUS:
		var mark_pos: Vector2 = eye_offset + Vector2(0.0, -22.0)
		draw_circle(mark_pos, 5.0, Color(1.0, 0.9, 0.15, 0.95))
		draw_line(mark_pos + Vector2(0.0, -7.0), mark_pos + Vector2(0.0, 2.0), Color(0.15, 0.1, 0.0, 0.9), 2.0)
		draw_circle(mark_pos + Vector2(0.0, 6.0), 1.5, Color(0.15, 0.1, 0.0, 0.9))
