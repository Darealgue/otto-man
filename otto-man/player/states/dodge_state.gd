extends "res://player/states/state.gd"

const DODGE_SPEED := 620.0  # İleri atılma / havada uçuş hızı (Dash: 2500)
# Takla fazının kendi ilerleme hızı. Takla SADECE yerdeyken oynadığı için bu değer
# boşluk aşma menzilini etkilemez - o tamamen DODGE_SPEED'e bağlı. Yani yerdeki dodge
# mesafesini buradan serbestçe ayarlayabilirsin.
# Toplam mesafe (yerde, tuşsuz) = 0.20 * DODGE_SPEED + 0.25 * DODGE_ROLL_SPEED + çıkış kayması
const DODGE_ROLL_SPEED := 850.0
const DODGE_DURATION := 0.45  # Animasyon süresine eşit (0.45s)
const DODGE_COOLDOWN := 0.0   # Cooldown kaldırıldı (stamina ile sınırlı)
const DODGE_END_SPEED_MULTIPLIER := 0.4  # Dodge sonrası hız korunma
# Animasyon fazları: dodge_start (kare 0-3) -> dodge_air (kare 9-12 loop) veya dodge_roll (kare 4-8).
# Kare 4 iniş hareketinin başlangıcı olduğu için uçuş fazına değil taklaya ait.
# Süreler eski tek parça "dodge" animasyonunun kare dağılımıyla birebir aynı (0.05'lik adımlar),
# bu yüzden düz zeminde dodge bugünküyle aynı görünür ve aynı sürer.
const DODGE_FLIGHT_START := 0.20  # Kare 3'ten sonrası: yerdeyse takla (kare 4-8), havadaysa uçuş loop'u (kare 9-12)
const DODGE_ROLL_LENGTH := 0.25   # dodge_roll animasyonunun süresi (kare 4-8)
const DEBUG_DODGE: bool = false

# Animasyon fazı: 0 = start (kare 0-3), 1 = havada uçuş loop'u (kare 9-12), 2 = takla (kare 4-8)
enum DodgePhase { START, AIR, ROLL }
var _phase: int = DodgePhase.START
var _jumped_during_dodge := false  # Zıplayarak dodge'dan çıkıldıysa takla/uçuş devri yapılmaz
var _dodge_dir := 1.0  # enter()'da bir kez belirlenir; sprite.flip_h'a geri beslemeyi önler
var _roll_time_left := 0.0  # Takla animasyonundan kalan süre (pencere bitse de tamamlanır)
var _window_finished := false  # 0.45s pencere sonu işleri bir kez çalışsın
var _roll_air_time := 0.0  # Takla uzatmasında zemin temasının koptuğu süre
const ROLL_AIR_GRACE := 0.10  # Bu kadarlık kopma tolere edilir

var dodge_timer := 0.0
var cooldown_timer := 0.0
var _speed_mult := 1.0  # Karşı Atılım: mesafe çarpanı
var can_dodge := true
var dodge_charges := 1  # Number of available dodge charges
var max_dodge_charges := 1  # Maximum dodge charges
var original_collision_mask := 0  # Store original collision mask
var original_collision_layer := 0  # Store original collision layer
var dodge_start_position := Vector2.ZERO  # Store start position for signal

# Hareket ailesi temas hasarı (zehirli_sekme veya "restless_body" eşiği): dodge sırasında
# içinden geçilen düşmanlara bu dodge başına bir kez temas hasarı + aktif element(ler).
# Gerçek mantık ItemManager.apply_movement_contact_tick() içinde — bkz. o fonksiyon.
var _movement_contact_hit_ids: Array = []
const MOVEMENT_CONTACT_RADIUS := 50.0
const MOVEMENT_CONTACT_DAMAGE := 5.0

func _ready() -> void:
	await owner.ready  # Wait for owner to be ready
	if player:
		if !is_connected("state_entered", player._on_dodge_state_entered):
			connect("state_entered", player._on_dodge_state_entered)
		if !is_connected("state_exited", player._on_dodge_state_exited):
			connect("state_exited", player._on_dodge_state_exited)

