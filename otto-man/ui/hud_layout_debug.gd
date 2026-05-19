extends RefCounted
class_name HudLayoutDebug

const AUTO_DUMP := true
const ALIGN_WARN_PX := 2.0

static var _dumped_keys: Dictionary = {}


static func dump_health_display(health: Control, reason: String = "layout") -> void:
	if not AUTO_DUMP or health == null:
		return
	var key: String = "%s|%s" % [health.get_instance_id(), reason]
	if reason != "ready" and _dumped_keys.has(key):
		return
	await health.get_tree().process_frame
	await health.get_tree().process_frame
	_print_report(health, reason)
	if reason == "ready":
		_dumped_keys[key] = true


static func _print_report(health: Control, reason: String) -> void:
	var scene: Node = health.get_tree().current_scene if health.get_tree() else null
	var scene_name: String = scene.name if scene else "?"

	print("")
	print("========== HUD DEBUG [%s] ==========" % reason)
	print("Sahne: %s" % scene_name)

	_line_control("HealthDisplay", health)
	_line_global("HealthDisplay", health)

	var portrait: Control = health.get_node_or_null("Portrait") as Control
	_line_control("Portrait", portrait)
	if portrait:
		var frame: TextureRect = portrait.get_node_or_null("PortraitFrame") as TextureRect
		var face: TextureRect = portrait.get_node_or_null("PortraitImage") as TextureRect
		_dump_texture_rect("PortraitFrame", frame)
		_dump_texture_rect("PortraitImage", face)
		_dump_alignment(portrait, face)
		if face and face.texture:
			print("  yuz texture: %dx%d | ekranda KEEP boyut: %s" % [
				face.texture.get_width(), face.texture.get_height(), face.size
			])
			if absf(face.size.x - float(HudLayout.PORTRAIT_PIXEL_SIZE)) > ALIGN_WARN_PX:
				print("  !!! UYARI: Yuz ekranda %dpx degil (hedef %dpx 1:1)" % [int(face.size.x), HudLayout.PORTRAIT_PIXEL_SIZE])

	var bar: Control = health.get_node_or_null("BarContainer") as Control
	_line_control("BarContainer", bar)
	if bar and bar.size.y < 8.0:
		print("  !!! UYARI: Can bari cok ince (h=%.1f)" % bar.size.y)

	_line_control("StaminaBar", _find_stamina(health))
	print("  cerceve kaynak=%s delik=%s (1:1, olcek yok)" % [
		HudLayout.FRAME_TEXTURE_SIZE, HudLayout.get_portrait_hole_rect_local()
	])
	print("================================================")
	print("")


static func _find_stamina(health: Control) -> Control:
	var p: Node = health.get_parent()
	if p == null:
		return null
	var sb: Control = p.get_node_or_null("StaminaBar") as Control
	if sb:
		return sb
	return p.get_node_or_null("UI/StaminaBar") as Control


static func _dump_texture_rect(label: String, node: TextureRect) -> void:
	if node == null:
		print("  %s: <yok>" % label)
		return
	var tex_sz := Vector2.ZERO
	if node.texture:
		tex_sz = node.texture.get_size()
	print(
		"  %s: local pos=%s size=%s stretch=%d | tex=%s | global=%s"
		% [label, node.position, node.size, node.stretch_mode, tex_sz, node.get_global_rect()]
	)


static func _dump_alignment(portrait_root: Control, face: TextureRect) -> void:
	if portrait_root == null or face == null:
		return
	var expected_local: Rect2 = HudLayout.get_portrait_hole_rect_local()
	var expected_global: Rect2 = portrait_root.get_global_transform() * expected_local
	var face_global: Rect2 = face.get_global_rect()
	var d_pos: Vector2 = face_global.position - expected_global.position
	var d_size: Vector2 = face_global.size - expected_global.size
	print(
		"  hizalama: fark pos=(%.1f,%.1f) size=(%.1f,%.1f)"
		% [d_pos.x, d_pos.y, d_size.x, d_size.y]
	)


static func _line_control(label: String, node: Control) -> void:
	if node == null:
		print("  %s: <null>" % label)
		return
	print("  %s: pos=%s size=%s" % [label, node.position, node.size])


static func _line_global(label: String, node: Control) -> void:
	if node == null:
		return
	var gr: Rect2 = node.get_global_rect()
	print("  %s (ekran): %.0fx%.0f @ (%.0f,%.0f)" % [label, gr.size.x, gr.size.y, gr.position.x, gr.position.y])
