extends RefCounted
class_name ForestNightLightUtil

## 0 = full day, 1 = full night (matches CampFire / DayNightController feel).
static func get_night_blend() -> float:
	if TimeManager == null or not TimeManager.has_method("get_continuous_hour_float"):
		return 1.0
	var hour: float = TimeManager.get_continuous_hour_float()
	if hour >= 21.5 or hour < 4.0:
		return 1.0
	if hour < 6.0:
		return remap(hour, 4.0, 6.0, 1.0, 0.85)
	if hour < 9.0:
		return remap(hour, 6.0, 9.0, 0.85, 0.0)
	if hour < 15.0:
		return 0.0
	if hour < 18.0:
		return remap(hour, 15.0, 18.0, 0.0, 0.85)
	if hour < 21.5:
		return remap(hour, 18.0, 21.5, 0.85, 1.0)
	return 1.0


## Işık kaynakları için: gün batımına kadar 0, sonra geceye doğru artar.
static func get_light_night_blend(sunset_hour: float = 19.5, full_night_hour: float = 21.5) -> float:
	if TimeManager == null or not TimeManager.has_method("get_continuous_hour_float"):
		return 1.0
	var hour: float = TimeManager.get_continuous_hour_float()
	if hour >= full_night_hour or hour < 4.0:
		return 1.0
	if hour < 6.0:
		return remap(hour, 4.0, 6.0, 1.0, 0.0)
	if hour < sunset_hour:
		return 0.0
	return remap(hour, sunset_hour, full_night_hour, 0.0, 1.0)


## Ateş böcekleri görünürlüğü: gün batımından sonra yavaşça belirir.
static func get_firefly_fade_blend(sunset_hour: float = 19.5, full_fade_hour: float = 22.5) -> float:
	if TimeManager == null or not TimeManager.has_method("get_continuous_hour_float"):
		return 1.0
	var hour: float = TimeManager.get_continuous_hour_float()
	if hour >= full_fade_hour or hour < 4.0:
		return 1.0
	if hour < 6.0:
		return remap(hour, 4.0, 6.0, 1.0, 0.0)
	if hour < sunset_hour:
		return 0.0
	return remap(hour, sunset_hour, full_fade_hour, 0.0, 1.0)


## Tile dekorları + forest_biom_trees_1 (z -5). Daha arka parallax (biom 2/3, trees_front…) hariç.
const FOREST_LIGHT_RANGE_Z_MIN: int = -5
const FOREST_LIGHT_RANGE_Z_MAX: int = 20


static func configure_ground_light(light: PointLight2D) -> void:
	if light == null:
		return
	# z < -5: biom_trees_2 (-6), biom_trees_3 (-7), trees_front (-8), dağlar…
	light.z_index = 0
	light.range_z_min = FOREST_LIGHT_RANGE_Z_MIN
	light.range_z_max = FOREST_LIGHT_RANGE_Z_MAX
	light.range_layer_min = -1
	light.range_layer_max = 1
	light.range_item_cull_mask = 0xFFFFFFFF


static func make_light_gradient_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0, 0, 0, 1)])
	grad.offsets = PackedFloat32Array([0.0, 0.7])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	return gtex


static func update_flickering_light(
	light: PointLight2D,
	base_energy: float,
	base_texture_scale: float,
	time: float,
	noise: FastNoiseLite,
	random_offset: float,
	night_blend: float,
	day_energy_multiplier: float = 0.0,
	night_energy_multiplier: float = 1.0,
	day_range_multiplier: float = 0.0,
	night_range_multiplier: float = 1.0,
	flicker_speed: float = 0.8,
	flicker_variation: float = 0.35,
	range_variation: float = 0.12,
	intensity_min: float = 0.2,
	intensity_max: float = 1.6
) -> void:
	if light == null:
		return
	var energy_mul: float = lerpf(day_energy_multiplier, night_energy_multiplier, night_blend)
	var range_mul: float = lerpf(day_range_multiplier, night_range_multiplier, night_blend)
	light.visible = night_blend > 0.02 or day_energy_multiplier > 0.01
	if not light.visible:
		light.energy = 0.0
		return
	var noise_value: float = noise.get_noise_1d(time * flicker_speed + random_offset)
	var flicker: float = noise_value * flicker_variation
	var random_variation: float = randf_range(-0.04, 0.04)
	var flicker_energy: float = clampf(base_energy + flicker + random_variation, intensity_min, intensity_max)
	light.energy = flicker_energy * energy_mul * maxf(night_blend, day_energy_multiplier)
	var range_noise: float = noise.get_noise_1d((time + random_offset * 1.7) * flicker_speed * 0.3)
	var scale_variation: float = 1.0 + range_noise * range_variation + randf_range(-0.02, 0.02)
	light.texture_scale = base_texture_scale * scale_variation * maxf(range_mul, 0.05)


static func blend_sprite_modulate(
	sprite: CanvasItem,
	day_color: Color,
	night_color: Color,
	night_blend: float
) -> void:
	if sprite == null:
		return
	sprite.modulate = day_color.lerp(night_color, night_blend)
