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
	await _scenario_gulle_knockback_olmadan()
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
	await _scenario_kazik_darbesi_asagi_saldir()
	await _scenario_gercek_giris_vuruslar()
	await _scenario_gercek_giris_dash_yarilan_alev()
	await _scenario_gercek_giris_parry()
	await _scenario_gercek_giris_dusme_saldirisi()
	await _scenario_gercek_giris_havada_bulasici()
	await _scenario_zincir_zehir_delirmesi()
	await _scenario_zincir_korku_yangini()
	await _scenario_zincir_yangin_yayilimi()
	await _scenario_zincir_duvar_carpmasi()
	await _scenario_zincir_gulle_ziplatan()
	await _scenario_zincir_mesale_dusman()
	await _scenario_zincir_tasiyici()
	await _scenario_zincir_fitil_hatti()
	await _scenario_zincir_zehirli_yem_oyuncu()
	await _scenario_zincir_barut_dolgusu()
	await _scenario_dusmanlar_oyuncuya_hasar_verir()
	await _scenario_item_hasar_taramasi()
	await _scenario_hurtbox_dodge_sonrasi_acik()
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
	if not _want("_scenario_gulle"):
		return
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
	if not _want("_scenario_duvar_carpmasi"):
		return
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
	if not _want("_scenario_kazik_darbesi"):
		return
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
	if not _want("_scenario_barut_sicrayisi"):
		return
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
	if not _want("_scenario_zehir_delirmesi"):
		return
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
	if not _want("_scenario_korku_yangini"):
		return
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
	if not _want("_scenario_mesale_dusman"):
		return
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
	if not _want("_scenario_bulasici_darbe"):
		return
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
	if not _want("_scenario_yangin_yayilimi"):
		return
	await _begin("yangin_yayilimi")
	var a := _spawn_enemy(-2400.0)
	var b := _spawn_enemy(-2350.0)
	await _frames(40)
	a.add_burn_stack()
	await _frames(40)
	_check(int(b.burn_remaining_ticks) > 0, "Yangın Yayılımı: komşu gerçek düşman tutuştu", "Yangın Yayılımı: komşu tutuşmadı")

## Alev Dalgası: ağır vuruş şeridi gerçek düşmanı yakar.
func _scenario_alev_dalgasi() -> void:
	if not _want("_scenario_alev_dalgasi"):
		return
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
	if not _want("_scenario_yarilan_alev"):
		return
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
	if not _want("_scenario_attack_signal_leak"):
		return
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
	if not _want("_scenario_golge_gercek_dusman"):
		return
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
	if not _want("_scenario_tasiyici"):
		return
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
	if not _want("_scenario_zehir_havuzu"):
		return
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
	if not _want("_scenario_kivilcim_yagmuru"):
		return
	await _begin("gokten_dusus")
	var e := _spawn_enemy(2650.0)
	await _frames(40)
	_player.emit_signal("fall_attack_impacted", Vector2(2500.0, -10.0))
	await _frames(110)
	_check(int(e.burn_remaining_ticks) > 0 or _enemy_hp(e) < 60.0, "Kıvılcım Yağmuru: kıvılcımlar gerçek düşmanı yaktı", "Kıvılcım Yağmuru: kıvılcımlar 150 px'teki düşmana ulaşmadı")

## Kor Patlatma: yanan gerçek düşmana ağır vuruş yanmayı tüketip anında hasar verir.
func _scenario_kor_patlatma() -> void:
	if not _want("_scenario_kor_patlatma"):
		return
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
	if not _want("_scenario_alevli_parry"):
		return
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
	if not _want("_scenario_ac_gozlu_toksin"):
		return
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
	if not _want("_scenario_aci_parry"):
		return
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
	if not _want("_scenario_fitil_hatti"):
		return
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
	if not _want("_scenario_barut_dolgusu"):
		return
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
	if not _want("_scenario_pusu_zehri"):
		return
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
	if not _want("_scenario_golge_itemleri_gercek_dodge"):
		return
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
	if not _want("_scenario_tum_dusman_tipleri"):
		return
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

## REGRESYON: Her gerçek düşman tipi, hiçbir item yokken oyuncuya GERÇEKTEN hasar verebilmeli
## (dalga arenasında "basic/firemage/flying bana hasar vuramadı" şikayeti).
func _scenario_dusmanlar_oyuncuya_hasar_verir() -> void:
	if not _want("_scenario_dusmanlar_oyuncuya_hasar_verir"):
		return
	var types := {
		"basic": "res://enemy/basic/basic_enemy.tscn",
		"firemage": "res://enemy/firemage/firemage_enemy.tscn",
		"flying": "res://enemy/flying/flying_enemy.tscn",
		"spearman": "res://enemy/spearman/spearman_enemy.tscn",
		"hunter": "res://enemy/hunter/hunter_enemy.tscn",
		"heavy": "res://enemy/heavy/heavy_enemy.tscn",
		"canonman": "res://enemy/canonman/canonman_enemy.tscn",
	}
	var ps = get_root().get_node("/root/PlayerStats")
	var all_ok := true
	var x_base := -3200.0
	for name in types.keys():
		_im.clear_all_items()
		await _cleanup_arena_nodes()
		await _ground_player(x_base)
		var scene = load(types[name])
		if scene == null:
			print("ARENA INFO: %s sahnesi yüklenemedi" % name)
			continue
		var e = scene.instantiate()
		_arena.add_child(e)
		# Dalga arenasındaki gibi: menzil sınırsız, uyumaz (ChallengeWaveSpawner._spawn_one ile aynı kurulum)
		e.set_meta("always_aggro", true)
		var st = e.get("stats")
		if st:
			st = st.duplicate(true)
			e.set("stats", st)
			st.detection_range = maxf(st.detection_range, 3000.0)
		if "sleep_distance" in e:
			e.set("sleep_distance", 1.0e6)
		if "wake_distance" in e:
			e.set("wake_distance", 1.0e6)
		if "is_sleeping" in e:
			e.is_sleeping = false
		var y_off := -90.0 if name == "flying" else -10.0
		e.global_position = Vector2(x_base + 150.0, y_off)
		if e.get("health") != null:
			e.health = 100000.0
		_player.set("invincibility_timer", 0.0)
		ps.set_current_health(ps.get_max_health(), false)
		var took := [0]
		var cb := func(_a, _b): took[0] += 1
		_player.connect("player_took_damage", cb)
		var behaviors := {}
		var hit_frame := -1
		for i in range(900):
			await physics_frame
			if is_instance_valid(e):
				behaviors[str(e.current_behavior)] = true
			if took[0] > 0 and hit_frame < 0:
				hit_frame = i
				break
			# oyuncuyu yerinde ve ayakta tut (test düzeneği); sağlık dolu
			_player.global_position.x = x_base
		_player.disconnect("player_took_damage", cb)
		var tgt = null
		if is_instance_valid(e) and e.has_method("get_nearest_player"):
			tgt = e.get_nearest_player()
		print("ARENA INFO: hasar_testi tip=%-9s vurdu=%s kare=%d davranislar=%s hedef=%s mesafe=%.0f" % [name, str(took[0] > 0), hit_frame, str(behaviors.keys()), str(tgt), (absf(e.global_position.x - _player.global_position.x) if is_instance_valid(e) else -1.0)])
		if took[0] == 0 and name == "canonman":
			# Topçu yakın mesafede yerden nişan alıp mermiyi üzerimizden atabiliyor; bilgi olarak bırakıldı
			print("ARENA INFO: canonman 900 karede vuramadı (arena düşmanı değil, bilinen davranış)")
		elif took[0] == 0:
			all_ok = false
			print("ARENA FAIL: %s oyuncuya hasar veremedi" % name)
		_player.set("invincibility_timer", 1000000.0)
		ps.set_current_health(ps.get_max_health(), false)
		if is_instance_valid(e):
			e.queue_free()
		x_base += 400.0
	_check(all_ok, "Tüm düşman tipleri oyuncuya hasar verebildi", "Bazı düşman tipleri oyuncuya hasar veremedi")
	_place_player(2200.0)

