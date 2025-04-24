extends Node2D

@export var unit_scene: PackedScene
@export var unit_stats_swordsman: UnitStats
@export var unit_stats_archer: UnitStats
@export var unit_stats_cavalry: UnitStats
@export var unit_stats_spearman: UnitStats
@export var unit_stats_shieldbearer: UnitStats
@export var battle_area: Rect2 = Rect2(0, 0, 1920, 1080)
@export var player_unit_count: int = 10
@export var enemy_unit_count: int = 10

# <<< YENİ: Sıralı Spawn Ayarları >>>
@export var ordered_spawn: bool = false # Eğer true ise, birimler belirli bir düzende spawn olur
@export var units_per_row: int = 8
@export var unit_spacing: float = 50.0 # Birimler arası yatay boşluk
@export var row_spacing: float = 60.0   # Sıralar arası dikey boşluk
@export var formation_depth: int = 5    # <<< YENİ: Sıralı spawn'da kolon derinliği >>>
@export var player_spawn_start: Vector2 = Vector2(150, 250) # Ordered: Formasyonun SAĞ üstü, Random: Sol üstü
@export var enemy_spawn_start: Vector2 = Vector2(1770, 250) # Ordered: Formasyonun SOL üstü, Random: Sağ üstü
@export var spawn_random_offset: float = 10.0 # Pozisyona eklenecek rastgelelik

# <<< YENİ: Ordered Spawn için Birim Sayıları (ordered_spawn true ise kullanılır) >>>
@export_group("Player Unit Counts (Ordered Spawn)")
@export var player_shieldbearer_count: int = 0
@export var player_spearman_count: int = 0
@export var player_swordsman_count: int = 0
@export var player_archer_count: int = 0
@export var player_cavalry_count: int = 0
@export_group("Enemy Unit Counts (Ordered Spawn)")
@export var enemy_shieldbearer_count: int = 0
@export var enemy_spearman_count: int = 0
@export var enemy_swordsman_count: int = 0
@export var enemy_archer_count: int = 0
@export var enemy_cavalry_count: int = 0

# <<< YENİ: Yasak Alanlar >>>
@export var forbidden_areas: Array[Rect2] = []

var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
# <<< YENİ: Spawn Planı >>>
var spawn_plan: Array = [] 

var battle_over: bool = false
var winner_team_id: int = -1
# <<< YENİ: Savaş Durumu Bayrakları >>>
var preparing_for_battle: bool = false
var battle_started: bool = false
# <<< YENİ: Savaş Başlatma Zamanlayıcısı >>>
var waiting_for_battle_start: bool = false
var pre_battle_timer: Timer = null
const PRE_BATTLE_DELAY: float = 2.0 # Saniye cinsinden bekleme

# <<< YENİ: UI Node Referansları >>>
@onready var unit_count_label: Label = $CanvasLayer/UnitCountLabel
@onready var game_over_label: Label = $CanvasLayer/GameOverLabel
# <<< YENİ: Yükleme Arayüzü Referansları >>>
@onready var loading_ui: CanvasLayer = $LoadingUI
@onready var progress_bar: ProgressBar = $LoadingUI/LoadingProgressBar
# @onready var loading_label: Label = $LoadingUI/LoadingLabel # Opsiyonel

# <<< YENİ: Aşamalı Yükleme Değişkenleri >>>
var is_spawning: bool = true
var spawned_unit_count: int = 0
var total_units_to_spawn: int = 0
const UNITS_PER_FRAME: int = 20 # Her karede oluşturulacak/aktive edilecek birim sayısı
# <<< YENİ: Aşamalı Aktivasyon Değişkenleri >>>
var is_activating_units: bool = false
var activated_unit_count: int = 0
# <<< YENİ: Güvenli Dikey Alan Sınırları >>>
var safe_vertical_start_y: float = 0.0
var safe_vertical_end_y: float = 0.0

