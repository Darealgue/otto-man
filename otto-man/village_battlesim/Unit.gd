extends CharacterBody2D
class_name Unit

# <<< YENİ: Ok Sahnesi >>>
var ArrowScene = preload("res://village_battlesim/arrow.tscn")

# <<< YENİ: Birim öldüğünde gönderilecek sinyal >>>
signal died(unit)
# <<< YENİ: Birim bayıldığında gönderilecek sinyal >>>
signal fainted(unit)

# Bu birimin istatistiklerini tutan Resource dosyası
@export var stats: UnitStats = null

# <<< YENİ: Ok Fırlatma Gecikmesi Değişkenleri >>>
var arrow_fire_timer: float = 0.0
var is_waiting_to_fire_arrow: bool = false
var _target_for_pending_arrow: Unit = null # Zamanlayıcı bitince hedefi bilmek için
const MAX_ARROW_FIRE_DELAY: float = 0.4 # Maksimum rastgele gecikme (saniye) - ARTIRILDI
# <<< YENİ: Iskalama için >>>
var _pending_arrow_is_miss: bool = false
const MISS_OFFSET_MIN: float = 50.0 # Iskalama min sapma mesafesi
const MISS_OFFSET_MAX: float = 150.0 # Iskalama max sapma mesafesi

# <<< YENİ: Yakın Dövüş Hasar Gecikmesi >>>
var melee_damage_timer: float = 0.0
var _target_for_pending_melee: Unit = null
const MELEE_DAMAGE_DELAY: float = 0.5 # Saniye cinsinden gecikme <<< DEĞİŞTİ >>>
# <<< YENİ SONU >>>

# <<< YENİ: Saldırıda Takılma Zamanlayıcısı >>>
var stuck_attacking_timer: float = 0.0
const STUCK_ATTACKING_TIMEOUT: float = 1.5 # Saniye
# <<< YENİ SONU >>>

# Mevcut can puanı
var current_hp: int = 100
# Hangi takıma ait (örn: 0 = oyuncu, 1 = düşman)
var team_id: int = 0 

# <<< YENİ: Bayılma Şansı >>>
const FAINT_CHANCE: float = 0.3 # %30 Bayılma şansı (ölmek yerine)

# Birimin olası durumları
enum State {
	IDLE,
	MOVING,
	ATTACKING,
	FLEEING,
	VICTORY,
	MARCHING,
	FAINTED,
	DEAD # <<< YENİ >>>
}
var _current_state = State.IDLE

# Hareket hedefi (şimdilik basit bir yön)
var move_direction: Vector2 = Vector2.ZERO

# <<< YENİ: Formasyon Hedefi >>>
var formation_target_pos: Vector2 = Vector2.ZERO

# Sahnedeki Sprite noduna erişim
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Hedef düşman
var target_enemy: Unit = null 

# Saldırı zamanlayıcısı
var attack_timer: float = 0.0

# <<< YENİ: Hedef Arama Zamanlayıcısı >>>
var find_target_timer: float = 0.0 
const FIND_TARGET_INTERVAL: float = 0.5 # Saniye cinsinden hedef arama sıklığı

# <<< YENİ: Ayrılma Hesaplama Zamanlayıcısı >>>
var separation_calc_timer: float = 0.0
const SEPARATION_CALC_INTERVAL: float = 0.1 # Saniye cinsinden (Düşük tutalım, sık çalışsın ama her kare değil)

@onready var detection_area: Area2D = $DetectionArea
@onready var friendly_detection_area: Area2D = $FriendlyDetectionArea
# @onready var collision_shape: CollisionShape2D = $DetectionArea/CollisionShape2D # Gerekirse

var position_debug_timer: float = 0.0
const POSITION_DEBUG_INTERVAL: float = 5.0 # Saniye cinsinden yazdırma aralığı

const ARCHER_FLEE_DISTANCE = 60.0 # Yakın dövüşçü bu mesafeye girerse okçu kaçar

# <<< YENİ: Zamanlayıcı Değişkenleri >>>
var threat_check_timer: float = 0.0
const THREAT_CHECK_INTERVAL: float = 0.5 # Saniye cinsinden tehdit kontrol aralığı
var current_threat: Unit = null # Mevcut tehdidi takip etmek için
# <<< YENİ SONU >>>

# <<< GÜNCELLENDİ: Seçilen Varyant İndeksi >>>
var _selected_variant_index = 1 # Başlangıçta 1 olsun (hem idle hem run için)

# <<< YENİ: Jitter Hareketi için Değişkenler >>>
var jitter_timer: float = 0.0
const JITTER_INTERVAL: float = 0.6 # Saniye cinsinden yön değiştirme sıklığı (Artırıldı)
var jitter_target_offset: Vector2 = Vector2.ZERO # Gidilecek küçük hedef ofseti

# <<< YENİ: BattleScene referansı >>>
var battle_scene_ref = null

# <<< YENİ: Savaş alanı sınırı >>>
var battle_area_limit: Rect2 = Rect2(0,0,0,0) # BattleScene tarafından atanacak

# <<< YENİ: Hasar Görsel Efekti Zamanlayıcısı >>>
var damage_flash_timer: float = 0.0
const DAMAGE_FLASH_DURATION: float = 0.2 # Saniye cinsinden

# <<< YENİ: Ayrılma Ağırlığı >>>
const SEPARATION_WEIGHT = 0.1 # Normal hareket sırasındaki ayrılma ağırlığı
const ATTACKING_SEPARATION_WEIGHT = 2.0 # Saldırı sırasındaki ayrılma ağırlığı (Daha Yüksek)

# <<< YENİ SABİT >>>
const LOW_HEALTH_THRESHOLD: float = 0.3 # %30 canın altı düşük kabul edilir
# <<< YENİ: Yürüme Hızı >>>
const MARCHING_SPEED: float = 80.0 # Formasyona yürürken kullanılacak hız

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if stats == null:
		#printerr("Unit (%s) has no stats assigned!" % name)
		queue_free()
		return
	# <<< YENİ: AnimatedSprite Kontrolü >>>
	if not is_instance_valid(animated_sprite):
		#printprierr("Unit (%s) has no AnimatedSprite2D node assigned or it's invalid!" % name)
		queue_free()
		return
	
	# <<< YENİ: Sinyali bağla >>>
	if is_instance_valid(animated_sprite):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	current_hp = stats.max_hp
	attack_timer = stats.attack_speed # Başlangıçta hemen saldırmasın

	# <<< GÜNCELLENDİ: Fizik, Düşman Algılama ve Dost Algılama Katman Ayarları >>>
	# Artık layer/mask team_id'ye göre atanacak
	# self.collision_layer = 1
	# self.collision_mask = 1 
	
	# Detection Area (Düşman Algılama): Takımlar sadece birbirini algılar.
	# Friendly Detection Area (Dost Algılama): Takımlar sadece kendini algılar.
	if team_id == 0: # Player
		# <<< YENİ: Oyuncu Fizik Katman/Maske >>>
		self.collision_layer = 1 # Oyuncular Katman 1'de
		self.collision_mask = 2  # Sadece Katman 2 (Düşman) ile çarpışır
		
		# Düşman Algılama: Layer 11, Detects Layer 12 (Enemy Area)
		detection_area.collision_layer = pow(2, 10) # 1024
		detection_area.collision_mask = pow(2, 11)  # 2048
		# Dost Algılama: Layer 3, Detects Layer 3 (Friendly Area)
		friendly_detection_area.collision_layer = pow(2, 2) # 4
		friendly_detection_area.collision_mask = pow(2, 2)  # 4
		friendly_detection_area.monitorable = true # Tespit edilebilmesi için
	elif team_id == 1: # Enemy
		# <<< YENİ: Düşman Fizik Katman/Maske >>>
		self.collision_layer = 2 # Düşmanlar Katman 2'de
		self.collision_mask = 1  # Sadece Katman 1 (Oyuncu) ile çarpışır
		
		# Düşman Algılama: Layer 12, Detects Layer 11 (Player Area)
		detection_area.collision_layer = pow(2, 11) # 2048
		detection_area.collision_mask = pow(2, 10)  # 1024
		# Dost Algılama: Layer 4, Detects Layer 4 (Friendly Area)
		friendly_detection_area.collision_layer = pow(2, 3) # 8
		friendly_detection_area.collision_mask = pow(2, 3)  # 8
		friendly_detection_area.monitorable = true # Tespit edilebilmesi için
	else:
		#printerr("Unit (%s) has invalid team_id: %d" % [name, team_id])
		# Hata durumunda çarpışmayı/algılamayı kapat
		self.collision_layer = 0
		self.collision_mask = 0 # Hata durumunda 0 kalmalı
		detection_area.collision_layer = 0
		detection_area.collision_mask = 0
		friendly_detection_area.collision_layer = 0 # <<< YENİ
		friendly_detection_area.collision_mask = 0  # <<< YENİ

	# Alanların izleme/izlenebilirlik durumunu her zaman açık tutalım
	detection_area.monitoring = true
	detection_area.monitorable = true
	friendly_detection_area.monitoring = true # <<< YENİ
	# <<< AYARLAR SONU >>>

	# Sinyalleri bağla (Bu kısım aynı kalıyor)
	detection_area.area_entered.connect(_on_detection_area_area_entered)
	detection_area.area_exited.connect(_on_detection_area_area_exited)

	# Başlangıç hareket yönü (MOVING state içinde dinamik)
	# if team_id == 0: move_direction = Vector2.RIGHT
	# elif team_id == 1: move_direction = Vector2.LEFT

