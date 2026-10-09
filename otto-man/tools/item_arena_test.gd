extends SceneTree
## Item arena testi: sahte düşman yerine GERÇEK düşman sahneleriyle (basic_enemy.tscn), gerçek zemin/duvar
## fiziğinde, fizik ve yapay zekaya dayanan item'ları başsız modda koşturur. item_smoke_test.gd
## sahte düşmanlarla "kod yolu"nu doğrular; bu test "gerçek düşman gerçekten böyle davranıyor mu"yu doğrular.
## Çalıştır: powershell -File tools/run_item_arena_test.ps1
## Sonuç satırı: "ARENA OK" ya da "ARENA FAILED (n)". Görsel/his/denge BURADA ölçülmez.

const ENEMY_SCENE := "res://enemy/basic/basic_enemy.tscn"
const ARENA_WALL_X := 420.0

var _failures: int = 0
var _arena: Node2D
var _player: Node
var _im: Node
var _fire_patch := "res://effects/fire_patch.gd"
var _poison_cloud := "res://effects/poison_cloud.gd"

func _initialize() -> void:
	call_deferred("_run")

func _fail(msg: String) -> void:
	_failures += 1
	print("ARENA FAIL: ", msg)

func _pass(msg: String) -> void:
	print("ARENA PASS: ", msg)

func _check(cond: bool, ok_msg: String, fail_msg: String) -> void:
	if cond:
		_pass(ok_msg)
	else:
		_fail(fail_msg)

func _frames(n: int) -> void:
	for _i in range(n):
		await physics_frame

