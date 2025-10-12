extends CanvasModulate

# Ana CanvasModulate için renkler
@export var night_color : Color = Color(0.2, 0.2, 0.4, 1.0)
@export var dawn_color : Color = Color(0.9, 0.6, 0.4, 1.0)
@export var morning_color : Color = Color(0.9, 0.7, 0.5, 1.0)
@export var day_color : Color = Color(1.0, 1.0, 1.0, 1.0)
@export var dusk_color : Color = Color(0.9, 0.6, 0.4, 1.0)

# BackgroundTint için renkler
@export_group("Background Colors")
@export var bg_night_color : Color = Color(0.1, 0.1, 0.3, 1.0)
@export var bg_dawn_color : Color = Color(0.8, 0.5, 0.3, 1.0)
@export var bg_morning_color : Color = Color(0.85, 0.65, 0.45, 1.0)
@export var bg_day_color : Color = Color(0.5, 0.7, 1.0, 1.0)
@export var bg_dusk_color : Color = Color(0.8, 0.5, 0.3, 1.0)
@export_group("")

@export var sky_gradient_resource: GradientTexture2D 
@export var transition_speed : float = 0.5

@export_group("Celestial Bodies")
@export var sun_follower_path: NodePath
@export var moon_follower_path: NodePath
@export var sun_sprite_path: NodePath
@export var moon_sprite_path: NodePath
@export var sun_light_path: NodePath
@export var moon_light_path: NodePath
@export var moon_phase_textures: Array[Texture2D] = []

@export_group("Celestial Times")
@export var sun_sunrise_hour: float = 6.0
@export var sun_sunset_hour: float = 18.0
@export var moon_rise_hour: float = 20.0
@export var moon_set_hour: float = 4.0 
@export var celestial_fade_duration: float = 1.0

@onready var background_modulate: CanvasModulate = get_node_or_null("../ParallaxBackground/BackgroundTint") 
@onready var _sun_follower: PathFollow2D = get_node_or_null(sun_follower_path)
@onready var _moon_follower: PathFollow2D = get_node_or_null(moon_follower_path)
@onready var _sun_sprite: Sprite2D = get_node_or_null(sun_sprite_path)
@onready var _moon_sprite: Sprite2D = get_node_or_null(moon_sprite_path)
@onready var _sun_light: PointLight2D = get_node_or_null(sun_light_path)
@onready var _moon_light: PointLight2D = get_node_or_null(moon_light_path)

var _current_hour: int = -1
var _target_main_color: Color
var _target_bg_color: Color

func _ready() -> void:
	# print("--- DayNightController.gd: _ready() ÇAĞRILDI! --- TOP LEVEL --- ")
	await get_tree().process_frame
	
	if not background_modulate:
		push_warning("DayNightController: BackgroundTint CanvasModulate not found!")
	if not sky_gradient_resource:
		push_warning("DayNightController: Sky Gradient Resource not assigned!")

	if TimeManager != null and TimeManager.has_method("get_continuous_hour_float"):
		# print("--- DayNightController: TimeManager FOUND in _ready() (Using direct check) ---")
		var initial_hour_float = TimeManager.get_continuous_hour_float()
		_update_target_colors(initial_hour_float)
		self.color = _target_main_color
		if background_modulate: background_modulate.color = _target_bg_color
		if sky_gradient_resource and sky_gradient_resource.gradient:
			var grad = sky_gradient_resource.gradient
			grad.set_color(0, _target_bg_color) 
			grad.set_color(1, _target_bg_color.lightened(0.3))
		_current_hour = floori(initial_hour_float)
		_update_celestial_bodies()
	else:
		# printerr("--- DayNightController: TimeManager NOT FOUND in _ready() (Using direct check) ---")
		# Varsayılan renkler (Öğlen)
		_target_main_color = day_color
		_target_bg_color = bg_day_color
		self.color = _target_main_color
		if background_modulate: background_modulate.color = _target_bg_color
		if sky_gradient_resource and sky_gradient_resource.gradient:
			sky_gradient_resource.gradient.set_color(0, bg_day_color)
			sky_gradient_resource.gradient.set_color(1, bg_day_color.lightened(0.3))
		if _sun_sprite: _sun_sprite.visible = false
		if _moon_sprite: _moon_sprite.visible = false
		if _sun_light: _sun_light.enabled = false
		if _moon_light: _moon_light.enabled = false