func enter():
	# Call parent enter to emit signal
	super.enter()
	
	# Zıplama input'unu engelle
	player.jump_input_blocked = true

	# Animasyon fazını sıfırla ve olası eski uçuş devrini temizle
	_phase = DodgePhase.START
	_jumped_during_dodge = false
	_roll_time_left = 0.0
	_window_finished = false
	_roll_air_time = 0.0
	player.dodge_air_carry = false
	_movement_contact_hit_ids.clear()

	# Charges sistemi kaldırıldı - sadece stamina kontrolü
	
	# Store original collision settings
	original_collision_mask = player.collision_mask
	original_collision_layer = player.collision_layer
	
	# Disable enemy collision (layer 3) - dodge sırasında düşmanlardan geçebilir
	player.collision_mask &= ~(1 << 2)  # Remove enemy collision mask (layer 3)
	player.collision_layer &= ~(1 << 2)  # Remove enemy collision layer (layer 3)
	
	# İnvincibility için hurtbox'ı devre dışı bırak
	var hurtbox = player.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.monitoring = false
		if DEBUG_DODGE:
			print("[Dodge] Hurtbox disabled for invincibility")
	
	# Karşı Atılım: parry sonrası ilk dodge bedava ve 2x uzun
	_speed_mult = player.consume_counter_dash()
	# Stamina tüket
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	if stamina_bar and _speed_mult <= 1.0:
		if stamina_bar.use_charge():
			if DEBUG_DODGE:
				print("[Dodge] Stamina consumed for dodge")
		else:
			if DEBUG_DODGE:
				print("[Dodge] ERROR: No stamina available!")
			# Stamina yoksa dodge yapamaz, idle'a dön
			state_machine.transition_to("Idle")
			return
	
	# Start dodge
	dodge_timer = DODGE_DURATION
	can_dodge = true  # Cooldown kaldırıldı, sadece stamina kontrolü
	dodge_start_position = player.position  # Store start position
	# Play dodge animation
	var anim_player = player.get_node("AnimationPlayer")
	if anim_player:
		# Connect animation finished signal if not already connected
		if not anim_player.is_connected("animation_finished", _on_animation_finished):
			anim_player.connect("animation_finished", _on_animation_finished)
		
		# Check if dodge animation exists (yeni 3 parçalı sistem, yoksa eski tek parçaya düş)
		if anim_player.has_animation("dodge_start"):
			anim_player.play("dodge_start")
			_play_dash_sfx()
			if DEBUG_DODGE:
				print("[Dodge] Playing dodge_start animation - SUCCESS")
		elif anim_player.has_animation("dodge"):
			anim_player.play("dodge")
			_play_dash_sfx()
			if DEBUG_DODGE:
				print("[Dodge] Fallback: playing legacy 'dodge' animation")
		else:
			if DEBUG_DODGE:
				print("[Dodge] ERROR: 'dodge_start' animation not found in AnimationPlayer!")
				print("[Dodge] Available animations: ", anim_player.get_animation_list())
	else:
		if DEBUG_DODGE:
			print("[Dodge] ERROR: AnimationPlayer not found!")
	
	# Set initial dodge velocity based on facing direction
	var dodge_direction = -1 if player.sprite.flip_h else 1
	_dodge_dir = float(dodge_direction)
	player.velocity.x = DODGE_SPEED * _speed_mult * dodge_direction
	# Yer çekimi çalışmaya devam etsin (dash'ten farklı olarak)
	# player.velocity.y = 0  # Bu satırı kaldırdık
	
	# Store start position for signal (already stored above)

const HayaletAdimDecoyScene = preload("res://effects/player_decoy.tscn")
const HAYALET_ADIM_TELEPORT_DIST := 60.0
const HAYALET_ADIM_LIFETIME := 0.4