func _ready() -> void:
	print("Battle Scene Ready! Starting phased spawn...")
	# Başlangıçta Game Over etiketini gizle
	if game_over_label != null:
		game_over_label.visible = false

	# <<< YENİ: Ordered Spawn Kontrolü ve Plan Oluşturma >>>
	
	# <<< GELECEKTEKİ KOMUTAN KONTROLÜ >>>
	# Bu değer ileride köy sahnesinden veya GlobalPlayerData'dan 
	# komutan olup olmadığına göre belirlenecek. Şimdilik Inspector'dan okunuyor.
	var use_ordered_spawn = ordered_spawn 
	
	# Toplam sayıları hesapla (artık her zaman özel sayılardan)
	var calculated_player_count = player_shieldbearer_count + player_spearman_count + player_swordsman_count + player_archer_count + player_cavalry_count
	var calculated_enemy_count = enemy_shieldbearer_count + enemy_spearman_count + enemy_swordsman_count + enemy_archer_count + enemy_cavalry_count
	
	# Eski total count'ları override et (artık bunlar ana kaynak)
	player_unit_count = calculated_player_count
	enemy_unit_count = calculated_enemy_count
	total_units_to_spawn = player_unit_count + enemy_unit_count

	if use_ordered_spawn:
		# Sayıların sıfır olup olmadığını kontrol et
		if total_units_to_spawn == 0:
			printerr("ERROR: Ordered spawn enabled, but all specific unit counts are zero!")
			is_spawning = false # Spawn'ı engelle
		else:
			print("Ordered spawn enabled. Generating spawn plan...")
			_generate_ordered_spawn_plan()
			# total_units_to_spawn'u plan boyutuna eşitlemek artık GEREKMİYOR
			if spawn_plan.size() != total_units_to_spawn:
				printerr("CRITICAL: Spawn plan size (%d) does not match calculated total units (%d)!" % [spawn_plan.size(), total_units_to_spawn])
			print("...Spawn plan generated with %d units." % spawn_plan.size())
	else:
		# Rastgele spawn için hazırlık
		print("Ordered spawn disabled. Using random type distribution.")
		if total_units_to_spawn == 0:
			printerr("ERROR: Random spawn selected, but unit counts result in zero total units!")
			is_spawning = false # Spawn'ı engelle

	# <<< KONTROL SONU >>>

	# <<< YENİ: Formasyon Yüksekliği ve Dikey Konumlandırma >>>
	var player_formation_height = 0.0
	var enemy_formation_height = 0.0
	var min_row_height = 20.0 # Tek sıra/derinlik için minimum yükseklik (sprite boyutuna göre ayarlanabilir)
	
	# <<< YENİ: formation_depth değerini logla >>>
	print("Formation Depth read in _ready: ", formation_depth)
	
	if use_ordered_spawn:
		# Sıralı mod: Yükseklik formation_depth'e göre belirlenir
		if formation_depth >= 1:
			# Her iki takım için de aynı derinlik varsayılır
			var ordered_height = (max(1, formation_depth) - 1) * row_spacing + min_row_height 
			player_formation_height = ordered_height
			enemy_formation_height = ordered_height
		else:
			player_formation_height = min_row_height # Geçersiz derinlikte varsayılan yükseklik
			enemy_formation_height = min_row_height
	else:
		# Rastgele mod: Yükseklik ARTIK formation_depth'e göre belirlenir
		if formation_depth >= 1:
			# Yüksekliği sıralı moddaki gibi hesapla
			var random_mode_height = (max(1, formation_depth) - 1) * row_spacing + min_row_height 
			player_formation_height = random_mode_height
			enemy_formation_height = random_mode_height # Takımlar aynı derinliği kullanır
		else:
			player_formation_height = min_row_height # Geçersiz derinlikte varsayılan yükseklik
			enemy_formation_height = min_row_height
	
	# Başlangıç Y koordinatlarını hesapla ve ayarla
	# <<< GÜNCELLENDİ: Yasak alanı hesaba kat >>>
	var forbidden_top_y = -INF # Varsayılan olarak sınır yok
	# Basitlik adına şimdilik SADECE İLK yasak alanın üst kenarını dikkate alalım
	# Daha karmaşık senaryolar için (örn. birden fazla yasak alan) daha gelişmiş mantık gerekebilir.
	if forbidden_areas.size() > 0:
		# Üst kenar = position.y + size.y
		forbidden_top_y = forbidden_areas[0].position.y + forbidden_areas[0].size.y
		print("Using Forbidden Area Top Edge: ", forbidden_top_y)
	
	# Kullanılabilir dikey alanı hesapla (Savaş alanı alt sınırı - Yasak alan üst sınırı)
	var margin = 1.0 # Yasak alan kenarından küçük bir boşluk
	safe_vertical_start_y = max(battle_area.position.y, forbidden_top_y + margin) # Y'nin başlayabileceği en düşük güvenli nokta
	safe_vertical_end_y = battle_area.end.y # Y'nin bitebileceği en yüksek nokta
	var available_safe_height = max(0, safe_vertical_end_y - safe_vertical_start_y)
	print("Safe Vertical Area: Y from %.1f to %.1f (Height: %.1f)" % [safe_vertical_start_y, safe_vertical_end_y, available_safe_height])
	
	# Oyuncu için
	var player_margin_y = max(0, (available_safe_height - player_formation_height) / 2.0)
	var player_centered_start_y = safe_vertical_start_y + player_margin_y # Güvenli alanın başlangıcına göre ortala
	player_spawn_start.y = player_centered_start_y
	print("Player Formation Height: %.1f, Centered Start Y: %.1f" % [player_formation_height, player_centered_start_y])

	# Düşman için
	var enemy_margin_y = max(0, (available_safe_height - enemy_formation_height) / 2.0)
	var enemy_centered_start_y = safe_vertical_start_y + enemy_margin_y # Güvenli alanın başlangıcına göre ortala
	enemy_spawn_start.y = enemy_centered_start_y 
	print("Enemy Formation Height: %.1f, Centered Start Y: %.1f" % [enemy_formation_height, enemy_centered_start_y])
	# <<< DİKEY KONUMLANDIRMA SONU >>>

	# Yükleme Arayüzünü Ayarla
	if is_instance_valid(progress_bar):
		progress_bar.max_value = total_units_to_spawn
		progress_bar.value = 0
	else:
		printerr("Progress Bar node not found or invalid!")
	
	if is_instance_valid(loading_ui):
		loading_ui.visible = true
	else:
		printerr("LoadingUI CanvasLayer not found or invalid!")
		
	# <<< YENİ: Spawn işlemini başlat >>>
	is_spawning = true
	spawned_unit_count = 0
	
	# <<< KALDIRILDI: Birim oluşturma döngüleri buradan kaldırıldı >>>
	# var player_offscreen_x = ...
	# var enemy_offscreen_x = ...
	# for i in range(player_unit_count):
	# ...
	# for i in range(enemy_unit_count):
	# ...