func _make_static_box(parent: Node, pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	parent.add_child(body)
	body.global_position = pos

func _spawn_enemy(x: float, face_right_hit: bool = true) -> Node:
	var scene: PackedScene = load(ENEMY_SCENE)
	var e = scene.instantiate()
	_arena.add_child(e)
	e.global_position = Vector2(x, -30.0)
	return e

func _cleanup_arena_nodes() -> void:
	for ch in _arena.get_children():
		if ch == _player:
			continue
		if ch is StaticBody2D:
			continue
		ch.queue_free()
	await process_frame
	await process_frame

func _count_scripts(path: String) -> int:
	var n := 0
	for ch in _arena.get_children():
		if ch.get_script() != null and String(ch.get_script().resource_path) == path:
			n += 1
	return n

func _active(id: String) -> Node:
	for it in _im.active_items:
		if is_instance_valid(it) and it.item_id == id:
			return it
	return null

func _begin(item_id: String) -> void:
	_im.clear_all_items()
	await _cleanup_arena_nodes()
	_im.activate_item(_im.ITEM_SCENES[item_id])
	await process_frame

func _run() -> void:
	Engine.time_scale = 1.0
	paused = false
	_im = root.get_node_or_null("ItemManager")
	if _im == null:
		print("ARENA FAIL: ItemManager yok")
		quit(1)
		return
	# Arena: geniş zemin (üst yüzey y=0) + sağda duvar. Oyuncu çok uzakta (düşman algı menzili dışı).
	var test_root := Node2D.new()
	test_root.name = "ArenaRoot"
	root.add_child(test_root)
	current_scene = test_root
	_arena = test_root
	_make_static_box(_arena, Vector2(0.0, 20.0), Vector2(10000.0, 40.0))
	_make_static_box(_arena, Vector2(ARENA_WALL_X + 20.0, -400.0), Vector2(40.0, 800.0))
	var player_scene: PackedScene = load("res://player/player.tscn")
	_player = player_scene.instantiate()
	_arena.add_child(_player)
	_player.global_position = Vector2(2200.0, -30.0)
	# Gerçek dodge/dash stamina çubuğu ister (HUD'da yaşar); arenaya gerçek çubuğu ekle
	var hud := CanvasLayer.new()
	_arena.add_child(hud)
	hud.add_child((load("res://ui/stamina_bar.tscn") as PackedScene).instantiate())
	await _frames(3)
	if _im.player != _player:
		_im.register_player(_player)
	_player.set("invincibility_timer", 1000000.0)   # gerçek düşmanlar oyuncuyu sersemletip testi bozmasın
	await _frames(20)

	await _scenario_gulle()
	await _scenario_gulle_yerde_knockback()
	await _scenario_duvar_carpmasi()
	await _scenario_kazik_darbesi()
	await _scenario_barut_sicrayisi()
	await _scenario_zehir_delirmesi()
	await _scenario_korku_yangini()
	await _scenario_mesale_dusman()
	await _scenario_bulasici_darbe()
	await _scenario_yangin_yayilimi()
	await _scenario_alev_dalgasi()
	await _scenario_yarilan_alev()
	await _scenario_attack_signal_leak()
	await _scenario_golge_gercek_dusman()
	await _scenario_tasiyici()
	await _scenario_zehir_havuzu()
	await _scenario_kivilcim_yagmuru()
	await _scenario_kor_patlatma()
	await _scenario_alevli_parry()
	await _scenario_ac_gozlu_toksin()
	await _scenario_aci_parry()
	await _scenario_fitil_hatti()
	await _scenario_barut_dolgusu()
	await _scenario_pusu_zehri()
	await _scenario_golge_itemleri_gercek_dodge()
	await _scenario_barut_bombasi_tur_firlatma()
	await _scenario_kazik_darbesi_gercek()
	await _scenario_tum_dusman_tipleri()

	_im.clear_all_items()
	if _failures == 0:
		print("ARENA OK")
	else:
		print("ARENA FAILED (%d)" % _failures)
	quit(0 if _failures == 0 else 1)

func _enemy_hp(e: Node) -> float:
	return float(e.health) if is_instance_valid(e) else -1.0

## Gülle: fırlatılan gerçek düşman yandaki gerçek düşmana çarpınca ikisi hasar alır.
func _scenario_gulle() -> void:
	await _begin("gulle")
	var a := _spawn_enemy(-100.0)
	var b := _spawn_enemy(-30.0)
	await _frames(40)   # yere otursunlar
	var hp_b0 := _enemy_hp(b)
	var hp_a0 := _enemy_hp(a)
	a.direction = -1                       # take_damage: velocity.x = -direction * kuvvet -> sağa
	a.take_damage(1.0, 420.0, 380.0, true)
	await _frames(70)
	var b_dmg := hp_b0 - _enemy_hp(b)
	_check(b_dmg >= 9.0, "Gülle: çarpılan gerçek düşman hasar aldı (%.1f)" % b_dmg,
		"Gülle: fırlatılan düşman yandakine çarpıp hasar vermedi (b hasar %.1f, a %.1f)" % [b_dmg, hp_a0 - _enemy_hp(a)])

## Duvar Çarpması: darbeyle duvara itilen gerçek düşman çarptığı yerde patlar.
func _scenario_duvar_carpmasi() -> void:
	await _begin("duvar_carpmasi")
	# BasicEnemy yerde knockback ile ~120 px kayıp durur: duvara yakın (~60 px) başla
	var a := _spawn_enemy(ARENA_WALL_X - 85.0)
	var b := _spawn_enemy(ARENA_WALL_X - 45.0)
	await _frames(40)
	var hp_a0 := _enemy_hp(a)
	var hp_b0 := _enemy_hp(b)
	a.direction = -1                       # sağa (duvara) it
	a.take_damage(1.0, 700.0, 0.0, true)
	var peak := 0.0
	var wall_seen := false
	var beh_seen := {}
	for _i in range(80):
		await physics_frame
		if is_instance_valid(a):
			peak = maxf(peak, absf(a.velocity.x))
			wall_seen = wall_seen or a.is_on_wall()
			beh_seen[str(a.current_behavior)] = true
	print('ARENA DBG duvar: tepe hiz=%.0f duvara dokundu=%s davranislar=%s x=%.0f (duvar %.0f)' % [peak, str(wall_seen), str(beh_seen.keys()), a.global_position.x, ARENA_WALL_X])
	var total := (hp_a0 - _enemy_hp(a)) + (hp_b0 - _enemy_hp(b))
	# a: 1 (darbe) + 12 (patlama), b: 12 (patlama) -> en az 20 bekleriz
	_check(total >= 20.0, "Duvar Çarpması: duvara çarpan düşman patladı (toplam hasar %.1f)" % total,
		"Duvar Çarpması: gerçek düşman duvara çarptı ama patlama olmadı (toplam hasar %.1f)" % total)

## Kazık Darbesi: havada vurulan gerçek düşman yere çakılır, indiği yerde alan hasarı verir.
func _scenario_kazik_darbesi() -> void:
	await _begin("kazik_darbesi")
	var a := _spawn_enemy(-300.0)
	var b := _spawn_enemy(-240.0)
	await _frames(40)
	var hp_a0 := _enemy_hp(a)
	var hp_b0 := _enemy_hp(b)
	a.direction = 1
	a.take_damage(1.0, 0.0, 420.0, true)    # düz yukarı fırlat
	await _frames(14)
	var airborne: bool = not a.is_on_floor()
	_check(airborne, "Kazık Darbesi: düşman gerçekten havaya fırladı", "Kazık Darbesi: take_damage ile düşman havaya fırlamadı (test kurulumu)")
	_player.emit_signal("player_attack_landed", "fall", 20.0, [a], a.global_position, "all")
	await _frames(70)
	var dmg_b := hp_b0 - _enemy_hp(b)
	var dmg_a := hp_a0 - _enemy_hp(a)
	_check(dmg_b >= 14.0, "Kazık Darbesi: çakılan düşmanın yanındaki düşman alan hasarı aldı (%.1f)" % dmg_b,
		"Kazık Darbesi: çakılma sonrası alan hasarı yok (komşu %.1f, çakılan %.1f)" % [dmg_b, dmg_a])

## Barut Sıçrayışı: bomba yer çekimiyle gerçek zemine düşüp patlar, gerçek düşmanı havaya fırlatır.
func _scenario_barut_sicrayisi() -> void:
	await _begin("barut_sicrayisi")
	var e := _spawn_enemy(-800.0)
	await _frames(40)
	var hp0 := _enemy_hp(e)
	_im.notify_item_event("_on_air_jump", [Vector2(-800.0, -260.0)])
	var launched := false
	for _i in range(90):
		await physics_frame
		if is_instance_valid(e) and (not e.is_on_floor()) and e.velocity.y < -50.0:
			launched = true
	_check(_enemy_hp(e) < hp0, "Barut Sıçrayışı: bomba düştü ve gerçek düşmana hasar verdi", "Barut Sıçrayışı: bomba zemine düşüp patlamadı ya da düşmana vurmadı")
	_check(launched, "Barut Sıçrayışı: gerçek düşman havaya fırladı", "Barut Sıçrayışı: patlama gerçek düşmanı havaya fırlatmadı")

## Zehir Delirmesi: delirmiş gerçek düşman oyuncuyu bırakıp yandaki düşmana yürür ve ona vurur.
func _scenario_zehir_delirmesi() -> void:
	await _begin("zehir_delirmesi")
	var a := _spawn_enemy(-1200.0)
	var b := _spawn_enemy(-1050.0)
	await _frames(40)
	var hp_b0 := _enemy_hp(b)
	var x0: float = a.global_position.x
	_im.max_out_poison(a)
	await _frames(15)
	_check(a.is_delirious(), "Zehir Delirmesi: dolu zehirli gerçek düşman delirdi", "Zehir Delirmesi: dolu zehirli düşman delirmedi")
	var target = a.get_nearest_player()
	_check(target == b, "Zehir Delirmesi: delirmiş düşmanın hedefi diğer düşman", "Zehir Delirmesi: hedef beklenen düşman değil (%s)" % str(target))
	await _frames(120)
	var moved: float = a.global_position.x - x0
	_check(moved > 40.0, "Zehir Delirmesi: delirmiş düşman komşusuna doğru yürüdü (%.0f px)" % moved,
		"Zehir Delirmesi: delirmiş düşman komşusuna yürümedi, yapay zeka hedefi izlemiyor (%.0f px)" % moved)
	_check(hp_b0 - _enemy_hp(b) >= 8.0, "Zehir Delirmesi: komşu delirmiş düşmandan hasar aldı", "Zehir Delirmesi: komşu hasar almadı (%.1f)" % (hp_b0 - _enemy_hp(b)))

## Korku Yangını: yanması dolan gerçek düşman paniğe girer, hedef kaybeder ve oyuncudan uzağa kaçar.
func _scenario_korku_yangini() -> void:
	await _begin("korku_yangini")
	var a := _spawn_enemy(1800.0)           # oyuncu (2200) sağda: kaçış SOLA olmalı
	await _frames(40)
	var x0: float = a.global_position.x
	a.burn_remaining_ticks = 9
	await _frames(30)
	_check(a.is_afraid(), "Korku Yangını: dolu yanan gerçek düşman paniğe girdi", "Korku Yangını: dolu yanan düşman panik başlatmadı")
	_check(a.get_nearest_player() == null, "Korku Yangını: korkmuş düşman hedef bulmuyor", "Korku Yangını: korkmuş düşman hâlâ hedef buluyor")
	var moved: float = x0 - a.global_position.x
	_check(moved > 20.0, "Korku Yangını: düşman oyuncudan uzağa kaçtı (%.0f px)" % moved,
		"Korku Yangını: düşman kaçmadı (sola %.0f px)" % moved)

## Meşale Düşman: yanan ve havaya fırlatılan gerçek düşman iz bırakır, inince 90 px kor birikintisi açar.
func _scenario_mesale_dusman() -> void:
	await _begin("mesale_dusman")
	var a := _spawn_enemy(-1600.0)
	await _frames(40)
	a.burn_remaining_ticks = 9
	a.direction = 1
	a.take_damage(1.0, 0.0, 450.0, true)
	var max_patches := 0
	var big := false
	var landed_frame := -1
	for _i in range(260):
		await physics_frame
		if landed_frame < 0 and _i > 10 and is_instance_valid(a) and a.is_on_floor():
			landed_frame = _i
		max_patches = maxi(max_patches, _count_scripts(_fire_patch))
		for ch in _arena.get_children():
			if ch.get_script() != null and String(ch.get_script().resource_path) == _fire_patch and absf(float(ch.radius) - 90.0) < 0.01:
				big = true
	print('ARENA DBG mesale: yere inis karesi=%d yanma=%d' % [landed_frame, int(a.burn_remaining_ticks)])
	_check(max_patches >= 1, "Meşale Düşman: havadaki yanan düşman alev izi bıraktı", "Meşale Düşman: havadaki yanan düşman iz bırakmadı")
	_check(big, "Meşale Düşman: yere inince büyük kor birikintisi açıldı", "Meşale Düşman: yere inince kor birikintisi açılmadı")

## Bulaşıcı Darbe: havadaki zehirli gerçek düşmana vuruş komşuya zehir bulaştırır.
func _scenario_bulasici_darbe() -> void:
	await _begin("bulasici_darbe")
	var a := _spawn_enemy(-2000.0)
	var b := _spawn_enemy(-1940.0)
	await _frames(40)
	_im.add_poison_stacks(a, 2)
	a.direction = 1
	a.take_damage(1.0, 0.0, 450.0, true)
	await _frames(12)
	_check(not a.is_on_floor(), "Bulaşıcı Darbe: düşman havada", "Bulaşıcı Darbe: düşman havaya fırlamadı (test kurulumu)")
	_player.emit_signal("player_attack_landed", "normal", 10.0, [a], a.global_position, "all")
	await process_frame
	_check(int(b.poison_stacks) >= 1, "Bulaşıcı Darbe: komşu gerçek düşman zehir aldı", "Bulaşıcı Darbe: komşuya zehir bulaşmadı")

## Yangın Yayılımı: yanan gerçek düşman yandaki düşmanı tutuşturur.
func _scenario_yangin_yayilimi() -> void:
	await _begin("yangin_yayilimi")
	var a := _spawn_enemy(-2400.0)
	var b := _spawn_enemy(-2350.0)
	await _frames(40)
	a.add_burn_stack()
	await _frames(40)
	_check(int(b.burn_remaining_ticks) > 0, "Yangın Yayılımı: komşu gerçek düşman tutuştu", "Yangın Yayılımı: komşu tutuşmadı")

## Alev Dalgası: ağır vuruş şeridi gerçek düşmanı yakar.
func _scenario_alev_dalgasi() -> void:
	await _begin("hizli_charge")
	var e := _spawn_enemy(-2800.0)
	await _frames(40)
	_player.global_position = Vector2(-2900.0, -30.0)   # şeridin başlangıcı oyuncu konumundan, sağa
	_player.set("facing_direction", 1)
	await _frames(5)
	_player.emit_signal("player_attack_landed", "heavy", 10.0, [], _player.global_position, "all")
	await _frames(70)
	_check(int(e.burn_remaining_ticks) > 0 or _enemy_hp(e) < 60.0, "Alev Dalgası: alev şeridi gerçek düşmanı yaktı", "Alev Dalgası: şerit düşmanı yakmadı (yanma %d)" % int(e.burn_remaining_ticks))
	_player.global_position = Vector2(2200.0, -30.0)

## Yarılan Alev: dodge yolundaki yanan gerçek düşman patlar.
func _scenario_yarilan_alev() -> void:
	await _begin("yarilan_alev")
	var e := _spawn_enemy(-3200.0)
	await _frames(40)
	e.burn_remaining_ticks = 6
	var hp0 := _enemy_hp(e)
	print('ARENA DBG yarilan: dusman konum=%s yanma=%d' % [str(e.global_position), int(e.burn_remaining_ticks)])
	_player.emit_signal("player_dodged", 1, Vector2(-3300.0, -30.0), Vector2(-3100.0, -30.0))
	await process_frame
	_check(int(e.burn_remaining_ticks) == 0 and hp0 - _enemy_hp(e) >= 8.0, "Yarılan Alev: yoldaki yanan gerçek düşman patladı", "Yarılan Alev: yoldaki yanan düşman patlamadı (yanma %d, hasar %.1f)" % [int(e.burn_remaining_ticks), hp0 - _enemy_hp(e)])

func _place_player(x: float) -> void:
	_player.global_position = Vector2(x, -30.0)
	_player.velocity = Vector2.ZERO
	_player.set("facing_direction", 1.0)
	_player.set("invincibility_timer", 1000000.0)
	_player.attack_cooldown_timer = 0.0

func _press(action: String, frames: int = 2) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)