# Hasar alma fonksiyonu
func take_damage(damage_amount: int) -> void:
	# <<< GÜNCELLENDİ: Baygın veya ölü ise hasar alma >>>
	if _current_state == State.FAINTED or _current_state == State.DEAD or _current_state == State.VICTORY or is_queued_for_deletion():
		return
		
	# Blok Kontrolü
	if stats != null and stats.block_chance > 0:
		if randf() < stats.block_chance:
			#print("%s BLOKLADI!" % name)
			# <<< GÜNCELLENDİ: Blok Animasyonu (Temel isim) >>>
			_play_animation("block") 
			return # Hasar almadı

	# Savunmayı hesaba kat
	var actual_damage = max(0, damage_amount - stats.defense)
	current_hp -= actual_damage
	#print("%s took %d damage (%d raw). HP left: %d / %d" % [name, actual_damage, damage_amount, current_hp, stats.max_hp])

	# Hasar Efektini Başlat
	damage_flash_timer = DAMAGE_FLASH_DURATION
	animated_sprite.modulate = Color.RED

	# Ölüm veya Bayılma kontrolü
	#print("DEBUG: Checking death/faint for %s. HP: %d" % [name, current_hp])
	if current_hp <= 0:
		# <<< GÜNCELLENDİ: Ölme veya Bayılma Şansı >>>
		if randf() < FAINT_CHANCE:
			_faint() # Bayılma fonksiyonunu çağır
		else:
			_die() # Ölme fonksiyonunu çağır

# Ölüm fonksiyonu
func _die() -> void:
	# <<< YENİ: Ekstra Güvenlik Kontrolü >>>
	if _current_state == State.DEAD or _current_state == State.FAINTED: return
	died.emit(self)
	#print("DEBUG: _die() called for %s" % name)
	
	set_current_state(State.DEAD)
	#print("%s died!" % name)
	
	# <<< GÜNCELLENDİ: Ölüm Animasyonu (Temel isim) >>>
	_play_animation("dead")
	
	# Ölüyü etkisiz hale getir (bayılmadaki gibi)
	self.collision_layer = 0
	self.collision_mask = 0
	if is_instance_valid(detection_area):
		detection_area.monitoring = false
		detection_area.monitorable = false
	if is_instance_valid(friendly_detection_area):
		friendly_detection_area.monitoring = false
		friendly_detection_area.monitorable = false
	
	# Aktif zamanlayıcıları/durumları sıfırla
	attack_timer = 9999 
	is_waiting_to_fire_arrow = false
	_target_for_pending_arrow = null
	_pending_arrow_is_miss = false
	target_enemy = null
	current_threat = null
	jitter_target_offset = Vector2.ZERO
	damage_flash_timer = 0.0 
	# <<< GÜNCELLENDİ: Renk >>>
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = Color(0.3, 0.3, 0.3, 0.8) # Koyu gri, hafif şeffaf (geçici)
	
	velocity = Vector2.ZERO
	# queue_free() # <<< KALDIRILDI >>>

# <<< YENİ: Bayılma Fonksiyonu >>>
func _faint() -> void:
	# <<< YENİ: Ekstra Güvenlik Kontrolü >>>
	if _current_state == State.FAINTED or _current_state == State.DEAD: return
	fainted.emit(self)
	#print("DEBUG: _faint() called for %s" % name)
	
	set_current_state(State.FAINTED)
	#print("%s fainted!" % name)
	
	# Baygın birimi etkisiz hale getir (çarpışma, algılama vb.)
	self.collision_layer = 0
	self.collision_mask = 0
	if is_instance_valid(detection_area):
		detection_area.monitoring = false
		detection_area.monitorable = false
	if is_instance_valid(friendly_detection_area):
		friendly_detection_area.monitoring = false
		friendly_detection_area.monitorable = false
	
	# Aktif zamanlayıcıları/durumları sıfırla
	attack_timer = 9999 
	is_waiting_to_fire_arrow = false
	_target_for_pending_arrow = null
	_pending_arrow_is_miss = false
	target_enemy = null
	current_threat = null
	jitter_target_offset = Vector2.ZERO
	damage_flash_timer = 0.0 # Hasar efektini hemen bitir
	
	# Baygın birim hareket etmemeli (_physics_process'te kontrol edilecek)
	velocity = Vector2.ZERO
	
	# <<< GÜNCELLENDİ: Bayılma Animasyonu (Temel isim) >>>
	_play_animation("faint")
	# <<< YENİ: Renk Modülasyonu >>>
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = Color.GRAY # Baygın rengi (geçici)
	
	# Not: queue_free() ÇAĞIRMIYORUZ. Birim sahnede kalacak.

# _process fonksiyonu ileride hareket, saldırı vb. için kullanılacak
# func _process(delta: float) -> void:
#	pass