func _process(delta: float) -> void:
	# <<< Aşamalı Yükleme (Spawn) >>>
	if is_spawning:
		var units_to_spawn_this_frame = min(UNITS_PER_FRAME, total_units_to_spawn - spawned_unit_count)
		for i in range(units_to_spawn_this_frame):
			var team_id_to_spawn = 0
			var index_in_team = 0
			
			# Hangi takımdan ve hangi index'teki birimi spawn edeceğimizi belirle
			# Not: spawned_unit_count bir sonraki satırda artırılmadan ÖNCE kullanılır
			if spawned_unit_count < player_unit_count:
				team_id_to_spawn = 0
				index_in_team = spawned_unit_count
			else:
				team_id_to_spawn = 1
				index_in_team = spawned_unit_count - player_unit_count
				
			# Birimi spawn et
			# <<< DEĞİŞTİ: ordered_spawn durumuna göre farklı fonksiyon çağır >>>
			if ordered_spawn:
				var spawn_details = spawn_plan[spawned_unit_count]
				_spawn_single_unit_ordered(spawn_details)
			else:
				_spawn_single_unit_random(team_id_to_spawn, index_in_team)
			# <<< DEĞİŞİKLİK SONU >>>
			
			spawned_unit_count += 1

		# İlerleme çubuğunu güncelle (döngüden sonra)
		if is_instance_valid(progress_bar):
			progress_bar.value = spawned_unit_count
		# Spawn bitti mi kontrol et
		if spawned_unit_count >= total_units_to_spawn:
			is_spawning = false
			if is_instance_valid(loading_ui):
				loading_ui.visible = false
			print("...Phased spawn complete! Starting phased activation...")
			# <<< DEĞİŞTİ: Hemen preparing_for_battle değil, aktivasyonu başlat >>>
			# preparing_for_battle = true 
			is_activating_units = true
			activated_unit_count = 0
			
		return # Spawn devam ediyorsa başka işlem yapma
	
	# <<< YENİ: Aşamalı Aktivasyon >>>
	if is_activating_units:
		var units_to_activate_this_frame = min(UNITS_PER_FRAME, total_units_to_spawn - activated_unit_count)
		var current_activated_in_frame = 0
		
		# Önce oyuncuları aktive et
		for i in range(activated_unit_count, min(activated_unit_count + units_to_activate_this_frame, player_unit_count)):
			if i < player_units.size() and is_instance_valid(player_units[i]):
				player_units[i].set_current_state(Unit.State.MARCHING)
				current_activated_in_frame += 1
				if current_activated_in_frame >= units_to_activate_this_frame: break
				
		# Sonra düşmanları aktive et (eğer hala yer varsa bu frame'de)
		if current_activated_in_frame < units_to_activate_this_frame:
			var remaining_activation_slots = units_to_activate_this_frame - current_activated_in_frame
			var start_enemy_index = max(0, activated_unit_count - player_unit_count)
			var end_enemy_index = min(start_enemy_index + remaining_activation_slots, enemy_unit_count)
			
			for i in range(start_enemy_index, end_enemy_index):
				if i < enemy_units.size() and is_instance_valid(enemy_units[i]):
					enemy_units[i].set_current_state(Unit.State.MARCHING)
					# current_activated_in_frame += 1 # Bunu saymaya gerek yok, döngü zaten sınırlar

		activated_unit_count += units_to_activate_this_frame # Bu frame'de aktive edilenleri ekle

		# Aktivasyon bitti mi?
		if activated_unit_count >= total_units_to_spawn:
			is_activating_units = false
			print("...Phased activation complete! Starting preparation phase.")
			preparing_for_battle = true # Şimdi hazırlık başlayabilir
			
		return # Aktivasyon devam ediyorsa başka işlem yapma
		
	# <<< Yükleme ve Aktivasyon Bittikten Sonraki Normal _process Mantığı >>>
	# Savaş bittiyse UI'ı güncellemeyi durdur
	if battle_over:
		return
	
	# Aktif birim sayılarını say
	var player_active_count = 0
	for unit in player_units:
		if is_instance_valid(unit) and unit.get_current_state() != Unit.State.DEAD and unit.get_current_state() != Unit.State.FAINTED:
			player_active_count += 1
	var enemy_active_count = 0
	for unit in enemy_units:
		if is_instance_valid(unit) and unit.get_current_state() != Unit.State.DEAD and unit.get_current_state() != Unit.State.FAINTED:
			enemy_active_count += 1
	# Sayım etiketini güncelle
	if unit_count_label != null:
		unit_count_label.text = "Oyuncu: %d | Düşman: %d" % [player_active_count, enemy_active_count]

