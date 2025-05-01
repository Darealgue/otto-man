extends CanvasModulate

# Arka planı etkileyecek ikinci CanvasModulate'e referans
# Bu yolun doğru olduğunu varsayıyoruz: Ana CanvasModulate ve ParallaxBackground aynı ebeveyne sahip.
@onready var background_modulate: CanvasModulate = get_node_or_null("../ParallaxBackground/BackgroundTint")

# Geçiş hızını ayarlayan değişken (daha küçük değer = daha yavaş geçiş)
@export var transition_speed : float = 0.5

# Farklı zamanlar için hedef renkler (Alfa değerleri 1.0 olmalı!)
@export var night_color : Color = Color(0.2, 0.2, 0.4, 1.0)  # Koyu Mavi (Alfa=1)
@export var dawn_color : Color = Color(0.9, 0.6, 0.4, 1.0)   # Turuncumsu Şafak (Alfa=1)
@export var morning_color : Color = Color(0.9, 0.7, 0.5, 1.0) # Pembemsi Sabah (Alfa=1)
@export var day_color : Color = Color(1.0, 1.0, 1.0, 1.0)    # Normal Gün Işığı (Beyaz, Alfa=1)
@export var dusk_color : Color = Color(0.9, 0.6, 0.4, 1.0)    # Turuncumsu Akşam Üzeri (Alfa=1)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Başlangıçta bir uyarı verelim eğer arka plan modülatörü bulunamazsa
	if not background_modulate:
		push_warning("Arka plan için CanvasModulate bulunamadı! Yol doğru mu?: ../ParallaxBackground/BackgroundTint")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# --- Zamanı TimeManager'dan Al ---
	# TimeManager'ınızın global singleton olduğunu varsayıyoruz.
	# Eğer TimeManager singleton olarak eklenmediyse veya adı farklıysa, burayı değiştirin.
	var current_hour = TimeManager.get_hour() # Saati al (float veya int olabilir)
	var current_minute = TimeManager.get_minute() # Dakikayı al (daha hassas geçiş için)

	# --- Hedef Rengi Belirle ---
	var target_color = determine_target_color(current_hour, current_minute)

	# --- Mevcut Rengi Hedefe Doğru Yumuşakça Değiştir (Lerp) ---
	# Ana CanvasModulate'in rengini güncelle (Script zaten CanvasModulate olduğu için)
	color = color.lerp(target_color, transition_speed * delta)
	
	# Arka Plan CanvasModulate'in rengini de güncelle (eğer bulunduysa)
	if background_modulate:
		background_modulate.color = background_modulate.color.lerp(target_color, transition_speed * delta)


# Saate ve dakikaya göre hedef rengi belirleyen yardımcı fonksiyon
func determine_target_color(hour: float, minute: float) -> Color:
	# Bu sadece bir ÖRNEK mantıktır, kendi saatlerinize ve renklerinize göre ayarlayın!
	# Daha yumuşak geçişler için saat aralıklarını biraz üst üste bindirebilir
	# veya saat+dakikayı kullanarak daha hassas lerp yapabilirsiniz.

	if hour >= 21 or hour < 4: # Gece 9 PM - 4 AM
		return night_color
	elif hour < 6: # Şafak 4 AM - 6 AM
		# 4 ile 6 arasında dawn_color'a doğru geçiş yap
		var progress = remap(hour + minute/60.0, 4.0, 6.0, 0.0, 1.0)
		return night_color.lerp(dawn_color, progress)
	elif hour < 8: # Sabah 6 AM - 8 AM
		# 6 ile 8 arasında morning_color'a doğru geçiş yap
		var progress = remap(hour + minute/60.0, 6.0, 8.0, 0.0, 1.0)
		return dawn_color.lerp(morning_color, progress)
	elif hour < 17: # Gündüz 8 AM - 5 PM
		# 8 ile 9 arasında day_color'a doğru geçiş yap (daha hızlı olabilir)
		if hour < 9:
			var progress = remap(hour + minute/60.0, 8.0, 9.0, 0.0, 1.0)
			return morning_color.lerp(day_color, progress)
		else:
			return day_color
	elif hour < 19: # Akşam Üzeri 5 PM - 7 PM
		# 17 ile 19 arasında dusk_color'a doğru geçiş yap
		var progress = remap(hour + minute/60.0, 17.0, 19.0, 0.0, 1.0)
		return day_color.lerp(dusk_color, progress)
	else: # Geceye Geçiş 7 PM - 9 PM
		# 19 ile 21 arasında night_color'a doğru geçiş yap
		var progress = remap(hour + minute/60.0, 19.0, 21.0, 0.0, 1.0)
		return dusk_color.lerp(night_color, progress)


# (Opsiyonel) Gün ilerlemesine (0.0-1.0) göre renk belirleme fonksiyonu
# func determine_target_color_from_progress(progress: float) -> Color:
#    # ... progress değerine göre renkler arasında lerp yap ...
#    return Color.WHITE