func _physics_process(delta: float) -> void:
	# Zafer, Bayılma veya Ölüm durumunda işlem yapma
	if _current_state == State.VICTORY or _current_state == State.FAINTED or _current_state == State.DEAD:
		velocity = Vector2.ZERO
		set_physics_process(false) # <<< OPTİMİZASYON: Artık işlem yapmayacaksa kapat >>>
		return 

	# Hasar Efekti Güncelleme 
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		if damage_flash_timer <= 0:
			# <<< GÜNCELLENDİ: animated_sprite kullan >>>
			if is_instance_valid(animated_sprite) and _current_state != State.DEAD and _current_state != State.FAINTED:
				animated_sprite.modulate = Color.WHITE # Sadece hayattaysa normale dön

	var move_direction = Vector2.ZERO # Her frame sıfırla, state machine belirlesin
	var target_velocity = Vector2.ZERO
	var current_separation_weight = SEPARATION_WEIGHT
	var allow_threat_check = true # Tehdit kontrolü varsayılan olarak açık
	var target_base_anim = "idle" # Varsayılan animasyon

	# <<< YENİ: Ayrılma Zamanlayıcı Güncelleme >>>
	separation_calc_timer -= delta

	# Okçu Tehlike Kontrolü (Sadece izinliyse)
	if allow_threat_check and stats != null and stats.unit_type_id == "archer":
		threat_check_timer += delta
		if threat_check_timer >= THREAT_CHECK_INTERVAL:
			var found_threat = _find_nearby_melee_threat()
			if found_threat != current_threat:
				# print("DEBUG (%s): Threat check result: %s (Previous: %s)" % [name, found_threat, current_threat]) # Biraz kalabalık yapıyor, şimdilik kapalı
				current_threat = found_threat
			elif found_threat == null and current_threat != null:
				# print("DEBUG (%s): Previous threat %s no longer found by timer check." % [name, current_threat]) # Biraz kalabalık yapıyor, şimdilik kapalı
				current_threat = null
			threat_check_timer = 0.0

	# Tehdide Tepki (Sadece izinliyse)
	if allow_threat_check and stats != null and stats.unit_type_id == "archer" and _current_state != State.FLEEING:
		if current_threat != null and is_instance_valid(current_threat):
			# Geçerli tehdit var, FLEEING durumuna geç
			# print("DEBUG (%s): Reacting to valid threat %s. Switching to FLEEING." % [name, current_threat.name]) # Biraz kalabalık yapıyor, şimdilik kapalı
			set_current_state(State.FLEEING)
			target_enemy = null # Kaçarken hedefi bırak
			# Kaçış yönü FLEEING state içinde belirlenecek
			# Bu frame'de state değiştiği için match bloğunun FLEEING kısmına girecek
			# return # Gerek yok, state değişti, match bloğu halleder

	# Bekleyen Ok Fırlatma Kontrolü (Her durumda çalışabilir)
	if is_waiting_to_fire_arrow:
		arrow_fire_timer -= delta
		if arrow_fire_timer <= 0:
			is_waiting_to_fire_arrow = false
			# Hedef hala geçerli mi diye kontrol et
			if is_instance_valid(_target_for_pending_arrow):
				# _spawn_attack_effect fonksiyonu içinde _pending_arrow_is_miss sıfırlanacak
				_spawn_attack_effect(_target_for_pending_arrow)
			else:
				# Hedef geçersizse, bekleyen ıskalama bayrağını temizle
				_pending_arrow_is_miss = false 
			_target_for_pending_arrow = null # Hedefi temizle (her durumda)
	# <<< KONTROL SONU >>>

	# <<< YENİ: Bekleyen Yakın Dövüş Hasar Kontrolü >>>
	if melee_damage_timer > 0:
		melee_damage_timer -= delta
		if melee_damage_timer <= 0:
			if is_instance_valid(_target_for_pending_melee):
				# Hedef hala geçerli, hasarı uygula
				var damage = stats.attack_damage # Hasarı burada hesapla
				#print("DEBUG (%s): MELEE - Applying delayed damage %d to %s" % [name, damage, _target_for_pending_melee.name]) # <<< YENİ DEBUG >>>
				_target_for_pending_melee.take_damage(damage)
			#else:
				#print("DEBUG (%s): MELEE - Delayed damage target %s became invalid." % [name, _target_for_pending_melee.name if _target_for_pending_melee else 'null']) # <<< YENİ DEBUG >>>
			_target_for_pending_melee = null # Hedefi temizle (her durumda)
	# <<< YAKIN DÖVÜŞ HASAR KONTROL SONU >>>

	# --- Durum Makinesi ---
	match _current_state:
		State.MARCHING:
			allow_threat_check = false # Yürürken tehdit arama
			var distance_to_target_sq = global_position.distance_squared_to(formation_target_pos)
			# <<< GÜNCELLENDİ: Varış eşiği artırıldı >>>
			if distance_to_target_sq < 100.0: # Hedefe ulaşıldı (karesi 10 piksel)
				set_current_state(State.IDLE)
				move_direction = Vector2.ZERO
				velocity = Vector2.ZERO # Anında dur
				global_position = formation_target_pos # Tam hedefe oturt (isteğe bağlı)
			else:
				# Hedefe doğru hareket et
				move_direction = (formation_target_pos - global_position).normalized()
				current_separation_weight = 0.0
				target_base_anim = "march" # <<< Temel isim kullanılıyor >>>

		State.IDLE:
			move_direction = Vector2.ZERO # IDLE iken hareket etme
			jitter_target_offset = Vector2.ZERO # IDLE iken jitter yapma
			# <<< GÜNCELLENDİ: Seçilmiş idle indexini kullan >>>
			target_base_anim = "idle" # <<< DOĞRUSU: Sadece temel ismi ver >>>

		State.MOVING:
			if target_enemy != null and is_instance_valid(target_enemy):
				var distance_to_target = global_position.distance_to(target_enemy.global_position)
				var is_ranged = stats.is_ranged # <<< YENİ KONTROL >>>

				if is_ranged:
					# Menzilli Birim Mantığı
					if distance_to_target <= stats.attack_range:
						# Menzil içinde, dur ve saldırıya geç
						move_direction = Vector2.ZERO
						set_current_state(State.ATTACKING)
						attack_timer = 0.0 # Hemen saldırıya hazır ol
					else:
						# Menzil dışı, yaklaş
						move_direction = (target_enemy.global_position - global_position).normalized()
						# <<< DÜZELTME: Menzil dışı olsa bile hedefi ata! >>>
						target_enemy = target_enemy
						#print("DEBUG (%s): Ranged setting target to %s (out of range), move_direction: %s" % [name, target_enemy.name, move_direction.round()]) # <<< YENİ DEBUG >>>
				else:
					# Yakın Dövüşçü Birim Mantığı
					if distance_to_target <= stats.attack_range:
						# Menzil içinde (yakınında), dur ve saldırıya geç
						move_direction = Vector2.ZERO
						set_current_state(State.ATTACKING)
						attack_timer = 0.0
					else:
						# Menzil dışı, yaklaş
						move_direction = (target_enemy.global_position - global_position).normalized()
			else:
				# Belirli bir hedef yok, zamanlayıcıyı kontrol et ve en yakını ara
				find_target_timer -= delta
				if find_target_timer <= 0:
					find_target_timer = FIND_TARGET_INTERVAL # Zamanlayıcıyı sıfırla
					#print("DEBUG (%s): Find target timer expired. Searching..." % name) # <<< YENİ DEBUG >>>
					var closest_enemy = _find_closest_enemy_on_map()
					if closest_enemy != null and is_instance_valid(closest_enemy):
						#print("DEBUG (%s): Found closest enemy: %s" % [name, closest_enemy.name]) # <<< YENİ DEBUG >>>
						var distance_to_closest = global_position.distance_to(closest_enemy.global_position)
						var is_ranged = stats.is_ranged # <<< YENİ KONTROL >>>

						if is_ranged:
							# Menzilli Birim Mantığı (Hedef Yok)
							if distance_to_closest <= stats.attack_range:
								# En yakın düşman menzilde, onu hedef al ve saldırıya geç
								target_enemy = closest_enemy
								move_direction = Vector2.ZERO
								set_current_state(State.ATTACKING)
								attack_timer = 0.0
							else:
								# En yakın düşmana yaklaş
								move_direction = (closest_enemy.global_position - global_position).normalized()
								# <<< DÜZELTME: Menzil dışı olsa bile hedefi ata! >>>
								target_enemy = closest_enemy
								#print("DEBUG (%s): Ranged setting target to %s (out of range), move_direction: %s" % [name, closest_enemy.name, move_direction.round()]) # <<< YENİ DEBUG >>>
						else:
							# Yakın Dövüşçü Birim Mantığı (Hedef Yok)
							# Her zaman en yakına doğru hareket et
							move_direction = (closest_enemy.global_position - global_position).normalized()
							# <<< YENİ: Yakın dövüşçü de hedefi hemen alsın >>>
							target_enemy = closest_enemy 
							#print("DEBUG (%s): Melee setting target to %s, move_direction: %s" % [name, closest_enemy.name, move_direction.round()]) # <<< YENİ DEBUG >>>
						# <<< DEĞİŞTİ: Düşman bulunamazsa IDLE yapma >>>
						#else:
						#	# Zamanlayıcı doldu ama düşman yok, IDLE'a geç
						#	set_current_state(State.IDLE)
						#	move_direction = Vector2.ZERO
						# Zamanlayıcı dolmadıysa veya hedef bulunduysa mevcut yönde devam et (veya sıfır)
						# (move_direction zaten döngünün başında veya önceki if bloklarında ayarlandı)

			# Hareket varsa animasyonu ayarla
			if move_direction != Vector2.ZERO:
				target_base_anim = "run" # <<< Temel isim kullanılıyor >>>

		State.ATTACKING:
			# <<< YENİ: Saldırı sırasında ayrılma ağırlığını artır >>>
			current_separation_weight = ATTACKING_SEPARATION_WEIGHT
			if target_enemy != null and is_instance_valid(target_enemy):
				# <<< YENİ: Saldırıdan Önce Hedef Kontrolü >>>
				if target_enemy.get_current_state() == State.DEAD or target_enemy.get_current_state() == State.FAINTED:
					# Hedef artık aktif değil, MOVING'e geç
					target_enemy = null
					melee_damage_timer = 0.0 
					_target_for_pending_melee = null
					attack_timer = stats.attack_speed # Reset attack timer too
					set_current_state(State.MOVING)
					jitter_target_offset = Vector2.ZERO 
				else:
					# Hedef hala geçerli
					var distance_to_target = global_position.distance_to(target_enemy.global_position)
					var exit_range = stats.attack_range + 5.0 
					
					# Saldırı/Hasar bekleme durumu kontrolü
					var attack_timer_active = attack_timer > 0 and attack_timer < stats.attack_speed 
					var damage_pending = melee_damage_timer > 0 
					var attack_in_progress = attack_timer_active or damage_pending
					
					# Menzildeyse VEYA saldırı zaten başladıysa devam et
					if distance_to_target <= exit_range or attack_in_progress:
						move_direction = Vector2.ZERO 
						
						# Gerçek saldırı menzilindeyse
						if distance_to_target <= stats.attack_range:
							stuck_attacking_timer = 0.0 # Menzildeyken sayacı sıfırla
							# Hasar beklemiyorsa saldırı zamanlayıcısını yönet
							if not damage_pending: 
								attack_timer -= delta
								if attack_timer <= 0:
									_attack(target_enemy)
									attack_timer = stats.attack_speed # Saldırıdan hemen sonra sıfırla
						else: # Menzil dışında ama exit_range içinde veya saldırı devam ediyor
							stuck_attacking_timer += delta # Menzil dışındayken sayacı artır
							# print("DEBUG (%s): Out of attack range (%f > %f), incrementing stuck timer: %f" % [name, distance_to_target, stats.attack_range, stuck_attacking_timer]) # Debug

						# <<< YENİ: Takılma Kontrolü >>>
						if stuck_attacking_timer > STUCK_ATTACKING_TIMEOUT:
							#print("WARNING (%s): Stuck in ATTACKING state too long! Target: %s. Forcing MOVING." % [name, target_enemy.name])
							target_enemy = null # Yeni hedef ara
							melee_damage_timer = 0.0 # Bekleyen hasarı iptal et
							_target_for_pending_melee = null
							attack_timer = stats.attack_speed # Saldırı sayacını sıfırla
							set_current_state(State.MOVING)
							jitter_target_offset = Vector2.ZERO
							# Bu return önemli, çünkü state değişti, bu frame'de başka işlem yapma
							return 
							
					else: # Menzil dışına çıktı VE saldırı/hasar bekleme durumu YOK
						# print("DEBUG (%s): Target %s moved out of exit_range (%f > %f) AND no attack pending, switching to MOVING." % [name, target_enemy.name, distance_to_target, exit_range]) # Debug
						set_current_state(State.MOVING)
						jitter_target_offset = Vector2.ZERO 
			else:
				# Hedef geçersiz (null veya silinmiş), MOVING'e geç
				target_enemy = null
				melee_damage_timer = 0.0 
				_target_for_pending_melee = null
				attack_timer = stats.attack_speed # Reset attack timer too
				set_current_state(State.MOVING)
				jitter_target_offset = Vector2.ZERO

		State.FLEEING: # <-- GÜNCELLENMİŞ DURUM
			# Tehdit hala geçerli mi? (is_instance_valid kontrolü önemli)
			if current_threat != null and is_instance_valid(current_threat):
				# Tehditten uzağa kaçış yönünü belirle
				move_direction = (global_position - current_threat.global_position).normalized()

				# <<< YENİ: Sınır Kontrolü >>>
				if battle_area_limit.size != Vector2.ZERO: # Eğer sınırlar atanmışsa
					var next_pos = global_position + move_direction * stats.move_speed * delta * 1.1 # Biraz ileri bak

					# X ekseninde sınıra çarpıyor mu?
					if (move_direction.x < 0 and next_pos.x < battle_area_limit.position.x) or \
						(move_direction.x > 0 and next_pos.x > battle_area_limit.end.x):
						move_direction.x = 0 # X yönünde hareketi durdur

					# Y ekseninde sınıra çarpıyor mu?
					if (move_direction.y < 0 and next_pos.y < battle_area_limit.position.y) or \
						(move_direction.y > 0 and next_pos.y > battle_area_limit.end.y):
						move_direction.y = 0 # Y yönünde hareketi durdur

					# Eğer her iki yönde de hareket durduysa (köşeye sıkıştıysa), MOVING'e geç
					if move_direction == Vector2.ZERO:
						set_current_state(State.MOVING)
						current_threat = null # Tehdit artık öncelikli değil
			else:
				# Tehdit yok, MOVING'e geç
				current_threat = null
				set_current_state(State.MOVING)
			# Kaçarken jitter yapmasın
			jitter_target_offset = Vector2.ZERO
			target_base_anim = "run" # <<< Temel isim kullanılıyor >>>

		_: # Beklenmedik durum
			set_current_state(State.IDLE)
			move_direction = Vector2.ZERO
			jitter_target_offset = Vector2.ZERO
			target_base_anim = "idle" # <<< Temel isim kullanılıyor >>>

	# <<< GÜNCELLENDİ: Ayrılma (Separation) Mantığı (Zamanlayıcı Kontrollü) >>>
	var separation_vector = Vector2.ZERO
	if separation_calc_timer <= 0:
		separation_calc_timer = SEPARATION_CALC_INTERVAL # Zamanlayıcıyı sıfırla
		separation_vector = _calculate_separation_vector()
	# <<< Ayrılma hesaplama zamanlayıcı kontrolü sonu >>>
		
	var final_direction = move_direction

	# <<< GÜNCELLENDİ: Animasyon oynatma yeri >>>
	if _current_state != State.ATTACKING and _current_state != State.DEAD and _current_state != State.FAINTED and _current_state != State.VICTORY:
		_play_animation(target_base_anim) # DEAD, FAINTED, VICTORY kendi animasyonlarını kendi fonksiyonlarında ayarlar
	# else: # Animasyon ATTACKING, DEAD, FAINTED, VICTORY durumlarında ayrı yönetiliyor
	# 	pass

	# Eğer ayrılma kuvveti varsa (ve bu frame hesaplandıysa), duruma göre belirlenen ağırlıkla birleştir
	if separation_vector != Vector2.ZERO:
		# Eğer durum makinesi bir yön belirlemediyse (örn. ATTACKING cooldown), sadece separation kullan
		if move_direction == Vector2.ZERO:
			final_direction = separation_vector
		else:
			final_direction = (move_direction * (1.0 - current_separation_weight) + separation_vector * current_separation_weight).normalized()
	# <<< Ayrılma Mantığı Sonu >>>

	# Hız Hesaplama ve move_and_slide
	if stats != null:
		if final_direction != Vector2.ZERO:
			# <<< GÜNCELLENDİ: Duruma göre hız kullan >>>
			if _current_state == State.MARCHING:
				target_velocity = final_direction * MARCHING_SPEED
			else:
				target_velocity = final_direction * stats.move_speed
		else:
			target_velocity = Vector2.ZERO
	else:
		target_velocity = Vector2.ZERO
	velocity = target_velocity 
	move_and_slide()

	# <<< YENİ: Yasak Alan Kontrolü (Clamp) >>>
	if is_instance_valid(battle_scene_ref) and battle_scene_ref.has_method("get_forbidden_areas"):
		var forbidden = battle_scene_ref.get_forbidden_areas()
		for area in forbidden:
			if area.has_point(global_position):
				# Birim yasak alanın içinde, en yakın kenara it
				var center = area.get_center()
				var half_size = area.size * 0.5
				var offset = global_position - center
				
				# Hangi eksende daha az itme gerekecek?
				var overlap_x = half_size.x - abs(offset.x)
				var overlap_y = half_size.y - abs(offset.y)
				
				if overlap_x < overlap_y:
					# X ekseninde it
					global_position.x = center.x + sign(offset.x) * half_size.x
				else:
					# Y ekseninde it
					global_position.y = center.y + sign(offset.y) * half_size.y
				# Pozisyon değiştiği için hızı sıfırlamak iyi olabilir
				velocity = Vector2.ZERO 
	# <<< YASAK ALAN KONTROL SONU >>>

	# <<< GÜNCELLENDİ: Sprite yönünü ayarla (animated_sprite üzerinden) >>>
	if is_instance_valid(animated_sprite):
		# Sadece hareket varsa veya saldırıyorsa yönü güncelle
		if velocity.length_squared() > 0.1 or _current_state == State.ATTACKING:
			# Saldırı durumunda hedefe göre yön belirle
			if _current_state == State.ATTACKING and is_instance_valid(target_enemy):
				if target_enemy.global_position.x > global_position.x: animated_sprite.flip_h = false
				else: animated_sprite.flip_h = true
			# Diğer durumlarda hıza göre belirle
			elif velocity.x > 0.1: animated_sprite.flip_h = false
			elif velocity.x < -0.1: animated_sprite.flip_h = true

	# Pozisyon Debug
	position_debug_timer += delta
	if position_debug_timer >= POSITION_DEBUG_INTERVAL:
		var target_name = "None"
		if target_enemy != null and is_instance_valid(target_enemy): # Yine de garanti olsun
			target_name = target_enemy.name
		#print("POS DEBUG: %s at %s (State: %s, Target: %s, HP: %d)" % [
			#name, 
			#global_position.round(), 
			#State.keys()[_current_state],
			#target_name,
			#current_hp 
		#])
		#position_debug_timer = 0.0