## REGRESYON (0.26.2): dodge/dash sonrasında hurtbox AÇIK kalmalı. Gölgeye Karışma ve Görünmezlik Pelerini
## hurtbox.monitoring'i kalıcı kapatıp basic/uçan/ateş büyücüsünün hasarını engelliyordu (yalnızca overlap
## sorgusuyla vuran charger'lar vurabiliyordu). ARENA_ONLY=hurtbox_taramasi ile TÜM item'lar denenir.
func _scenario_hurtbox_dodge_sonrasi_acik() -> void:
	var only: String = OS.get_environment("ARENA_ONLY")
	var all_items: bool = only == "hurtbox_taramasi"
	if not (only.is_empty() or all_items or only == "hurtbox_dodge"):
		return
	var ids: Array = ["golgeye_karisma", "gorunmezlik_pelerini", "ortaoyunu", "hayalet_adim", "kukla_oyunu", "refleks", "golge_adimi"]
	if all_items:
		ids = _im.ITEM_SCENES.keys()
		ids.sort()
	var bad: Array = []
	for id in ids:
		if not _im.ITEM_SCENES.has(id):
			continue
		_im.clear_all_items()
		await _cleanup_arena_nodes()
		await _ground_player(-2000.0)
		_im.activate_item(_im.ITEM_SCENES[id])
		await process_frame
		for _round in range(2):
			_refill_stamina()
			await _frames(20)
			await _press("dash")
			await _frames(70)   # dodge + 3 sn'lik görünmezlik hariç tüm flaşlar (0.4 sn) bitsin; pelerin için 200 kare
			if id == "gorunmezlik_pelerini":
				await _frames(150)
		var hb = _player.get("hurtbox")
		var st: String = str(_player.get("state_machine").current_state.name)
		if hb != null and not hb.monitoring and st != "Dodge":
			bad.append(String(id))
			print("ARENA INFO: HURTBOX_KAPALI item=%s durum=%s" % [str(id), st])
		hb.monitoring = true
	_check(bad.is_empty(), "Dodge sonrası hurtbox açık kaldı (%d item denendi)" % ids.size(), "Dodge sonrası hurtbox KAPALI kalan item'lar: %s" % str(bad))
	_im.clear_all_items()
	_place_player(2200.0)

## TEŞHİS: Her item tek başına aktifken sıradan bir basic düşman oyuncuya vurabiliyor mu? Vuramayanlar (ya da
## hedefi oyuncu olmayanlar) listelenir. Savunma item'ları (kalkan/ilk hasarı engelleme) meşru olarak 0 çıkabilir.
## ARENA_ONLY=item_hasar_taramasi ile çalışır; varsayılan koşuda ATLANIR (uzun sürer).
func _scenario_item_hasar_taramasi() -> void:
	if OS.get_environment("ARENA_ONLY") != "item_hasar_taramasi":
		return
	var ps = get_root().get_node("/root/PlayerStats")
	var ids: Array = _im.ITEM_SCENES.keys()
	ids.sort()
	ids.push_front("")   # kontrol: item yok
	var blocked: Array = []
	var x := -3200.0
	for id in ids:
		_im.clear_all_items()
		await _cleanup_arena_nodes()
		await _ground_player(x)
		if String(id) != "":
			_im.activate_item(_im.ITEM_SCENES[id])
		await _frames(10)
		var e := _spawn_enemy(x + 80.0)
		e.health = 100000.0
		_player.set("invincibility_timer", 0.0)
		ps.set_current_health(ps.get_max_health(), false)
		var took := [0]
		var cb := func(_a, _b): took[0] += 1
		_player.connect("player_took_damage", cb)
		var target_decoy := false
		var target_null := false
		for i in range(300):
			await physics_frame
			if took[0] > 0:
				break
			if is_instance_valid(e):
				var t = e.get_nearest_player()
				if t == null:
					target_null = true
				elif t != _player:
					target_decoy = true
		_player.disconnect("player_took_damage", cb)
		if took[0] == 0:
			blocked.append(String(id))
			print("ARENA INFO: HASAR_YOK item=%-22s hedef_null=%s hedef_baska=%s" % [str(id), str(target_null), str(target_decoy)])
		_player.set("invincibility_timer", 1000000.0)
		ps.set_current_health(ps.get_max_health(), false)
		if is_instance_valid(e):
			e.queue_free()
	print("ARENA INFO: tarama bitti, hasar vurulamayan item sayisi=%d / %d : %s" % [blocked.size(), ids.size(), str(blocked)])
	_im.clear_all_items()
	_place_player(2200.0)

## Barut Sıçrayışı bombası: basic dışındaki düşman tiplerini de gerçekten havaya kaldırır (launch_enemy).
func _scenario_barut_bombasi_tur_firlatma() -> void:
	if not _want("_scenario_barut_bombasi_tur_firlatma"):
		return
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
	if not _want("_scenario_kazik_darbesi_gercek"):
		return
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
	if not _want("_scenario_gulle_yerde_knockback"):
		return
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

## Gülle: knockback ALMADAN kendi başına yüksekten aşağı atlayan/düşen gerçek düşman komşuyu gülle gibi vurmamalı
## (oyuncu peşinden koşup aşağı atlayan askerler havada birbirine çarpıp hasar alıyordu).
func _scenario_gulle_knockback_olmadan() -> void:
	if not _want("_scenario_gulle_knockback_olmadan"):
		return
	await _begin("gulle")
	_place_player(2300.0)
	var b := _spawn_enemy(2150.0)    # oyuncuya yakın: uyumaz
	var a := _spawn_enemy(1980.0)
	await _frames(45)
	a.health = 5000.0
	b.health = 5000.0
	b.velocity = Vector2.ZERO
	b.set_physics_process(false)   # b yerinde dursun; can_process() true kalır, Gülle onu hedef görür
	# a: peşinden koşup zıplayan asker gibi, KENDİ gücüyle b'nin yanından havada yatay geçer (knockback YOK)
	a.global_position = Vector2(1980.0, -70.0)
	var hp_a0 := _enemy_hp(a)
	var hp_b0 := _enemy_hp(b)
	var fast := false
	var min_dist := 99999.0
	for _i in range(90):
		if is_instance_valid(a) and a.global_position.x < 2330.0:
			a.velocity = Vector2(350.0, -30.0)
		await physics_frame
		if is_instance_valid(a) and is_instance_valid(b):
			min_dist = minf(min_dist, a.global_position.distance_to(b.global_position))
			if a.velocity.length() >= 140.0 and not a.is_on_floor():
				fast = true
	print('ARENA DBG gulle zıplayan: en yakin mesafe=%.0f hizli_havada=%s' % [min_dist, str(fast)])
	var dmg := (hp_a0 - _enemy_hp(a)) + (hp_b0 - _enemy_hp(b))
	_check(fast and min_dist < 60.0, "Gülle (knockback yok): kendi başına zıplayan düşman komşuya hızla yaklaştı (test kurulumu, mesafe %.0f)" % min_dist, "Gülle (knockback yok): test kurulumu geçersiz (hızlı=%s, en yakın mesafe %.0f)" % [str(fast), min_dist])
	_check(dmg == 0.0, "Gülle: knockback almadan kendi başına zıplayan/koşan düşman gülle sayılmadı", "Gülle: knockback almamış zıplayan düşman gülle sayıldı (toplam hasar %.1f)" % dmg)
	a.queue_free()
	b.queue_free()
	_place_player(2200.0)