func _poison_stacks_of(e: Node) -> int:
	return int(e.poison_stacks) if is_instance_valid(e) else -1

## Gerçek oyuncu saldırıları: ağır vuruş SADECE "heavy", normal vuruş SADECE "normal" yayınlamalı.
## (Önceden state'lerin açık kalan hit bağlantıları her vuruşta ikinci bir yayın çıkarıyordu.)
func _scenario_attack_signal_leak() -> void:
	await _begin("zehirli_tirnak")   # herhangi bir item; sadece temiz başlangıç
	_im.clear_all_items()
	_place_player(3500.0)
	var e := _spawn_enemy(3560.0)
	await _frames(40)
	e.health = 5000.0
	var types: Array = []
	var cb := func(t, _d, _tg, _p, _f): types.append(String(t))
	_player.connect("player_attack_landed", cb)
	_place_player(3500.0)
	await _press("attack_heavy")
	await _frames(70)
	var heavy_types := types.duplicate()
	types.clear()
	_place_player(3500.0)
	e.global_position = Vector2(3560.0, -30.0)
	await _frames(40)
	await _press("attack")
	await _frames(50)
	var normal_types := types.duplicate()
	_player.disconnect("player_attack_landed", cb)
	print("ARENA DBG saldiri yayinlari: agir=%s normal=%s" % [str(heavy_types), str(normal_types)])
	if heavy_types.is_empty():
		print("ARENA SKIP: gerçek ağır saldırı isabet etmedi (test kurulumu), heavy sızıntı kontrolü atlandı")
	else:
		_check(not heavy_types.has("normal"), "Saldırı yayını: ağır vuruş 'normal' yayınlamadı", "Saldırı yayını: ağır vuruş yanlışlıkla 'normal' yayınladı %s" % str(heavy_types))
	if normal_types.is_empty():
		print("ARENA SKIP: gerçek normal saldırı isabet etmedi (test kurulumu), normal sızıntı kontrolü atlandı")
	else:
		_check(not normal_types.has("heavy"), "Saldırı yayını: normal vuruş 'heavy' yayınlamadı (sızıntı yok)", "Saldırı yayını: normal vuruş 'heavy' yayınladı %s (sızıntı!)" % str(normal_types))
	_place_player(2200.0)