func _physics_process(delta: float) -> void:
	# Savaş Başlatma Kontrolü
	if preparing_for_battle:
		var all_units_in_position = true
		# Oyuncu birimlerini kontrol et
		for unit in player_units:
			if not is_instance_valid(unit) or unit.get_current_state() != Unit.State.IDLE:
				all_units_in_position = false
				break
		# Düşman birimlerini kontrol et (eğer oyuncular tamamsa)
		if all_units_in_position:
			for unit in enemy_units:
				if not is_instance_valid(unit) or unit.get_current_state() != Unit.State.IDLE:
					all_units_in_position = false
					break
					
		# Herkes yerindeyse savaşı başlatmak için zamanlayıcıyı kur
		if all_units_in_position:
			print("*** Birimler Pozisyonda, Savaş Başlaması Bekleniyor... ***")
			preparing_for_battle = false
			waiting_for_battle_start = true # Zamanlayıcıyı bekliyoruz
			
			# Zamanlayıcıyı oluştur ve başlat
			pre_battle_timer = Timer.new()
			pre_battle_timer.wait_time = PRE_BATTLE_DELAY
			pre_battle_timer.one_shot = true
			pre_battle_timer.timeout.connect(_start_battle) # Yeni fonksiyona bağla
			add_child(pre_battle_timer)
			pre_battle_timer.start()

			# <<< KALDIRILDI: Birimleri hemen MOVING'e geçirme >>>
			# battle_started = true
			# for unit in player_units:
			# ...
			# for unit in enemy_units:
			# ...
			
		return # Hazırlık aşamasındayken başka işlem yapma

	# Savaş Sonu Kontrolü (Başlamadıysa veya bittiyse devam etme)
	if battle_over or not battle_started or waiting_for_battle_start:
		return

	# <<< GÜNCELLENDİ: Savaş sonu kontrolü - Aktif birim sayısına bak >>>
	var player_active_count = 0
	for unit in player_units:
		if is_instance_valid(unit) and unit.get_current_state() != Unit.State.DEAD and unit.get_current_state() != Unit.State.FAINTED:
			player_active_count += 1
			
	var enemy_active_count = 0
	for unit in enemy_units:
		if is_instance_valid(unit) and unit.get_current_state() != Unit.State.DEAD and unit.get_current_state() != Unit.State.FAINTED:
			enemy_active_count += 1
	
	# Savaş sonu kontrolü
	if player_active_count == 0 and enemy_active_count > 0:
		_end_battle(1)
	elif enemy_active_count == 0 and player_active_count > 0:
		_end_battle(0)
	elif player_active_count == 0 and enemy_active_count == 0: # İki taraf da aynı anda yok olabilir mi?
		_end_battle(-2)

