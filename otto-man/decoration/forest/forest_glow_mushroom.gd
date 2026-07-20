extends Node2D

const TEXTURE_PATHS: Array[String] = [
	"res://decoration/forest/mushroom1.png",
	"res://decoration/forest/mushroom2.png",
	"res://decoration/forest/mushroom3.png",
]

const DAY_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_MODULATE := Color(1.15, 1.25, 1.05, 1.0)

@onready var _sprite: Sprite2D = $Sprite
@onready var _light: PointLight2D = $PointLight2D

const OFFSCREEN_CULL_MARGIN := 400.0

var _time: float = 0.0
var _random_offset: float = 0.0
var _noise: FastNoiseLite
var _base_light_energy: float = 1.05
var _base_light_scale: float = 12.5
var _pulse_phase: float = 0.0


func _ready() -> void:
	add_to_group("background_decor")
	add_to_group("forest_night_light")
	z_as_relative = false
	z_index = 2
	_random_offset = randf() * 10.0
	_pulse_phase = randf() * TAU
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 0.18
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_setup_sprite()
	_align_sprite_bottom()
	if _light:
		ForestNightLightUtil.configure_ground_light(_light)
		_base_light_energy = _light.energy
		_base_light_scale = _light.texture_scale
		_light.energy = 0.0
	_setup_offscreen_culling()


## Ekran dışındayken flicker hesabını durdurur; sabit duran mantarlar da chunk penceresi
## boyunca aktif kalıp gereksiz yere ışık/gürültü hesaplıyordu.
func _setup_offscreen_culling() -> void:
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-OFFSCREEN_CULL_MARGIN, -OFFSCREEN_CULL_MARGIN, OFFSCREEN_CULL_MARGIN * 2.0, OFFSCREEN_CULL_MARGIN * 2.0)
	add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	notifier.screen_entered.connect(_on_screen_entered)
	if not notifier.is_on_screen():
		_on_screen_exited()


func _on_screen_exited() -> void:
	set_process(false)


func _on_screen_entered() -> void:
	set_process(true)


func _setup_sprite() -> void:
	if _sprite == null:
		return
	var path := TEXTURE_PATHS[randi() % TEXTURE_PATHS.size()]
	if not ResourceLoader.exists(path):
		path = TEXTURE_PATHS[0]
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	_sprite.texture = tex
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_meta("mushroom_variant", path.get_file())


func _align_sprite_bottom() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var h := _sprite.texture.get_height()
	_sprite.position = Vector2(-_sprite.texture.get_width() * 0.5, -h)
	if _light:
		_light.position = Vector2(0.0, -h * 0.42)


func _process(delta: float) -> void:
	_time += delta
	var light_blend: float = ForestNightLightUtil.get_light_night_blend()
	var pulse: float = sin(_time * 1.4 + _pulse_phase) * 0.08
	var night_glow := NIGHT_MODULATE * (1.0 + pulse)
	ForestNightLightUtil.blend_sprite_modulate(_sprite, DAY_MODULATE, night_glow, light_blend)
	if _light:
		ForestNightLightUtil.update_flickering_light(
			_light,
			_base_light_energy,
			_base_light_scale,
			_time,
			_noise,
			_random_offset,
			light_blend,
			0.0,
			1.0,
			0.0,
			1.0,
			0.65,
			0.22,
			0.08
		)