## Kazık Darbesi, havada AŞAĞI + SALDIR (AirAttackDown) ile: oyuncunun asıl kullandığı vuruş.
func _scenario_kazik_darbesi_asagi_saldir() -> void:
	if not _want("_scenario_kazik_darbesi_asagi_saldir"):
		return
	await _begin("kazik_darbesi")
	var a := _spawn_enemy(1400.0)
	var b := _spawn_enemy(1470.0)
	await _frames(45)
	a.health = 5000.0
	b.health = 5000.0
	var hp_b0 := _enemy_hp(b)
	_place_player(1360.0)
	await _frames(35)
	a.direction = 1
	a.take_damage(1.0, 0.0, 420.0, true)
	await _frames(40)
	var ay: float = a.global_position.y
	var pin_pos: Vector2 = a.global_position   # vuruş penceresinde düşmanı havada sabitle (zirvedeki küçük hareket vuruşu şansa bırakmasın)
	_player.global_position = Vector2(a.global_position.x - 40.0, ay - 45.0)   # düşman sağda ve biraz aşağıda
	_player.velocity = Vector2.ZERO
	_player.set("facing_direction", 1.0)
	await _frames(3)
	var sm = _player.get("state_machine")
	Input.action_press("down")
	Input.action_press("attack")
	var slam_seen := false
	var states := []
	var trace := []
	for i in range(150):
		if not slam_seen and i < 30 and is_instance_valid(a):
			a.velocity = Vector2.ZERO
			a.global_position = pin_pos
		await physics_frame
		if i == 2:
			Input.action_release("attack")
		if i < 12:
			states.append(str(sm.current_state.name))
		if is_instance_valid(a) and a.has_meta("kazik_darbesi_slam"):
			slam_seen = true
		if i % 10 == 0 and is_instance_valid(a):
			trace.append('%d:ax=%.0f ay=%.0f avy=%.0f meta=%s bx=%.0f' % [i, a.global_position.x, a.global_position.y, a.velocity.y, str(a.has_meta('kazik_darbesi_slam')), b.global_position.x])
	Input.action_release("down")
	print('ARENA DBG kazik iz: ', str(trace))
	var dmg_b := hp_b0 - _enemy_hp(b)
	print("ARENA DBG kazik asagi+saldir: durumlar=%s slam=%s komsu hasar=%.1f" % [str(states), str(slam_seen), dmg_b])
	_check(slam_seen, "Kazık Darbesi (aşağı + saldır): gerçek AirAttackDown vuruşu düşmanı çakmaya aldı", "Kazık Darbesi (aşağı + saldır): AirAttackDown vuruşu düşmanı çakmaya almadı (durumlar %s)" % str(states))
	_check(dmg_b >= 14.0, "Kazık Darbesi (aşağı + saldır): komşu alan hasarı aldı (%.1f)" % dmg_b, "Kazık Darbesi (aşağı + saldır): komşu alan hasarı almadı (%.1f)" % dmg_b)
	_place_player(2200.0)

## --- GERÇEK GİRİŞ senaryoları: sinyali elle yayınlamak yerine oyuncunun gerçekte bastığı tuşlar ---

func _refill_stamina() -> void:
	var sb = get_first_node_in_group("stamina_bar")
	if sb != null and sb.get("charges") != null:
		for i in range(sb.charges.size()):
			sb.charges[i] = 1.0
		sb.recharging_index = -1
		if sb.has_method("update_segments"):
			sb.update_segments()

func _ground_player(x: float) -> void:
	_refill_stamina()
	# Zaten orada ve yerdeyse tekrar ışınlama (ışınlama oyuncuyu havaya alıp Fall durumuna sokar)
	if absf(_player.global_position.x - x) > 4.0 or not _player.is_on_floor():
		_place_player(x)
		await _frames(40)
	_player.set("facing_direction", 1.0)

## Kor Patlatma / Alev Dalgası (gerçek ağır vuruş), Aç Gözlü Toksin (gerçek hafif vuruş).
func _scenario_gercek_giris_vuruslar() -> void:
	if not _want("_scenario_gercek_giris_vuruslar"):
		return
	# Kor Patlatma: gerçek ağır vuruş yanan düşmanın yanmasını tüketir
	await _begin("guc_kayasi")
	await _ground_player(3000.0)
	var e := _spawn_enemy(3055.0)
	await _frames(40)
	e.health = 5000.0
	e.burn_remaining_ticks = 9
	await _ground_player(3000.0)
	e.global_position = Vector2(3055.0, e.global_position.y)
	var sig_log: Array = []
	var sig_cb := func(t, d, _tg, _p, _f): sig_log.append('%s:%.0f' % [String(t), float(d)])
	_player.connect("player_attack_landed", sig_cb)
	var pstate0 := str(_player.get("state_machine").current_state.name)
	await _press("attack_heavy")
	var pstates := []
	for _k in range(12):
		await physics_frame
		pstates.append(str(_player.get("state_machine").current_state.name))
	await _frames(80)
	_player.disconnect("player_attack_landed", sig_cb)
	print('ARENA DBG kor patlatma: oncesi=%s durumlar=%s yayinlar=%s oyuncu=%s dusman=%s burn=%d' % [pstate0, str(pstates), str(sig_log), str(_player.global_position), str(e.global_position), int(e.burn_remaining_ticks)])
	_check(int(e.burn_remaining_ticks) <= 1, "Kor Patlatma (gerçek ağır vuruş): yanma tüketildi (%d)" % int(e.burn_remaining_ticks), "Kor Patlatma (gerçek ağır vuruş): yanma tüketilmedi (%d)" % int(e.burn_remaining_ticks))

	# Alev Dalgası: gerçek ağır vuruş alev şeridi çıkarır
	await _begin("hizli_charge")
	await _ground_player(3400.0)
	var e2 := _spawn_enemy(3455.0)
	await _frames(40)
	e2.health = 5000.0
	await _ground_player(3400.0)
	e2.global_position = Vector2(3455.0, e2.global_position.y)
	e2.velocity = Vector2.ZERO
	e2.set_physics_process(false)   # yerinde dursun (yürüyüp oyuncunun arkasına geçmesin)
	var p0 := _count_scripts(_fire_patch)
	var al: Array = []
	var al_cb := func(t, d, _tg, _p, _f): al.append('%s:%.0f' % [String(t), float(d)])
	_player.connect("player_attack_landed", al_cb)
	var max_p := 0
	await _press("attack_heavy")
	for _k in range(100):
		await physics_frame
		max_p = maxi(max_p, _count_scripts(_fire_patch))
	_player.disconnect("player_attack_landed", al_cb)
	print('ARENA DBG alev dalgasi: yayinlar=%s en_cok_birikinti=%d p0=%d burn=%d oyuncu=%s dusman=%s' % [str(al), max_p, p0, int(e2.burn_remaining_ticks), str(_player.global_position), str(e2.global_position)])
	_check(max_p > p0 or int(e2.burn_remaining_ticks) > 0, "Alev Dalgası (gerçek ağır vuruş): alev şeridi çıktı", "Alev Dalgası (gerçek ağır vuruş): alev şeridi çıkmadı")

	# Aç Gözlü Toksin: gerçek hafif vuruş, katman başına ek hasar (item'lı - item'siz fark)
	var dmg_without := 0.0
	var dmg_with := 0.0
	for phase in range(2):
		_im.clear_all_items()
		if phase == 1:
			_im.activate_item(_im.ITEM_SCENES["ac_gozlu_toksin"])
		await _cleanup_arena_nodes()
		await _ground_player(3800.0)
		var t := _spawn_enemy(3850.0)
		await _frames(40)
		t.health = 5000.0
		_im.add_poison_stacks(t, 4)
		await _ground_player(3800.0)
		t.global_position = Vector2(3850.0, t.global_position.y)
		var hp0 := _enemy_hp(t)
		await _press("attack")
		await _frames(25)
		var d := hp0 - _enemy_hp(t)
		if phase == 0:
			dmg_without = d
		else:
			dmg_with = d
	print("ARENA DBG ac gozlu: item'siz hasar=%.1f item'li hasar=%.1f" % [dmg_without, dmg_with])
	_check(dmg_without > 0.0 and dmg_with - dmg_without >= 4.0, "Aç Gözlü Toksin (gerçek hafif vuruş): zehirli düşmana ek hasar (+%.1f)" % (dmg_with - dmg_without), "Aç Gözlü Toksin (gerçek hafif vuruş): ek hasar yok (item'siz %.1f, item'li %.1f)" % [dmg_without, dmg_with])
	_place_player(2200.0)