func _end_battle(winning_team: int) -> void:
	if battle_over:
		return 
		
	battle_over = true
	winner_team_id = winning_team
	
	# <<< YENİ: Son aktif sayıları burada hesapla ve UI'ı güncelle >>>
	var final_player_active_count = 0
	for unit in player_units:
		if is_instance_valid(unit) and unit.get_current_state() != Unit.State.DEAD and unit.get_current_state() != Unit.State.FAINTED:
			final_player_active_count += 1
			
	var final_enemy_active_count = 0
	for unit in enemy_units:
		if is_instance_valid(unit) and unit.get_current_state() != Unit.State.DEAD and unit.get_current_state() != Unit.State.FAINTED:
			final_enemy_active_count += 1
			
	if unit_count_label != null:
		unit_count_label.text = "Oyuncu: %d | Düşman: %d" % [final_player_active_count, final_enemy_active_count]

	# <<< GÜNCELLENDİ: Game Over Etiketini Ayarla ve Göster >>>
	var game_over_text = ""
	if winner_team_id == 0:
		game_over_text = "PLAYER KAZANDI!"
		print("-------------------") # Konsol logları kalsın
		print("  PLAYER KAZANDI!  ")
		print("-------------------")
		for unit in player_units:
			# <<< GÜNCELLENDİ: Sadece aktifse zafer durumuna geç >>>
			if is_instance_valid(unit) and unit.get_current_state() != Unit.State.DEAD and unit.get_current_state() != Unit.State.FAINTED:
				unit.enter_victory_state()
	elif winner_team_id == 1:
		game_over_text = "DÜŞMAN KAZANDI!"
		print("-------------------")
		print("  DÜŞMAN KAZANDI!  ")
		print("-------------------")
		for unit in enemy_units:
			# <<< GÜNCELLENDİ: Sadece aktifse zafer durumuna geç >>>
			if is_instance_valid(unit) and unit.get_current_state() != Unit.State.DEAD and unit.get_current_state() != Unit.State.FAINTED:
				unit.enter_victory_state()
	elif winner_team_id == -2: # Beraberlik durumu
		game_over_text = "BERABERE!"
		print("-------------------")
		print("     BERABERE!     ")
		print("-------------------")
	
	# Game Over etiketini güncelle ve görünür yap
	if game_over_label != null:
		game_over_label.text = game_over_text
		game_over_label.visible = true

func _on_unit_died(unit: Unit) -> void:
	print("DEBUG: BattleScene received died signal from %s (Team %d)" % [unit.name, unit.team_id])
	# <<< GÜNCELLENDİ: Artık listeden ÇIKARMIYORUZ >>>
	# Sadece log yazdırabiliriz veya ileride ölüler listesine ekleyebiliriz
	# if unit.team_id == 0:
	# 	if player_units.has(unit):
	# 		# player_units.erase(unit)
	# 		print("DEBUG: Unit %s DIED (Player). Remaining active: %d" % [unit.name, player_units.filter(func(u): return u.current_state != Unit.State.DEAD and u.current_state != Unit.State.FAINTED).size()])
	# ... (WARN log)
	# elif unit.team_id == 1:
	# 	if enemy_units.has(unit):
	# 		# enemy_units.erase(unit)
	# 		print("DEBUG: Unit %s DIED (Enemy). Remaining active: %d" % [unit.name, enemy_units.filter(func(u): return u.current_state != Unit.State.DEAD and u.current_state != Unit.State.FAINTED).size()])
	# ... (WARN log)
	# ... (ERROR log)
	pass # Şimdilik bir şey yapma

