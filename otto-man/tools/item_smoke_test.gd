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
	# Çocuk item'ın bir unlock havuzu (tema/kademe) olmalı, yoksa asla açılamaz
	for id in im._dependent_item_ids():
		if id in im.EXCLUDED_ITEM_IDS:
			continue
		if im._child_home(id).size() != 2:
			_fail("çocuk item'ın evi yok (CHILD_HOME_BY_PARENT'e ebeveyn ekle): %s" % id)

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
		# Önceki item'ın bıraktığı zehir/yanma/don sonrakini kirletmesin (zehir+ateş patlaması oyuncuya da vurur)
		_reset_enemy_status_effects()
		count += 1
	print("Dinamik aşama: %d item activate/sinyal/deactivate edildi" % count)
	await _run_projectile_kind_checks(im, test_scene, player)
	await _run_shadow_checks(im, test_scene, player)
	await _run_poison_item_checks(im, test_scene, player)
	await _run_fire_item_checks(im, test_scene, player)
	await _run_powder_item_checks(im, test_scene, player)
	_run_attack_state_leak_check(player)
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

const _POISON_STUB_SRC := """extends Node2D
var hp := 1000.0
var current_behavior := "idle"
var poison_stacks := 0
var airborne := false
var delirious := false
var started := 0
func take_damage(amount, _kb = 0.0, _kb_up = 0.0, _stun = false):
	hp -= amount
func add_poison_stack(max_stacks, _d = 1.0, _t = 2.0):
	poison_stacks = min(poison_stacks + 1, max_stacks)
func is_on_floor():
	return not airborne
func is_delirious():
	return delirious
func start_delirium(_s):
	delirious = true
	started += 1
"""

func _make_poison_stub(parent: Node, pos: Vector2) -> Node2D:
	var src := GDScript.new()
	src.source_code = _POISON_STUB_SRC
	src.reload()
	var e := Node2D.new()
	e.set_script(src)
	e.add_to_group("enemies")
	parent.add_child(e)
	e.global_position = pos
	return e

const _FIRE_STUB_SRC := """extends Node2D
var hp := 1000.0
var current_behavior := "idle"
var burn_remaining_ticks := 0
var burn_tick_timer := 0.0
var airborne := false
var afraid := false
var fear_started := 0
var velocity := Vector2.ZERO
var air_float_timer := 0.0
var on_wall := false
var last_up := 0.0
func take_damage(amount, _kb = 0.0, kb_up = 0.0, _stun = false):
	hp -= amount
	last_up = kb_up
func is_on_wall():
	return on_wall
func add_burn_stack():
	burn_remaining_ticks = min(burn_remaining_ticks + 3, 9)
func is_on_floor():
	return not airborne
func is_afraid():
	return afraid
func start_fear(_s):
	afraid = true
	fear_started += 1
func move_and_collide(v):
	global_position += v
	return null
"""

func _make_fire_stub(parent: Node, pos: Vector2) -> Node2D:
	var src := GDScript.new()
	src.source_code = _FIRE_STUB_SRC
	src.reload()
	var e := Node2D.new()
	e.set_script(src)
	e.add_to_group("enemies")
	parent.add_child(e)
	e.global_position = pos
	return e

func _count_scripts(test_scene: Node, path: String) -> int:
	var n := 0
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == path:
			n += 1
	return n

