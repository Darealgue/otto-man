extends Node2D

@export var num_stars: int = 30
@export var center: Vector2 = Vector2(0, -400)
@export var min_radius: float = 200.0
@export var max_radius: float = 600.0
@export var min_speed: float = 0.01
@export var max_speed: float = 0.03
@export var star_texture: Texture2D

var stars = []
var last_debug_hour = -1 # Debug için önceki saati kaydet

func _ready():
	randomize()
	print("StarsContainer _ready başladı")
	for i in range(num_stars):
		var star = Sprite2D.new()
		star.texture = star_texture
		star.scale = Vector2(randf_range(0.3, 0.6), randf_range(0.3, 0.6))
		add_child(star)
		var angle = randf_range(0, TAU)
		var radius = randf_range(min_radius, max_radius)
		var speed = randf_range(min_speed, max_speed) # Tüm yıldızlar aynı yönde (saat yönünde)
		var twinkle_speed = randf_range(1.0, 3.0)
		var twinkle_offset = randf_range(0, TAU)
		stars.append({
			"node": star,
			"angle": angle,
			"radius": radius,
			"speed": speed,
			"twinkle_speed": twinkle_speed,
			"twinkle_offset": twinkle_offset
		})
	print("StarsContainer: ", num_stars, " yıldız oluşturuldu")

func _process(delta):
	var hour = 0.0
	# Access TimeManager directly instead of through DayNightController
	if TimeManager != null and TimeManager.has_method("get_continuous_hour_float"):
		hour = TimeManager.get_continuous_hour_float()
	# Gece-gündüz alpha ayarı
	var base_alpha = 0.0
	if hour >= 21.5 or hour < 4.0:
		base_alpha = 1.0
	elif hour < 6.0:
		base_alpha = 1.0 - ((hour - 4.0) / 2.0) # 4.0-6.0 arası yavaşça kaybolur
	elif hour >= 19.5:
		# 19:30-21:30 arası (2 saat) çok yumuşak fade in
		var fade_progress = (hour - 19.5) / 2.0
		# Manuel ease-in curve ile çok yavaş başlangıç (quadratic)
		base_alpha = fade_progress * fade_progress
	
	# DEBUG: Sadece saat değiştiğinde yazdır
	if int(hour) != last_debug_hour:
		print("SAAT DEĞİŞTİ - Hour:", hour, " Base Alpha:", base_alpha)
		last_debug_hour = int(hour)

	var t = Time.get_ticks_msec() / 1000.0
	for idx in range(len(stars)):
		var star = stars[idx]
		star["angle"] += star["speed"] * delta
		var pos = center + Vector2(cos(star["angle"]), sin(star["angle"])) * star["radius"]
		star["node"].position = pos
		star["node"].z_index = 0 # Artık StarsLayer (-10) altında, ek z_index gereksiz
		# Yanıp sönme efekti ve parlak modulate
		var twinkle = 0.7 + 0.3 * sin(t * star["twinkle_speed"] + star["twinkle_offset"])
		star["node"].modulate = Color(5.0, 5.0, 8.0, base_alpha * twinkle)
		# Sadece ilk yıldız için, sadece saat değiştiğinde debug
		if idx == 0 and int(hour) != last_debug_hour:
			print("Yıldız Alpha:", base_alpha * twinkle)
