class_name TutorialSpeechHelper
extends RefCounted
## Zindan/kamp sahnelerinde köydeki mentor konuşmasıyla AYNI çerçeveyi (TutorialSpeechBar)
## tekrar kullanmak için ortak yardımcı — VillageMentorNPC._find_or_create_speech_bar ile
## aynı desen: "tutorial_speech_bar" grubunda varsa onu kullanır, yoksa oluşturur.

const _SpeechBarScene := preload("res://tutorial/ui/TutorialSpeechBar.tscn")


static func find_or_create_speech_bar(host: Node) -> Node:
	var tree := host.get_tree()
	if tree == null:
		return null
	var existing := tree.get_first_node_in_group("tutorial_speech_bar")
	if existing:
		return existing
	if _SpeechBarScene == null:
		return null
	var inst := _SpeechBarScene.instantiate()
	tree.current_scene.add_child(inst)
	return inst


## Metni gösterir ve oyuncu {interact}/{ui_up} ile kapatana kadar bekler — köydeki mentor
## balonuyla aynı davranış. Çağıran taraf await etmeden de çağırabilir (fire-and-forget).
static func show_and_await_dismiss(host: Node, bbcode_text: String) -> void:
	await show_pages_and_await_dismiss(host, [bbcode_text])


## Uzun anlatımları TEK kutuya sığdırmaya çalışmak yerine (kutu kırpıyor, "devam" tuşu da
## kutuyu kapatıyordu — bkz. kullanıcı raporu) birden fazla sayfaya bölüp sırayla gösterir;
## her sayfa {interact}/{ui_up} ile kapatılınca bir sonraki açılır, son sayfa kapanınca
## balon tamamen temizlenir. Köydeki mentorun mesaj kuyruğu (TutorialManager pending) ile
## aynı "sırayla oku" hissini veriyor.
static func show_pages_and_await_dismiss(host: Node, pages: Array) -> void:
	var bar := find_or_create_speech_bar(host)
	if bar == null:
		return
	for page in pages:
		if not is_instance_valid(host) or not host.is_inside_tree():
			break
		if bar.has_method("set_speech_bbcode"):
			bar.call("set_speech_bbcode", String(page))
		await _await_dismiss(host)
	if is_instance_valid(bar) and bar.has_method("clear_speech"):
		bar.call("clear_speech")


static func _await_dismiss(host: Node) -> void:
	var tree := host.get_tree()
	if tree == null:
		return
	await tree.create_timer(0.3).timeout
	while true:
		if not is_instance_valid(host) or not host.is_inside_tree():
			break
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_up"):
			break
		await tree.process_frame