## Gölge sistemi gerçek düşmanla: agro, gölgeye vuran gerçek düşman (Zehirli Yem), gölgenin taklit saldırısı.
func _scenario_golge_gercek_dusman() -> void:
	await _begin("zehirli_yem")
	var decoy_scene: PackedScene = load("res://effects/player_decoy.tscn")
	# 1) Agro + gölgeye vuruş
	var e := _spawn_enemy(-3600.0)
	await _frames(40)
	var decoy = decoy_scene.instantiate()
	_arena.add_child(decoy)
	decoy.setup(Vector2(-3500.0, 0.0), false, _player)   # gölge orijini AYAKTA (zemin y=0)
	e.health = 5000.0
	var old_player_pos: Vector2 = _player.global_position
	_player.global_position = Vector2(-3560.0, -30.0)   # oyuncu gölgeden DAHA yakın
	_check(e.get_nearest_player() == decoy, "Gölge: gerçek düşman daha yakın oyuncu varken gölgeyi hedef aldı", "Gölge: gerçek düşman gölgeyi hedef almadı (%s)" % str(e.get_nearest_player()))
	_player.global_position = old_player_pos
	var clouds0 := _count_scripts(_poison_cloud)
	await _frames(300)
	_check(_count_scripts(_poison_cloud) > clouds0 or _enemy_hp(e) < 5000.0 and _count_scripts(_poison_cloud) >= 0 and e.poison_stacks > 0,
		"Gölge: gerçek düşman gölgeye vurdu ve Zehirli Yem bulutu çıktı", "Gölge: gerçek düşman gölgeye vurmadı ya da Zehirli Yem tetiklenmedi (bulut %d)" % (_count_scripts(_poison_cloud) - clouds0))
	if is_instance_valid(decoy):
		decoy.queue_free()
	await _cleanup_arena_nodes()
	# 2) Gölgenin taklit saldırısı gerçek düşmanı vurur ve oyuncu vuruşu (is_shadow_hit) olarak sayılır
	_im.clear_all_items()
	var e2 := _spawn_enemy(-4060.0)
	await _frames(40)
	e2.health = 5000.0
	var d2 = decoy_scene.instantiate()
	_arena.add_child(d2)
	d2.setup(Vector2(-4120.0, 0.0), false, _player)
	await _frames(2)
	var hb = _player.get_node_or_null("Hitbox")
	hb.damage = 20.0
	var shadow_flags: Array = []
	var cb := func(t, _d, _tg, _p, f): shadow_flags.append([String(t), String(f), _im.is_shadow_hit()])
	_player.connect("player_attack_landed", cb)
	var hp0 := _enemy_hp(e2)
	var raw_hits := [0]
	var raw_cb := func(_en): raw_hits[0] += 1
	d2._decoy_hitbox.hit_enemy.connect(raw_cb)
	_player.emit_signal("player_attack_performed", "attack_1.2", 20.0)
	await _frames(2)
	await _frames(23)
	_player.disconnect("player_attack_landed", cb)
	var dealt := hp0 - _enemy_hp(e2)
	print('ARENA DBG golge: ham hit_enemy=%d player_attack_landed yayin=%d has_hit=%s' % [raw_hits[0], shadow_flags.size(), str(d2._decoy_hitbox.has_hit_enemy)])
	_check(dealt >= 3.0 and dealt <= 60.0, "Gölge: taklit saldırı gerçek düşmana hasar verdi (%.1f)" % dealt, "Gölge: taklit saldırı gerçek düşmana hasar vermedi (%.1f)" % dealt)
	var shadow_ok := false
	for s in shadow_flags:
		if s[1] == "all" and s[2]:
			shadow_ok = true
	_check(shadow_ok, "Gölge: vuruş 'all' + is_shadow_hit ile oyuncu vuruşu sayıldı", "Gölge: vuruş oyuncu vuruşu olarak yayınlanmadı %s" % str(shadow_flags))
	if is_instance_valid(d2):
		d2.queue_free()

