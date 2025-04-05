extends CharacterBody2D
class_name Villager

enum VillagerState { LEAVING_BUILDING, GOING_TO_WORK, RETURNING, ENTERING_BUILDING }

# İşçi tanımlama özellikleri
@export var worker_id: int = 0
@export var resource_type: String = ""

# Hedef ve hareket özellikleri
var target_building: Node = null
var gathering_point: Vector2 = Vector2.ZERO  # Kaynak toplama noktası (ekran dışında)

# Köylü özellikleri
var move_speed: float = 50.0        # Hareket hızı
var state: VillagerState = VillagerState.LEAVING_BUILDING
var direction: int = 1              # 1: sağa, -1: sola
var home_position: Vector2          # Binanın konumu
var target_position: Vector2        # Hedef konum (kaynak toplama yeri)
var is_job_done: bool = false       # İş tamamlandı mı?
var is_returning_home: bool = false # Eve dönüş modunda mı?
var job_duration: float = 0.0       # İş süresi (saniye)
var max_job_duration: float = 20.0  # Maksimum iş süresi
var fixed_y_position: float = 950.0 # Köylünün sabit y ekseni pozisyonu

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var state_label: Label = $StateLabel if has_node("StateLabel") else null
@onready var info_label: Label = $Label if has_node("Label") else null

func _ready() -> void:
	# Çarpışma ayarlarını yapılandır
	collision_layer = 16   # Köylü katmanı (5. bit)
	collision_mask = 1     # Sadece zemin ile etkileşim (1. bit)
	
	print("Köylü çarpışma ayarları: Katman=", collision_layer, ", Maske=", collision_mask)
	
	# Y pozisyonunu zorla
	position.y = fixed_y_position
	print("Köylü Y pozisyonu sabitlendi: ", fixed_y_position)
	
	# State etiketi yoksa oluştur
	if not state_label:
		state_label = Label.new()
		state_label.name = "StateLabel"
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.position = Vector2(-60, -60)
		state_label.custom_minimum_size = Vector2(120, 20)
		state_label.add_theme_color_override("font_color", Color(1, 1, 0))
		add_child(state_label)
		print("State etiketi oluşturuldu")
	
	# Kimlik etiketini güncelle
	if info_label:
		info_label.text = "İşçi #" + str(worker_id) + "\n" + resource_type
	
	# Durum etiketini güncelle
	_update_state_label()
	
	# Eğer hazır bir ikon/sprite yoksa, resource type'a göre renk değiştir
	if sprite:
		match resource_type:
			"wood":
				sprite.modulate = Color(0.5, 0.3, 0.1) # Kahverengi
			"water":
				sprite.modulate = Color(0.1, 0.5, 0.9) # Mavi
			"food":
				sprite.modulate = Color(0.2, 0.8, 0.2) # Yeşil
			"stone":
				sprite.modulate = Color(0.6, 0.6, 0.6) # Gri
			"metal":
				sprite.modulate = Color(0.7, 0.7, 0.8) # Açık gri
	
	# Rastgele iş süresi
	max_job_duration = randf_range(15.0, 30.0)

func _process(delta: float) -> void:
	match state:
		VillagerState.LEAVING_BUILDING:
			_process_leaving_building(delta)
		
		VillagerState.GOING_TO_WORK:
			_process_going_to_work(delta)
			
		VillagerState.RETURNING:
			_process_returning(delta)
			
		VillagerState.ENTERING_BUILDING:
			_process_entering_building(delta)
	
	# 0.5 saniyede bir durum etiketini güncelle
	if Engine.get_process_frames() % 30 == 0:  # 60 FPS'de her 0.5 saniyede bir
		_update_state_label()

func _update_state_label() -> void:
	if state_label:
		var state_text = ""
		match state:
			VillagerState.LEAVING_BUILDING:
				state_text = "ÇIKIYOR"
				state_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
			
			VillagerState.GOING_TO_WORK:
				state_text = "İŞE GİDİYOR"
				state_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
			
			VillagerState.RETURNING:
				if job_duration < max_job_duration and not is_returning_home:
					state_text = "ÇALIŞIYOR - " + str(int(job_duration)) + "s"
					state_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
				else:
					state_text = "DÖNÜYOR"
					state_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.9))
			
			VillagerState.ENTERING_BUILDING:
				state_text = "GİRİYOR"
				state_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		
		state_label.text = state_text

func setup(res_type: String, target_pos: Vector2, speed: float, start_pos: Vector2) -> void:
	resource_type = res_type
	target_position = target_pos
	move_speed = speed
	home_position = start_pos
	
	# Yön belirle (Target'ın konumuna göre)
	direction = 1 if target_pos.x > start_pos.x else -1
	
	# Spriteı çevir
	if sprite:
		sprite.flip_h = (direction < 0)
	
	# İlk durumu ayarla
	_change_state(VillagerState.LEAVING_BUILDING)