## Ateş item'ları: her birinin gerçek etkisi sahte (burn alanlı) düşmanlarla ölçülür.
func _run_fire_item_checks(im: Node, test_scene: Node, player: Node) -> void:
	Engine.time_scale = 1.0
	paused = false
	var base := Vector2(600000.0, 600000.0)
	var old_pos: Vector2 = player.global_position
	player.global_position = base
	var made: Array = []
	var patch_path := "res://effects/fire_patch.gd"
	var spark_path := "res://effects/ember_spark.gd"
	var mk := func(offset: Vector2) -> Node2D:
		var s := _make_fire_stub(test_scene, base + offset)
		made.append(s)
		return s

	# Kor Patlatma (guc_kayasi): ağır vuruş yanan düşmanın 6 tick'ini tüketip 6x1x1.5 = 9 hasar verir
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["guc_kayasi"])
	await process_frame
	var k1: Node2D = mk.call(Vector2(500, 0))
	k1.burn_remaining_ticks = 6
	player.emit_signal("player_attack_landed", "normal", 10.0, [k1], k1.global_position, "all")
	if k1.burn_remaining_ticks != 6:
		_fail("Kor Patlatma normal vuruşta çalışmamalı")
	player.emit_signal("player_attack_landed", "heavy", 10.0, [k1], k1.global_position, "all")
	if k1.burn_remaining_ticks != 0 or absf(1000.0 - k1.hp - 9.0) > 0.01:
		_fail("Kor Patlatma: 9 hasar ve sıfır yanma beklenirdi (hasar %s, tick %d)" % [str(1000.0 - k1.hp), k1.burn_remaining_ticks])

	# Alev Dalgası (hizli_charge): ağır vuruş 6 alev birikintisi şeridi çıkarır; bekleme süresi içinde ikincisi çıkmaz
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["hizli_charge"])
	await process_frame
	var p0 := _count_scripts(test_scene, patch_path)
	player.emit_signal("player_attack_landed", "heavy", 10.0, [], player.global_position, "all")
	if _count_scripts(test_scene, patch_path) - p0 != 6:
		_fail("Alev Dalgası: 6 birikinti beklenirdi, %d" % (_count_scripts(test_scene, patch_path) - p0))
	player.emit_signal("player_attack_landed", "heavy", 10.0, [], player.global_position, "all")
	if _count_scripts(test_scene, patch_path) - p0 != 6:
		_fail("Alev Dalgası bekleme süresine uymadı")
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == patch_path:
			ch.queue_free()

	# Kıvılcım Yağmuru (gokten_dusus): düşme vuruşu 5 kıvılcım saçar (oyuncu ve gölge yolu)
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["gokten_dusus"])
	await process_frame
	var s0 := _count_scripts(test_scene, spark_path)
	player.emit_signal("fall_attack_impacted", player.global_position)
	if _count_scripts(test_scene, spark_path) - s0 != 5:
		_fail("Kıvılcım Yağmuru: 5 kıvılcım beklenirdi, %d" % (_count_scripts(test_scene, spark_path) - s0))
	var gd = _active_item(im, "gokten_dusus")
	if gd != null:
		gd.apply_fall_attack_effect_at(player.global_position, true)
		if _count_scripts(test_scene, spark_path) - s0 != 10:
			_fail("Kıvılcım Yağmuru: gölge yolu da 5 kıvılcım saçmalı")
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == spark_path:
			ch.queue_free()

	# Yangın Yayılımı: yanan düşman 55px içindeki zehirsiz... yanmayan düşmanı yakar, uzaktakini yakmaz
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["yangin_yayilimi"])
	await process_frame
	var fa: Node2D = mk.call(Vector2(1500, 0))
	fa.burn_remaining_ticks = 6
	var fb: Node2D = mk.call(Vector2(1540, 0))
	var fc: Node2D = mk.call(Vector2(1900, 0))
	var spread_item = _active_item(im, "yangin_yayilimi")
	spread_item._poll_left = 0.0
	spread_item.process(player, 0.3)
	if fb.burn_remaining_ticks <= 0:
		_fail("Yangın Yayılımı: yakındaki düşman tutuşmalıydı")
	if fc.burn_remaining_ticks != 0:
		_fail("Yangın Yayılımı: uzaktaki düşman tutuşmamalı")

	# Alevli Parry: perfect parry saldırganın yönüne 5 birikinti şeridi (saldırgan solda → şerit solda)
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["alevli_parry"])
	await process_frame
	var attacker: Node2D = mk.call(Vector2(-200, 0))
	var bs = player.get_node_or_null("StateMachine/Block")
	if bs == null:
		_fail("Alevli Parry testi: Block state yok")
	else:
		bs.set("_last_parried_attacker", attacker)
		var q0 := _count_scripts(test_scene, patch_path)
		player.emit_signal("perfect_parry")
		if _count_scripts(test_scene, patch_path) - q0 != 5:
			_fail("Alevli Parry: 5 birikinti beklenirdi, %d" % (_count_scripts(test_scene, patch_path) - q0))
		var all_left := true
		for ch in test_scene.get_children():
			if ch.get_script() != null and String(ch.get_script().resource_path) == patch_path and ch.global_position.x > player.global_position.x:
				all_left = false
		if not all_left:
			_fail("Alevli Parry: şerit saldırganın (sol) yönüne gitmeli")
		bs.set("_last_parried_attacker", null)
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == patch_path:
			ch.queue_free()

	# Meşale Düşman: yanan ve havadaki düşman iz bırakır; yere inince büyük kor birikintisi (yarıçap 90)
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["mesale_dusman"])
	await process_frame
	var torch: Node2D = mk.call(Vector2(2500, -100))
	torch.burn_remaining_ticks = 6
	torch.airborne = true
	var torch_item = _active_item(im, "mesale_dusman")
	var t0 := _count_scripts(test_scene, patch_path)
	torch_item._poll_left = 0.0
	torch_item.process(player, 0.2)
	if _count_scripts(test_scene, patch_path) - t0 != 1:
		_fail("Meşale Düşman: havadayken 1 iz birikintisi beklenirdi, %d" % (_count_scripts(test_scene, patch_path) - t0))
	torch.airborne = false
	torch_item._poll_left = 0.0
	torch_item.process(player, 0.2)
	var big := false
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == patch_path and absf(float(ch.radius) - 90.0) < 0.01:
			big = true
	if not big:
		_fail("Meşale Düşman: yere inince yarıçap 90'lık kor birikintisi açılmalı")
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == patch_path:
			ch.queue_free()

	# Yarılan Alev: dodge yolundaki yanan düşman patlar (4 tick x1.5 = 6), yoldan uzaktaki dokunulmaz
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["yarilan_alev"])
	await process_frame
	var on_path: Node2D = mk.call(Vector2(3050, 10))
	on_path.burn_remaining_ticks = 4
	var off_path: Node2D = mk.call(Vector2(3050, 400))
	off_path.burn_remaining_ticks = 4
	player.emit_signal("player_dodged", 1, base + Vector2(3000, 0), base + Vector2(3100, 0))
	if on_path.burn_remaining_ticks != 0 or absf(1000.0 - on_path.hp - 6.0) > 0.01:
		_fail("Yarılan Alev: yoldaki düşman 6 hasar almalı ve yanması sıfırlanmalı (%s / %d)" % [str(1000.0 - on_path.hp), on_path.burn_remaining_ticks])
	if off_path.burn_remaining_ticks != 4:
		_fail("Yarılan Alev: yoldan uzaktaki düşmana dokunmamalı")

	# Korku Yangını: dolu yanan düşman panikler, senden uzağa kaçar, bekleme süresine uyar
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["korku_yangini"])
	await process_frame
	var scared: Node2D = mk.call(Vector2(4050, 0))
	scared.burn_remaining_ticks = 9
	var fear_item = _active_item(im, "korku_yangini")
	player.global_position = base + Vector2(4000, 0)
	var x_before := scared.global_position.x
	fear_item.process(player, 0.1)
	if scared.fear_started != 1 or not scared.afraid:
		_fail("Korku Yangını: dolu yanan düşman panik başlatmalı")
	fear_item.process(player, 0.5)
	if scared.global_position.x <= x_before:
		_fail("Korku Yangını: panikleyen düşman oyuncudan uzağa kaçmalı (%s -> %s)" % [str(x_before), str(scared.global_position.x)])
	scared.afraid = false
	fear_item.process(player, 0.1)
	if scared.fear_started != 1:
		_fail("Korku Yangını bekleme süresine uymadı")
	# Gerçek düşman tarafı: korkmuşken hedef (oyuncu) kaybedilir
	var real_enemy: Node = null
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("start_fear") and e.has_method("get_nearest_player"):
			real_enemy = e
			break
	if real_enemy == null:
		print("Korku hedef testi atlandı: havuzda korkabilen düşman yok")
	else:
		real_enemy.start_fear(2.0)
		if real_enemy.get_nearest_player() != null:
			_fail("Korkmuş düşman hedef bulmamalı")
		real_enemy.fear_until_msec = 0
		if real_enemy.is_afraid():
			_fail("Korku bitişi sıfırlanınca is_afraid() false olmalı")

	for s in made:
		if is_instance_valid(s):
			s.queue_free()
	for ch in test_scene.get_children():
		if ch != player and ch.get_script() != null and String(ch.get_script().resource_path).begins_with("res://effects/"):
			ch.queue_free()
	player.global_position = old_pos
	im.clear_all_items()
	await process_frame
	print("Ateş item'ları: Kor Patlatma, Alev Dalgası, Kıvılcım Yağmuru, Yangın Yayılımı, Alevli Parry, Meşale Düşman, Yarılan Alev, Korku Yangını kontrol edildi")