# Haritadaki en yakın düşmanı bulur (Atlılar için okçu, Okçular için Kalkanlı önceliği ile)
func _find_closest_enemy_on_map() -> Unit:
	if battle_scene_ref == null or not is_instance_valid(battle_scene_ref):
		return null
	var enemies: Array[Unit] = []
	if team_id == 0: enemies = battle_scene_ref.enemy_units
	elif team_id == 1: enemies = battle_scene_ref.player_units
	else: return null

	var my_stats = self.stats # Kendi istatistiklerimize erişim
	if my_stats == null: return null # Güvenlik kontrolü

	var is_cavalry = my_stats.unit_type_id == "cavalry"
	var is_archer = my_stats.unit_type_id == "archer"

	# --- Özel Öncelik Kontrolleri --- 
	
	# Okçu için Kalkanlı Önceliği (YENİ DETAYLI MANTIK)
	if is_archer:
		var closest_shieldbearer_in_range: Unit = null
		var min_shieldbearer_dist_sq_in_range: float = INF
		var closest_other_enemy_in_range: Unit = null # Kalkanlı yoksa diğer en yakın (menzildeki)
		var min_other_dist_sq_in_range: float = INF
		var closest_shieldbearer_overall: Unit = null # Menzil dışı en yakın kalkanlı (fallback)
		var min_shieldbearer_dist_sq_overall: float = INF
		var closest_enemy_overall: Unit = null # Genel en yakın (son fallback)
		var min_dist_sq_overall: float = INF

		var attack_range_sq = stats.attack_range * stats.attack_range

		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.get_current_state() == State.FAINTED or enemy.get_current_state() == State.DEAD or enemy.stats == null:
				continue 
				
			var distance_sq = global_position.distance_squared_to(enemy.global_position)
			var is_shieldbearer = enemy.stats.unit_type_id == "shieldbearer"
			var is_in_range = distance_sq <= attack_range_sq

			# 1. Menzildeki Kalkanlıları Kontrol Et
			if is_shieldbearer and is_in_range:
				if distance_sq < min_shieldbearer_dist_sq_in_range:
					min_shieldbearer_dist_sq_in_range = distance_sq
					closest_shieldbearer_in_range = enemy
					
			# 2. Menzildeki Diğer Düşmanları Kontrol Et (Eğer henüz menzilde kalkanlı bulmadıysak)
			elif not is_shieldbearer and is_in_range:
				# Sadece HENÜZ menzilde kalkanlı bulamadıysak bunu değerlendir
				if closest_shieldbearer_in_range == null and distance_sq < min_other_dist_sq_in_range:
					min_other_dist_sq_in_range = distance_sq
					closest_other_enemy_in_range = enemy
			
			# 3. Menzil Dışı En Yakın Kalkanlıyı Takip Et (Fallback)
			if is_shieldbearer: # Menzilde olsun veya olmasın
				if distance_sq < min_shieldbearer_dist_sq_overall:
					min_shieldbearer_dist_sq_overall = distance_sq
					closest_shieldbearer_overall = enemy
					
			# 4. Genel En Yakın Düşmanı Takip Et (Son Fallback)
			# Not: Düşük can önceliği şimdilik kaldırıldı, bu mantıkla çakışabilir.
			# İleride tekrar eklenebilir.
			if distance_sq < min_dist_sq_overall:
				min_dist_sq_overall = distance_sq
				closest_enemy_overall = enemy

		# Sonuçları Değerlendir ve Dön
		if closest_shieldbearer_in_range != null:
			# print("DEBUG ARCHER TARGET: Closest Shieldbearer IN RANGE: %s" % closest_shieldbearer_in_range.name) # Debug
			return closest_shieldbearer_in_range
		elif closest_other_enemy_in_range != null:
			# print("DEBUG ARCHER TARGET: Closest Other IN RANGE: %s" % closest_other_enemy_in_range.name) # Debug
			return closest_other_enemy_in_range
		elif closest_shieldbearer_overall != null:
			# print("DEBUG ARCHER TARGET: Closest Shieldbearer OVERALL (Fallback): %s" % closest_shieldbearer_overall.name) # Debug
			return closest_shieldbearer_overall
		else:
			# print("DEBUG ARCHER TARGET: Closest Enemy OVERALL (Last Fallback): %s" % (closest_enemy_overall.name if closest_enemy_overall else 'None')) # Debug
			return closest_enemy_overall # Bu null olabilir
		
	# <<< ESKİ Kalkanlı Önceliği (Sadece en yakına bakıyordu) >>>
	# if is_archer:
	# 	var closest_shieldbearer: Unit = null
	# 	var min_shieldbearer_dist_sq: float = INF
	# 	for enemy in enemies:
	# 		if not is_instance_valid(enemy) or ... enemy.stats.unit_type_id != "shieldbearer":
	# 			continue 
	# 		var distance_sq = ...
	# 		if distance_sq < min_shieldbearer_dist_sq:
	# 			min_shieldbearer_dist_sq = distance_sq
	# 			closest_shieldbearer = enemy
	# 	if closest_shieldbearer != null:
	# 		return closest_shieldbearer
	# 	# else: Kalkanlı bulunamadı, normal aramaya devam
		
	# Atlılar için Okçu Önceliği (Bu mantık aynı kalabilir)
	if is_cavalry:
		var closest_archer: Unit = null
		var min_archer_distance_sq: float = INF
		for enemy in enemies:
			# <<< GÜNCELLENDİ: Getter kullan >>>
			if not is_instance_valid(enemy) or enemy.get_current_state() == State.FAINTED or enemy.get_current_state() == State.DEAD or enemy.stats == null or enemy.stats.unit_type_id != "archer":
				continue
			var distance_sq = global_position.distance_squared_to(enemy.global_position)
			if distance_sq < min_archer_distance_sq:
				min_archer_distance_sq = distance_sq
				closest_archer = enemy
		if closest_archer != null:
			return closest_archer
		# else: Okçu bulunamadı, normal aramaya devam
	
	# --- Genel Arama (Düşük Canlı Önceliği ile) --- 
	var closest_enemy: Unit = null
	var min_distance_sq: float = INF
	var closest_low_health_enemy: Unit = null # <<< YENİ
	var min_low_health_distance_sq: float = INF # <<< YENİ
	
	for enemy in enemies:
		# <<< GÜNCELLENDİ: Getter kullan >>>
		# <<< OKÇU ZATEN YUKARIDA HEDEFLENDİ, BURADA ATLA >>>
		if is_archer or not is_instance_valid(enemy) or enemy.get_current_state() == State.FAINTED or enemy.get_current_state() == State.DEAD or enemy.stats == null or enemy.current_hp <= 0: # Canı 0 olanı da atla
			continue
			
		var distance_sq = global_position.distance_squared_to(enemy.global_position)
		
		# En yakını her zaman takip et
		if distance_sq < min_distance_sq:
			min_distance_sq = distance_sq
			closest_enemy = enemy
			
		# Düşük canlı kontrolü
		if enemy.stats.max_hp > 0: # Bölme hatasını önle
			var health_percentage = float(enemy.current_hp) / enemy.stats.max_hp
			if health_percentage < LOW_HEALTH_THRESHOLD:
				# Düşük canlı, mesafeyi kontrol et
				if distance_sq < min_low_health_distance_sq:
					min_low_health_distance_sq = distance_sq
					closest_low_health_enemy = enemy

	# --- Sonuç Seçimi --- 
	# <<< OKÇU ZATEN YUKARIDA DÖNDÜ >>>
	if is_archer: return null # Bu noktaya gelinmemeli ama garanti olsun
	
	if closest_low_health_enemy != null:
		# Düşük canlı düşman bulundu, onu hedefle
		# print("DEBUG (%s): Prioritizing low health enemy %s" % [name, closest_low_health_enemy.name]) # DEBUG
		return closest_low_health_enemy
	elif closest_enemy != null:
		# Düşük canlı yok, en yakını hedefle
		# print("DEBUG (%s): No low health enemy found, targeting closest: %s" % [name, closest_enemy.name]) # DEBUG
		return closest_enemy
	else:
		# Hiç düşman bulunamadı
		return null