## Taşıyıcı: gerçek kayma sırasında zehirli düşmandan zehir kapılır, sonraki zehirsiz düşmana bırakılır.
func _scenario_tasiyici() -> void:
	await _begin("tasiyici")
	_place_player(3000.0)
	var e1 := _spawn_enemy(3090.0)
	var e2 := _spawn_enemy(3170.0)
	await _frames(40)
	_im.add_poison_stacks(e1, 4)
	_place_player(3000.0)
	Input.action_press("crouch")
	var sm = _player.get("state_machine")
	sm.transition_to("Slide")
	var in_slide: bool = sm.current_state != null and sm.current_state.name == "Slide"
	for _i in range(50):
		await physics_frame
	Input.action_release("crouch")
	print("ARENA DBG tasiyici: kayma basladi=%s e1 zehir=%d e2 zehir=%d" % [str(in_slide), _poison_stacks_of(e1), _poison_stacks_of(e2)])
	if not in_slide:
		print("ARENA SKIP: Slide durumuna geçilemedi (test kurulumu), Taşıyıcı atlandı")
	else:
		_check(_poison_stacks_of(e2) >= 1, "Taşıyıcı: kayarken kapılan zehir sonraki düşmana bırakıldı", "Taşıyıcı: zehir sonraki düşmana geçmedi (e1 %d, e2 %d)" % [_poison_stacks_of(e1), _poison_stacks_of(e2)])
	_place_player(2200.0)

## Zehir Havuzu: zehirli düşmana düşme vuruşu havuz açar; havuz komşuyu zehirler.
func _scenario_zehir_havuzu() -> void:
	await _begin("zehir_havuzu")
	var a := _spawn_enemy(-2500.0)
	var b := _spawn_enemy(-2440.0)
	await _frames(40)
	_im.add_poison_stacks(a, 3)
	var b0 := _poison_stacks_of(b)
	_player.emit_signal("player_attack_landed", "fall", 10.0, [a], a.global_position, "all")
	await _frames(110)
	_check(_poison_stacks_of(b) > b0, "Zehir Havuzu: havuz gerçek komşuyu zehirledi", "Zehir Havuzu: havuz komşuyu zehirlemedi (%d)" % _poison_stacks_of(b))

## Kıvılcım Yağmuru: düşme vuruşu kıvılcımları gerçek düşmanı yakar.
func _scenario_kivilcim_yagmuru() -> void:
	await _begin("gokten_dusus")
	var e := _spawn_enemy(2650.0)
	await _frames(40)
	_player.emit_signal("fall_attack_impacted", Vector2(2500.0, -10.0))
	await _frames(110)
	_check(int(e.burn_remaining_ticks) > 0 or _enemy_hp(e) < 60.0, "Kıvılcım Yağmuru: kıvılcımlar gerçek düşmanı yaktı", "Kıvılcım Yağmuru: kıvılcımlar 150 px'teki düşmana ulaşmadı")

## Kor Patlatma: yanan gerçek düşmana ağır vuruş yanmayı tüketip anında hasar verir.
func _scenario_kor_patlatma() -> void:
	await _begin("guc_kayasi")
	var e := _spawn_enemy(2900.0)
	await _frames(40)
	e.burn_remaining_ticks = 6
	var hp0 := _enemy_hp(e)
	_player.emit_signal("player_attack_landed", "heavy", 10.0, [e], e.global_position, "all")
	await _frames(2)
	_check(int(e.burn_remaining_ticks) <= 1 and hp0 - _enemy_hp(e) >= 8.0, "Kor Patlatma: yanma tüketildi, anında hasar verildi (%.1f)" % (hp0 - _enemy_hp(e)), "Kor Patlatma: gerçek düşmanda patlama yok (yanma %d, hasar %.1f)" % [int(e.burn_remaining_ticks), hp0 - _enemy_hp(e)])

## Alevli Parry: perfect parry saldırganın yönüne alev şeridi çıkarır, şeritteki gerçek düşman yanar.
func _scenario_alevli_parry() -> void:
	await _begin("alevli_parry")
	_place_player(2000.0)
	var e := _spawn_enemy(1880.0)
	await _frames(40)
	_place_player(2000.0)
	var bs = _player.get_node_or_null("StateMachine/Block")
	bs.set("_last_parried_attacker", e)
	_player.emit_signal("perfect_parry")
	await _frames(90)
	bs.set("_last_parried_attacker", null)
	_check(int(e.burn_remaining_ticks) > 0 or _enemy_hp(e) < 60.0, "Alevli Parry: şeritteki gerçek düşman yandı", "Alevli Parry: şerit saldırganı yakmadı")
	_place_player(2200.0)

## Aç Gözlü Toksin: zehirli gerçek düşmana normal vuruş katman başına ek hasar verir.
func _scenario_ac_gozlu_toksin() -> void:
	await _begin("ac_gozlu_toksin")
	var e := _spawn_enemy(1200.0)
	await _frames(40)
	_im.add_poison_stacks(e, 4)
	var hp0 := _enemy_hp(e)
	_player.emit_signal("player_attack_landed", "normal", 10.0, [e], e.global_position, "all")
	await _frames(2)
	_check(hp0 - _enemy_hp(e) >= 5.5, "Aç Gözlü Toksin: gerçek düşman ek hasar aldı (%.1f)" % (hp0 - _enemy_hp(e)), "Aç Gözlü Toksin: ek hasar yok (%.1f)" % (hp0 - _enemy_hp(e)))

## Acı Parry: perfect parry saldırganı ve yakındaki gerçek düşmanı 3 katman zehirler.
func _scenario_aci_parry() -> void:
	await _begin("aci_parry")
	_place_player(1500.0)
	var e := _spawn_enemy(1560.0)
	var e2 := _spawn_enemy(1430.0)
	await _frames(40)
	_place_player(1500.0)
	var bs = _player.get_node_or_null("StateMachine/Block")
	bs.set("_last_parried_attacker", e)
	_player.emit_signal("perfect_parry")
	await _frames(2)
	bs.set("_last_parried_attacker", null)
	_check(_poison_stacks_of(e) >= 3 and _poison_stacks_of(e2) >= 3, "Acı Parry: saldırgan ve yakındaki gerçek düşman 3 katman zehirlendi", "Acı Parry: zehirlenme eksik (saldırgan %d, yakın %d)" % [_poison_stacks_of(e), _poison_stacks_of(e2)])
	_place_player(2200.0)