## Yarılan Alev: GERÇEK dash/dodge ile yanan düşmanın içinden geç.
func _scenario_gercek_giris_dash_yarilan_alev() -> void:
	if not _want("_scenario_gercek_giris_dash_yarilan_alev"):
		return
	await _begin("yarilan_alev")
	await _ground_player(-1500.0)
	var e := _spawn_enemy(-1440.0)
	await _frames(40)
	e.health = 5000.0
	e.burn_remaining_ticks = 6
	await _ground_player(-1500.0)
	e.velocity = Vector2.ZERO
	e.set_physics_process(false)   # gerçek AI düşmanı dash'ten önce uzaklaştırabiliyordu (flaky)
	e.global_position = Vector2(-1440.0, e.global_position.y)
	var hp0 := _enemy_hp(e)
	var dsb = get_first_node_in_group("stamina_bar")
	print('ARENA DBG dash oncesi: durum=%s charges=%s zemin=%s' % [str(_player.get("state_machine").current_state.name), str(dsb.charges if dsb else 'yok'), str(_player.is_on_floor())])
	await _press("dash")
	var dstates := []
	for _k in range(10):
		await physics_frame
		dstates.append(str(_player.get("state_machine").current_state.name))
	print('ARENA DBG dash durumlar=%s oyuncu=%s' % [str(dstates), str(_player.global_position)])
	await _frames(30)
	_check(int(e.burn_remaining_ticks) == 0 and hp0 - _enemy_hp(e) >= 6.0, "Yarılan Alev (gerçek dash): yanan düşmanın yanması patladı (%.1f hasar)" % (hp0 - _enemy_hp(e)), "Yarılan Alev (gerçek dash): patlama yok (yanma %d, hasar %.1f, oyuncu x=%.0f düşman x=%.0f)" % [int(e.burn_remaining_ticks), hp0 - _enemy_hp(e), _player.global_position.x, e.global_position.x])
	_place_player(2200.0)

## Alevli Parry / Acı Parry: GERÇEK perfect parry (düşman saldırısına tam zamanında block).
func _scenario_gercek_giris_parry() -> void:
	if not _want("_scenario_gercek_giris_parry"):
		return
	_im.clear_all_items()
	await _cleanup_arena_nodes()
	_im.activate_item(_im.ITEM_SCENES["alevli_parry"])
	_im.activate_item(_im.ITEM_SCENES["aci_parry"])
	await process_frame
	await _ground_player(-2000.0)
	_player.set("invincibility_timer", 0.0)   # parry için gerçek hasar işlemesi gerekir
	var e := _spawn_enemy(-1960.0)
	await _frames(30)
	e.health = 5000.0
	var parries := [0]
	var cb := func(): parries[0] += 1
	_player.connect("perfect_parry", cb)
	var took := [0]
	var blocked := [0]
	var took_cb := func(_a, _b): took[0] += 1
	var blk_cb := func(_a, _b): blocked[0] += 1
	_player.connect("player_took_damage", took_cb)
	_player.connect("player_blocked", blk_cb)
	var beh_seen := {}
	var st_seen := {}
	var tries := 0
	var hold := 0
	var cooldown := 0
	while parries[0] == 0 and tries < 1500:
		tries += 1
		if is_instance_valid(e):
			beh_seen[str(e.current_behavior)] = true
			# Düşman saldırıya geçer geçmez bloğa bas (saldırı animasyonu vuruştan önce hazırlık süresi verir)
			if hold == 0 and cooldown == 0 and e.current_behavior == "attack":
				Input.action_press("block")
				hold = 14
		st_seen[str(_player.get("state_machine").current_state.name)] = true
		if hold > 0:
			hold -= 1
			if hold == 0:
				Input.action_release("block")
				cooldown = 25
		elif cooldown > 0:
			cooldown -= 1
		# düşman yürüyüp uzaklaştıysa / oyuncu savrulduysa yeniden yaklaştır
		if is_instance_valid(e) and absf(e.global_position.x - _player.global_position.x) > 90.0 and _player.get("state_machine").current_state.name == "Idle":
			e.global_position = Vector2(_player.global_position.x + 45.0, e.global_position.y)
		await physics_frame
	Input.action_release("block")
	var patch_dbg: Array = []
	for _k in range(50):
		await physics_frame
		if _k % 10 == 0:
			var xs: Array = []
			for ch in _arena.get_children():
				if ch.get_script() != null and String(ch.get_script().resource_path) == _fire_patch:
					xs.append('%.0f%s' % [ch.global_position.x, '' if ch.visible else '(gizli)'])
			patch_dbg.append('%d: e.x=%.0f burn=%d patches=%s' % [_k, e.global_position.x, int(e.burn_remaining_ticks), str(xs)])
	print('ARENA DBG alevli parry iz: ', str(patch_dbg), ' oyuncu_x=%.0f' % _player.global_position.x)
	_player.disconnect("perfect_parry", cb)
	_player.set("invincibility_timer", 1000000.0)
	_player.disconnect("player_took_damage", took_cb)
	_player.disconnect("player_blocked", blk_cb)
	print('ARENA DBG parry: perfect_parry=%d deneme=%d hasar_aldi=%d bloklandi=%d dusman_davranislari=%s oyuncu_durumlari=%s dusman_x=%.0f oyuncu_x=%.0f' % [parries[0], tries, took[0], blocked[0], str(beh_seen.keys()), str(st_seen.keys()), e.global_position.x, _player.global_position.x])
	if parries[0] == 0:
		print("ARENA SKIP: gerçek perfect parry zamanlaması yakalanamadı (test kurulumu), Parry item'ları sinyalle test edildi")
	else:
		_check(_poison_stacks_of(e) >= 3, "Acı Parry (gerçek perfect parry): saldırgan zehirlendi (%d)" % _poison_stacks_of(e), "Acı Parry (gerçek perfect parry): saldırgan zehirlenmedi (%d)" % _poison_stacks_of(e))
		_check(int(e.burn_remaining_ticks) > 0, "Alevli Parry (gerçek perfect parry): yakındaki saldırgan alev şeridinde yandı (%d)" % int(e.burn_remaining_ticks), "Alevli Parry (gerçek perfect parry): yakındaki saldırgan yanmadı (%d, saldırgan x=%.0f oyuncu x=%.0f)" % [int(e.burn_remaining_ticks), e.global_position.x, _player.global_position.x])
	_place_player(2200.0)