func _process(delta: float) -> void:
	# print("--- DayNightController.gd: _process() ÇAĞRILDI! Delta: ", delta, " --- TOP LEVEL ---")

	if TimeManager == null or not TimeManager.has_method("get_continuous_hour_float"):
		# print("--- DayNightController: TimeManager NOT FOUND or no get_continuous_hour_float in _process (Using direct check) ---")
		return

	# print("--- DayNightController: TimeManager IS AVAILABLE in _process (Using direct check) ---")
	
	var current_time_float = TimeManager.get_continuous_hour_float()

	_update_target_colors(current_time_float)
	
	_current_hour = floori(current_time_float)
	
	var lerp_val = delta * transition_speed
	self.color = self.color.lerp(_target_main_color, lerp_val)
	if background_modulate:
		background_modulate.color = background_modulate.color.lerp(_target_bg_color, lerp_val)

	if sky_gradient_resource and sky_gradient_resource.gradient:
		var grad = sky_gradient_resource.gradient
		var current_top_grad_color = grad.get_color(0)
		var current_bottom_grad_color = grad.get_color(1)
		
		# Use _target_main_color for sky gradient to match the overall color scheme
		var target_top_grad_color = _target_main_color 
		var target_bottom_grad_color = _target_main_color.lightened(0.3)

		grad.set_color(0, current_top_grad_color.lerp(target_top_grad_color, lerp_val))
		grad.set_color(1, current_bottom_grad_color.lerp(target_bottom_grad_color, lerp_val))
		
		# print("Target SkyTop: ", target_top_grad_color, " Current SkyTop: ", sky_gradient_resource.gradient.get_color(0)) # Bu print'ler _update_target_colors içindekilerle çakışabilir, şimdilik kapalı
		# print("Target SkyBottom: ", target_bottom_grad_color, " Current SkyBottom: ", sky_gradient_resource.gradient.get_color(1))

	# print("--- _process DEBUG --- Delta: ", delta, " Lerp Val: ", lerp_val) # Bu print'ler _update_target_colors içindekilerle çakışabilir, şimdilik kapalı
	# print("Target Main: ", _target_main_color, " Current Main: ", self.color)
	# if background_modulate:
	# 	print("Target BG: ", _target_bg_color, " Current BG: ", background_modulate.color)
	
	_update_celestial_bodies()


func _update_target_colors(hour_float: float) -> void:
	# print("--- _update_target_colors CALLED for hour_float: ", hour_float, " ---") 
	var current_hour_for_color: float = hour_float

	# Güncellenmiş Zaman Aralıkları:
	if current_hour_for_color >= 21.5 or current_hour_for_color < 4.0: # Full Night (21.5 - 04.0)
		_target_main_color = night_color
		_target_bg_color = bg_night_color
	elif current_hour_for_color < 6.0: # 4.0 to 6.0 (Night -> Dawn)
		var progress = remap(current_hour_for_color, 4.0, 6.0, 0.0, 1.0)
		_target_main_color = night_color.lerp(dawn_color, progress)
		_target_bg_color = bg_night_color.lerp(bg_dawn_color, progress)
	elif current_hour_for_color < 8.0: # 6.0 to 8.0 (Dawn -> Morning)
		var progress = remap(current_hour_for_color, 6.0, 8.0, 0.0, 1.0)
		_target_main_color = dawn_color.lerp(morning_color, progress)
		_target_bg_color = bg_dawn_color.lerp(bg_morning_color, progress)
	elif current_hour_for_color < 9.0: # 8.0 to 9.0 (Morning -> Day)
		var progress = remap(current_hour_for_color, 8.0, 9.0, 0.0, 1.0)
		_target_main_color = morning_color.lerp(day_color, progress)
		_target_bg_color = bg_morning_color.lerp(bg_day_color, progress)
	elif current_hour_for_color < 18.0: # 9.0 to 18.0 (Full Day)
		_target_main_color = day_color
		_target_bg_color = bg_day_color
	elif current_hour_for_color < sun_sunset_hour: # 18.0 to sun_sunset_hour (19.5) (Day -> Dusk)
		var progress = remap(current_hour_for_color, 18.0, sun_sunset_hour, 0.0, 1.0)
		_target_main_color = day_color.lerp(dusk_color, progress)
		_target_bg_color = bg_day_color.lerp(bg_dusk_color, progress)
	else: # sun_sunset_hour (19.5) to 21.5 (Dusk -> Night)
		var progress = remap(current_hour_for_color, sun_sunset_hour, 21.5, 0.0, 1.0)
		_target_main_color = dusk_color.lerp(night_color, progress)
		_target_bg_color = bg_dusk_color.lerp(bg_night_color, progress)
	# print("Target Main Color: ", _target_main_color, " Target BG Color: ", _target_bg_color)


