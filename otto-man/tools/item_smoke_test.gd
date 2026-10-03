## Item sistemi duman testi. Çalıştırma:
##   powershell -File tools/run_item_smoke_test.ps1
## ya da doğrudan:
##   godot --headless --path . --script res://tools/item_smoke_test.gd
##
## Aşama A (statik): kayıt bütünlüğü (starter/havuz/excluded/ön koşul çakışma ve kırık referansları),
##   her item'ın instantiate edilip item_id'sinin anahtarla eşleştiği, TR+EN isim/açıklama
##   çevirilerinin gerçekten çözüldüğü.
## Aşama B (dinamik): gerçek Player sahnesiyle her item'ı activate eder, tipik oyuncu sinyallerini
##   (isabet, parry, blok, dodge, hasar...) boş hedeflerle ateşler, deactivate eder. Çalışma zamanı
##   hataları "SCRIPT ERROR" olarak çıktıya düşer; sarmalayıcı script bunları da yakalar.
## Çıkış kodu 0 = temiz, 1 = statik bir kontrol başarısız.
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	# Autoload'lar bu noktada hazır; bare identifier yerine root'tan çözüyoruz.
	await process_frame
	_run_static_checks()
	await _run_dynamic_checks()
	print("")
	if _failures.is_empty():
		print("SMOKE OK")
		quit(0)
	else:
		for f in _failures:
			print("SMOKE FAIL: ", f)
		print("SMOKE FAILED (%d)" % _failures.size())
		quit(1)

func _fail(msg: String) -> void:
	_failures.append(msg)

func _im() -> Node:
	return root.get_node_or_null("ItemManager")

func _run_static_checks() -> void:
	var im := _im()
	if im == null:
		_fail("ItemManager autoload bulunamadı")
		return
	var scenes: Dictionary = im.ITEM_SCENES
	var starter: Array = im.STARTER_ITEM_IDS
	var pools: Dictionary = im.DUNGEON_THEME_POOLS
	var reqs: Dictionary = im.ITEM_REQUIREMENTS
	var reqs_any: Dictionary = im.ITEM_REQUIREMENTS_ANY
	var excluded: Array = im.EXCLUDED_ITEM_IDS
	print("Toplam item: %d | starter: %d | excluded: %d" % [scenes.size(), starter.size(), excluded.size()])

	var seen := {}
	for id in starter:
		if seen.has(id):
			_fail("çift atama (starter): %s" % id)
		seen[id] = true
	for theme in pools.keys():
		for tier in pools[theme].keys():
			for id in pools[theme][tier]:
				if not scenes.has(id):
					_fail("havuzda olup ITEM_SCENES'te olmayan: %s (%s/%s)" % [id, theme, tier])
				if seen.has(id):
					_fail("birden fazla yerde: %s" % id)
				seen[id] = true
	for id in excluded:
		if seen.has(id):
			_fail("excluded ama başka yerde de atanmış: %s" % id)
		seen[id] = true
	for id in reqs.keys():
		seen[id] = true
		if not scenes.has(id):
			_fail("ITEM_REQUIREMENTS anahtarı kayıtsız: %s" % id)
		var parents = reqs[id]
		for p in (parents if parents is Array else [parents]):
			if not scenes.has(p):
				_fail("ITEM_REQUIREMENTS ebeveyni kayıtsız: %s -> %s" % [id, p])
	for id in reqs_any.keys():
		seen[id] = true
		if not scenes.has(id):
			_fail("ITEM_REQUIREMENTS_ANY anahtarı kayıtsız: %s" % id)
		for p in reqs_any[id]:
			if not scenes.has(p):
				_fail("ITEM_REQUIREMENTS_ANY ebeveyni kayıtsız: %s -> %s" % [id, p])
	for id in scenes.keys():
		if not seen.has(id):
			_fail("hiçbir yere atanmamış item: %s" % id)

	var tr_res = load("res://localization/strings.tr.translation")
	var en_res = load("res://localization/strings.en.translation")
	if tr_res == null or en_res == null:
		_fail("çeviri kaynakları yüklenemedi (--import çalıştırıldı mı?)")
	for pair in im.ITEM_SYNERGY_PAIRS:
		for i in range(2):
			if not scenes.has(pair[i]):
				_fail("sinerji çiftinde kayıtsız item: %s" % pair[i])
		var skey := String(pair[2])
		if tr_res and String(tr_res.get_message(skey)).is_empty():
			_fail("TR çeviri eksik: %s" % skey)
		if en_res and String(en_res.get_message(skey)).is_empty():
			_fail("EN çeviri eksik: %s" % skey)
	for id in scenes.keys():
		var inst = scenes[id].instantiate()
		if inst == null or inst.get("item_id") != id:
			_fail("instantiate/item_id uyuşmazlığı: %s" % id)
		if inst:
			inst.queue_free()
		if excluded.has(id):
			continue
		for suffix in ["name", "description"]:
			var key := "item.%s.%s" % [id, suffix]
			if tr_res and String(tr_res.get_message(key)).is_empty():
				_fail("TR çeviri eksik: %s" % key)
			if en_res and String(en_res.get_message(key)).is_empty():
				_fail("EN çeviri eksik: %s" % key)