func _attack(target: Unit) -> void:
	# <<< YENİ: Fonksiyon çağrısını ve hedefi logla >>>
	var target_name = "null" 
	if is_instance_valid(target):
		target_name = target.name
	#print("DEBUG: _attack called by %s for target %s" % [name, target_name])

	if stats == null or target == null or not is_instance_valid(target):
		#print("DEBUG: _attack aborted for %s, target invalid or null." % name) # <<< YENİ: Neden bittiğini logla >>>
		return

	# Saldırı zamanlayıcısını hemen sıfırla (bir sonraki saldırı için)
	attack_timer = stats.attack_speed
	
	# <<< YENİ: Menzil Kontrolü (is_ranged bayrağı ile) >>>
	# var is_ranged_unit = stats.attack_range > 50.0 # ESKİ KONTROL
	var is_ranged_unit = stats.is_ranged # <<< YENİ KONTROL >>>

	var is_a_miss = false # Bu saldırı ıskalama mı?
	# Iskalama Kontrolü
	if stats.hit_chance < 1.0:
		if randf() > stats.hit_chance:
			is_a_miss = true
			# print("%s ISKALADI! -> %s" % [name, target.name]) # İstersen logu aç

	# <<< GÜNCELLENDİ: Hasar Uygulama ve Zamanlayıcı Başlatma >>>
	if not is_ranged_unit: # Yakın Dövüşçü
		if not is_a_miss:
			# <<< GÜNCELLENDİ: Saldırı Animasyonu (Temel isim) >>>
			_play_animation("attack") 
			# <<< DEĞİŞTİ: Hasarı hemen uygulama, zamanlayıcı başlat >>>
			# var damage = stats.attack_damage
			# target.take_damage(damage)
			melee_damage_timer = MELEE_DAMAGE_DELAY
			_target_for_pending_melee = target
			#print("DEBUG (%s): MELEE - Attack animation started, damage delay timer set for %s." % [name, target_name]) # <<< GÜNCELLENMİŞ DEBUG >>>
		# else: # Iskaladıysa bir şey yapma
			pass 
	else: # Menzilli Birim
		if not is_waiting_to_fire_arrow: # Zaten bir efekt beklemiyorsa yenisini başlat
			# <<< GÜNCELLENDİ: Saldırı Animasyonu (Temel isim) >>>
			_play_animation("attack") 
			is_waiting_to_fire_arrow = true
			arrow_fire_timer = randf_range(0.0, MAX_ARROW_FIRE_DELAY)
			_target_for_pending_arrow = target # Hedefi kaydet
			_pending_arrow_is_miss = is_a_miss # Bu okun ıskalama olup olmadığını kaydet