## Barut item'ları: her birinin gerçek etkisi sahte düşmanlarla ölçülür.
func _run_powder_item_checks(im: Node, test_scene: Node, player: Node) -> void:
	Engine.time_scale = 1.0
	paused = false
	var base := Vector2(800000.0, 800000.0)
	var old_pos: Vector2 = player.global_position
	player.global_position = base + Vector2(0, 5000)   # oyuncu hiçbir patlamanın yakınında olmasın
	var made: Array = []
	var mk := func(offset: Vector2) -> Node2D:
		var s := _make_fire_stub(test_scene, base + offset)
		made.append(s)
		return s

	# Barut Sıçrayışı: hava zıplaması 90px içindeki düşmana 10 hasar + 220 fırlatma verir, uzağa dokunmaz
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["barut_sicrayisi"])
	await process_frame
	var near: Node2D = mk.call(Vector2(50, 0))
	var far: Node2D = mk.call(Vector2(500, 0))
	var bomb_path := "res://effects/jump_bomb.gd"
	var b0 := _count_scripts(test_scene, bomb_path)
	im.notify_item_event("_on_air_jump", [base])
	if _count_scripts(test_scene, bomb_path) - b0 != 1:
		_fail("Barut Sıçrayışı: hava zıplaması 1 bomba bırakmalı, %d" % (_count_scripts(test_scene, bomb_path) - b0))
	var jump_bomb: Node = null
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == bomb_path:
			jump_bomb = ch
	if jump_bomb == null:
		_fail("Barut Sıçrayışı: bomba düğümü bulunamadı")
	else:
		if jump_bomb.velocity.y <= 0.0:
			_fail("Barut Sıçrayışı: bomba aşağı doğru başlamalı (yer çekimi), hız %s" % str(jump_bomb.velocity))
		jump_bomb.detonate_now()
		if absf(1000.0 - near.hp - 10.0) > 0.01 or absf(near.last_up - 220.0) > 0.01:
			_fail("Barut Sıçrayışı: patlama 10 hasar ve 220 fırlatma vermeli (hasar %s, fırlatma %s)" % [str(1000.0 - near.hp), str(near.last_up)])
		if far.hp != 1000.0:
			_fail("Barut Sıçrayışı: uzaktaki düşmana dokunmamalı")
		# Yer çekimi: bir fizik karesi sonra bomba daha hızlı düşmeli (yeni bomba, patlatmadan)
		im.notify_item_event("_on_air_jump", [base + Vector2(0, -3000)])
		var falling: Node = null
		for ch in test_scene.get_children():
			if ch.get_script() != null and String(ch.get_script().resource_path) == bomb_path and not ch.is_queued_for_deletion():
				falling = ch
		if falling != null:
			var v0: float = falling.velocity.y
			await physics_frame
			await physics_frame
			if is_instance_valid(falling) and falling.velocity.y <= v0:
				_fail("Barut Sıçrayışı: bomba yer çekimiyle hızlanmalı (%s -> %s)" % [str(v0), str(falling.velocity.y)])
			if is_instance_valid(falling):
				falling.queue_free()

	# Kazık Darbesi: havadaki düşmana düşme vuruşu çakar (velocity.y 1100); inince alan hasarı max(0.8x, 8)
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["kazik_darbesi"])
	await process_frame
	var slam: Node2D = mk.call(Vector2(1000, -150))
	slam.airborne = true
	var slam_neighbor: Node2D = mk.call(Vector2(1060, 0))
	var grounded: Node2D = mk.call(Vector2(1500, 0))
	var stake = _active_item(im, "kazik_darbesi")
	player.emit_signal("player_attack_landed", "fall", 20.0, [grounded], grounded.global_position, "all")
	if grounded.velocity.y != 0.0:
		_fail("Kazık Darbesi: yerdeki düşman çakılmamalı")
	player.emit_signal("player_attack_landed", "fall", 20.0, [slam], slam.global_position, "all")
	if absf(slam.velocity.y - 1100.0) > 0.01:
		_fail("Kazık Darbesi: havadaki düşman 1100 hızla çakılmalı (%s)" % str(slam.velocity.y))
	slam.airborne = false
	slam.global_position = base + Vector2(1000, 0)
	stake._poll_left = 0.0
	stake.process(player, 0.1)
	if absf(1000.0 - slam.hp - 16.0) > 0.01 or absf(1000.0 - slam_neighbor.hp - 16.0) > 0.01:
		_fail("Kazık Darbesi: çakılan ve komşusu 16 hasar almalı (%s / %s)" % [str(1000.0 - slam.hp), str(1000.0 - slam_neighbor.hp)])

	# Gülle: hızla uçan düşman komşuya çarpar: komşu 10 + fırlatma, gülle 5; bekleme süresi var
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["gulle"])
	await process_frame
	var ball: Node2D = mk.call(Vector2(2000, -100))
	ball.airborne = true
	ball.velocity = Vector2(0, -400)
	var pin: Node2D = mk.call(Vector2(2030, -100))
	pin.airborne = false
	var gulle_item = _active_item(im, "gulle")
	gulle_item.process(player, 0.016)
	if absf(1000.0 - pin.hp - 10.0) > 0.01 or absf(pin.last_up - 180.0) > 0.01 or absf(1000.0 - ball.hp - 5.0) > 0.01:
		_fail("Gülle: komşu 10 + 180 fırlatma, gülle 5 hasar almalı (komşu %s/%s, gülle %s)" % [str(1000.0 - pin.hp), str(pin.last_up), str(1000.0 - ball.hp)])
	gulle_item.process(player, 0.016)
	if absf(1000.0 - pin.hp - 10.0) > 0.01:
		_fail("Gülle bekleme süresine uymadı")
	# Regresyon (2026-10-09): ObjectPool'daki bekleyen düşmanlar gizli+devre dışı olarak (0,0)'da üst üste durur;
	# Gülle onları "havada hızlı uçan düşman" sanıp birbirine vurdurup öldürüyor ve XP veriyordu.
	var pooled: Array = []
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("take_damage") and not e.can_process() and e.get("health") != null:
			pooled.append(e)
	if pooled.size() < 2:
		print("Gülle havuz regresyon testi atlandı: havuzda devre dışı düşman yok")
	else:
		# Önceki aşamalar havuz düşmanlarını (0,0)'da çoktan öldürmüş olabilir: hepsini sağlam hâle getir,
		# üst üste yığ ve hızlı "uçuyor" göster (gerçek oyundaki bekleyen yığın böyle duruyor).
		for pe in pooled:
			pe.health = 60.0
			pe.set("current_behavior", "idle")
			pe.global_position = Vector2.ZERO
			if pe.get("velocity") != null:
				pe.velocity = Vector2(0.0, -600.0)
		for _i in range(5):
			gulle_item.process(player, 0.016)
		var damaged := 0
		for pe in pooled:
			if float(pe.health) != 60.0:
				damaged += 1
		if damaged > 0:
			_fail("Gülle havuzdaki %d devre dışı düşmana dokundu (hasar verdi)" % damaged)
		for pe in pooled:
			pe.health = 60.0   # sonraki aşamaları etkilemesin

	# Barut Dolgusu: 3 öldürme = x1.45, üst sınır 5 öldürme = x1.75, süre dolunca sıfırlanır; ExplosionModifiers okur
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["barut_dolgusu"])
	await process_frame
	var pack = _active_item(im, "barut_dolgusu")
	for _i in range(3):
		pack.on_enemy_killed(null)
	if absf(ExplosionModifiers.damage_mult() - 1.45) > 0.001:
		_fail("Barut Dolgusu: 3 öldürmede x1.45 beklenirdi, %s" % str(ExplosionModifiers.damage_mult()))
	for _i in range(4):
		pack.on_enemy_killed(null)
	if absf(ExplosionModifiers.radius_mult() - 1.75) > 0.001:
		_fail("Barut Dolgusu: üst sınır x1.75 olmalı, %s" % str(ExplosionModifiers.radius_mult()))
	pack.process(player, 5.0)
	if absf(ExplosionModifiers.damage_mult() - 1.0) > 0.001:
		_fail("Barut Dolgusu: süre dolunca çarpan 1.0'a dönmeli")

	# Duvar Çarpması: darbe durumunda yüksek hızlı düşman duvara çarpınca patlar; bekleme süresi var
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["duvar_carpmasi"])
	await process_frame
	var crash: Node2D = mk.call(Vector2(3000, 0))
	crash.current_behavior = "hurt"
	crash.velocity = Vector2(400, 0)
	var crash_neighbor: Node2D = mk.call(Vector2(3050, 0))
	var wall_item = _active_item(im, "duvar_carpmasi")
	wall_item.process(player, 0.016)
	if crash.hp != 1000.0:
		_fail("Duvar Çarpması: duvara çarpmadan patlamamalı")
	crash.on_wall = true
	crash.velocity = Vector2.ZERO
	wall_item.process(player, 0.016)
	if absf(1000.0 - crash.hp - 12.0) > 0.01 or absf(1000.0 - crash_neighbor.hp - 12.0) > 0.01:
		_fail("Duvar Çarpması: çarpan ve komşusu 12 hasar almalı (%s / %s)" % [str(1000.0 - crash.hp), str(1000.0 - crash_neighbor.hp)])
	crash.velocity = Vector2(400, 0)
	wall_item.process(player, 0.016)
	crash.velocity = Vector2.ZERO
	wall_item.process(player, 0.016)
	if absf(1000.0 - crash.hp - 12.0) > 0.01:
		_fail("Duvar Çarpması bekleme süresine uymadı")

	# Fitil Hattı: komşu patlama bekleyen Dodge Bombası'nı ve Lağımcı izini fitilini beklemeden patlatır
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["fitil_hatti"])
	im.activate_item(im.ITEM_SCENES["dodge_bombasi"])
	await process_frame
	var bomb_item = _active_item(im, "dodge_bombasi")
	var trail := Node2D.new()
	trail.set_script(load("res://effects/powder_trail.gd"))
	test_scene.add_child(trail)
	trail.global_position = base + Vector2(4100, 0)
	if bomb_item == null:
		_fail("Fitil Hattı testi: Dodge Bombası aktif bulunamadı")
	else:
		bomb_item._player = player
		bomb_item._spawn_bomb_at_position(base + Vector2(4000, 0))
		if bomb_item._pending_bombs.size() != 1:
			_fail("Fitil Hattı testi: bekleyen bomba kaydı oluşmadı")
		ExplosionModifiers.announce(base + Vector2(4050, 0), 90.0)
		await create_timer(0.35).timeout
		if bomb_item._pending_bombs.size() != 0:
			_fail("Fitil Hattı: bekleyen Dodge Bombası fitilini beklemeden patlamalıydı")
		if is_instance_valid(trail) and not trail.is_queued_for_deletion():
			_fail("Fitil Hattı: Lağımcı izi komşu patlamayla hemen patlamalıydı")
	# Uzaktaki iz tetiklenmez
	var far_trail := Node2D.new()
	far_trail.set_script(load("res://effects/powder_trail.gd"))
	test_scene.add_child(far_trail)
	far_trail.global_position = base + Vector2(9000, 0)
	ExplosionModifiers.announce(base + Vector2(4050, 0), 90.0)
	await create_timer(0.35).timeout
	if not is_instance_valid(far_trail) or far_trail.is_queued_for_deletion():
		_fail("Fitil Hattı: uzaktaki iz tetiklenmemeli")
	if is_instance_valid(far_trail):
		far_trail.queue_free()

	for s in made:
		if is_instance_valid(s):
			s.queue_free()
	for ch in test_scene.get_children():
		if ch != player and ch.get_script() != null and String(ch.get_script().resource_path).begins_with("res://effects/"):
			ch.queue_free()
	player.global_position = old_pos
	im.clear_all_items()
	await process_frame
	print("Barut item'ları: Sıçrayış, Kazık, Gülle, Dolgu, Duvar Çarpması, Fitil Hattı kontrol edildi")

