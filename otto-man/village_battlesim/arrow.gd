extends Node2D
class_name Arrow

# Ayarlar (Editörden değiştirilebilir)
@export var peak_height_offset: float = 40.0 # Okun ne kadar yükseleceği
@export var arrow_speed: float = 600.0 # <<< YENİ: Okun hızı (piksel/saniye) >>>
const MIN_TRAVEL_TIME: float = 0.05 # <<< YENİ: Minimum seyahat süresi >>>
const MIN_VISUAL_TRAVEL_TIME: float = 0.3 # <<< YENİ: Görsel hareket için minimum süre >>>

# Dahili değişkenler
var start_position: Vector2
var target_position: Vector2
var time_elapsed: float = 0.0
var fired: bool = false
var previous_position: Vector2 # Açıyı hesaplamak için

# <<< YENİ: Hasar ve Hedef Bilgileri >>>
var damage: int = 0
var firer_team_id: int = -1 # Geçersiz bir değerle başlat
var original_target: Unit = null
var is_miss: bool = false
var total_travel_time: float = 0.6 # <<< YENİ: Artık dahili değişken, varsayılan değer >>>

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Şimdilik boş


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# _physics_process daha uygun görünüyor hareket için
	pass

# <<< GÜNCELLENDİ: Okçu tarafından çağrılacak fonksiyon >>>
func fire(start_pos: Vector2, target_pos: Vector2, p_damage: int, p_firer_team_id: int, p_original_target: Unit, p_is_miss: bool):
	start_position = start_pos
	target_position = target_pos # Bu, görsel hedef (sapmış olabilir)
	damage = p_damage
	firer_team_id = p_firer_team_id
	original_target = p_original_target # Bu, hasar alacak asıl hedef
	is_miss = p_is_miss
	
	global_position = start_position # Başlangıç pozisyonunu ayarla
	previous_position = start_position # İlk açı hesaplaması için
	time_elapsed = 0.0
	fired = true
	
	# <<< YENİ: Mesafeye Göre Seyahat Süresini Hesapla >>>
	var distance = start_position.distance_to(target_position)
	if arrow_speed > 0.1: # Çok düşük hız veya sıfır hız kontrolü
		total_travel_time = distance / arrow_speed
		# Minimum süreyi uygula
		total_travel_time = max(total_travel_time, MIN_TRAVEL_TIME)
		# print("Arrow travel time: %.2f (dist: %.1f)" % [total_travel_time, distance]) # DEBUG
	else:
		printerr("Arrow speed is too low or zero! Using default travel time.")
		total_travel_time = 0.6 # Hız geçersizse varsayılan süre
	# <<< HESAPLAMA SONU >>>
	
	# <<< KALDIRILDI: Eski kendini yok etme zamanlayıcısı >>>
	# var timer = Timer.new()
	# timer.one_shot = true
	# timer.wait_time = self_destruct_delay
	# timer.timeout.connect(queue_free)
	# add_child(timer)
	# timer.start()
	

func _physics_process(delta: float):
	if not fired:
		return

	time_elapsed += delta

	# <<< Hasar Uygulama Kontrolü (Değişiklik Yok, gerçek süreye göre) >>>
	if time_elapsed >= total_travel_time:
		fired = false # Tekrar işlem yapmasın

		# Hasar Uygulama Mantığı (Aynı kaldı)
		if not is_miss:
			if is_instance_valid(original_target):
				if original_target.team_id != firer_team_id:
					# print("Arrow applying %d damage to %s" % [damage, original_target.name]) # DEBUG
					original_target.take_damage(damage)
				
		# Oku yok et (Aynı kaldı)
		queue_free()
		return

	# --- Görsel Yolculuk Hesaplamaları --- 
	# <<< GÜNCELLENDİ: Görsel süre minimum ile sınırlandı >>>
	var visual_travel_time = max(total_travel_time, MIN_VISUAL_TRAVEL_TIME)
	
	# Yolculuğun GÖRSEL yüzdesini hesapla (0.0 -> 1.0)
	# Not: time_elapsed hala artıyor, ama visual_travel_time daha büyük olabilir
	# Bu yüzden t'nin 1.0'ı geçmemesini sağlayalım (görsel olarak hedefe yapışsın)
	var t = min(time_elapsed / visual_travel_time, 1.0)
	
	# t = ease(t, EasingType.EASE_OUT) # Hareketi yumuşatmak istersen

	# Doğrusal interpolasyon (Görsel t'ye göre)
	var linear_pos = start_position.lerp(target_position, t)

	# Parabolik Y ofseti (Görsel t'ye göre)
	var arc_offset_y = 4.0 * peak_height_offset * t * (1.0 - t)
	
	# Yeni pozisyonu hesapla
	var new_pos = linear_pos + Vector2(0, -arc_offset_y)
	
	# Açıyı hesapla ve ayarla
	var velocity = new_pos - previous_position
	if velocity.length_squared() > 0.001:
		rotation = velocity.angle()
		
	# Pozisyonu güncelle
	global_position = new_pos
	previous_position = new_pos