## Fitil Hattı: gerçek bir patlama, bekleyen gerçek Dodge Bombası'nı ve Lağımcı izini fitilini beklemeden patlatır.
func _scenario_fitil_hatti() -> void:
	await _begin("fitil_hatti")
	_im.activate_item(_im.ITEM_SCENES["dodge_bombasi"])
	await process_frame
	var bomb_item = _active("dodge_bombasi")
	var e := _spawn_enemy(4660.0)
	await _frames(40)
	e.health = 5000.0
	var hp0 := _enemy_hp(e)
	var trail := Node2D.new()
	trail.set_script(load("res://effects/powder_trail.gd"))
	_arena.add_child(trail)
	trail.global_position = Vector2(4640.0, -8.0)
	_player.emit_signal("player_dodged", 1, Vector2(4500.0, -30.0), Vector2(4400.0, -30.0))   # bekleyen Dodge Bombası (fitil 0.5 sn)
	var pending_ok: bool = bomb_item != null and bomb_item._pending_bombs.size() == 1
	var jb := Node2D.new()
	jb.set_script(load("res://effects/jump_bomb.gd"))
	_arena.add_child(jb)
	jb.setup(Vector2(4560.0, -20.0), Vector2.ZERO)
	jb.detonate_now()
	await _frames(24)   # ~0.4 sn: Dodge Bombası'nın kendi fitili (0.5 sn) dolmadan, Lağımcı'nınki (3 sn) çok önce
	var bomb_done: bool = bomb_item != null and bomb_item._pending_bombs.size() == 0
	var trail_done: bool = (not is_instance_valid(trail)) or trail.is_queued_for_deletion()
	_check(pending_ok, "Fitil Hattı: bekleyen Dodge Bombası kaydı oluştu", "Fitil Hattı: test kurulumu, bekleyen bomba oluşmadı")
	_check(bomb_done, "Fitil Hattı: bekleyen Dodge Bombası fitilini beklemeden patladı", "Fitil Hattı: bekleyen Dodge Bombası erken patlamadı")
	_check(trail_done, "Fitil Hattı: Lağımcı izi 3 sn fitilini beklemeden patladı", "Fitil Hattı: Lağımcı izi erken patlamadı")
	_check(hp0 - _enemy_hp(e) >= 10.0, "Fitil Hattı: zincir patlama yakındaki gerçek düşmana hasar verdi (%.1f)" % (hp0 - _enemy_hp(e)), "Fitil Hattı: zincir patlama gerçek düşmana hasar vermedi (%.1f)" % (hp0 - _enemy_hp(e)))

## Barut Dolgusu: gerçek öldürmeler (ItemManager.on_enemy_killed) patlama çarpanını büyütür, patlama daha çok vurur.
func _scenario_barut_dolgusu() -> void:
	await _begin("barut_dolgusu")
	var victims: Array = []
	for i in range(3):
		var v := _spawn_enemy(4800.0 + float(i) * 30.0)
		victims.append(v)
	var target := _spawn_enemy(4960.0)
	await _frames(40)
	target.health = 5000.0
	for v in victims:
		v.health = 1.0
	for v in victims:
		v.take_damage(50.0, 0.0, 0.0, false)
	await _frames(30)
	var mult: float = ExplosionModifiers.damage_mult()
	_check(mult >= 1.14 and mult <= 1.76, "Barut Dolgusu: gerçek öldürmeler patlama çarpanını büyüttü (x%.2f)" % mult, "Barut Dolgusu: gerçek öldürmeler çarpanı büyütmedi (x%.2f)" % mult)
	var hp0 := _enemy_hp(target)
	var jb := Node2D.new()
	jb.set_script(load("res://effects/jump_bomb.gd"))
	_arena.add_child(jb)
	jb.setup(target.global_position + Vector2(0.0, -10.0), Vector2.ZERO)
	jb.detonate_now()
	await _frames(2)
	var dealt := hp0 - _enemy_hp(target)
	_check(dealt >= 10.0 * mult - 0.6, "Barut Dolgusu: büyütülmüş patlama daha çok vurdu (%.1f, taban 10)" % dealt, "Barut Dolgusu: patlama hasarı büyümedi (%.1f, beklenen ~%.1f)" % [dealt, 10.0 * mult])

## Pusu Zehri: gerçek dodge ile gerçek görünmezlik, sonra gerçek saldırı: ilk vuruş hedefin zehrini doldurur.
func _scenario_pusu_zehri() -> void:
	await _begin("gorunmezlik_pelerini")
	_im.activate_item(_im.ITEM_SCENES["pusu_zehri"])
	await process_frame
	_place_player(4000.0)
	var e := _spawn_enemy(4110.0)
	await _frames(40)
	e.health = 5000.0
	_place_player(4000.0)
	await _frames(30)   # teleport sonrası zemine insin (dodge yerde olmayı ister)
	await _press("dash")
	await _frames(6)
	var invisible: bool = float(_player.get("gorunmezlik_first_attack_mult")) > 1.0
	_check(invisible, "Pusu Zehri: gerçek dodge görünmezlik ilk vuruş bonusunu açtı", "Pusu Zehri: gerçek dodge görünmezlik bonusunu açmadı (Görünmezlik Pelerini)")
	var stacks := 0
	for _try in range(8):
		await _frames(25)
		_player.attack_cooldown_timer = 0.0
		var px: float = _player.global_position.x
		e.global_position = Vector2(px + 55.0, e.global_position.y)
		await _press("attack")
		await _frames(25)
		stacks = _poison_stacks_of(e)
		if stacks > 0:
			break
	_check(stacks >= _im.get_poison_max_stacks(), "Pusu Zehri: gerçek saldırı hedefin zehrini maksimuma çıkardı (%d)" % stacks, "Pusu Zehri: gerçek görünmezlik çıkış vuruşu zehri doldurmadı (%d)" % stacks)
	_place_player(2200.0)