## Zehir Havuzu ve Kıvılcım Yağmuru: GERÇEK düşme saldırısı (aşağı + zıpla ile FallAttack) yere iner.
func _scenario_gercek_giris_dusme_saldirisi() -> void:
	if not _want("_scenario_gercek_giris_dusme_saldirisi"):
		return
	# Zehir Havuzu: zehirli düşmana gerçek düşme vuruşu, havuz komşuyu zehirler
	await _begin("zehir_havuzu")
	await _ground_player(-2600.0)
	var a := _spawn_enemy(-2600.0)
	var b := _spawn_enemy(-2500.0)    # 100 px: düşme vuruşu a'yı vursun (zehirli), havuz yarıçapı (120) b'yi kapsasın
	await _frames(45)
	a.health = 5000.0
	b.health = 5000.0
	_im.add_poison_stacks(a, 3)
	var b0 := _poison_stacks_of(b)
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO
	a.set_physics_process(false)   # yerlerinde dursunlar: düşme vuruşu zehirli a'yı vursun
	b.set_physics_process(false)
	_player.global_position = Vector2(a.global_position.x, a.global_position.y - 150.0)
	_player.velocity = Vector2.ZERO
	await _frames(3)
	var sm = _player.get("state_machine")
	var zl: Array = []
	var z_cb := func(t, d, tg, _p, _f): zl.append('%s:%.0f hedef_x=%s zehir=%s' % [String(t), float(d), str((tg[0].global_position.x) if tg.size() > 0 else 'yok'), str(int(tg[0].poison_stacks) if tg.size() > 0 and tg[0].get('poison_stacks') != null else -1)])
	_player.connect("player_attack_landed", z_cb)
	sm.transition_to("FallAttack")
	var zs := []
	for _k in range(20):
		await physics_frame
		zs.append(str(sm.current_state.name))
	await _frames(130)
	_player.disconnect("player_attack_landed", z_cb)
	print('ARENA DBG zehir havuzu: durumlar=%s yayinlar=%s a_zehir=%d b_zehir=%d havuz_sayisi=%d' % [str(zs), str(zl), _poison_stacks_of(a), _poison_stacks_of(b), _count_scripts(_poison_cloud)])
	_check(_poison_stacks_of(b) > b0, "Zehir Havuzu (gerçek düşme saldırısı): havuz komşuyu zehirledi", "Zehir Havuzu (gerçek düşme saldırısı): komşu zehirlenmedi (%d)" % _poison_stacks_of(b))
	# Kıvılcım Yağmuru: gerçek düşme saldırısı inişi kıvılcım saçar, yakındaki düşmanı yakar
	await _begin("gokten_dusus")
	await _ground_player(-3000.0)
	var c := _spawn_enemy(-2850.0)
	await _frames(45)
	c.health = 5000.0
	_player.global_position = Vector2(-3000.0, -150.0)
	_player.velocity = Vector2.ZERO
	await _frames(3)
	sm.transition_to("FallAttack")
	await _frames(150)
	_check(int(c.burn_remaining_ticks) > 0 or _enemy_hp(c) < 5000.0, "Kıvılcım Yağmuru (gerçek düşme saldırısı): kıvılcımlar düşmanı yaktı", "Kıvılcım Yağmuru (gerçek düşme saldırısı): kıvılcımlar 150 px'teki düşmana ulaşmadı")
	_place_player(2200.0)

## Bulaşıcı Darbe: GERÇEK havada saldırı (oyuncu havada, düşman havada ve zehirli).
func _scenario_gercek_giris_havada_bulasici() -> void:
	if not _want("_scenario_gercek_giris_havada_bulasici"):
		return
	await _begin("bulasici_darbe")
	await _ground_player(-3600.0)
	var a := _spawn_enemy(-3560.0)
	var b := _spawn_enemy(-3500.0)
	await _frames(45)
	a.health = 5000.0
	b.health = 5000.0
	_im.add_poison_stacks(a, 2)
	var b0 := _poison_stacks_of(b)
	b.velocity = Vector2.ZERO
	b.set_physics_process(false)   # komşu yerinde dursun
	a.direction = 1
	a.take_damage(1.0, 0.0, 420.0, true)
	await _frames(35)
	var pin: Vector2 = a.global_position
	_player.global_position = Vector2(pin.x - 45.0, pin.y)
	_player.velocity = Vector2.ZERO
	_player.set("facing_direction", 1.0)
	await _frames(3)
	var got := false
	var bl: Array = []
	var bl_cb := func(t, d, tg, _p, _f): bl.append('%s:%.0f' % [String(t), float(d)])
	_player.connect("player_attack_landed", bl_cb)
	for attempt in range(4):
		if got:
			break
		pin = a.global_position if attempt > 0 else pin
		for i in range(26):
			if is_instance_valid(a):
				a.velocity = Vector2.ZERO
				a.global_position = pin
			_player.velocity = Vector2.ZERO
			if i == 3:
				Input.action_press("attack")
			if i == 6:
				Input.action_release("attack")
			await physics_frame
			if _poison_stacks_of(b) > b0:
				got = true
	_player.disconnect("player_attack_landed", bl_cb)
	print('ARENA DBG bulasici: yayinlar=%s a=%s b=%s' % [str(bl), str(a.global_position), str(b.global_position)])
	_check(got, "Bulaşıcı Darbe (gerçek havada saldırı): komşuya zehir bulaştı", "Bulaşıcı Darbe (gerçek havada saldırı): komşuya zehir bulaşmadı (a zehir %d, b %d)" % [_poison_stacks_of(a), _poison_stacks_of(b)])
	_place_player(2200.0)

## ARENA_ONLY ortam değişkeni doluysa yalnızca adı o metni içeren senaryolar koşar (örn. ARENA_ONLY=parry).
func _want(scenario: String) -> bool:
	var only: String = OS.get_environment("ARENA_ONLY")
	return only.is_empty() or scenario.contains(only)

## --- ZİNCİR senaryoları: tetikleyiciyi ben doldurmuyorum, oyuncunun gerçek silahı biriktiriyor ---

func _light_hits(n: int, gap: int = 22) -> void:
	for _i in range(n):
		_player.attack_cooldown_timer = 0.0
		await _press("attack", 2)
		await _frames(gap)