func physics_update(delta: float):
	dodge_timer -= delta

	# Hayalet Adım: dodge sırasında eğilme -> dodge iptal, sahte kopya bırak, geriye ışınlan
	if Input.is_action_just_pressed("crouch"):
		var im := get_node_or_null("/root/ItemManager")
		if im and im.has_active_item("hayalet_adim"):
			_do_hayalet_adim()
			return

	_movement_contact_tick()


	# Zıplama kontrolü: İlk yarıda zıplama engellensin, son yarıda serbest olsun
	var dodge_progress = 1.0 - (dodge_timer / DODGE_DURATION)  # 0.0 = başlangıç, 1.0 = bitiş
	var can_jump_during_dodge = dodge_progress >= 0.5  # Son yarıda zıplama serbest

	# Animasyon fazı güncellemesi (sadece görsel - fizik/i-frame timeline'ına dokunmaz)
	_update_animation_phase()

	# Faza göre ileri itiş. Zıplayarak dodge'dan çıkıldıysa zıplamanın momentumuna karışma.
	if not _jumped_during_dodge:
		if _phase == DodgePhase.ROLL:
			player.velocity.x = DODGE_ROLL_SPEED * _speed_mult * _dodge_dir
		else:
			player.velocity.x = DODGE_SPEED * _speed_mult * _dodge_dir

	# Debug: Dodge state info
	if DEBUG_DODGE:
		print("[DODGE_DEBUG] Progress: ", dodge_progress, " Timer: ", dodge_timer, " is_on_floor: ", player.is_on_floor(), " velocity: ", player.velocity, " gravity_active: ", dodge_timer < (DODGE_DURATION - 0.1), " block_blocked_timer: ", player.block_input_blocked_timer)
	
	# Block input'u engelle - sadece just_pressed ile (sürekli basılı kalmasını engelle)
	# Özellikle yerçekimi devreye girdiği son 0.1 saniyede engelle
	if Input.is_action_just_pressed("block"):
		if DEBUG_DODGE:
			print("[Dodge] Block input blocked during dodge - progress: ", dodge_progress)
		# Input'u tamamen tüket - diğer state'lerin görmesini engelle
		get_viewport().set_input_as_handled()
		return
	
	# Zıplama input kontrolü - EN YÜKSEK ÖNCELİK
	if Input.is_action_just_pressed("jump"):
		if DEBUG_DODGE:
			print("[Dodge] Jump input detected - progress: ", dodge_progress, " can_jump: ", can_jump_during_dodge, " on_floor: ", player.is_on_floor())
		if can_jump_during_dodge and player.is_on_floor():
			# Son yarıda zıplama yapılabilir - flag'i kaldır
			player.jump_input_blocked = false
			player.jump_block_timer = 0.0  # Timer'ı da sıfırla
			if DEBUG_DODGE:
				print("[Dodge] Jump allowed in second half - progress: ", dodge_progress)
			# Dodge'u iptal etmeden zıplama yap - dodge devam etsin
			player.start_jump()
			# Zıplandığı için havada uçuş loop'una geçilmesin, eski davranış korunsun
			_jumped_during_dodge = true
			# Dodge state'den çıkma, sadece zıplama yap
			return
		else:
			# İlk yarıda zıplama engellensin
			if DEBUG_DODGE:
				print("[Dodge] Jump blocked - progress: ", dodge_progress, " can_jump: ", can_jump_during_dodge)
			# Input'u "tüket" - diğer state'lerin görmesini engelle
			# Bu input'u hiçbir şekilde işleme
			# Input'u tamamen engellemek için return yap
			return
	
	# Yer çekimi uygula (dodge sırasında da çalışsın)
	# İlk 0.1 saniye yer çekimi yok (hafif yukarı zıplama efekti)
	if not player.is_on_floor() and dodge_timer < (DODGE_DURATION - 0.1):
		# Dodge sırasında daha yumuşak gravity - normal gravity'nin %60'ı
		player.velocity.y += player.gravity * 0.6 * delta
	
	if _phase == DodgePhase.ROLL and _roll_time_left > 0.0:
		_roll_time_left -= delta

	if dodge_timer <= 0:
		# Pencere sonu işleri SADECE BİR KEZ: sinyal, hız kesme, çarpışma/i-frame geri alma.
		# Takla animasyonu için state uzatılabildiğinden bu blok tekrar çalışmamalı.
		var will_carry_flight: bool = false
		if not _window_finished:
			_window_finished = true
			# Emit signal for items
			var end_pos = player.position
			var dodge_dir = -1 if player.sprite.flip_h else 1
			if player.has_signal("player_dodged"):
				if DEBUG_DODGE:
					print("[Dodge] Emitting player_dodged signal: dir=", dodge_dir, " start=", dodge_start_position, " end=", end_pos)
				player.emit_signal("player_dodged", dodge_dir, dodge_start_position, end_pos)
			else:
				if DEBUG_DODGE:
					print("[Dodge] ❌ player_dodged signal yok!")
			var im := get_node_or_null("/root/ItemManager")
			if im:
				im.spawn_element_trail_if_active(end_pos)
				im.apply_movement_trail_if_active(_movement_contact_hit_ids, dodge_start_position, end_pos)

			# Havada bitip uçuş Fall'a devredilecek mi? Öyleyse hızı burada tek karede kesme -
			# 800'den 320'ye anlık düşüş yayı kırıyordu. Fall içinde sabit ivmeyle yavaşlıyor.
			will_carry_flight = (not player.is_on_floor()) \
				and _phase == DodgePhase.AIR and not _jumped_during_dodge

			# Reduce speed when ending dodge to prevent excessive drift
			if not will_carry_flight:
				player.velocity.x *= DODGE_END_SPEED_MULTIPLIER
			# Restore collision settings and end dodge
			player.collision_mask = original_collision_mask
			player.collision_layer = original_collision_layer
			var hb = player.get_node_or_null("Hurtbox")
			if hb:
				hb.monitoring = true
			# Dodge mekanik olarak burada bitti. Aşağıdaki takla uzatması sırasında tuzak
			# bağışıklığı sürmesin diye bayrağı da şimdi düşürüyoruz.
			player.is_dodging = false
		else:
			will_carry_flight = (not player.is_on_floor()) \
				and _phase == DodgePhase.AIR and not _jumped_during_dodge

		# Yerde ve takla hâlâ oynuyorsa animasyonun bitmesini bekle. 1 tile yükseklikten
		# inişte yere pencere kapanmadan hemen önce değiliyor; eskiden takla burada
		# kesilip doğrudan Idle/Run'a geçiliyordu.
		if _phase == DodgePhase.ROLL and _roll_time_left > 0.0:
			# Zemin teması bir iki kare kopabiliyor (tile dikişi, iniş sekmesi). Kısa bir
			# tolerans tanımazsak takla o tek karede kesiliyor. Gerçekten uçurumdan
			# yuvarlanırsak tolerans dolar ve normal düşüşe geçeriz.
			if player.is_on_floor():
				_roll_air_time = 0.0
			else:
				_roll_air_time += delta
				player.velocity.y += player.gravity * delta
			if _roll_air_time < ROLL_AIR_GRACE:
				player.apply_move_and_slide()
				return

		# Transition to appropriate state based on player state
		if player.is_on_floor():
			if DEBUG_DODGE:
				print("[Dodge] Transitioning to Idle state")
			state_machine.transition_to("Idle")
		elif will_carry_flight:
			# Dodge penceresi bitti ama oyuncu hâlâ havada: mekanik olarak normal
			# düşüşe geçiyoruz (tuzak bağışıklığı, hava kontrolü, i-frame'ler bugünkü
			# gibi burada bitiyor), sadece uçuş animasyonu Fall içinde devam ediyor
			# ve yere değince takla oynuyor.
			player.dodge_air_carry = true
			player.dodge_air_carry_dir = _dodge_dir
			if DEBUG_DODGE:
				print("[Dodge] Handing flight animation over to Fall state")
			state_machine.transition_to("Fall")
		else:
			if DEBUG_DODGE:
				print("[Dodge] Transitioning to Fall state")
			state_machine.transition_to("Fall")
		return
	
	player.apply_move_and_slide()