func _run_dynamic_checks() -> void:
	var im := _im()
	if im == null:
		return
	var player_scene = load("res://player/player.tscn")
	if player_scene == null:
		_fail("player.tscn yüklenemedi")
		return
	# Script modunda current_scene yok; oyunda her zaman var ve birçok efekt ona ekleniyor.
	var test_scene := Node2D.new()
	test_scene.name = "SmokeTestScene"
	root.add_child(test_scene)
	current_scene = test_scene
	var player = player_scene.instantiate()
	test_scene.add_child(player)
	await process_frame
	await process_frame
	if im.player != player:
		im.register_player(player)

	var excluded: Array = im.EXCLUDED_ITEM_IDS
	var ids: Array = im.ITEM_SCENES.keys()
	ids.sort()
	var count := 0
	for id in ids:
		if excluded.has(id):
			continue
		im.activate_item(im.ITEM_SCENES[id])
		await process_frame
		_exercise_player_signals(player)
		await process_frame
		im.clear_all_items()
		count += 1
	print("Dinamik aşama: %d item activate/sinyal/deactivate edildi" % count)
	await _run_projectile_kind_checks(im, test_scene, player)
	await _run_scene_change_check(im, test_scene, player, ids, excluded)
	if is_instance_valid(player):
		player.queue_free()

const _STUB_ENEMY_SRC := """extends Node2D
var hp := 1000.0
var current_behavior := "idle"
var hits := 0
func take_damage(amount, _kb = 0.0, _kb_up = 0.0, _stun = false):
	hits += 1
	hp -= amount
	if hp <= 0.0:
		current_behavior = "dead"
func add_burn_stack(): pass
func add_poison_stack(_a = 0, _b = 0.0, _c = 0.0): pass
func add_frost_stack(_a = 1): pass
"""

func _make_stub_enemy(parent: Node, pos: Vector2, hp: float) -> Node2D:
	var src := GDScript.new()
	src.source_code = _STUB_ENEMY_SRC
	src.reload()
	var e := Node2D.new()
	e.set_script(src)
	e.add_to_group("enemies")
	parent.add_child(e)
	e.global_position = pos
	e.hp = hp
	return e

## Mermi türleri (ok/top/bomb): her tür, tüm mermi yükseltmeleri aktifken de gerçek düşman benzeri
## hedeflere çarpıp hasar vermeli, "ranged" sinyali yayınlamalı, Top/Bomba alan hasarı vermeli ve
## Ok Yağmuru → Top / Ateş Bombası → bomba seçimi doğru olmalı. Çalışma zamanı hataları SCRIPT ERROR olur.
func _run_projectile_kind_checks(im: Node, test_scene: Node, player: Node) -> void:
	# Önceki aşamadaki sinyal bombardımanı ağacı duraklatmış olabilir (paused=true görüldü);
	# duraklatılmış ağaçta mermi hiç hareket etmez ve test sessizce "hedef yok" der.
	Engine.time_scale = 1.0
	paused = false
	for mode in ["yalın", "tüm yükseltmeler"]:
		for kind in ["ok", "top", "bomb"]:
			im.clear_all_items()
			if mode != "yalın":
				for id in ["suru_oku", "ruh_mermisi", "ruzgarin_nisani", "yanki_oku", "yansiyan_ok", "pesine_dusen", "kartal_bakisi", "agir_mermi", "cift_vurus", "atesli_yumruk"]:
					if im.ITEM_SCENES.has(id):
						im.activate_item(im.ITEM_SCENES[id])
				await process_frame
			# ObjectPool'daki havuzlanmış düşmanlar (0,0)'da "enemies" grubunda bekliyor; mermiyi onlardan uzak tut.
			var base := Vector2(100000.0, 100000.0)
			var a := _make_stub_enemy(test_scene, base + Vector2(60, 0), 1000.0)
			var b := _make_stub_enemy(test_scene, base + Vector2(60, 25), 1000.0)
			var c := _make_stub_enemy(test_scene, base + Vector2(60, -25), 1.0)
			var ranged_events := [0]
			var cb := func(t, _d, _tg, _p, _f): if t == "ranged": ranged_events[0] += 1
			player.connect("player_attack_landed", cb)
			im.spawn_upgraded_projectile(test_scene, base, Vector2.RIGHT, 20.0, -1.0, kind, true)
			for _i in range(60):
				await physics_frame
			var total: int = a.hits + b.hits + c.hits
			if total == 0:
				_fail("mermi türü '%s' (%s): hiçbir hedefe hasar vermedi" % [kind, mode])
			if ranged_events[0] == 0:
				_fail("mermi türü '%s' (%s): player_attack_landed(\"ranged\") yayınlanmadı" % [kind, mode])
			if mode == "yalın" and kind != "ok" and total < 2:
				_fail("mermi türü '%s': alan hasarı komşu hedefe ulaşmadı (toplam isabet %d)" % [kind, total])
			player.disconnect("player_attack_landed", cb)
			for e in [a, b, c]:
				e.queue_free()
			for ch in test_scene.get_children():
				if ch != player and ch.get_script() != null and String(ch.get_script().resource_path).begins_with("res://effects/"):
					ch.queue_free()
			await process_frame
	# Ok Yağmuru türü seçimi: varsayılan Top, Ateş Bombası aktifse bomba
	for with_bomb in [false, true]:
		im.clear_all_items()
		im.activate_item(im.ITEM_SCENES["ok_yagmuru"])
		if with_bomb:
			im.activate_item(im.ITEM_SCENES["ates_bombasi"])
		await process_frame
		var before := test_scene.get_child_count()
		player.emit_signal("heavy_attack_impact", "heavy_neutral")
		await process_frame
		var want := "res://effects/player_fire_bomb_projectile.gd" if with_bomb else "res://effects/cannon_projectile.gd"
		var found := false
		for ch in test_scene.get_children():
			if ch.get_script() != null and String(ch.get_script().resource_path) == want:
				found = true
				ch.queue_free()
		if not found:
			_fail("Ok Yağmuru ağır saldırısı beklenen mermiyi atmadı: %s (çocuk %d -> %d)" % [want, before, test_scene.get_child_count()])
		await process_frame
	im.clear_all_items()
	print("Mermi türleri: ok/top/bomb (yalın + tüm yükseltmeler) ve Ok Yağmuru tür seçimi kontrol edildi")