func _process_leaving_building(delta: float) -> void:
	# Binadan çıkış animasyonu (sadece X ekseni üzerinde hareket)
	var move_dir = Vector2(direction, 0) * move_speed * 0.5 * delta
	position.x += move_dir.x
	position.y = fixed_y_position  # Y pozisyonunu zorla
	
	# Yeterince uzaklaştık mı?
	if abs(position.x - home_position.x) > 20:
		_change_state(VillagerState.GOING_TO_WORK)

func _process_going_to_work(delta: float) -> void:
	# Hedefe doğru hareket et (sadece X ekseni üzerinde)
	var target_dir = Vector2(sign(target_position.x - global_position.x), 0)
	position.x += target_dir.x * move_speed * delta
	position.y = fixed_y_position  # Y pozisyonunu zorla
	
	# Hedefe vardık mı? (ya da ekrandan çıktık mı?)
	var viewport_size = get_viewport_rect().size
	if global_position.x < -20 or global_position.x > viewport_size.x + 20:
		# Hedefe ulaştık, işe başla
		job_duration = 0.0
		_change_state(VillagerState.RETURNING)

func _process_returning(delta: float) -> void:
	# İş süresi kontrolü
	job_duration += delta
	
	if job_duration < max_job_duration and not is_returning_home:
		# İş hala devam ediyor, bekle
		return
	
	# İşi bitirmiş olarak işaretle
	is_returning_home = true
	
	# Eve doğru hareket et (sadece X ekseni üzerinde)
	# Yönü tersine çevirmeyin, doğrudan eve gitmek için yönü hesaplayın
	direction = sign(home_position.x - global_position.x)
	
	# Spriteı çevir
	if sprite:
		sprite.flip_h = (direction < 0)
	
	# Eve doğru hareket et
	position.x += direction * move_speed * delta
	position.y = fixed_y_position  # Y pozisyonunu zorla
	
	# Debug bilgisi
	if Engine.get_process_frames() % 60 == 0:  # Her saniyede bir
		print("Köylü ", worker_id, " eve dönüyor: Pozisyon=", global_position, ", Hedef=", home_position, ", Yön=", direction)
	
	# Eve yaklaştık mı?
	if abs(global_position.x - home_position.x) < 25:
		_change_state(VillagerState.ENTERING_BUILDING)

func _process_entering_building(delta: float) -> void:
	# Binanın kapısına doğru yavaşça hareket et (sadece X ekseni üzerinde)
	var building_dir = Vector2(sign(home_position.x - global_position.x), 0)
	position.x += building_dir.x * move_speed * 0.5 * delta
	position.y = fixed_y_position  # Y pozisyonunu zorla
	
	# Binanın içine girdik mi?
	if abs(global_position.x - home_position.x) < 5:
		# İşi bitir
		is_job_done = true
		queue_free()  # Bu köylüyü yok et

func _change_state(new_state: VillagerState) -> void:
	state = new_state
	
	# Durum etiketini hemen güncelle
	_update_state_label()
	
	print("Köylü ", worker_id, " durumu değişti: ", VillagerState.keys()[new_state])
	
	# Durum değişimine göre animasyon oynat
	match new_state:
		VillagerState.LEAVING_BUILDING:
			if animation_player and animation_player.has_animation("walk"):
				animation_player.play("walk")
		
		VillagerState.GOING_TO_WORK:
			if animation_player and animation_player.has_animation("walk"):
				animation_player.play("walk")
		
		VillagerState.RETURNING:
			if animation_player and animation_player.has_animation("walk"):
				animation_player.play("walk")
		
		VillagerState.ENTERING_BUILDING:
			if animation_player and animation_player.has_animation("walk"):
				animation_player.play("walk")

func return_home() -> void:
	# Köylüyü evine gönder (örn. gece olduğunda)
	if state != VillagerState.ENTERING_BUILDING:
		is_returning_home = true
		_change_state(VillagerState.RETURNING) 

func set_target_building(building: Node) -> void:
	if building == null:
		print("UYARI: Hedef bina belirtilmedi!")
		return
	
	target_building = building
	# Hedef binadan ev konumunu ayarla
	if building.global_position:
		home_position = building.global_position
		print("Köylü için ev konumu ayarlandı: ", home_position)
	else:
		print("UYARI: Binanın global_position özelliği yok!")

func set_gathering_point(point: Vector2) -> void:
	gathering_point = point
	target_position = point
	print("Köylü için kaynak toplama noktası ayarlandı: ", point)
	
	# Görev başlangıcı için yön ayarla
	if home_position != Vector2.ZERO:
		setup(resource_type, gathering_point, move_speed, home_position)
	else:
		print("UYARI: Ev konumu ayarlanmadan kaynak toplama noktası ayarlanamaz!") 