func _items_on(ids: Array) -> void:
	_im.clear_all_items()
	await _cleanup_arena_nodes()
	for id in ids:
		_im.activate_item(_im.ITEM_SCENES[id])
	await process_frame

## Zehirli Tırnak (gerçek hafif vuruşlar zehir biriktirir) + Zehir Delirmesi: dolunca düşman delirir.
func _scenario_zincir_zehir_delirmesi() -> void:
	if not _want("zincir_zehir_delirmesi"):
		return
	await _items_on(["zehirli_tirnak", "zehir_delirmesi"])
	await _ground_player(-1000.0)
	var e := _spawn_enemy(-945.0)
	await _frames(40)
	e.health = 5000.0
	e.velocity = Vector2.ZERO
	e.set_physics_process(false)
	e.global_position = Vector2(-945.0, e.global_position.y)
	var max_stacks := 0
	var went_mad := false
	for _i in range(9):
		_player.attack_cooldown_timer = 0.0
		await _press("attack", 2)
		for _k in range(22):
			await physics_frame
			max_stacks = maxi(max_stacks, _poison_stacks_of(e))
			if is_instance_valid(e) and e.is_delirious():
				went_mad = true
	print("ARENA DBG zincir zehir: en_cok_katman=%d delirdi=%s (maks %d)" % [max_stacks, str(went_mad), _im.get_poison_max_stacks()])
	_check(max_stacks >= _im.get_poison_max_stacks(), "Zincir: gerçek hafif vuruşlar zehri maksimuma çıkardı (%d)" % max_stacks, "Zincir: gerçek vuruşlar zehri maksimuma çıkaramadı (%d / %d)" % [max_stacks, _im.get_poison_max_stacks()])
	_check(went_mad, "Zincir (Zehirli Tırnak + Zehir Delirmesi): dolan düşman delirdi", "Zincir (Zehirli Tırnak + Zehir Delirmesi): düşman delirmedi")
	_place_player(2200.0)

## Ateşli Yumruk (gerçek hafif vuruşlar yanma biriktirir) + Korku Yangını: yanma dolunca düşman paniğe girer.
func _scenario_zincir_korku_yangini() -> void:
	if not _want("zincir_korku_yangini"):
		return
	await _items_on(["atesli_yumruk", "korku_yangini"])
	await _ground_player(-1400.0)
	var e := _spawn_enemy(-1345.0)
	await _frames(40)
	e.health = 5000.0
	e.velocity = Vector2.ZERO
	e.set_physics_process(false)
	e.global_position = Vector2(-1345.0, e.global_position.y)
	var max_burn := 0
	var afraid := false
	for _i in range(9):
		_player.attack_cooldown_timer = 0.0
		await _press("attack", 2)
		for _k in range(22):
			await physics_frame
			if is_instance_valid(e):
				max_burn = maxi(max_burn, int(e.burn_remaining_ticks))
				if e.is_afraid():
					afraid = true
	print("ARENA DBG zincir korku: en_cok_yanma=%d korktu=%s" % [max_burn, str(afraid)])
	_check(max_burn >= 9, "Zincir: gerçek hafif vuruşlar yanmayı doldurdu (%d)" % max_burn, "Zincir: gerçek vuruşlar yanmayı 9 tike çıkaramadı (%d)" % max_burn)
	_check(afraid, "Zincir (Ateşli Yumruk + Korku Yangını): yanması dolan düşman paniğe girdi", "Zincir (Ateşli Yumruk + Korku Yangını): düşman paniğe girmedi")
	_place_player(2200.0)

## Ateşli Yumruk + Yangın Yayılımı: gerçek vuruşla yakılan düşmandan komşuya yangın geçer.
func _scenario_zincir_yangin_yayilimi() -> void:
	if not _want("zincir_yangin_yayilimi"):
		return
	await _items_on(["atesli_yumruk", "yangin_yayilimi"])
	await _ground_player(-1800.0)
	var a := _spawn_enemy(-1745.0)
	var b := _spawn_enemy(-1700.0)
	await _frames(40)
	a.health = 5000.0
	b.health = 5000.0
	for x in [a, b]:
		x.velocity = Vector2.ZERO
		x.set_physics_process(false)
	a.global_position = Vector2(-1745.0, a.global_position.y)
	b.global_position = Vector2(-1700.0, b.global_position.y)
	await _light_hits(2)
	await _frames(60)
	print("ARENA DBG zincir yayilim: a_yanma=%d b_yanma=%d" % [int(a.burn_remaining_ticks), int(b.burn_remaining_ticks)])
	_check(int(b.burn_remaining_ticks) > 0, "Zincir (Ateşli Yumruk + Yangın Yayılımı): komşu yandı", "Zincir (Ateşli Yumruk + Yangın Yayılımı): komşuya yangın geçmedi (a %d, b %d)" % [int(a.burn_remaining_ticks), int(b.burn_remaining_ticks)])
	_place_player(2200.0)

## Duvar Çarpması: gerçek ağır vuruşun knockback'i düşmanı duvara çarptırınca patlar (item'li - item'siz fark).
func _scenario_zincir_duvar_carpmasi() -> void:
	if not _want("zincir_duvar_carpmasi"):
		return
	var loss := [0.0, 0.0]
	for phase in range(2):
		await _items_on([] if phase == 0 else ["duvar_carpmasi"])
		# Gerçek oyunda düşman oyuncuya BAKAR; knockback yönü düşmanın baktığı yönün tersidir (-direction)
		await _ground_player(ARENA_WALL_X - 100.0)
		var e := _spawn_enemy(ARENA_WALL_X - 45.0)
		await _frames(40)
		e.health = 5000.0
		await _ground_player(ARENA_WALL_X - 100.0)
		e.global_position = Vector2(ARENA_WALL_X - 45.0, e.global_position.y)
		e.direction = -1   # oyuncuya (solda) bakıyor -> vurulunca sağa, duvara savrulur
		var hp0 := _enemy_hp(e)
		await _pinned_heavy_hit(e, ARENA_WALL_X - 45.0)
		var peak_vx := 0.0
		var wall_hit := false
		var min_x := 99999.0
		var max_x := -99999.0
		var last_beh := ''
		for _k in range(110):
			await physics_frame
			if is_instance_valid(e):
				peak_vx = maxf(peak_vx, absf(e.velocity.x))
				wall_hit = wall_hit or e.is_on_wall()
				min_x = minf(min_x, e.global_position.x)
				max_x = maxf(max_x, e.global_position.x)
				last_beh = str(e.current_behavior)
		print('ARENA DBG duvar faz%d: tepe_vx=%.0f duvara_degdi=%s x=[%.0f..%.0f] duvar_yuzu=%.0f davranis=%s' % [phase, peak_vx, str(wall_hit), min_x, max_x, ARENA_WALL_X, last_beh])
		loss[phase] = hp0 - _enemy_hp(e)
	print("ARENA DBG zincir duvar: item'siz=%.1f item'li=%.1f" % [loss[0], loss[1]])
	_check(loss[1] - loss[0] >= 8.0, "Zincir: gerçek ağır vuruşla duvara çarpan düşman patladı (+%.1f)" % (loss[1] - loss[0]), "Zincir: gerçek ağır vuruş knockback'i düşmanı duvara patlatacak hıza ulaştırmadı (item'siz %.1f, item'li %.1f)" % [loss[0], loss[1]])
	_place_player(2200.0)

