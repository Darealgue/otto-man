extends Node

## Dims dungeon camp lights during the day when used as forest night decor.

var _light: PointLight2D
var _time: float = 0.0
var _random_offset: float = 0.0
var _noise: FastNoiseLite
var _base_energy: float = 1.2
var _base_texture_scale: float = 15.0

const OFFSCREEN_CULL_MARGIN := 400.0


func _ready() -> void:
	_random_offset = randf() * 10.0
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 0.15
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	call_deferred("_bind_light")


func _bind_light() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_light = parent.find_child("PointLight2D", true, false) as PointLight2D
	if _light == null:
		return
	ForestNightLightUtil.configure_ground_light(_light)
	_base_energy = _light.energy
	_base_texture_scale = _light.texture_scale
	_light.energy = 0.0
	_setup_offscreen_culling()


## Ekran dışındayken flicker hesabını durdurur.
## Not: bu adapter düz bir Node; VisibleOnScreenNotifier2D'yi kendine değil, Node2D olan
## kamp köküne (parent) ekliyoruz, yoksa transform miras alınmayıp dünya orijinine sabitlenir.
func _setup_offscreen_culling() -> void:
	var parent_2d := get_parent() as Node2D
	if parent_2d == null:
		return
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-OFFSCREEN_CULL_MARGIN, -OFFSCREEN_CULL_MARGIN, OFFSCREEN_CULL_MARGIN * 2.0, OFFSCREEN_CULL_MARGIN * 2.0)
	parent_2d.add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	notifier.screen_entered.connect(_on_screen_entered)
	if not notifier.is_on_screen():
		_on_screen_exited()


func _on_screen_exited() -> void:
	set_process(false)


func _on_screen_entered() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta
	var light_blend: float = ForestNightLightUtil.get_light_night_blend()
	ForestNightLightUtil.update_flickering_light(
		_light,
		_base_energy,
		_base_texture_scale,
		_time,
		_noise,
		_random_offset,
		light_blend,
		0.0,
		1.0,
		0.0,
		1.0
	)