# <<< Saldırı Efektini Fırlatma/Gösterme Fonksiyonu (Sadece Menzilli Birimler İçin) >>>
func _spawn_attack_effect(target: Unit):
	# Hedefin geçerliliğini tekrar kontrol et
	if not is_instance_valid(target):
		_pending_arrow_is_miss = false
		return
		
	var is_miss = _pending_arrow_is_miss
	_pending_arrow_is_miss = false

	# Sadece okçu ise ok fırlat
	if stats != null and stats.unit_type_id == "archer": # Şimdilik sadece okçu kontrolü
		# <<< YENİ: ArrowScene Geçerli mi Kontrol Et (Detaylı Loglama) >>>
		if ArrowScene == null:
			printerr("Unit (%s): ArrowScene is null BEFORE trying to instantiate! Cannot spawn arrow." % name)
			return
			
		# <<< YENİ: Instantiation Öncesi Loglama >>>
		# print("DEBUG (%s): ArrowScene seems valid (%s). Attempting instantiate..." % [name, ArrowScene]) # Gerekirse aç

		var arrow_instance = ArrowScene.instantiate() # <<< Instantiation Denemesi >>>

		# <<< YENİ: Instantiation Sonrası Kontrol ve Loglama >>>
		if not is_instance_valid(arrow_instance):
			printerr("Unit (%s): FAILED to instantiate ArrowScene! ArrowScene was: %s" % [name, ArrowScene])
			# Instantiation başarısız olduysa ArrowScene'i null yapmayı dene? (Dikkatli ol!)
			# ArrowScene = null # <<< Bu riskli olabilir, şimdilik yapma >>>
			return # Instantiation başarısız olduğu için devam etme
		
		# else: # Başarılı (isteğe bağlı log)
		#	print("DEBUG (%s): Arrow instance created successfully: %s" % [name, arrow_instance]) # Gerekirse aç

		# if is_instance_valid(arrow_instance): # <<< Bu if artık gereksiz, yukarıda kontrol edildi >>>
		var final_target_position: Vector2
		if is_miss:
			# Iskalama: Hedefin etrafında rastgele bir noktaya gönder
			var random_angle = randf() * TAU
			var random_distance = randf_range(MISS_OFFSET_MIN, MISS_OFFSET_MAX)
			var offset_vector = Vector2.RIGHT.rotated(random_angle) * random_distance
			final_target_position = target.global_position + offset_vector
		else:
			# Vuruş: Doğrudan hedefin o anki pozisyonuna (Görsel olarak)
			final_target_position = target.global_position

		if is_instance_valid(battle_scene_ref):
			battle_scene_ref.add_child(arrow_instance)
			# Okun fire fonksiyonunu çağır (parametreler aynı)
			arrow_instance.fire(
				global_position,
				final_target_position,
				stats.attack_damage, 
				self.team_id,
				target,
				is_miss
			)
		else:
			printerr("Unit (%s): Cannot spawn arrow, battle_scene_ref is invalid! Freeing arrow instance." % name)
			if is_instance_valid(arrow_instance): # Güvenlik kontrolü
				arrow_instance.queue_free()
		# else: # <<< Bu else artık gereksiz >>>
		# 	# Instantiation başarısız olduysa hata mesajı YUKARIDA yazdırıldı.
		# 	pass 
		# <<< Instance kontrolü SONU >>>

	# else:
	#   # İleride diğer menzilli birim türleri için efektler eklenebilir
	#   pass
# <<< FONKSİYON SONU >>>

# <<< YENİ: Varyant İndeksi Ayarlama Fonksiyonu >>>
func _set_random_variant_index(anim_type: String) -> void:
	# Gerekli kontroller
	if stats == null:
		_selected_variant_index = 1
		return
	
	# Birim tipine göre prefix al
	var prefix = stats.unit_type_id
	if stats.unit_type_id == "swordsman": prefix = "sword"
	elif stats.unit_type_id == "spearman": prefix = "spear"
	elif stats.unit_type_id == "shieldbearer": prefix = "shield" # <<< YENİ KISALTMA >>>
	
	# O prefix için alternatifleri al
	var alternatives = {}
	if prefix == "sword": alternatives = {"idle": 2, "victory": 2, "attack": 2, "block": 1, "run": 1, "march": 1, "dead": 1, "faint": 1}
	elif prefix == "archer": alternatives = {"idle": 2, "victory": 3, "attack": 1, "block": 1, "run": 1, "march": 1, "dead": 1, "faint": 1}
	elif prefix == "spear": alternatives = {"idle": 2, "victory": 2, "attack": 2, "block": 1, "run": 1, "march": 1, "dead": 1, "faint": 1}
	elif prefix == "cavalry": alternatives = {"idle": 1, "victory": 2, "attack": 3, "block": 1, "run": 2, "march": 1, "dead": 1, "faint": 1}
	else: alternatives = {"idle": 1, "run": 1} # Varsayılan

	# <<< GÜNCELLENMİŞ MANTIK >>>
	# Sadece idle veya run için index ayarla
	if alternatives.has(anim_type) and (anim_type == "idle" or anim_type == "run"):
		var count = alternatives[anim_type]
		if count > 1:
			_selected_variant_index = randi_range(1, count)
			# <<< RUN/IDLE DEBUG >>>
			#print("DEBUG (%s): Setting %s variant index to %d" % [name, anim_type, _selected_variant_index])
			# <<< DEBUG SONU >>>
		else: # count <= 1
			_selected_variant_index = 1
			# print("DEBUG (%s): Setting %s variant index to 1 (Count <= 1)" % [name, anim_type]) # Gerekirse aç
	else:
		# Eğer anim_type idle/run değilse veya alternatives içinde yoksa, index 1'de kalır.
		# (Bu durum normalde _set_random_variant_index çağrıları nedeniyle olmamalı)
		_selected_variant_index = 1 
# <<< YENİ FONKSİYON SONU >>>

