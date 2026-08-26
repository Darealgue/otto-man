extends Node
## GEÇİCİ TEŞHİS DOSYASI - kullanıldıktan sonra silinecek.
## Ana menüyü yükleyip ekran görüntüsü alır, font kontrolü için.

const OUT_PATH := "user://menu_probe.png"


func _ready() -> void:
	var menu := load("res://scenes/MainMenu.tscn").instantiate()
	add_child(menu)

	# Intro ekranını geçmek için bir tuş gönder
	await get_tree().create_timer(1.2).timeout
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)

	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_PATH)
	print("[MenuProbe] saved -> ", ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit()