func _update_celestial_bodies() -> void:
	if TimeManager == null or not TimeManager.has_method("get_continuous_hour_float"):
		if _sun_sprite: _sun_sprite.visible = false
		if _moon_sprite: _moon_sprite.visible = false
		if _sun_light: _sun_light.enabled = false
		if _moon_light: _moon_light.enabled = false
		return

	var current_hour_float: float = TimeManager.get_continuous_hour_float()
	var current_game_day: int = TimeManager.get_current_day_count()

	if _sun_follower and _sun_sprite:
		var sun_day_duration = sun_sunset_hour - sun_sunrise_hour
		if sun_day_duration <= 0: 
			_sun_sprite.visible = false
			_sun_sprite.modulate.a = 0.0 # Emin olmak için alfayı sıfırla
			if _sun_light: _sun_light.enabled = false
		else:
			if current_hour_float >= sun_sunrise_hour and current_hour_float < sun_sunset_hour:
				_sun_sprite.visible = true
				if _sun_light: _sun_light.enabled = true
				var elapsed_sun_time = current_hour_float - sun_sunrise_hour
				var sun_progress = clampf(elapsed_sun_time / sun_day_duration, 0.0, 1.0)
				_sun_follower.progress_ratio = sun_progress
				
				var sun_alpha = 1.0
				if elapsed_sun_time < celestial_fade_duration: 
					sun_alpha = elapsed_sun_time / celestial_fade_duration
				elif (sun_sunset_hour - current_hour_float) < celestial_fade_duration: 
					sun_alpha = (sun_sunset_hour - current_hour_float) / celestial_fade_duration
				
				# Glow için parlak temel renk (RGB) ve hesaplanan alfa
				_sun_sprite.modulate = Color(4.0, 3.5, 2.5, sun_alpha) # Maksimum parlak sarımsı beyaz
			else:
				_sun_sprite.visible = false
				_sun_sprite.modulate.a = 0.0 
				if _sun_light: _sun_light.enabled = false

	if _moon_follower and _moon_sprite:
		var is_moon_time = false
		var moon_progress = 0.0
		var moon_duration_hours = 0.0
		var elapsed_moon_time = 0.0

		if moon_rise_hour < moon_set_hour: 
			moon_duration_hours = moon_set_hour - moon_rise_hour
			if current_hour_float >= moon_rise_hour and current_hour_float < moon_set_hour:
				is_moon_time = true
				elapsed_moon_time = current_hour_float - moon_rise_hour
		else: 
			moon_duration_hours = (24.0 - moon_rise_hour) + moon_set_hour
			if current_hour_float >= moon_rise_hour: 
				is_moon_time = true
				elapsed_moon_time = current_hour_float - moon_rise_hour
			elif current_hour_float < moon_set_hour: 
				is_moon_time = true
				elapsed_moon_time = (24.0 - moon_rise_hour) + current_hour_float
		
		if is_moon_time and moon_duration_hours > 0:
			var was_moon_visible_previously = _moon_sprite.visible
			_moon_sprite.visible = true
			if _moon_light: _moon_light.enabled = true

			if not was_moon_visible_previously:
				if moon_phase_textures and not moon_phase_textures.is_empty():
					var phase_index = current_game_day % moon_phase_textures.size()
					if phase_index >= 0 and phase_index < moon_phase_textures.size():
						_moon_sprite.texture = moon_phase_textures[phase_index]
			
			moon_progress = clampf(elapsed_moon_time / moon_duration_hours, 0.0, 1.0)
			_moon_follower.progress_ratio = moon_progress
			
			if _moon_sprite.texture == null and moon_phase_textures and not moon_phase_textures.is_empty():
				var phase_index = current_game_day % moon_phase_textures.size()
				if phase_index >= 0 and phase_index < moon_phase_textures.size():
					_moon_sprite.texture = moon_phase_textures[phase_index]

			var moon_alpha = 1.0
			if elapsed_moon_time < celestial_fade_duration: 
				moon_alpha = elapsed_moon_time / celestial_fade_duration
			elif (moon_duration_hours - elapsed_moon_time) < celestial_fade_duration: 
				moon_alpha = (moon_duration_hours - elapsed_moon_time) / celestial_fade_duration
			
			# Glow için parlak temel renk (RGB) ve hesaplanan alfa
			_moon_sprite.modulate = Color(20.0, 20.0, 30.0, moon_alpha) # Ultra parlak mavimsi beyaz
		else:
			_moon_sprite.visible = false
			_moon_sprite.modulate.a = 0.0
			if _moon_light: _moon_light.enabled = false

func remap(value, from_min, from_max, to_min, to_max):
	return to_min + (value - from_min) * (to_max - to_min) / (from_max - from_min)