func exit():
	# Call parent exit to emit signal
	super.exit()
	
	# Zıplama input'unu timer ile serbest bırak
	# Input buffering sorununu çözmek için 0.05 saniye daha engelle
	player.jump_block_timer = 0.05
	if DEBUG_DODGE:
		print("[Dodge] Jump input will be unblocked after 0.05s timer")
	
	# Block input'unu da kısa bir süre engelle (0.3 saniye) - global timer kullan
	# Yerçekimi devreye girdiği son 0.1 saniye + ekstra güvenlik için 0.3 saniye
	player.block_input_blocked_timer = 0.3
	if DEBUG_DODGE:
		print("[Dodge] Block input will be blocked for 0.3s after dodge")
	
	# Eğer block tuşu hala basılıysa, input'u tüket
	if Input.is_action_pressed("block"):
		if DEBUG_DODGE:
			print("[Dodge] Consuming block input on exit")
		get_viewport().set_input_as_handled()
	
	# Ensure collision settings are restored when exiting state
	player.collision_mask = original_collision_mask
	player.collision_layer = original_collision_layer
	
	# Hurtbox'ı geri aç
	var hurtbox = player.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.monitoring = true
		if DEBUG_DODGE:
			print("[Dodge] Hurtbox re-enabled")

func cooldown_update(delta: float):
	# Cooldown kaldırıldı - sadece stamina kontrolü
	pass

func can_start_dodge() -> bool:
	# Check if item allows air dodge
	var allow_air = has_meta("allow_air_dodge") and get_meta("allow_air_dodge") == true
	
	# Allow dodge when on ground (or in air if item allows) and we have stamina
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar")
	var has_stamina = stamina_bar and stamina_bar.has_charges()
	var on_ground_or_allowed = player.is_on_floor() or allow_air
	return can_dodge and on_ground_or_allowed and has_stamina

func set_dodge_charges(charges: int) -> void:
	max_dodge_charges = charges
	dodge_charges = charges
	can_dodge = dodge_charges > 0
	print("[Dodge State] Set dodge charges: " + str(charges))