## Saldırı state'lerinin hitbox.hit_enemy bağlantısı state'ten çıkınca KOPMALI. Açık kalan bağlantı, başka bir
## saldırının isabetinde eski state'in player_attack_landed yayınını da çıkarıyordu (Alev Dalgası vb. ağır
## saldırı item'ları normal vuruşta tetikleniyordu).
func _run_attack_state_leak_check(player: Node) -> void:
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox == null:
		_fail("Sızıntı testi: Hitbox yok")
		return
	for state_name in ["Attack", "HeavyAttack", "AirAttackUp", "AirAttackDown"]:
		var state = player.get_node_or_null("StateMachine/%s" % state_name)
		if state == null or not state.has_method("_on_enemy_hit"):
			print("Sızıntı testi atlandı: %s state'i bulunamadı" % state_name)
			continue
		if not hitbox.hit_enemy.is_connected(state._on_enemy_hit):
			hitbox.hit_enemy.connect(state._on_enemy_hit)
		state.exit()
		if hitbox.hit_enemy.is_connected(state._on_enemy_hit):
			_fail("%s state'i çıkışta hit_enemy bağlantısını koparmadı (isabet yayını sızar)" % state_name)
			hitbox.hit_enemy.disconnect(state._on_enemy_hit)

func _reset_enemy_status_effects() -> void:
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		for prop in ["poison_stacks", "burn_remaining_ticks", "frost_stacks"]:
			if e.get(prop) != null:
				e.set(prop, 0)
		if e.get("delirium_until_msec") != null:
			e.set("delirium_until_msec", 0)

