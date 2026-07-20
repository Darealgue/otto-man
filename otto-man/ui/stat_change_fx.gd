class_name StatChangeFX
extends RefCounted
## Bir HUD sayı etiketi değiştiğinde küçük bir "sallanma" (scale pop) + yükselip
## kaybolan renkli delta metni (+1 yeşil / -1 kırmızı) oynatır.
## Amaç: oyuncu zindandayken köyde olan bir şeyi (asker kaybı, yeni köylü, moral
## değişimi) geri döndüğünde sayının aniden zıplamasından değil, bu geçişten
## fark edebilsin.

const COLOR_UP := Color(0.45, 0.9, 0.5, 1.0)
const COLOR_DOWN := Color(1.0, 0.45, 0.45, 1.0)
const SHAKE_UP_TIME := 0.12
const SHAKE_DOWN_TIME := 0.28
const SHAKE_SCALE := 1.35
const POPUP_RISE := 24.0
const POPUP_DURATION := 0.9


## label: metni zaten güncellenmiş olan Label. delta: yeni_değer - eski_değer.
static func bump(label: Label, delta: int) -> void:
	if not is_instance_valid(label) or delta == 0:
		return
	_shake(label)
	_spawn_popup(label, delta)


static func _shake(label: Label) -> void:
	if label.has_meta("_stat_fx_tween"):
		var old_tw = label.get_meta("_stat_fx_tween")
		if old_tw is Tween and old_tw.is_valid():
			old_tw.kill()
	label.scale = Vector2.ONE
	label.pivot_offset = label.size * 0.5
	var tw := label.create_tween()
	label.set_meta("_stat_fx_tween", tw)
	tw.tween_property(label, "scale", Vector2.ONE * SHAKE_SCALE, SHAKE_UP_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2.ONE, SHAKE_DOWN_TIME).set_ease(Tween.EASE_IN)


static func _spawn_popup(label: Label, delta: int) -> void:
	var parent := label.get_parent()
	if not is_instance_valid(parent):
		return
	var popup := Label.new()
	popup.name = "StatDeltaPopup"
	popup.top_level = true
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.text = "%s%d" % ["+" if delta > 0 else "", delta]
	var color := COLOR_UP if delta > 0 else COLOR_DOWN
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	popup.add_theme_constant_override("outline_size", 3)
	popup.add_theme_font_size_override("font_size", 16)
	TextOutline.apply_font_to_control(popup)
	popup.z_index = 200
	parent.add_child(popup)
	popup.global_position = label.get_global_rect().position + Vector2(label.size.x * 0.5, -6.0)

	var tw := popup.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "global_position:y", popup.global_position.y - POPUP_RISE, POPUP_DURATION)
	tw.tween_property(popup, "modulate:a", 0.0, POPUP_DURATION * 0.6).set_delay(POPUP_DURATION * 0.4)
	tw.chain().tween_callback(popup.queue_free)