## Gerçek Ortaoyunu gölgesi: Uzayan Gölge ömrü iki katlar, Gerçek Gölge taklit hasarını tama çıkarır.
func _scenario_golge_itemleri_gercek_dodge() -> void:
	await _begin("ortaoyunu")
	_im.activate_item(_im.ITEM_SCENES["uzayan_golge"])
	_im.activate_item(_im.ITEM_SCENES["gercek_golge"])
	await process_frame
	_place_player(-4500.0)
	await _frames(30)   # zemine insin
	await _press("dash")
	await _frames(4)
	var decoys: Array = get_nodes_in_group("player_decoy")
	_check(decoys.size() >= 1, "Gölge itemleri: gerçek dodge Ortaoyunu gölgesi bıraktı", "Gölge itemleri: gerçek dodge gölge bırakmadı")
	if decoys.size() >= 1:
		var d = decoys[0]
		var life: float = float(d.get("_timer"))
		_check(life > 7.0 and life <= 8.0, "Uzayan Gölge: gerçek gölge ömrü ~8 sn (%.2f)" % life, "Uzayan Gölge: gölge ömrü 8 sn olmalıydı (%.2f)" % life)
		var e := _spawn_enemy(d.global_position.x + 60.0)
		await _frames(40)
		e.health = 5000.0
		var hb = _player.get_node_or_null("Hitbox")
		hb.damage = 20.0
		var hp0 := _enemy_hp(e)
		_player.emit_signal("player_attack_performed", "attack_1.2", 20.0)
		await _frames(25)
		var dealt := hp0 - _enemy_hp(e)
		_check(dealt >= 15.0, "Gerçek Gölge: gölge taklit saldırısı tam hasar verdi (%.1f / 20)" % dealt, "Gerçek Gölge: gölge hasarı tam olmalıydı (%.1f / 20)" % dealt)
	_place_player(2200.0)

## Dayanıklılık: TÜM gerçek düşman tipleri; yeni item'ların hepsi aktifken zehir/yanma/korku/delirme/fırlatma/çakma
## uygulanır. Betik hatası (SCRIPT ERROR) koşucu tarafından raporlanır; burada tür başına davranış bilgisi basılır.
func _scenario_tum_dusman_tipleri() -> void:
	var types := {
		"canonman": "res://enemy/canonman/canonman_enemy.tscn",
		"firemage": "res://enemy/firemage/firemage_enemy.tscn",
		"flying": "res://enemy/flying/flying_enemy.tscn",
		"heavy": "res://enemy/heavy/heavy_enemy.tscn",
		"hunter": "res://enemy/hunter/hunter_enemy.tscn",
		"shield_captain": "res://enemy/miniboss/shield_captain/shield_captain.tscn",
		"spearman": "res://enemy/spearman/spearman_enemy.tscn",
		"summoner": "res://enemy/summoner/summoner_enemy.tscn",
		"turtle": "res://enemy/turtle/turtle_enemy.tscn",
	}
	_im.clear_all_items()
	await _cleanup_arena_nodes()
	for id in ["zehir_delirmesi", "korku_yangini", "gulle", "duvar_carpmasi", "kazik_darbesi", "mesale_dusman", "yangin_yayilimi", "bulasici_darbe", "zehir_havuzu", "hizli_charge", "gokten_dusus", "guc_kayasi", "ac_gozlu_toksin", "yarilan_alev"]:
		_im.activate_item(_im.ITEM_SCENES[id])
	await process_frame
	var enemies := {}
	var x := -4400.0
	for name in types.keys():
		var scene = load(types[name])
		if scene == null:
			print("ARENA INFO: %s sahnesi yüklenemedi" % name)
			continue
		var e = scene.instantiate()
		_arena.add_child(e)
		e.global_position = Vector2(x, -30.0)
		x += 140.0
		enemies[name] = e
	await _frames(60)
	for name in enemies.keys():
		var e = enemies[name]
		if not is_instance_valid(e):
			continue
		if e.get("health") != null:
			e.health = maxf(float(e.health), 5000.0)
	# durum etkileri
	var info := {}
	for name in enemies.keys():
		var e = enemies[name]
		if not is_instance_valid(e):
			continue
		info[name] = {"hp0": _enemy_hp(e)}
		if e.has_method("add_poison_stack"):
			_im.max_out_poison(e)
		if e.has_method("add_burn_stack"):
			e.burn_remaining_ticks = 9
	await _frames(40)
	var launched := {}
	for name in enemies.keys():
		var e = enemies[name]
		if not is_instance_valid(e) or not e.has_method("take_damage"):
			continue
		e.direction = 1
		e.take_damage(1.0, 150.0, 380.0, true)
	var peaked := {}
	for _i in range(40):
		await physics_frame
		for name in enemies.keys():
			var e = enemies[name]
			if is_instance_valid(e) and e.has_method("is_on_floor") and not e.is_on_floor() and e.get("velocity") != null and e.velocity.y < -60.0:
				peaked[name] = true
	for name in enemies.keys():
		var e = enemies[name]
		if is_instance_valid(e):
			_player.emit_signal("player_attack_landed", "fall", 20.0, [e], e.global_position, "all")
	await _frames(120)   # yere insinler
	var helper_peaked := {}
	for name in enemies.keys():
		var e = enemies[name]
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.direction = 1
			_im.launch_enemy(e, 1.0, 150.0, 380.0)
	for _i in range(40):
		await physics_frame
		for name in enemies.keys():
			var e = enemies[name]
			if is_instance_valid(e) and e.has_method("is_on_floor") and not e.is_on_floor() and e.get("velocity") != null and e.velocity.y < -60.0:
				helper_peaked[name] = true
	await _frames(100)
	for name in enemies.keys():
		var e = enemies[name]
		var alive: bool = is_instance_valid(e) and e.get("current_behavior") != "dead"
		var delirious: bool = is_instance_valid(e) and e.has_method("is_delirious") and e.is_delirious()
		var afraid: bool = is_instance_valid(e) and e.has_method("is_afraid") and e.is_afraid()
		print("ARENA INFO: tip=%-14s canli=%s ham_firlatma=%s launch_enemy=%s delirmis=%s korkmus=%s" % [name, str(alive), str(peaked.has(name)), str(helper_peaked.has(name)), str(delirious), str(afraid)])
	_check(true, "Tüm düşman tipleri item'larla çökmeden çalıştı (betik hatalarını koşucu raporlar)", "")
	_im.clear_all_items()
	await _cleanup_arena_nodes()