func _active_item(im: Node, id: String) -> Node:
	for it in im.active_items:
		if is_instance_valid(it) and it.item_id == id:
			return it
	return null

## Zehir item'ları: her birinin gerçek etkisi sahte (poison alanlı) düşmanlarla ölçülür.
func _run_poison_item_checks(im: Node, test_scene: Node, player: Node) -> void:
	Engine.time_scale = 1.0
	paused = false
	var base := Vector2(400000.0, 400000.0)
	var old_pos: Vector2 = player.global_position
	player.global_position = base
	var made: Array = []
	var mk := func(offset: Vector2) -> Node2D:
		var s := _make_poison_stub(test_scene, base + offset)
		made.append(s)
		return s

	# Aç Gözlü Toksin: 4 katman x 1.5 = 6 ek hasar (sadece normal/ranged saldırı)
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["ac_gozlu_toksin"])
	await process_frame
	var t1: Node2D = mk.call(Vector2(500, 0))
	t1.poison_stacks = 4
	player.emit_signal("player_attack_landed", "normal", 10.0, [t1], t1.global_position, "all")
	if absf(1000.0 - t1.hp - 6.0) > 0.01:
		_fail("Aç Gözlü Toksin: 6 ek hasar beklenirdi, %s" % str(1000.0 - t1.hp))
	var hp_before: float = t1.hp
	player.emit_signal("player_attack_landed", "heavy", 10.0, [t1], t1.global_position, "all")
	if t1.hp != hp_before:
		_fail("Aç Gözlü Toksin ağır saldırıda çalışmamalı")

	# Pusu Zehri: görünmezlik çıkış vuruşu olayı zehri maksimuma tamamlar
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["pusu_zehri"])
	await process_frame
	var t2: Node2D = mk.call(Vector2(600, 0))
	im.notify_item_event("_on_stealth_opener_hit", [t2])
	if t2.poison_stacks != im.get_poison_max_stacks():
		_fail("Pusu Zehri: %d katman beklenirdi, %d" % [im.get_poison_max_stacks(), t2.poison_stacks])

	# Acı Parry: saldırgan + 100px içindeki düşman 3 katman alır, uzaktaki almaz
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["aci_parry"])
	await process_frame
	var att: Node2D = mk.call(Vector2(60, 0))
	var near: Node2D = mk.call(Vector2(-70, 0))
	var far: Node2D = mk.call(Vector2(900, 0))
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state == null:
		_fail("Acı Parry testi: Block state bulunamadı")
	else:
		block_state.set("_last_parried_attacker", att)
		player.emit_signal("perfect_parry")
		if att.poison_stacks != 3 or near.poison_stacks != 3:
			_fail("Acı Parry: saldırgan ve yakın düşman 3 katman almalı (%d / %d)" % [att.poison_stacks, near.poison_stacks])
		if far.poison_stacks != 0:
			_fail("Acı Parry: uzaktaki düşman zehirlenmemeli")
		block_state.set("_last_parried_attacker", null)

	# Bulaşıcı Darbe: havadaki zehirli düşmana vuruş en fazla 3 komşuya 1 katman bulaştırır, yerdeyken bulaştırmaz
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["bulasici_darbe"])
	await process_frame
	var src: Node2D = mk.call(Vector2(2000, 0))
	src.poison_stacks = 2
	var n1: Node2D = mk.call(Vector2(2050, 0))
	var n2: Node2D = mk.call(Vector2(2000, 60))
	var n3: Node2D = mk.call(Vector2(1940, 0))
	var n4: Node2D = mk.call(Vector2(2000, -120))
	src.airborne = false
	player.emit_signal("player_attack_landed", "normal", 10.0, [src], src.global_position, "all")
	if n1.poison_stacks != 0:
		_fail("Bulaşıcı Darbe yerdeki düşmanda bulaştırmamalı")
	src.airborne = true
	player.emit_signal("player_attack_landed", "normal", 10.0, [src], src.global_position, "all")
	var spread: int = n1.poison_stacks + n2.poison_stacks + n3.poison_stacks + n4.poison_stacks
	if spread != 3:
		_fail("Bulaşıcı Darbe: tam 3 komşuya bulaştırmalı, toplam %d" % spread)

	# Zehir Havuzu: zehirli düşmana düşme saldırısı, katmanla büyüyen havuz açar
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["zehir_havuzu"])
	await process_frame
	var victim: Node2D = mk.call(Vector2(3000, 0))
	victim.poison_stacks = 3
	var cloud_path := "res://effects/poison_cloud.gd"
	var pools_before := 0
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == cloud_path:
			pools_before += 1
	player.emit_signal("player_attack_landed", "fall", 10.0, [victim], victim.global_position, "all")
	var pool_radius := -1.0
	var pools_after := 0
	for ch in test_scene.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == cloud_path:
			pools_after += 1
			pool_radius = float(ch.radius)
	if pools_after - pools_before != 1:
		_fail("Zehir Havuzu: 1 havuz beklenirdi, %d" % (pools_after - pools_before))
	elif absf(pool_radius - 120.0) > 0.01:
		_fail("Zehir Havuzu: 3 katmanda yarıçap 120 olmalı, %s" % str(pool_radius))

	# Zehir Delirmesi: dolu zehirli düşman delirir, delirmişken komşusuna 8 hasar verir, bekleme süresi var
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["zehir_delirmesi"])
	await process_frame
	var mad: Node2D = mk.call(Vector2(4000, 0))
	var prey: Node2D = mk.call(Vector2(4050, 0))
	mad.poison_stacks = im.get_poison_max_stacks()
	var madness = _active_item(im, "zehir_delirmesi")
	if madness == null:
		_fail("Zehir Delirmesi aktif item olarak bulunamadı")
	else:
		madness.process(player, 0.2)
		if mad.started != 1 or not mad.delirious:
			_fail("Zehir Delirmesi dolu zehirli düşmanı delirtmedi")
		madness.process(player, 0.2)
		if mad.started != 1:
			_fail("Zehir Delirmesi bekleme süresine uymadı (tekrar delirdi)")
		if absf(1000.0 - prey.hp - 8.0) > 0.01:
			_fail("Zehir Delirmesi: komşu 8 hasar almalı, %s" % str(1000.0 - prey.hp))

	# Gerçek düşman tarafı: delirmişken oyuncuyu değil en yakın diğer düşmanı hedef alır
	var real_enemy: Node = null
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("start_delirium") and e.has_method("get_nearest_player"):
			real_enemy = e
			break
	if real_enemy == null:
		print("Delirme hedef testi atlandı: havuzda delirebilen düşman yok")
	else:
		var neighbor := _make_poison_stub(test_scene, real_enemy.global_position + Vector2(80, 0))
		made.append(neighbor)
		real_enemy.start_delirium(2.0)
		var tgt = real_enemy.get_nearest_player()
		if tgt == null or tgt == real_enemy or tgt.is_in_group("player") or not tgt.is_in_group("enemies"):
			_fail("Delirmiş düşman başka bir düşmanı hedef almalı, oyuncuyu değil (hedef: %s)" % str(tgt))
		real_enemy.delirium_until_msec = 0
		if real_enemy.is_delirious():
			_fail("Delirme bitişi sıfırlanınca is_delirious() false olmalı")

	# Taşıyıcı: kayma durumunda zehirli düşmandan katman kapar, zehirsiz düşmana bırakır
	im.clear_all_items()
	im.activate_item(im.ITEM_SCENES["tasiyici"])
	await process_frame
	var carrier = _active_item(im, "tasiyici")
	var sm = player.get("state_machine")
	if carrier == null or sm == null:
		_fail("Taşıyıcı testi: item veya state machine bulunamadı")
	else:
		player.global_position = base + Vector2(5000, 0)
		var src2 := _make_poison_stub(test_scene, player.global_position + Vector2(20, 0))
		var dst2 := _make_poison_stub(test_scene, player.global_position + Vector2(30, 0))
		made.append(src2)
		made.append(dst2)
		src2.poison_stacks = 4
		# Slide'a geç ve KARE BEKLEMEDEN ölç: fizik karesi crouch basılı olmadığı için Slide'ı hemen bitirir
		sm.transition_to("Slide")
		if sm.current_state == null or sm.current_state.name != "Slide":
			print("Taşıyıcı testi atlandı: Slide durumuna geçilemedi (%s)" % (str(sm.current_state.name) if sm.current_state else "null"))
		else:
			player.global_position = base + Vector2(5000, 0)
			# Aynı kayışta: src2'den 4 katman kapılır, yanındaki zehirsiz dst2'ye bırakılır
			carrier._poll_left = 0.0
			carrier.process(player, 0.1)
			if src2.poison_stacks != 0 or dst2.poison_stacks != 4 or int(carrier.get("_carried")) != 0:
				_fail("Taşıyıcı: 4 katman src'den dst'ye geçmeli (src %d, dst %d, taşınan %s)" % [src2.poison_stacks, dst2.poison_stacks, str(carrier.get("_carried"))])
			# Ping pong yok: bırakılan düşmandan zehir hemen geri çalınmaz
			carrier._poll_left = 0.0
			carrier.process(player, 0.1)
			if dst2.poison_stacks != 4 or int(carrier.get("_carried")) != 0:
				_fail("Taşıyıcı: bırakılan zehir geri çalındı (dst %d, taşınan %s)" % [dst2.poison_stacks, str(carrier.get("_carried"))])
		sm.transition_to("Idle")
		await process_frame

	for s in made:
		if is_instance_valid(s):
			s.queue_free()
	for ch in test_scene.get_children():
		if ch != player and ch.get_script() != null and String(ch.get_script().resource_path).begins_with("res://effects/"):
			ch.queue_free()
	player.global_position = old_pos
	im.clear_all_items()
	await process_frame
	print("Zehir item'ları: Toksin, Pusu, Acı Parry, Bulaşıcı Darbe, Havuz, Delirme, Taşıyıcı kontrol edildi")