# <<< YENİ Fonksiyon: İstenen animasyonu (alternatifleri rastgele seçerek) oynatır >>>
func _play_animation(base_anim_name: String) -> void:
	# Gerekli node'lar geçerli mi kontrol et
	if stats == null or not is_instance_valid(animated_sprite) or not is_instance_valid(animated_sprite.sprite_frames):
		return

	# <<< YENİ: SpriteFrames Hazır mı Kontrolü >>>
	# Eğer SpriteFrames henüz animasyon içermiyorsa (yüklenmemiş olabilir), işlemi ertele.
	if animated_sprite.sprite_frames.get_animation_names().size() == 0:
		# print("DEBUG ANIM WARN: Unit='%s', SpriteFrames not ready yet (0 animations found). Skipping check for '%s'." % [name, base_anim_name]) # Gerekirse aç
		return # Henüz hazır değil, bu karede animasyonu ayarlama

	# <<< GÜNCELLENDİ: Prefix'i tekrar manuel ayarla >>>
	var prefix = stats.unit_type_id # Varsayılan
	if stats.unit_type_id == "swordsman":
		prefix = "sword"
	elif stats.unit_type_id == "spearman":
		prefix = "spear"
	elif stats.unit_type_id == "shieldbearer":
		prefix = "shield" # <<< YENİ KISALTMA >>>

	# <<< GÜNCELLENDİ: Alternatifler Sözlüğü (Kısa prefix'lerle) >>>
	var alternatives = {
		"sword": { # "swordsman" yerine
			"idle": 2,
			"victory": 2,
			"attack": 2, # <<< GERİ ALINDI: Kullanıcı 2 attack animasyonu olduğunu belirtti >>>
			"block": 1,
			"run": 1,
			"march": 1,
			"dead": 1,
			"faint": 1
		},
		"archer": { # Değişiklik yok
			"idle": 2,
			"victory": 3,
			"attack": 1,
			"block": 1,
			"run": 1,
			"march": 1,
			"dead": 1,
			"faint": 1
		},
		"spear": { # "spearman" yerine
			"idle": 2,
			"victory": 2,
			"attack": 2,
			"block": 1,
			"run": 1,
			"march": 1,
			"dead": 1,
			"faint": 1
		},
		"cavalry": { # Değişiklik yok
			"idle": 1,
			"victory": 2,
			"attack": 3,
			"block": 1,
			"run": 2,
			"march": 1,
			"dead": 1,
			"faint": 1
		},
		"shield": { # "shieldbearer" yerine <<< YENİ >>>
			"idle": 1,
			"victory": 1,
			"attack": 1,
			"block": 1, 
			"run": 1,
			"march": 1,
			"dead": 1,
			"faint": 1
		}
	}

	var anim_index = 1
	var full_anim_name = ""
	var current_alternatives = {} # Bu prefix için alternatifler

	# Doğru alternatif setini al
	if alternatives.has(prefix):
		current_alternatives = alternatives[prefix]
	else:
		#printerr("Unknown unit type prefix in alternatives: %s (UnitType: %s). Using default alternatives." % [prefix, stats.unit_type_id]) # Hata mesajına UnitType eklendi
		current_alternatives = {"idle": 1, "victory": 1, "attack": 1, "block": 1, "run": 1, "march": 1, "dead": 1, "faint": 1}

	# Eğer temel isim için alternatif tanımı varsa
	if current_alternatives.has(base_anim_name):
		var count = current_alternatives[base_anim_name]
		# <<< GÜNCELLENDİ: Idle ve Run için özel durum >>>
		if base_anim_name == "idle" or base_anim_name == "run":
			if count > 1:
				anim_index = _selected_variant_index # Önceden seçilmiş indeksi kullan
			else:
				anim_index = 1 # Sadece 1 alternatif varsa onu kullan
		# <<< GÜNCELLENDİ: Diğer animasyonlar için rastgele seçim >>>
		elif count > 1: 
			# Diğer alternatifler (örn: attack, victory) için rastgele seç
			anim_index = randi_range(1, count)
			# <<< YENİ DEBUG (Doğru Yer) >>>
			# if base_anim_name == "attack" or base_anim_name == "victory":
			# 	print("DEBUG (%s): Randomly selected %s index: %d (Count: %d)" % [name, base_anim_name, anim_index, count]) # Debug için kapatıldı
			# <<< DEBUG SONU >>>
		# <<< YENİ: Hiç alternatif yoksa veya sadece 1 varsa >>>
		else: # count == 1 veya count == 0 (hata durumu)
			anim_index = 1 # Sadece 1. indexi kullan
		
		# Tam animasyon adını oluştur
		full_anim_name = prefix + "_" + base_anim_name + str(anim_index)
	else:
		# Alternatif tanımı yoksa (örn. dead, faint, march, block), sadece index 1'i kullan
		# VEYA Hatalı/bilinmeyen bir temel isim gelirse, varsayılan idle dene
		#if not current_alternatives.has(base_anim_name): # Sadece gerçekten bilinmiyorsa hata ver
			#printerr("Unknown base animation name: '%s' for unit %s (prefix: %s). Trying default idle." % [base_anim_name, name, prefix])
		full_anim_name = prefix + "_idle1" # Hata durumunda idle1'e dön
		anim_index = 1 # İndexi de sıfırla

	# <<< YENİ: Detaylı Kontrol Öncesi Loglama (Yorumlandı) >>>
	# print("DEBUG ANIM CHECK: Unit='%s', Checking for '%s' in SpriteFrames: %s" % [name, full_anim_name, animated_sprite.sprite_frames])

	# Animasyon var mı kontrol et
	var animation_exists = animated_sprite.sprite_frames.has_animation(full_anim_name) # <<< Sonucu değişkene ata

	if animation_exists: # <<< Değişkeni kullan
		# <<< YENİ: Log Animation Found (Yorumlandı) >>>
		# print("DEBUG ANIM FOUND: Unit='%s', Animation '%s' EXISTS." % [name, full_anim_name])
		# Sadece farklıysa oynat
		if animated_sprite.animation != full_anim_name:
			var old_anim = animated_sprite.animation # Eski animasyonu kaydet
			animated_sprite.play(full_anim_name)
			# <<< YENİ: Log Animation Played (Yorumlandı) >>>
			# print("DEBUG ANIM PLAYING: Unit='%s', Playing '%s' (was '%s')." % [name, full_anim_name, old_anim])
		# else: # Zaten oynuyor (İsteğe bağlı: loglayabilirsin)
		#	print("DEBUG ANIM SKIPPING: Unit='%s', Animation '%s' already playing." % [name, full_anim_name])
			pass
	else: # Animasyon bulunamadıysa
		# <<< YENİ: Log Animation Not Found (BEFORE printerr) (Yorumlandı) >>>
		# print("DEBUG ANIM NOT FOUND: Unit='%s', Animation '%s' DOES NOT EXIST in SpriteFrames: %s." % [name, full_anim_name, animated_sprite.sprite_frames])
		# Hata mesajını yazdır (Bu artık olmamalı, ama güvenlik için kalsın)
		printerr("Animation not found: %s (Searched for: %s, Base: %s, Index: %d)" % [prefix, full_anim_name, base_anim_name, anim_index])

# <<< YENİ: Animasyon Bittiğinde Çağrılan Fonksiyon >>>
func _on_animation_finished() -> void:
	# Gerekli node'lar geçerli mi kontrol et
	if stats == null or not is_instance_valid(animated_sprite):
		return

	var finished_anim_name = animated_sprite.animation
	# <<< GÜNCELLENDİ: Prefix'i tekrar manuel ayarla >>>
	var prefix = stats.unit_type_id # Varsayılan
	if stats.unit_type_id == "swordsman":
		prefix = "sword"
	elif stats.unit_type_id == "spearman":
		prefix = "spear"
	elif stats.unit_type_id == "shieldbearer":
		prefix = "shield"

	# Biten animasyonun temel adını ve indeksini bulmaya çalışalım
	var base_name = ""
	var index_str = ""
	# Sayıyı ayırmak için: prefix + "_" kısmını kaldırıp kalanını ayır
	var remaining = finished_anim_name.trim_prefix(prefix + "_")
	# <<< GÜNCELLENDİ: Sayı bulma mantığı - Rakam olmayan ilk karaktere kadar al >>>
	for i in range(remaining.length()):
		if not remaining[i].is_valid_int():
			# Rakam olmayan bir karakter bulundu (veya string bitti)
			if i > 0 and remaining[i-1].is_valid_int(): # Eğer önceki karakter rakamsa, oradan böl
				base_name = remaining.substr(0, i)
				index_str = remaining.substr(i)
				# index_str'nin gerçekten sayı olduğunu kontrol et (isteğe bağlı ama güvenli)
				if not index_str.is_valid_int(): index_str = "1" # Sayı değilse 1 varsay
				break
			else: # Rakam olmayan karakter en başta veya arada rakam yok
				base_name = remaining
				index_str = "1"
				break
		# Stringin sonuna geldiysek ve hepsi rakamsa (pek olası değil ama)
		elif i == remaining.length() - 1:
			base_name = remaining # Ya da hata ver?
			index_str = "1"
	# Rakam olmayan karakter hiç bulunamadıysa (yani animasyon adı sadece prefix + _), idle varsay
	if base_name == "":
		base_name = "idle"
		index_str = "1"

	# print("DEBUG (%s): Animation finished: %s, Base: '%s', Index: '%s'" % [name, finished_anim_name, base_name, index_str]) # Gerekirse aç

	# Eğer biten animasyon saldırı veya blok animasyonu ise idle'a dön
	if base_name == "attack" or base_name == "block":
		# Sadece birim hala hayattaysa idle oyna
		if _current_state != State.DEAD and _current_state != State.FAINTED:
			_play_animation("idle")

# Yakındaki yakın dövüş tehdidini bulur (Okçular için)
func _find_nearby_melee_threat() -> Unit:
	if stats == null or stats.unit_type_id != "archer": return null 
	if battle_scene_ref == null or not is_instance_valid(battle_scene_ref): return null # BattleScene ref lazım

	# <<< DEBUG: Bu fonksiyon artık sadece timer ile çağrılmalı >>>
	# print("DEBUG (%s): _find_nearby_melee_threat CALLED (by timer)" % name) # İstersen bu logu açabilirsin

	var enemies: Array[Unit] = []
	if team_id == 0: enemies = battle_scene_ref.enemy_units
	elif team_id == 1: enemies = battle_scene_ref.player_units
	else: return null

	var closest_threat: Unit = null
	var min_distance_sq = ARCHER_FLEE_DISTANCE * ARCHER_FLEE_DISTANCE # Kareli mesafe ile karşılaştır

	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		# <<< GÜNCELLENDİ: Getter kullan >>>
		if enemy.stats == null or enemy.is_queued_for_deletion() or enemy.get_current_state() == State.DEAD or enemy.get_current_state() == State.FAINTED or enemy.stats.is_ranged:
			continue 

		var distance_sq = global_position.distance_squared_to(enemy.global_position)
		if distance_sq < min_distance_sq:
			# print("DEBUG (%s): Potential melee threat %s at distance %s (sq)" % [name, enemy.name, distance_sq]) # Kalabalık yapabilir
			# En yakını değil, _herhangi_ biri yeterli olabilir, ama şimdilik en yakını bulalım
			# Şimdilik ilk bulduğunu döndürelim
			# print("DEBUG (%s):    - >>> MELEE THREAT FOUND: %s <<<" % [name, enemy.name])
			return enemy # Tehdit bulundu!

	return null # Tehdit yok

# <<< YENİ: Yardımcı Fonksiyon >>>
# Algılama alanındaki en yakın okçuyu bulur
func _find_closest_archer_in_detection_area() -> Unit:
	var closest_archer: Unit = null
	var min_distance_sq: float = INF
	
	if not is_instance_valid(detection_area): return null # Safety check

	var overlapping_areas = detection_area.get_overlapping_areas()
	for area in overlapping_areas:
		var owner = area.get_owner()
		# Check if owner is a Unit, not self, different team, and valid
		# <<< GÜNCELLENDİ: Getter kullan >>>
		if owner is Unit and owner != self and owner.team_id != self.team_id and is_instance_valid(owner) and not owner.is_queued_for_deletion() and owner.get_current_state() != State.DEAD and owner.get_current_state() != State.FAINTED and owner.stats != null:
			# Check if it's an archer
			if owner.stats.unit_type_id == "archer":
				var distance_sq = global_position.distance_squared_to(owner.global_position)
				if distance_sq < min_distance_sq:
					min_distance_sq = distance_sq
					closest_archer = owner
					
	return closest_archer