# <<< YENİ: Bayılan Birim İçin Callback >>>
func _on_unit_fainted(unit: Unit) -> void:
	print("DEBUG: BattleScene received fainted signal from %s (Team %d)" % [unit.name, unit.team_id])
	# <<< GÜNCELLENDİ: Artık listeden ÇIKARMIYORUZ >>>
	# Sadece log yazdırabiliriz veya ileride baygınlar listesine ekleyebiliriz
	# if unit.team_id == 0:
	# 	if player_units.has(unit):
	# 		# player_units.erase(unit)
	# 		print("DEBUG: Unit %s FAINTED (Player). Remaining active: %d" % [unit.name, player_units.filter(func(u): return u.current_state != Unit.State.DEAD and u.current_state != Unit.State.FAINTED).size()])
	# ... (WARN log)
	# elif unit.team_id == 1:
	# 	if enemy_units.has(unit):
	# 		# enemy_units.erase(unit)
	# 		print("DEBUG: Unit %s FAINTED (Enemy). Remaining active: %d" % [unit.name, enemy_units.filter(func(u): return u.current_state != Unit.State.DEAD and u.current_state != Unit.State.FAINTED).size()])
	# ... (WARN log)
	# ... (ERROR log)
	pass # Şimdilik bir şey yapma

# <<< YENİ: Savaşı Başlatan Fonksiyon >>>
func _start_battle() -> void:
	waiting_for_battle_start = false # Beklemeyi durdur
	battle_started = true
	print("*** SAVAŞ BAŞLADI! ***")
	print("DEBUG: Starting battle. Player units: %d, Enemy units: %d" % [player_units.size(), enemy_units.size()]) # <<< YENİ DEBUG >>>
	
	# Tüm birimleri MOVING durumuna geçir (yeni setter ile)
	for unit in player_units:
		if is_instance_valid(unit):
			unit.set_current_state(Unit.State.MOVING) # Doğrudan atama yerine setter kullan
			
	for unit in enemy_units:
		if is_instance_valid(unit):
			unit.set_current_state(Unit.State.MOVING) # Doğrudan atama yerine setter kullan

	# Zamanlayıcıyı temizle (artık gerekli değil)
	if pre_battle_timer != null and is_instance_valid(pre_battle_timer):
		pre_battle_timer.queue_free()
		pre_battle_timer = null

# <<< YENİ: Yasak Alanları Döndüren Metod >>>
func get_forbidden_areas() -> Array[Rect2]:
	return forbidden_areas

# <<< DEĞİŞTİ: Fonksiyon Adı ve Mantığı (Rastgele Spawn İçin) >>>
func _spawn_single_unit_random(team_id: int, index_in_team: int) -> void:
	var unit_instance = unit_scene.instantiate() as Unit
	
	# <<< DEĞİŞTİ: Sıra/Sütun Hesaplama (formation_depth kullan) >>>
	var col = 0
	var row = 0
	if formation_depth > 0: # Sıfıra bölme hatasını önle
		col = index_in_team / formation_depth 
		row = index_in_team % formation_depth 
	else:
		# Geçersiz formation_depth durumu (belki hata ver veya varsayılan kullan?)
		printerr("ERROR: formation_depth is zero or negative in random spawn mode!")
		col = index_in_team # Tüm birimleri tek sütuna yığ? 
		row = 0
	# <<< ESKİ Hesaplama (units_per_row ile) >>>
	# var row = index_in_team / units_per_row
	# var col = index_in_team % units_per_row
	
	# Hedef ve Başlangıç Pozisyonlarını Hesapla
	var formation_pos: Vector2
	var start_pos: Vector2
	var spawn_origin: Vector2 = player_spawn_start if team_id == 0 else enemy_spawn_start # Spawn origin'i burada alalım
	var horizontal_direction: float = 1.0
	var offscreen_offset: float = 600.0
		
	if team_id == 1: # Sadece düşman için yönü değiştir
		horizontal_direction = -1.0
		
	var target_x = spawn_origin.x + (col * unit_spacing * horizontal_direction) + randf_range(-spawn_random_offset, spawn_random_offset)
	var target_y = spawn_origin.y + (row * row_spacing) + randf_range(-spawn_random_offset, spawn_random_offset)
	
	# <<< YENİ: target_y'yi savaş alanının dikey sınırlarına kelepçele >>>
	# <<< GÜNCELLENDİ: Artık güvenli dikey alan sınırlarını kullan >>>
	target_y = clamp(target_y, safe_vertical_start_y, safe_vertical_end_y)
	
	formation_pos = Vector2(target_x, target_y)
	
	# Başlangıç pozisyonunu hesapla (start_pos)
	if team_id == 0: # Oyuncu - Sola kaydır
		start_pos = formation_pos - Vector2(offscreen_offset, 0) 
	else: # Düşman - Sağa kaydır
		start_pos = formation_pos + Vector2(offscreen_offset, 0)
	
	# Birim türünü belirle (Rastgele dağılım için - index_in_team kullanarak)
	var stats_to_use: UnitStats = unit_stats_swordsman # Varsayılan
	var i = index_in_team # index_in_team'i eski döngüdeki i gibi kullanalım
	if i % 4 == 0 and unit_stats_cavalry != null:
		stats_to_use = unit_stats_cavalry
	elif i % 5 == 3 and unit_stats_shieldbearer != null: 
		stats_to_use = unit_stats_shieldbearer
	elif i % 3 == 1 and unit_stats_archer != null: 
		stats_to_use = unit_stats_archer
	elif i % 3 == 2 and unit_stats_spearman != null: 
		stats_to_use = unit_stats_spearman
	elif unit_stats_swordsman == null:
		printerr("Cannot spawn unit (random), default Swordsman stats are null...")
		unit_instance.queue_free() # Hatalıysa ekleme
		return
		
	# Birimi Ayarla (Ortak kısımlar)
	unit_instance.stats = stats_to_use # Burada belirlendi
	unit_instance.global_position = start_pos # Burada hesaplandı
	unit_instance.formation_target_pos = formation_pos # Burada hesaplandı
	_finalize_unit_spawn(unit_instance, team_id) # Kalan ortak ayarlar