## Sahne değişimi: tüm item'lar aktifken yeni bir Player gelir (player.gd _ready → register_player).
## Her item'ın otomatik bağlanan sinyalleri YENİ oyuncuda olmalı; yoksa item "aktif" görünüp hiçbir şey
## yapmaz (Uzun Menzil: melee kapalı + mermi yok). 2026-10-02'de gerçek oyunda yakalanan hata.
func _run_scene_change_check(im: Node, test_scene: Node, old_player: Node, ids: Array, excluded: Array) -> void:
	im.clear_all_items()
	for id in ids:
		if not excluded.has(id):
			im.activate_item(im.ITEM_SCENES[id])
	await process_frame
	var new_player = load("res://player/player.tscn").instantiate()
	test_scene.add_child(new_player)
	await process_frame
	await process_frame
	if im.player != new_player:
		_fail("sahne değişimi: ItemManager.player yeni oyuncuya geçmedi")
		return
	var checked := 0
	for item in im.active_items:
		for hook in im.AUTO_SIGNAL_HOOKS:
			var method: String = hook[0]
			var sig: String = hook[1]
			if not item.has_method(method) or not new_player.has_signal(sig):
				continue
			if sig == "heavy_attack_impact" and item.get("item_id") == "zehirli_dev":
				continue
			checked += 1
			if not new_player.is_connected(sig, Callable(item, method)):
				_fail("sahne değişimi sonrası bağlantı yok: %s.%s -> %s" % [item.get("item_id"), method, sig])
	print("Sahne değişimi: %d otomatik sinyal bağlantısı yeni oyuncuda doğrulandı" % checked)
	if checked == 0:
		_fail("sahne değişimi testi hiçbir bağlantı kontrol etmedi")
	im.clear_all_items()
	old_player.queue_free()
	await process_frame
	new_player.queue_free()

func _exercise_player_signals(p: Node) -> void:
	var kinds := ["normal", "ranged", "heavy", "fall"]
	if p.has_signal("player_attack_landed"):
		for k in kinds:
			p.emit_signal("player_attack_landed", k, 10.0, [], Vector2.ZERO, "all")
	if p.has_signal("perfect_parry"):
		p.emit_signal("perfect_parry")
	if p.has_signal("player_blocked"):
		p.emit_signal("player_blocked", 5.0, null)
	if p.has_signal("player_dodged"):
		p.emit_signal("player_dodged", 1, Vector2.ZERO, Vector2(100, 0))
	if p.has_signal("player_took_damage"):
		p.emit_signal("player_took_damage", 5.0, null)
	if p.has_signal("fall_attack_impacted"):
		p.emit_signal("fall_attack_impacted", Vector2.ZERO)
	if p.has_signal("heavy_attack_impact"):
		p.emit_signal("heavy_attack_impact", "heavy_neutral")
	if p.has_signal("heavy_attack_performed"):
		p.emit_signal("heavy_attack_performed")
	if p.has_signal("player_light_attack_performed"):
		p.emit_signal("player_light_attack_performed", Vector2.RIGHT, Vector2.ZERO, 10.0)
	if p.has_signal("dodge_started"):
		p.emit_signal("dodge_started")
	if p.has_signal("dash_started"):
		p.emit_signal("dash_started")