# <<< YENİ SONU >>>

# --- Sinyal Callbackleri ---
func _on_detection_area_area_entered(area: Area2D) -> void:
	# <<< GÜNCELLENDİ: FLEEING durumunda da işlem yapma >>>
	if _current_state == State.FLEEING or _current_state == State.DEAD or _current_state == State.FAINTED: return # Ölü/Baygın/Kaçanlar hedef değiştirmez
	var owner = area.get_owner()
	if owner is Unit and owner != self and owner.team_id != self.team_id:
		var potential_target = owner as Unit
		# <<< GÜNCELLENDİ: Getter kullan >>>
		if not is_instance_valid(potential_target) or potential_target.get_current_state() == State.FAINTED or potential_target.get_current_state() == State.DEAD:
			return

		if potential_target.stats == null:
			return

		var my_stats = self.stats
		if my_stats == null: return

		var is_cavalry = my_stats.unit_type_id == "cavalry"
		var is_archer = my_stats.unit_type_id == "archer"
		
		var potential_is_archer = potential_target.stats.unit_type_id == "archer"
		var potential_is_shieldbearer = potential_target.stats.unit_type_id == "shieldbearer"

		var has_valid_target = target_enemy != null and is_instance_valid(target_enemy) and target_enemy.stats != null and target_enemy.get_current_state() != State.DEAD and target_enemy.get_current_state() != State.FAINTED
		var current_target_is_archer = false
		var current_target_is_shieldbearer = false
		var current_target_name = "None"
		if has_valid_target:
			current_target_is_archer = target_enemy.stats.unit_type_id == "archer"
			current_target_is_shieldbearer = target_enemy.stats.unit_type_id == "shieldbearer"
			current_target_name = target_enemy.name

		var should_target = false
		var reason = ""
		
		if is_archer: # Okçu Mantığı
			if potential_is_shieldbearer:
				if not has_valid_target or not current_target_is_shieldbearer:
					should_target = true
					reason = "New shieldbearer, current target is not shieldbearer (or none)"
				elif global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position):
					should_target = true
					reason = "New shieldbearer closer than current shieldbearer target"
			else: # Giren Kalkanlı değilse
				if not has_valid_target or (not current_target_is_shieldbearer and global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position)):
					should_target = true
					reason = "New non-shieldbearer, no current shieldbearer target (or closer)"
		
		elif is_cavalry: # Atlı Mantığı
			# <<< GÜNCELLENDİ: Detaylı Atlı Hedefleme Mantığı >>>
			if potential_is_archer: # Giren düşman bir okçu
				if not has_valid_target: # Mevcut hedef yoksa, kesin hedefle
					should_target = true
					reason = "Cavalry targeting first detected archer"
				elif not current_target_is_archer: # Mevcut hedef okçu değilse, okçuyu hedefle
					should_target = true
					reason = "Cavalry switching from non-archer to archer"
				elif global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position):
					# Mevcut hedef zaten okçu, ama yenisi daha yakınsa hedefle
					should_target = true
					reason = "Cavalry switching to closer archer"
				# else: Mevcut okçu hedef daha yakın, değiştirme
					
			else: # Giren düşman okçu DEĞİL
				if not has_valid_target: # Sadece mevcut hedef yoksa diğerlerini hedefle
					should_target = true
					reason = "Cavalry targeting non-archer (no current target)"
			# else: Mevcut hedef varken başka bir non-archer hedefleme
				
		else: # Diğer Birimler (Kılıçlı, Mızraklı) - Eski Mantık
			# Okçu veya Atlı değilse, her zaman en yakını hedefle
			# <<< GÜNCELLENDİ: Hedef Değiştirme Koşulu Daha Katı Hale Getirildi >>>
			if not has_valid_target: # Mevcut hedef yoksa kesin hedefle
				should_target = true
				reason = "Default unit targeting first detected enemy"
			elif global_position.distance_squared_to(potential_target.global_position) < global_position.distance_squared_to(target_enemy.global_position) * 0.75: # Yeni hedef %25 daha yakınsa DEĞİŞTİR
				should_target = true
				reason = "Default unit targeting significantly closer enemy"

		if should_target:
			target_enemy = potential_target
			# print("DEBUG (%s): SWITCHING TARGET to %s. Reason: %s" % [name, potential_target.name, reason]) # Gerekirse logu aç
			if _current_state == State.IDLE:
				set_current_state(State.MOVING)
		else:
			pass # Boş else kalsın

func _on_detection_area_area_exited(area: Area2D) -> void:
	# print(">>> SIGNAL area_exited FIRED for %s <<<" % name)
	var owner = area.get_owner()
	if owner is Unit and owner == target_enemy:
		# print("DEBUG (%s): Current target %s exited detection area." % [name, target_enemy.name]) # Kalabalık yapabilir
		# Hedef algılama alanından çıktı.
		# ATTACKING state zaten menzili kontrol ediyor, MOVING state en yakını bulacak.
		# Belki hedefi hemen null yapabiliriz?
		# target_enemy = null # Şimdilik kalsın, MOVING halleder
		pass

# <<< YENİ Fonksiyon: Ayrılma Vektörü Hesaplama >>>
# <<< DÜZELTİLDİ: Girintiler kontrol edildi >>>
func _calculate_separation_vector() -> Vector2:
	var separation_force = Vector2.ZERO
	var neighbor_count = 0

	if not is_instance_valid(friendly_detection_area): return Vector2.ZERO

	var overlapping_areas = friendly_detection_area.get_overlapping_areas()
	for area in overlapping_areas:
		var neighbor = area.get_owner()
		# <<< GÜNCELLENDİ: Getter kullan >>>
		if neighbor is Unit and neighbor != self and neighbor.team_id == self.team_id and is_instance_valid(neighbor) and not neighbor.is_queued_for_deletion() and neighbor.get_current_state() != State.DEAD and neighbor.get_current_state() != State.FAINTED:
			var to_neighbor = neighbor.global_position - global_position
			var dist_sq = to_neighbor.length_squared()
			if dist_sq > 0.01: # Çok küçük mesafeleri atla
				# <<< YENİ: Mesafe ile ters orantılı kuvvet >>>
				var dist = sqrt(dist_sq)
				# Kuvveti komşudan uzağa doğru, mesafe azaldıkça artacak şekilde ayarla.
				# 50.0 sabitini deneyerek ayarlayabiliriz.
				separation_force -= to_neighbor.normalized() * (50.0 / max(dist, 1.0)) 
				neighbor_count += 1

	if neighbor_count > 0:
		# return separation_force.normalized() # Normalize etmek kuvvetin büyüklüğünü yok eder
		return separation_force / neighbor_count # Ortalama bir kuvvet döndür
	else:
		return Vector2.ZERO
# <<< YENİ Fonksiyon Sonu >>>

# <<< YENİ: Zafer Durumuna Geçiş Fonksiyonu >>>
func enter_victory_state() -> void:
	#print("Unit %s entering VICTORY state." % name) # DEBUG
	set_current_state(State.VICTORY)
	# Saldırı, hareket vb. ile ilgili zamanlayıcıları/bayrakları sıfırla (gerekirse)
	attack_timer = 9999 # Çok büyük bir değere ayarla ki tekrar saldırmasın
	is_waiting_to_fire_arrow = false
	_target_for_pending_arrow = null
	_pending_arrow_is_miss = false
	target_enemy = null
	current_threat = null
	jitter_target_offset = Vector2.ZERO
	# Diğer state'lere özel değişkenleri de sıfırlamak gerekebilir
	
	# <<< GÜNCELLENDİ: Zafer Animasyonu (Temel isim - _play_animation rastgele seçecek) >>>
	_play_animation("victory") 

# <<< YENİ: State Setter Fonksiyonu >>>
func set_current_state(new_state) -> void:
	# Aynı duruma tekrar girmeyi önle (gereksiz işlemleri engeller)
	if new_state == _current_state:
		return 

	var old_state = _current_state # Eski durumu sakla (opsiyonel, debug için)
	_current_state = new_state
	# print("DEBUG (%s): State changed from %s to %s" % [name, State.keys()[old_state], State.keys()[_current_state]]) # Gerekirse aç

	# <<< YENİ: ATTACKING durumuna girerken takılma sayacını sıfırla >>>
	if _current_state == State.ATTACKING:
		stuck_attacking_timer = 0.0
		
	# Duruma göre otomatik olarak variant indexini ayarla
	if _current_state == State.MOVING or _current_state == State.FLEEING:
		_set_random_variant_index("run")
	elif _current_state == State.IDLE:
		_set_random_variant_index("idle")
# <<< YENİ FONKSİYON SONU >>>

# <<< YENİ: State Getter Fonksiyonu >>>
func get_current_state():
	return _current_state