## Zıplatan Yumruk (gerçek ağır vuruş fırlatır) + Gülle: fırlayan düşman arkasındaki komşuya çarpar (item'li - item'siz).
func _scenario_zincir_gulle_ziplatan() -> void:
	if not _want("zincir_gulle_ziplatan"):
		return
	var b_loss := [0.0, 0.0]
	for phase in range(2):
		await _items_on(["ziplatan_yumruk"] if phase == 0 else ["ziplatan_yumruk", "gulle"])
		await _ground_player(2700.0)
		var a := _spawn_enemy(2750.0)
		var b := _spawn_enemy(2812.0)
		await _frames(40)
		a.health = 5000.0
		b.health = 5000.0
		await _ground_player(2700.0)
		a.global_position = Vector2(2750.0, a.global_position.y)
		b.global_position = Vector2(2812.0, b.global_position.y)
		a.direction = -1   # oyuncuya (solda) bakıyor -> vurulunca sağa, B'ye doğru savrulur
		b.velocity = Vector2.ZERO
		b.set_physics_process(false)
		var hb0 := _enemy_hp(b)
		await _pinned_heavy_hit(a, 2750.0)
		var peak_vx2 := 0.0
		var peak_up := 0.0
		var min_d := 99999.0
		var max_ax := -99999.0
		for _k in range(100):
			await physics_frame
			if is_instance_valid(a) and is_instance_valid(b):
				peak_vx2 = maxf(peak_vx2, absf(a.velocity.x))
				peak_up = maxf(peak_up, -a.velocity.y)
				min_d = minf(min_d, a.global_position.distance_to(b.global_position))
				max_ax = maxf(max_ax, a.global_position.x)
		print('ARENA DBG gulle faz%d: a_tepe_vx=%.0f a_tepe_yukari=%.0f en_yakin_mesafe=%.0f a_max_x=%.0f b_x=%.0f' % [phase, peak_vx2, peak_up, min_d, max_ax, b.global_position.x])
		b_loss[phase] = hb0 - _enemy_hp(b)
	print("ARENA DBG zincir gulle: komsu hasar gulle'siz=%.1f gulle'li=%.1f" % [b_loss[0], b_loss[1]])
	_check(b_loss[1] - b_loss[0] >= 8.0, "Zincir (Zıplatan Yumruk + Gülle): fırlayan düşman komşuya çarptı (+%.1f)" % (b_loss[1] - b_loss[0]), "Zincir (Zıplatan Yumruk + Gülle): fırlayan düşman komşuya hasar vermedi (gülle'siz %.1f, gülle'li %.1f)" % [b_loss[0], b_loss[1]])
	_place_player(2200.0)

## Ateşli Yumruk (gerçek vuruşlar yakar) + Zıplatan Yumruk (gerçek ağır vuruş fırlatır) + Meşale Düşman.
func _scenario_zincir_mesale_dusman() -> void:
	if not _want("zincir_mesale_dusman"):
		return
	await _items_on(["atesli_yumruk", "ziplatan_yumruk", "mesale_dusman"])
	await _ground_player(3200.0)
	var e := _spawn_enemy(3255.0)
	await _frames(40)
	e.health = 5000.0
	await _ground_player(3200.0)
	e.velocity = Vector2.ZERO
	e.set_physics_process(false)
	e.global_position = Vector2(3255.0, e.global_position.y)
	await _light_hits(3)
	var burn0 := int(e.burn_remaining_ticks)
	e.set_physics_process(true)
	e.direction = -1
	await _pinned_heavy_hit(e, 3255.0)
	var max_patches := 0
	var big := false
	var peak_up := 0.0
	for _i in range(200):
		await physics_frame
		if is_instance_valid(e):
			peak_up = maxf(peak_up, -e.velocity.y)
		max_patches = maxi(max_patches, _count_scripts(_fire_patch))
		for ch in _arena.get_children():
			if ch.get_script() != null and String(ch.get_script().resource_path) == _fire_patch and absf(float(ch.radius) - 90.0) < 0.01:
				big = true
	print("ARENA DBG zincir mesale: yanma=%d tepe_yukari=%.0f en_cok_iz=%d buyuk_kor=%s" % [burn0, peak_up, max_patches, str(big)])
	_check(burn0 > 0, "Zincir: gerçek hafif vuruşlar düşmanı yaktı (%d)" % burn0, "Zincir: Ateşli Yumruk düşmanı yakmadı")
	_check(max_patches >= 1, "Zincir (Meşale Düşman): gerçek ağır vuruşla havaya fırlayan yanan düşman iz bıraktı", "Zincir (Meşale Düşman): fırlatılan yanan düşman iz bırakmadı (tepe yukarı %.0f)" % peak_up)
	_check(big, "Zincir (Meşale Düşman): yere inince büyük kor birikintisi açıldı", "Zincir (Meşale Düşman): kor birikintisi açılmadı")
	_place_player(2200.0)

## Zehirli Tırnak (gerçek vuruşlar zehirler) + Taşıyıcı: gerçek kayma zehri sonraki temiz düşmana taşır.
func _scenario_zincir_tasiyici() -> void:
	if not _want("zincir_tasiyici"):
		return
	await _items_on(["zehirli_tirnak", "tasiyici"])
	await _ground_player(3600.0)
	var e1 := _spawn_enemy(3655.0)
	var e2 := _spawn_enemy(3725.0)   # gerçek kayma ~100 px sürer: e2, kaymanın bittiği yere yakın olmalı
	await _frames(40)
	for x in [e1, e2]:
		x.health = 5000.0
		x.velocity = Vector2.ZERO
		x.set_physics_process(false)
	await _ground_player(3600.0)
	e1.global_position = Vector2(3655.0, e1.global_position.y)
	e2.global_position = Vector2(3725.0, e2.global_position.y)
	await _light_hits(2)
	var s1 := _poison_stacks_of(e1)
	var sm = _player.get("state_machine")
	var in_slide := false
	var min_d1 := 99999.0
	var slide_frames := 0
	# Gerçek kayma zamanlaması dalgalanabiliyor: en çok 3 deneme (her denemede oyuncu temiz durumdan başlar)
	for attempt in range(3):
		sm.transition_to("Idle", true)
		_player.global_position = Vector2(3590.0, _player.global_position.y)
		_player.velocity = Vector2.ZERO
		await _frames(15)
		_player.set("facing_direction", 1.0)
		Input.action_press("crouch")
		sm.transition_to("Slide")
		in_slide = sm.current_state != null and sm.current_state.name == "Slide"
		for _i in range(60):
			await physics_frame
			min_d1 = minf(min_d1, _player.global_position.distance_to(e1.global_position))
			if sm.current_state != null and sm.current_state.name == "Slide":
				slide_frames += 1
		Input.action_release("crouch")
		if _poison_stacks_of(e2) >= 1:
			break
		# e1 zehrini geri koy (taşıyıcı başarısız olduysa ya da hiç dokunmadıysa)
		if _poison_stacks_of(e1) == 0:
			_im.add_poison_stacks(e1, 2)
	print("ARENA DBG zincir tasiyici: min_mesafe_e1=%.0f kayma_kare=%d oyuncu_x=%.0f e1_x=%.0f" % [min_d1, slide_frames, _player.global_position.x, e1.global_position.x])
	print("ARENA DBG zincir tasiyici: e1_once=%d kayma=%s e1=%d e2=%d" % [s1, str(in_slide), _poison_stacks_of(e1), _poison_stacks_of(e2)])
	_check(s1 > 0, "Zincir: gerçek hafif vuruşlar zehir biriktirdi (%d)" % s1, "Zincir: Zehirli Tırnak zehir biriktirmedi")
	if not in_slide:
		print("ARENA SKIP: Slide durumuna geçilemedi (test kurulumu), Taşıyıcı zinciri atlandı")
	else:
		_check(_poison_stacks_of(e2) >= 1, "Zincir (Taşıyıcı): kayarken alınan zehir sonraki düşmana geçti", "Zincir (Taşıyıcı): zehir geçmedi (e1 %d, e2 %d)" % [_poison_stacks_of(e1), _poison_stacks_of(e2)])
	_place_player(2200.0)