# <<< YENİ: Sıralı Spawn İçin Ayrı Fonksiyon >>>
func _spawn_single_unit_ordered(details: Dictionary) -> void:
	var unit_instance = unit_scene.instantiate() as Unit
	
	# Detayları al
	var team_id: int = details["team_id"]
	var stats_to_use: UnitStats = details["stats"]
	var row: int = details["row"]
	var col: int = details["col"]
	
	# Hedef ve Başlangıç Pozisyonlarını Hesapla (row/col kullanarak)
	var formation_pos: Vector2
	var start_pos: Vector2
	var spawn_origin: Vector2 = player_spawn_start if team_id == 0 else enemy_spawn_start # Spawn origin'i burada alalım
	var offscreen_offset: float = 600.0
	
	# <<< YENİ: target_x burada declare ediliyor >>>
	var target_x: float 
	
	# <<< DÜZELTME: Sıralı spawn için X koordinat hesaplaması düzeltildi >>>
	if team_id == 0: # Oyuncu (SAĞ üstten başlar, sola doğru kolon ekler)
		target_x = spawn_origin.x - (col * unit_spacing) + randf_range(-spawn_random_offset, spawn_random_offset)
	else: # Düşman (SOL üstten başlar, sağa doğru kolon ekler)
		target_x = spawn_origin.x + (col * unit_spacing) + randf_range(-spawn_random_offset, spawn_random_offset)
		
	# Y Pozisyonu (Aynı kalır)
	var target_y = spawn_origin.y + (row * row_spacing) + randf_range(-spawn_random_offset, spawn_random_offset)
	
	# <<< YENİ: target_y'yi savaş alanının dikey sınırlarına kelepçele >>>
	# <<< GÜNCELLENDİ: Artık güvenli dikey alan sınırlarını kullan >>>
	target_y = clamp(target_y, safe_vertical_start_y, safe_vertical_end_y)
	
	formation_pos = Vector2(target_x, target_y)
	
	# Başlangıç pozisyonunu hesapla (start_pos)
	if team_id == 0: # Oyuncu - Sola kaydır
		start_pos = formation_pos - Vector2(offscreen_offset, 0) 
	else: # Düşman - Sağa kaydır
		start_pos = formation_pos + Vector2(offscreen_offset, 0)
	
	# Birimi Ayarla (Ortak kısımlar)
	unit_instance.stats = stats_to_use # Detaylardan geldi
	unit_instance.global_position = start_pos # Burada hesaplandı
	unit_instance.formation_target_pos = formation_pos # Burada hesaplandı
	_finalize_unit_spawn(unit_instance, team_id) # Kalan ortak ayarlar