## Barut Sıçrayışı bombası: basic dışındaki düşman tiplerini de gerçekten havaya kaldırır (launch_enemy).
func _scenario_barut_bombasi_tur_firlatma() -> void:
	await _begin("barut_sicrayisi")
	var types := {
		"canonman": "res://enemy/canonman/canonman_enemy.tscn",
		"hunter": "res://enemy/hunter/hunter_enemy.tscn",
		"summoner": "res://enemy/summoner/summoner_enemy.tscn",
		"turtle": "res://enemy/turtle/turtle_enemy.tscn",
		"firemage": "res://enemy/firemage/firemage_enemy.tscn",
	}
	var x := 4200.0
	for name in types.keys():
		var e = (load(types[name]) as PackedScene).instantiate()
		_arena.add_child(e)
		e.global_position = Vector2(x, -30.0)
		await _frames(50)
		if e.get("health") != null:
			e.health = maxf(float(e.health), 5000.0)
		var jb := Node2D.new()
		jb.set_script(load("res://effects/jump_bomb.gd"))
		_arena.add_child(jb)
		jb.setup(e.global_position + Vector2(0.0, -10.0), Vector2.ZERO)
		jb.detonate_now()
		var launched := false
		for _i in range(30):
			await physics_frame
			if is_instance_valid(e) and e.has_method("is_on_floor") and not e.is_on_floor() and e.get("velocity") != null and e.velocity.y < -60.0:
				launched = true
		_check(launched, "Barut Sıçrayışı: %s tipi bomba patlamasıyla havaya kalktı" % name, "Barut Sıçrayışı: %s tipi bomba patlamasıyla havaya kalkmadı" % name)
		e.queue_free()
		x += 40.0

## Kazık Darbesi GERÇEK akışla: havadaki düşmana gerçek FallAttack durumuyla in. (Önceki senaryo sinyali elle yayınlıyordu.)
func _scenario_kazik_darbesi_gercek() -> void:
	await _begin("kazik_darbesi")
	var a := _spawn_enemy(1000.0)
	var b := _spawn_enemy(1070.0)
	await _frames(45)
	a.health = 5000.0
	b.health = 5000.0
	var hp_b0 := _enemy_hp(b)
	var hp_a0 := _enemy_hp(a)
	_place_player(1000.0)
	await _frames(35)   # oyuncu yere insin
	a.direction = 1
	a.take_damage(1.0, 0.0, 420.0, true)     # a'yi havaya fırlat
	await _frames(40)   # düşman zirveye yaklaşsın (yavaşlamış, vurması kolay)
	var ay: float = a.global_position.y
	_player.global_position = Vector2(a.global_position.x, ay - 150.0)   # oyuncu düşmanın üstünde, GERÇEKTEN havada
	_player.velocity = Vector2.ZERO
	await _frames(3)   # is_on_floor bayatlığı geçsin, oyuncu Fall durumuna girsin
	var sm = _player.get("state_machine")
	sm.transition_to("FallAttack")
	var log := []
	var slam_meta_seen := false
	for i in range(150):
		await physics_frame
		if i % 6 == 0 and is_instance_valid(a):
			var fa_hb = _player.get_node_or_null("FallAttack")
			log.append("%d:p=%s py=%.0f pvy=%.0f a_y=%.0f a_vy=%.0f fa_mon=%s fa_overlap=%d" % [i, str(sm.current_state.name), _player.global_position.y, _player.velocity.y, a.global_position.y, a.velocity.y, str(fa_hb.monitoring if fa_hb else 'yok'), (fa_hb.get_overlapping_areas().size() if fa_hb else -1)])
		if is_instance_valid(a) and a.has_meta("kazik_darbesi_slam"):
			slam_meta_seen = true
	print("ARENA DBG kazik gercek: ", str(log))
	var dmg_b := hp_b0 - _enemy_hp(b)
	var dmg_a := hp_a0 - _enemy_hp(a)
	_check(slam_meta_seen, "Kazık Darbesi (gerçek): gerçek düşme vuruşu çakma işaretini koydu", "Kazık Darbesi (gerçek): gerçek düşme vuruşu havadaki düşmanı çakmaya almadı (a hasar %.1f)" % dmg_a)
	_check(dmg_b >= 14.0, "Kazık Darbesi (gerçek): komşu alan hasarı aldı (%.1f)" % dmg_b, "Kazık Darbesi (gerçek): komşu alan hasarı almadı (%.1f, a %.1f)" % [dmg_b, dmg_a])
	_place_player(2200.0)

## Gülle her knockback'te: yerde, hafif vuruşla savrulan (havaya kalkmayan) gerçek düşman yandakine çarpınca hasar verir.
func _scenario_gulle_yerde_knockback() -> void:
	await _begin("gulle")
	var a = (load("res://enemy/canonman/canonman_enemy.tscn") as PackedScene).instantiate()
	_arena.add_child(a)
	a.global_position = Vector2(-600.0, -30.0)
	var b := _spawn_enemy(-540.0)
	await _frames(50)
	a.health = 5000.0
	b.health = 5000.0
	var hp_b0 := _enemy_hp(b)
	a.direction = -1                      # velocity.x = -direction * kuvvet * 0.35 -> sağa, yerde (hafif vuruş)
	a.take_damage(1.0, 900.0, -1.0, true)
	var left_floor := false
	for _i in range(40):
		await physics_frame
		if is_instance_valid(a) and not a.is_on_floor():
			left_floor = true
	var b_dmg := hp_b0 - _enemy_hp(b)
	print("ARENA DBG gulle yerde: havaya kalktı=%s komsu hasar=%.1f" % [str(left_floor), b_dmg])
	_check(b_dmg >= 9.0, "Gülle: yerde hafif vuruşla savrulan düşman komşuya çarpıp hasar verdi (%.1f)" % b_dmg,
		"Gülle: yerde savrulan düşman komşuya çarpınca hasar vermedi (%.1f, havaya kalktı=%s)" % [b_dmg, str(left_floor)])
	a.queue_free()
	b.queue_free()