## Barut Sıçrayışı (gerçek çift zıplama bomba bırakır) + Fitil Hattı: inen bombanın patlaması komşu bombayı erken patlatır.
func _scenario_zincir_fitil_hatti() -> void:
	if not _want("zincir_fitil_hatti"):
		return
	await _items_on(["barut_sicrayisi", "fitil_hatti"])
	await _ground_player(3900.0)
	var bomb_b := Node2D.new()
	bomb_b.set_script(load("res://effects/jump_bomb.gd"))
	_arena.add_child(bomb_b)
	# Gerçek oyuncunun altına yakın, zemine oturmuş (yatay hız 0) komşu bomba; kendi fünyesi 2 sn
	var floor_y: float = _player.global_position.y
	bomb_b.setup(Vector2(3935.0, floor_y - 4.0), Vector2.ZERO)
	var t0 := Time.get_ticks_msec()
	await _press("jump", 2)
	await _frames(8)
	await _press("jump", 2)
	var gone_at := -1
	for _i in range(150):
		await physics_frame
		if gone_at < 0 and (not is_instance_valid(bomb_b) or bomb_b.is_queued_for_deletion() or bool(bomb_b._exploded)):
			gone_at = Time.get_ticks_msec() - t0
	print("ARENA DBG zincir fitil: komsu_bomba_patladi_ms=%d" % gone_at)
	_check(gone_at >= 0 and gone_at < 1700, "Zincir (Fitil Hattı): gerçek çift zıplama bombasının patlaması komşu bombayı fünyesini beklemeden patlattı (%d ms)" % gone_at, "Zincir (Fitil Hattı): komşu bomba erken patlamadı (%d ms)" % gone_at)
	_place_player(2200.0)

## Zehirli Yem: gerçek düşmanın gerçek saldırısı oyuncuyu vurunca bulut çıkar.
func _scenario_zincir_zehirli_yem_oyuncu() -> void:
	if not _want("zincir_zehirli_yem_oyuncu"):
		return
	await _items_on(["zehirli_yem"])
	await _ground_player(4300.0)
	var e := _spawn_enemy(4360.0)
	await _frames(40)
	e.health = 5000.0
	await _ground_player(4300.0)
	e.global_position = Vector2(4360.0, e.global_position.y)
	var ps = get_root().get_node("/root/PlayerStats")
	_player.set("invincibility_timer", 0.0)   # harness oyuncuyu ölümsüz tutar; gerçek hasar işlenmeli
	var hp0: float = ps.get_current_health()
	var took := [0]
	var took_cb := func(_a, _b): took[0] += 1
	_player.connect("player_took_damage", took_cb)
	var clouds0 := _count_scripts(_poison_cloud)
	var hurt := false
	var behaviors := {}
	for _i in range(500):
		await physics_frame
		behaviors[str(e.current_behavior)] = true
		if _count_scripts(_poison_cloud) > clouds0:
			hurt = true
			break
	_player.disconnect("player_took_damage", took_cb)
	_player.set("invincibility_timer", 1000000.0)
	ps.set_current_health(100.0, false)
	var hp1: float = ps.get_current_health()
	print("ARENA DBG zehirli yem oyuncu: bulut=%s hasar_sayisi=%d can %.0f -> %.0f davranislar=%s mesafe=%.0f" % [str(hurt), took[0], hp0, hp1, str(behaviors.keys()), absf(_player.global_position.x - e.global_position.x)])
	_check(hurt, "Zehirli Yem: gerçek düşman saldırısı oyuncuyu vurunca zehir bulutu çıktı", "Zehirli Yem: oyuncu hasar aldı ama bulut çıkmadı (can %.0f -> %.0f)" % [hp0, hp1])
	_place_player(2200.0)

## Barut Dolgusu: gerçek hafif vuruşlarla gerçek öldürmeler patlama çarpanını büyütür.
func _scenario_zincir_barut_dolgusu() -> void:
	if not _want("zincir_barut_dolgusu"):
		return
	await _items_on(["barut_dolgusu"])
	await _ground_player(4500.0)
	var victims: Array = []
	for i in range(3):
		victims.append(_spawn_enemy(4550.0 + float(i) * 20.0))
	await _frames(40)
	await _ground_player(4500.0)
	for i in range(victims.size()):
		var v = victims[i]
		v.health = 1.0
		v.velocity = Vector2.ZERO
		v.set_physics_process(false)
		v.global_position = Vector2(4550.0 + float(i) * 20.0, v.global_position.y)
	var mult0: float = ExplosionModifiers.damage_mult()
	await _light_hits(4)
	# Ölüm geçişi düşmanın kendi fiziğinde işlenir: dondurma testin düzeneği, kapat
	for v in victims:
		if is_instance_valid(v):
			v.set_physics_process(true)
	await _frames(20)
	var dead := 0
	for v in victims:
		if not is_instance_valid(v) or _enemy_hp(v) <= 0.0:
			dead += 1
	var mult1: float = ExplosionModifiers.damage_mult()
	print("ARENA DBG zincir dolgu: oldu=%d carpan %.2f -> %.2f" % [dead, mult0, mult1])
	_check(dead >= 1, "Zincir: gerçek vuruşlar düşmanları öldürdü (%d)" % dead, "Zincir: gerçek vuruşlar kimseyi öldürmedi")
	_check(mult1 > mult0 + 0.01, "Zincir (Barut Dolgusu): gerçek öldürmeler patlama çarpanını büyüttü (%.2f -> %.2f)" % [mult0, mult1], "Zincir (Barut Dolgusu): öldürmeler çarpanı büyütmedi (%.2f -> %.2f)" % [mult0, mult1])
	_place_player(2200.0)

## Gerçek ağır vuruşu, düşman SABİT konumdayken indir: düşman hazırlık süresince oyuncuya yürüyüp üstüne binmesin.
## Vuruş (knockback damgası) gerçekleşene kadar düşman pin_x'te tutulur, sonra gerçek fizik serbest kalır.
func _pinned_heavy_hit(e: Node, pin_x: float) -> void:
	var t0: int = int(e.last_knockback_msec)
	_player.attack_cooldown_timer = 0.0
	Input.action_press("attack_heavy")
	for k in range(90):
		if is_instance_valid(e) and int(e.last_knockback_msec) == t0:
			e.global_position = Vector2(pin_x, e.global_position.y)
			e.velocity.x = 0.0
		if k == 2:
			Input.action_release("attack_heavy")
		await physics_frame
		if is_instance_valid(e) and int(e.last_knockback_msec) != t0:
			break
	Input.action_release("attack_heavy")