## Gölge (player_decoy): item gerektirmeden oyuncunun saldırısını yarı hasarla taklit eder, mermiyi
## yansıtır, düşman agrosunu çeker ve gölgeye vurulunca Zehirli Yem'i tetikler.
func _run_shadow_checks(im: Node, test_scene: Node, player: Node) -> void:
	Engine.time_scale = 1.0
	paused = false
	im.clear_all_items()
	var decoy_scene: PackedScene = load("res://effects/player_decoy.tscn")
	var base := Vector2(200000.0, 200000.0)
	var decoy := decoy_scene.instantiate()
	test_scene.add_child(decoy)
	decoy.setup(base, false, player)
	await process_frame

	# 1) Oran: varsayılan 0.5
	if absf(float(im.get_shadow_damage_ratio()) - 0.5) > 0.001:
		_fail("Gölge hasar oranı varsayılanı 0.5 olmalı, %s" % str(im.get_shadow_damage_ratio()))

	# 2) Taklit: item yokken oyuncunun saldırısı gölgenin hitbox'ını yarı hasarla açar
	var player_hb = player.get_node_or_null("Hitbox")
	var decoy_hb = decoy.get("_decoy_hitbox")
	if player_hb == null or decoy_hb == null:
		_fail("Gölge taklit testi: oyuncu veya gölge hitbox'ı bulunamadı")
	else:
		player_hb.damage = 20.0
		player.emit_signal("player_attack_performed", "attack_1.2", 20.0)
		if absf(float(decoy_hb.damage) - 10.0) > 0.01:
			_fail("Gölge taklit hasarı oyuncunun yarısı (10) olmalı, %s" % str(decoy_hb.damage))
		if not decoy_hb.monitoring:
			_fail("Gölge saldırısı hitbox'ı açmadı")

	# 3) Mermi yansıtma: Uzun Menzil atışı oyuncudan 1 + gölgeden 1 mermi çıkarır
	im.activate_item(im.ITEM_SCENES["uzun_menzil"])
	await process_frame
	var far := Vector2(300000.0, 300000.0)
	var foe := _make_stub_enemy(test_scene, base + Vector2(200, 0), 1000.0)
	var projectile_path := "res://effects/light_attack_projectile.gd"
	var count_projectiles := func() -> int:
		var n := 0
		for ch in test_scene.get_children():
			if ch.get_script() != null and String(ch.get_script().resource_path) == projectile_path:
				n += 1
		return n
	var before: int = count_projectiles.call()
	im.spawn_upgraded_projectile(test_scene, far, Vector2.RIGHT, 20.0, -1.0, "ok", true, true)
	var after: int = count_projectiles.call()
	if after - before != 2:
		_fail("Mermi yansıtma: 2 mermi beklenirdi (oyuncu + gölge), %d çıktı" % (after - before))
	before = count_projectiles.call()
	im.spawn_upgraded_projectile(test_scene, far, Vector2.RIGHT, 20.0, -1.0, "ok", true, false)
	if count_projectiles.call() - before != 1:
		_fail("mirror_to_shadows=false iken tek mermi beklenirdi")
	im.clear_all_items()
	foe.queue_free()

	# 4) Agro: havuzdaki gerçek bir düşman, oyuncu çok daha yakın olsa da gölgeyi hedef alır
	var real_enemy: Node = null
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("get_nearest_player"):
			real_enemy = e
			break
	if real_enemy == null:
		print("Gölge agro testi atlandı: havuzda get_nearest_player'lı düşman yok")
	else:
		var old_player_pos: Vector2 = player.global_position
		player.global_position = real_enemy.global_position + Vector2(10, 0)
		decoy.global_position = real_enemy.global_position + Vector2(500, 0)
		var target = real_enemy.get_nearest_player()
		if target != decoy:
			_fail("Düşman, daha yakın oyuncu varken gölgeyi hedef almadı (hedef: %s)" % str(target))
		player.global_position = old_player_pos
		decoy.global_position = base

	# 4b) Gölge vuruşu oyuncu vuruşu SAYILIR: Artan Güç zinciri artar; Gölge Bağı işareti gölge vuruşuyla tüketilmez
	if absf(float(decoy.get("_timer")) - 4.0) > 0.05:
		_fail("Gölge varsayılan ömrü 4 sn olmalı, %s" % str(decoy.get("_timer")))
	if absf(float(im.get_shadow_lifetime_mult()) - 1.0) > 0.001:
		_fail("Gölge ömür çarpanı varsayılanı 1.0 olmalı")
	im.activate_item(im.ITEM_SCENES["artan_guc"])
	im.activate_item(im.ITEM_SCENES["golge_bagi"])
	await process_frame
	var streak_item: Node = null
	for it in im.active_items:
		if is_instance_valid(it) and it.item_id == "artan_guc":
			streak_item = it
	var dummy := _make_stub_enemy(test_scene, base + Vector2(40, 0), 1000.0)
	if streak_item != null:
		var s_before: int = int(streak_item.get("_streak"))
		decoy._on_decoy_hitbox_hit_enemy(dummy)
		if int(streak_item.get("_streak")) != s_before + 1:
			_fail("Gölge vuruşu Artan Güç zincirini artırmadı (%d -> %s)" % [s_before, str(streak_item.get("_streak"))])
	if not dummy.has_meta("golge_bagi_until"):
		_fail("Gölge vuruşu Gölge Bağı işaretini tüketti (işaret kalmalıydı)")
	if im.is_shadow_hit():
		_fail("Gölge vuruşu bittikten sonra is_shadow_hit() hâlâ true")
	dummy.queue_free()
	im.clear_all_items()

	# 4c) Uzayan Gölge ömrü 2 katlar, Gerçek Gölge hasar oranını 1.0 yapar (yeni doğan gölge ve yeni hitbox hasarı)
	im.activate_item(im.ITEM_SCENES["uzayan_golge"])
	im.activate_item(im.ITEM_SCENES["gercek_golge"])
	await process_frame
	if absf(float(im.get_shadow_lifetime_mult()) - 2.0) > 0.001:
		_fail("Uzayan Gölge çarpanı 2.0 olmalı, %s" % str(im.get_shadow_lifetime_mult()))
	if absf(float(im.get_shadow_damage_ratio()) - 1.0) > 0.001:
		_fail("Gerçek Gölge oranı 1.0 olmalı, %s" % str(im.get_shadow_damage_ratio()))
	var long_decoy := decoy_scene.instantiate()
	test_scene.add_child(long_decoy)
	long_decoy.setup(base + Vector2(0, 5000), false, player)
	if absf(float(long_decoy.get("_timer")) - 8.0) > 0.05:
		_fail("Uzayan Gölge ile gölge ömrü 8 sn olmalı, %s" % str(long_decoy.get("_timer")))
	if player_hb != null and decoy_hb != null:
		player_hb.damage = 20.0
		player.emit_signal("player_attack_performed", "attack_1.2", 20.0)
		if absf(float(decoy_hb.damage) - 20.0) > 0.01:
			_fail("Gerçek Gölge ile gölge hasarı 20 olmalı, %s" % str(decoy_hb.damage))
	long_decoy.queue_free()
	im.clear_all_items()

	# 5) Zehirli Yem: gölgeye vuruş bulut çıkarır, 1.5 sn bekleme içinde ikincisi çıkmaz; oyuncu hasarı da çıkarır
	im.activate_item(im.ITEM_SCENES["zehirli_yem"])
	await process_frame
	var cloud_path := "res://effects/poison_cloud.gd"
	var count_clouds := func() -> int:
		var n := 0
		for ch in test_scene.get_children():
			if ch.get_script() != null and String(ch.get_script().resource_path) == cloud_path:
				n += 1
		return n
	var clouds_before: int = count_clouds.call()
	decoy.on_enemy_hit(null)
	decoy.on_enemy_hit(null)
	if count_clouds.call() - clouds_before != 1:
		_fail("Zehirli Yem: gölge isabeti 1 bulut çıkarmalı (bekleme süresi), %d çıktı" % (count_clouds.call() - clouds_before))
	await create_timer(1.7).timeout
	clouds_before = count_clouds.call()
	player.emit_signal("player_took_damage", 5.0, null)
	if count_clouds.call() - clouds_before != 1:
		_fail("Zehirli Yem: oyuncu hasar alınca bulut çıkmadı")

	im.clear_all_items()
	for ch in test_scene.get_children():
		if ch != player and ch.get_script() != null and String(ch.get_script().resource_path).begins_with("res://effects/"):
			ch.queue_free()
	await process_frame
	print("Gölge: taklit oranı, mermi yansıtma, agro ve Zehirli Yem kontrol edildi")

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