# <<< YENİ: Ortak Birim Ayarlama ve Ekleme Fonksiyonu >>>
func _finalize_unit_spawn(unit_instance: Unit, team_id: int) -> void:
	if not is_instance_valid(unit_instance) or unit_instance.stats == null:
		printerr("ERROR: Finalizing spawn for invalid unit instance or unit with null stats.")
		unit_instance.queue_free() # Güvenlik önlemi
		return
		
	unit_instance.team_id = team_id
	unit_instance.battle_scene_ref = self 
	unit_instance.battle_area_limit = battle_area 
	unit_instance.name = "%s_%s" % [unit_instance.stats.unit_type_id.capitalize(), unit_instance.get_instance_id()]
	
	# Sahneye Ekle ve Listeye Ekle
	# NOT: Node hiyerarşisini kontrol et, UnitsContainer altına eklemek daha iyi olabilir
	# add_child(unit_instance) 
	var units_container = $UnitsContainer
	if team_id == 0:
		units_container.get_node("PlayerUnits").add_child(unit_instance)
		player_units.append(unit_instance)
	else:
		units_container.get_node("EnemyUnits").add_child(unit_instance)
		enemy_units.append(unit_instance)
		
	# Sinyalleri Bağla
	unit_instance.died.connect(_on_unit_died)
	unit_instance.fainted.connect(_on_unit_fainted)
	
	# Spawn Pozisyon Kontrolü (Yasak Alan) - Hedef pozisyona bak
	for area in forbidden_areas:
		# formation_pos bu fonksiyonda yok, unit_instance.formation_target_pos kullanalım
		if area.has_point(unit_instance.formation_target_pos):
			printerr("WARNING: Unit %s target formation position (%s) is inside a forbidden area %s! ..." % [unit_instance.name, unit_instance.formation_target_pos.round(), area])
			break

# <<< YENİ: Ordered Spawn Planı Oluşturma Fonksiyonu >>>
func _generate_ordered_spawn_plan() -> void:
	spawn_plan.clear() # Önceki planı temizle (varsa)

	# Takım bilgilerini ve spawn sırasını tanımla (ÖN -> ARKA)
	var type_order = [
		unit_stats_shieldbearer,
		unit_stats_spearman,
		unit_stats_swordsman,
		unit_stats_archer,
		unit_stats_cavalry
	]

	var team_counts = {
		0: { # Player
			unit_stats_shieldbearer: player_shieldbearer_count,
			unit_stats_spearman: player_spearman_count,
			unit_stats_swordsman: player_swordsman_count,
			unit_stats_archer: player_archer_count,
			unit_stats_cavalry: player_cavalry_count
		},
		1: { # Enemy
			unit_stats_shieldbearer: enemy_shieldbearer_count,
			unit_stats_spearman: enemy_spearman_count,
			unit_stats_swordsman: enemy_swordsman_count,
			unit_stats_archer: enemy_archer_count,
			unit_stats_cavalry: enemy_cavalry_count
		}
	}

	for team_id in [0, 1]:
		var current_col_offset = 0 # <<< DEĞİŞTİ: Sütun offsetini takip et >>>

		for stats in type_order:
			var count = team_counts[team_id].get(stats, 0) # Sayıyı al

			if count <= 0 or stats == null:
				continue 

			# Bu tip için birimleri plana ekle (Kolon bazlı)
			for i in range(count):
				# <<< DEĞİŞTİ: Kolon ve Sıra Hesaplaması >>>
				var col_within_type = 0
				var row = 0
				if formation_depth > 0: # Sıfıra bölme hatasını önle
					col_within_type = i / formation_depth 
					row = i % formation_depth # Kolon içindeki dikey sıra
				else: # Geçersiz derinlik durumu
					printerr("ERROR: formation_depth is zero or negative during plan generation!")
					col_within_type = i # Tek bir sütuna yığ
					row = 0 
					
				var final_col = current_col_offset + col_within_type
				# <<< HESAPLAMA SONU >>>

				var spawn_details = {
					"team_id": team_id,
					"stats": stats,
					"row": row,       # <<< DEĞİŞTİ: Dikey pozisyon >>>
					"col": final_col  # <<< DEĞİŞTİ: Yatay pozisyon (kolon indeksi) >>>
				}
				spawn_plan.append(spawn_details)

			# Bu tipin kapladığı kolon sayısını hesapla ve offset'i güncelle
			if formation_depth > 0:
				var cols_used = ceil(count / float(formation_depth))
				current_col_offset += cols_used # <<< DEĞİŞTİ: Kolon offsetini artır >>>
			else: # Geçersiz derinlik, tümünü 1 sütunda varsay
				current_col_offset += 1 