func _on_animation_finished(anim_name: String):
	# Not: bu sinyal bağlantısı state'ten çıkınca da açık kalıyor, bu yüzden burada
	# state geçişi YAPMIYORUZ. Bütün geçişler physics_update'te dodge_timer ile sürüyor.
	if anim_name == "dodge" or anim_name == "dodge_start" or anim_name == "dodge_roll":
		if DEBUG_DODGE:
			print("[Dodge] Animation finished: ", anim_name)


# Animasyonu üç faza böler: dodge_start (kare 0-3) -> dodge_air (kare 9-12 loop) ya da dodge_roll (kare 4-8).
# Sadece hangi klibin oynadığına karar verir; yerçekimi, i-frame'ler, zıplama iptali ve
# dodge_timer'a bağlı her şey bu fonksiyondan tamamen bağımsız çalışmaya devam eder.
func _update_animation_phase() -> void:
	var anim_player := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player == null or not anim_player.has_animation("dodge_start"):
		return  # Eski tek parçalı "dodge" klibi oynuyor, karışma

	var elapsed: float = DODGE_DURATION - dodge_timer
	if elapsed < DODGE_FLIGHT_START:
		return

	if _phase == DodgePhase.START:
		# Düz zeminde (ve dodge'dan zıplandığında) bugünkü gibi doğrudan taklaya geç (kare 4'ten).
		if player.is_on_floor() or _jumped_during_dodge:
			_start_roll_animation(anim_player)
		else:
			_phase = DodgePhase.AIR
			if anim_player.has_animation("dodge_air"):
				anim_player.play("dodge_air")
	elif _phase == DodgePhase.AIR and player.is_on_floor():
		# Dodge penceresi kapanmadan yere inildi (küçük boşluk): taklayı hemen başlat.
		_start_roll_animation(anim_player)


func _start_roll_animation(anim_player: AnimationPlayer) -> void:
	_phase = DodgePhase.ROLL
	if not anim_player.has_animation("dodge_roll"):
		return
	# Takla her zaman normal hızında ve TAM oynar. Eskiden kalan pencereye sığdırmak için
	# hızlandırılıyordu; 1 tile yükseklikten inişte yere ~0.43s'de değildiği için kalan 0.02s'ye
	# sıkışıyor ve takla tek karede kesiliyordu. Artık pencere biterse state animasyon
	# bitene kadar bekliyor (bkz. physics_update sonundaki uzatma).
	_roll_time_left = DODGE_ROLL_LENGTH
	anim_player.play("dodge_roll")


## Dodge sırasında (dokunulmazlık penceresi boyunca) içinden geçilen her düşmana bu
## dodge başına yalnızca bir kez temas hasarı + aktif element(ler). zehirli_sekme item'ı
## VEYA "restless_body" hareket ailesi eşiği (3+ hareket kategorili item) bunu açar —
## bkz. ItemManager.apply_movement_contact_tick(), docs/ITEM_SYNERGY_DESIGN.md §10 Faz 4.
func _movement_contact_tick() -> void:
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	im.apply_movement_contact_tick(_movement_contact_hit_ids, MOVEMENT_CONTACT_RADIUS, MOVEMENT_CONTACT_DAMAGE)


func _do_hayalet_adim() -> void:
	var tree := get_tree()
	if tree and tree.current_scene:
		var decoy = HayaletAdimDecoyScene.instantiate()
		tree.current_scene.add_child(decoy)
		decoy.lifetime_override = HAYALET_ADIM_LIFETIME
		var flip_h: bool = player.sprite.flip_h if player.sprite else false
		decoy.setup(player.global_position, flip_h, player)
	# Dodge yönünün tersine, kısa mesafe ışınlan
	var dodge_dir := (-1.0 if player.sprite.flip_h else 1.0)
	player.global_position -= Vector2(dodge_dir * HAYALET_ADIM_TELEPORT_DIST, 0.0)
	# Restore collision settings (dodge sırasında kapatılmıştı)
	player.collision_mask = original_collision_mask
	player.collision_layer = original_collision_layer
	var hurtbox = player.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.monitoring = true
	if player.hurtbox and player.hurtbox.has_method("set_invincible"):
		player.hurtbox.set_invincible(0.15)
	if player.is_on_floor():
		state_machine.transition_to("Idle")
	else:
		state_machine.transition_to("Fall")

func _play_dash_sfx() -> void:
	if not is_instance_valid(player):
		return
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.play_sfx("dodge", player.global_position)
