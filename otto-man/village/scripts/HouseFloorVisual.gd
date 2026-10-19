extends Node2D

class_name HouseFloorVisual

const NUM_WINDOW_STATES: int = 3  # 0=kapalı, 1=yarı kapalı, 2=açık

@export var window_closed_texture: Texture2D
@export var window_half_closed_texture: Texture2D
@export var window_open_texture: Texture2D

# Çeşitlilik için: doluysa rastgele bu varyantlardan biri seçilir (boşsa mevcut texture korunur).
@export var body_texture_variants: Array[Texture2D] = []
@export var gate_texture_variants: Array[Texture2D] = []
@export var allow_horizontal_flip: bool = true

# Gece pencere ışığı: pencere sprite'ının koyu kemer (iç) bölgesinin üstüne sıcak bir dolgu basılır.
# Çerçeve/panjur dokunulmadan kalır, ışık "içeriden" geliyormuş gibi görünür.
@export var window_light_color_top: Color = Color(1.0, 0.58, 0.2, 0.92)
@export var window_light_color_bottom: Color = Color(1.0, 0.84, 0.42, 0.96)
# Işığın açık kalacağı saatler pencere başına rastgele: akşam yanma saati 18-20, sönme saati 0-4.
const LIGHT_ON_HOUR_MIN: int = 18
const LIGHT_ON_HOUR_SPREAD: int = 3
const LIGHT_OFF_HOUR_SPREAD: int = 5
const FLICKER_STRENGTH: float = 0.07
# Yumuşak açılış/sönüş süresi (saniye) ve havanın kararmasına göre parlaklık (saat): gün batımında loş (0.15) başlar,
# 21:00'de tam parlaklığa çıkar, 05:00'ten sonra sabaha doğru söner.
const LIGHT_FADE_SECONDS: float = 1.5
const LIGHT_DUSK_START_HOUR: float = 17.0
const LIGHT_FULL_HOUR: float = 21.0
const LIGHT_DAWN_START_HOUR: float = 5.0
const LIGHT_DAWN_END_HOUR: float = 7.5
const LIGHT_DUSK_MIN_INTENSITY: float = 0.15

# Pencere sprite'larındaki koyu kemer rengi (0x522E27); panjurlar bu renkte değil (0x663931).
const ARCH_COLOR_R8: int = 0x52
const ARCH_COLOR_G8: int = 0x2E
const ARCH_COLOR_B8: int = 0x27
# Kemer iç bölgesini bulmak için tohum noktası: genişliğin %40'ı, yüksekliğin yarısı.
const ARCH_SEED_X_RATIO: float = 0.4

# Pencere süsleri (saksı, kumaş, perde, halı...). Dosyalar `window_decor<1|2>_<tür><no>.png` adıyla bu klasörde durur:
# decor1 = pencerenin yarısını kaplar (sola çizilmiş, ters çevrilerek sağa da konur), decor2 = iki yarıyı birden kaplar.
# Tuval 85x150: pencere sprite'ı tuvalin 50-100 piksel bandına denk gelir, bu yüzden süs pencerenin 50 px üstünden başlar.
const DECOR_DIR: String = "res://village/buildings/sprite/house/decor/"
const DECOR_CANVAS_OFFSET_Y: float = -50.0
# Rengi kodla verilen (açık renk çizilmiş) türler.
const TINTED_DECOR_KINDS: Array[String] = ["cloth", "curtain", "carpet"]
const FABRIC_TINTS: Array[Color] = [
	Color(0.85, 0.35, 0.3), Color(0.35, 0.5, 0.8), Color(0.4, 0.7, 0.45), Color(0.9, 0.75, 0.35),
	Color(0.7, 0.45, 0.75), Color(0.35, 0.7, 0.7), Color(0.9, 0.6, 0.65), Color(0.75, 0.55, 0.4),
	Color(0.95, 0.95, 0.9),
]
# Perdeler sadece beyaz/bej gibi açık tonlarda boyanır.
const CURTAIN_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.96, 0.93, 0.82), Color(0.92, 0.86, 0.72),
	Color(0.88, 0.82, 0.7), Color(0.95, 0.9, 0.78), Color(0.85, 0.82, 0.76),
]
# Açık bir pencerede süs çıkma olasılıkları (pencere başına sabit rastgele), köy refahına (0..1) göre değişir:
# fakir köyde pencerelerin çoğu süssüz ve sade kumaşlı, zengin köyde çoğu çiçekli saksı, perde, seramik ve halılı.
const DECOR_EMPTY_CHANCE_POOR: float = 0.7
const DECOR_EMPTY_CHANCE_RICH: float = 0.08
const DECOR_WIDE_CHANCE_POOR: float = 0.03   # geniş (decor2) süs, ör. halı
const DECOR_WIDE_CHANCE_RICH: float = 0.16
const DECOR_PAIR_CHANCE_POOR: float = 0.15   # yarım süste, öbür yarıya da ikinci bir süs konma ihtimali
const DECOR_PAIR_CHANCE_RICH: float = 0.5
const PROSPERITY_BUCKETS: int = 4            # refah bu kadar basamağa bölünür; basamak değişince süs planı yenilenir
# Türlerin refaha göre ağırlığı: [fakirken, zenginken]. Listede olmayan tür her zaman 1.0.
const KIND_WEIGHTS_BY_PROSPERITY: Dictionary = {
	"plant": [0.5, 1.6], "ceramic": [0.6, 1.4], "curtain": [0.6, 1.5], "cloth": [1.5, 0.7],
}
# Rüzgârda sallanan (asılı) türler.
const SWAY_KINDS: Array[String] = ["cloth", "curtain", "carpet"]
const SWAY_SHADER_PATH: String = "res://shaders/window_sway.gdshader"
const SWAY_BASE_AMPLITUDE: float = 1.0       # hafif esinti (piksel)
const SWAY_WIND_AMPLITUDE: float = 5.0       # rüzgâr gücü 1.0 iken eklenen genlik
const SWAY_BASE_SPEED: float = 1.6
const SWAY_WIND_SPEED: float = 3.0

## Ziyaret köyünde köyün zenginliğinden (0..1) verilir; -1 iken oyuncu köyünün yiyecek ve moral durumundan hesaplanır.
static var prosperity_override: float = -1.0

static var _light_texture_cache: Dictionary = {}
static var _sway_materials: Dictionary = {}
static var _sway_last_frame: int = -1
static var _decor_library: Dictionary = {}
static var _decor_library_loaded: bool = false

var _window_sprites: Array[Sprite2D] = []
var _window_lights: Array[Sprite2D] = []
var _window_decor: Array = []        # pencere başına Array[Sprite2D]
var _decor_plans: Array = []         # tam açık pencere için süs planı (null = henüz kurulmadı)
var _decor_half_plans: Array = []    # yarı açık pencere için süs planı
var _plan_bucket: int = -1
var _has_swaying_decor: bool = false
var _last_window_states: Array = []
var _last_is_night: bool = false
var _time_manager_ref: Node = null

func _ready() -> void:
	add_to_group(&"house_floor_visual")
	_collect_window_sprites()
	_apply_random_variants()
	set_process(false)
	apply_window_states([], false)

## Tam açık (2) pencerelerin listesi: [{window: Sprite2D, index: int, wide_decor: bool}]. wide_decor: pencerede halı gibi iki yarıyı
## kaplayan bir süs var. Pencereden bakan köylü (WindowWatcherDirector) buradan pencere seçer.
func get_open_windows() -> Array:
	var out: Array = []
	for i in _window_sprites.size():
		var state: int = int(_last_window_states[i]) if i < _last_window_states.size() else 0
		if state != 2:
			continue
		var wide: bool = false
		for s in _window_decor[i]:
			if (s as Sprite2D).visible and (s as Sprite2D).texture != null and (s as Sprite2D).texture.resource_path.contains("decor2"):
				wide = true
		out.append({"window": _window_sprites[i], "index": i, "wide_decor": wide, "floor": self})
	return out

## Pencere kemerinin şeklini veren maske dokusu (kemer içi opak, dışı saydam); ışık ve pencereden bakan köylü için.
func get_window_arch_mask(window: Sprite2D) -> Texture2D:
	if window == null or window.texture == null:
		return null
	return _get_light_texture(window.texture, window_light_color_top, window_light_color_bottom)

## Katın bir yanındaki (-1 sol, +1 sağ) dış pencerenin dünya konumu ve durumu: {"pos": Vector2, "state": int}.
## Pencerenin dış kenarı sprite konumudur (sağdaki pencere çevrik, menteşesi sağ kenarda). Boşsa pos = Vector2.INF.
## Pencereden pencereye gerilen ipler (WindowRopeManager) bu bilgiyle komşu binadaki aynı yükseklikteki pencereyi bulur.
func get_outer_window(side: int) -> Dictionary:
	if _window_sprites.is_empty():
		_collect_window_sprites()
	for i in _window_sprites.size():
		var s: Sprite2D = _window_sprites[i]
		if (side > 0) == s.flip_h:
			var state: int = int(_last_window_states[i]) if i < _last_window_states.size() else 0
			return {"pos": s.global_position, "state": state}
	return {"pos": Vector2.INF, "state": 0}

func _collect_window_sprites() -> void:
	_window_sprites.clear()
	for child in get_children():
		if child is Sprite2D and String(child.name).begins_with("WindowSlot"):
			_window_sprites.append(child)
	_window_sprites.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool:
		return String(a.name) < String(b.name))
	_window_lights.clear()
	_window_lights.resize(_window_sprites.size())
	_window_decor.clear()
	_decor_plans.clear()
	_decor_half_plans.clear()
	for _i in _window_sprites.size():
		_window_decor.append([])
		_decor_plans.append(null)
		_decor_half_plans.append(null)

# Zemin/kapı görselinde rastgele çeşitlilik (varyant + flip).
# NOT: Pencereler flip edilmez — pencere state'leri (kapalı/yarı/açık) sabit bir
# köşeden (menteşe) büyüyen, centered=false yerleşimli sprite'lardır; WindowSlot'un
# flip_h değeri hangi kenardan (sol/sağ) büyüdüğünü belirler ve rastgele değiştirilirse
# pencere olması gereken yerden tamamen kayar.
#
# Varyant (hangi kapı/gövde dokusu) dünya konumundan türetilen sabit bir seed ile seçilir —
# böylece aynı ev köye her dönüşte (sahne yeniden yüklendiğinde) AYNI kapı sprite'ıyla kalır;
# sadece flip_h hâlâ her seferinde rastgele olabilir ("sadece flip edebilir" isteğiyle uyumlu).
func _apply_random_variants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(global_position.round()))
	var body := get_node_or_null("Body") as Sprite2D
	if body != null:
		if body_texture_variants.size() > 0:
			body.texture = body_texture_variants[rng.randi() % body_texture_variants.size()]
		if allow_horizontal_flip:
			body.flip_h = randf() < 0.5
	var gate := get_node_or_null("Gate") as Sprite2D
	if gate != null:
		if gate_texture_variants.size() > 0:
			gate.texture = gate_texture_variants[rng.randi() % gate_texture_variants.size()]
		if allow_horizontal_flip:
			gate.flip_h = randf() < 0.5

# window_states: her pencere yuvası için 0 (kapalı) / 1 (yarı kapalı) / 2 (açık) değerleri.
func apply_window_states(window_states: Array, is_night: bool = false) -> void:
	if _window_sprites.is_empty():
		_collect_window_sprites()
	_last_window_states = window_states.duplicate()
	_last_is_night = is_night
	var hour: int = _current_hour()
	var any_lit: bool = false
	var any_sway: bool = false
	# Köy refahı basamağı değişince süs planları yenilenir (pencereler refahla birlikte zenginleşir/sadeleşir).
	# Oyuncu bakarken hiçbir şey değişmez: ilk kurulum anında hemen, sonraki değişimler kat kamera dışındayken uygulanır
	# (apply_window_states saat başı çağrıldığı için bir sonraki uygun çağrıda).
	var bucket: int = _prosperity_bucket()
	if bucket != _plan_bucket and (_plan_bucket < 0 or _is_offscreen()):
		_plan_bucket = bucket
		for k in _decor_plans.size():
			_decor_plans[k] = null
			_decor_half_plans[k] = null
	for i in _window_sprites.size():
		var state: int = clamp(int(window_states[i]) if i < window_states.size() else 0, 0, NUM_WINDOW_STATES - 1)
		var sprite: Sprite2D = _window_sprites[i]
		var tex: Texture2D
		match state:
			1:
				tex = window_half_closed_texture
			2:
				tex = window_open_texture
			_:
				tex = window_closed_texture
		if tex != null:
			sprite.texture = tex
			# Pencere durumları (kapalı/yarı/açık) farklı genişlikte ve sabit bir
			# menteşe kenarından büyüyor. flip_h=false ise menteşe sol kenarda ve
			# sprite.position'dan sağa doğru büyür (offset.x=0 yeterli).
			# flip_h=true ise menteşe sağ kenarda; flip_h çizim alanını KAYDIRMAZ,
			# sadece içeriği aynalar, bu yüzden sprite'ın sağ kenarı sabit kalsın diye
			# offset.x'i -genişlik yapıp sola doğru büyümesini sağlıyoruz.
			sprite.offset.x = -tex.get_width() if sprite.flip_h else 0
		var lit: bool = state > 0 and _window_is_lit(i, hour, is_night)
		_set_window_light(i, sprite, lit, state)
		var swaying: bool = _set_window_decor(i, sprite, state)
		any_lit = any_lit or lit
		any_sway = any_sway or swaying
	_has_swaying_decor = any_sway
	# Sönmekte olan ışıkların da işlenmesi gerekir (yumuşak kararma).
	for light in _window_lights:
		if light != null and light.visible:
			any_lit = true
	set_process(any_lit or any_sway)

# Sadece gece bayrağını güncellemek için kısa yol (pencere durumu değişmeden saat değişince).
func set_night_mode(is_night: bool) -> void:
	apply_window_states(_last_window_states, is_night)

const OFFSCREEN_MARGIN: float = 150.0

# Kat kamera görüş alanının dışında mı (görünmeyen değişiklikler için)? Kamera yoksa true.
func _is_offscreen() -> bool:
	if not is_inside_tree():
		return true
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var half_view: float = get_viewport().get_visible_rect().size.x / maxf(cam.zoom.x, 0.01) * 0.5
	return absf(global_position.x - cam.get_screen_center_position().x) > half_view + OFFSCREEN_MARGIN

func _current_hour() -> int:
	if _time_manager_ref == null or not is_instance_valid(_time_manager_ref):
		_time_manager_ref = get_node_or_null("/root/TimeManager")
	if _time_manager_ref == null:
		return -1
	if _time_manager_ref.has_method("get_hour"):
		return int(_time_manager_ref.get_hour())
	return -1

# Pencere başına sabit (konum + yuva numarasından türeyen) yanma/sönme saati; saat bilgisi yoksa gece bayrağına düşer.
func _window_is_lit(index: int, hour: int, is_night: bool) -> bool:
	if hour < 0:
		return is_night
	var pos: Vector2 = global_position if is_inside_tree() else position
	var h: int = absi(hash("%s_%d" % [str(pos.round()), index]))
	var on_hour: int = LIGHT_ON_HOUR_MIN + (h % LIGHT_ON_HOUR_SPREAD)
	var off_hour: int = (h / 7) % LIGHT_OFF_HOUR_SPREAD
	return hour >= on_hour or hour < off_hour

# Pencerenin üstüne ışık katmanını (child Sprite2D) kurar veya gizler. Kapalı pencerede kemer görünmediği için ışık da çıkmaz.
#
# Açılış ve sönüş yumuşaktır: ışık sprite'ı "fade" (0..1) meta değerine göre belirir/kaybolur (_process), parlaklık da
# havanın kararmasına göre değişir (_night_intensity). Pencere kapanırsa (oyun mantığı) ışık hemen kalkar.
func _set_window_light(index: int, window: Sprite2D, lit: bool, state: int) -> void:
	var light: Sprite2D = _window_lights[index]
	if state <= 0:
		if light != null:
			light.visible = false
			light.set_meta("fade", 0.0)
			light.set_meta("target_on", false)
		return
	if not lit:
		if light != null:
			light.set_meta("target_on", false)  # sönüş: _process yumuşakça kısar ve gizler
		return
	var light_tex: Texture2D = null
	if window.texture != null:
		light_tex = _get_light_texture(window.texture, window_light_color_top, window_light_color_bottom)
	if light_tex == null:
		if light != null:
			light.visible = false
		return
	if light == null:
		light = Sprite2D.new()
		light.name = "WindowLight"
		light.centered = false
		light.set_meta("phase", randf() * TAU)
		light.set_meta("fade", 0.0)
		light.modulate.a = 0.0
		window.add_child(light)
		window.move_child(light, 0)  # ışık süslerin arkasında kalsın
		_window_lights[index] = light
	light.texture = light_tex
	light.flip_h = window.flip_h
	light.offset = window.offset
	light.set_meta("target_on", true)
	light.visible = true

# Havanın kararma düzeyi (0..1): gün batımında loş başlar, gece tam parlaklığa çıkar, sabaha doğru söner.
func _night_intensity() -> float:
	var h: float = _hour_float()
	if h < 0.0:
		return 1.0 if _last_is_night else 0.0
	if h >= LIGHT_FULL_HOUR or h < LIGHT_DAWN_START_HOUR:
		return 1.0
	if h >= LIGHT_DUSK_START_HOUR:
		return lerpf(LIGHT_DUSK_MIN_INTENSITY, 1.0, smoothstep(LIGHT_DUSK_START_HOUR, LIGHT_FULL_HOUR, h))
	if h < LIGHT_DAWN_END_HOUR:
		return 1.0 - smoothstep(LIGHT_DAWN_START_HOUR, LIGHT_DAWN_END_HOUR, h)
	return 0.0

func _hour_float() -> float:
	if _time_manager_ref == null or not is_instance_valid(_time_manager_ref):
		_time_manager_ref = get_node_or_null("/root/TimeManager")
	if _time_manager_ref == null:
		return -1.0
	if _time_manager_ref.has_method("get_continuous_hour_float"):
		return float(_time_manager_ref.get_continuous_hour_float())
	if _time_manager_ref.has_method("get_hour"):
		return float(_time_manager_ref.get_hour())
	return -1.0

# Klasördeki süs çizimlerini bir kez tarar: {1: [{tex, kind}], 2: [{tex, kind}]}. Dışa aktarılmış oyunda dosya listesi
# `.import` / `.remap` uzantılı gelir, uzantı atılıp load() ile yüklenir.
static func _ensure_decor_library() -> void:
	if _decor_library_loaded:
		return
	_decor_library_loaded = true
	_decor_library = {1: [], 2: []}
	var names: Array[String] = []
	for file in DirAccess.get_files_at(DECOR_DIR):
		var base: String = file.trim_suffix(".import").trim_suffix(".remap")
		if base.ends_with(".png") and base.begins_with("window_decor") and not names.has(base):
			names.append(base)
	names.sort()
	for base in names:
		var parts: PackedStringArray = base.get_basename().split("_")
		if parts.size() < 3:
			continue
		var group: int = 1 if parts[1] == "decor1" else (2 if parts[1] == "decor2" else 0)
		if group == 0:
			continue
		var tex := load(DECOR_DIR + base) as Texture2D
		if tex == null:
			continue
		var kind: String = String(parts[2]).rstrip("0123456789")
		_decor_library[group].append({"tex": tex, "kind": kind})

static func _make_decor_entry(item: Dictionary, swap_side: bool, rng: RandomNumberGenerator) -> Dictionary:
	var tint := Color.WHITE
	if String(item["kind"]) == "curtain":
		tint = CURTAIN_TINTS[rng.randi() % CURTAIN_TINTS.size()]
	elif TINTED_DECOR_KINDS.has(String(item["kind"])):
		tint = FABRIC_TINTS[rng.randi() % FABRIC_TINTS.size()]
	return {"tex": item["tex"], "kind": item["kind"], "swap": swap_side, "tint": tint}

## Köy refahı 0..1. Ziyaret köyünde sahne verir (prosperity_override); oyuncu köyünde VillageCatsController ile aynı
## formül: yiyecek doluluğu %65, moral %35.
static func get_prosperity() -> float:
	if prosperity_override >= 0.0:
		return prosperity_override
	var tree := Engine.get_main_loop() as SceneTree
	var vm: Node = tree.root.get_node_or_null("VillageManager") if tree != null else null
	if vm == null:
		return 0.5
	var food: float = 0.0
	var workers: float = 1.0
	var morale: float = 50.0
	if "resource_levels" in vm and vm.resource_levels is Dictionary:
		food = float(vm.resource_levels.get("food", 0))
	if "total_workers" in vm:
		workers = maxf(1.0, float(vm.total_workers))
	if vm.has_method("get_morale"):
		morale = float(vm.get_morale())
	return clampf(clampf(food / (workers * 2.0), 0.0, 1.0) * 0.65 + clampf(morale / 100.0, 0.0, 1.0) * 0.35, 0.0, 1.0)

static func _prosperity_bucket() -> int:
	return clampi(int(round(get_prosperity() * float(PROSPERITY_BUCKETS))), 0, PROSPERITY_BUCKETS)

# Türü refaha göre ağırlıklı seçer (fakirken kumaş, zenginken çiçek/perde/seramik daha olası).
func _pick_single(singles: Array, rng: RandomNumberGenerator, p: float, exclude_idx: int = -1) -> int:
	var total: float = 0.0
	var weights: Array[float] = []
	for i in singles.size():
		var w: float = 0.0
		if i != exclude_idx:
			var pair: Array = KIND_WEIGHTS_BY_PROSPERITY.get(String(singles[i]["kind"]), [1.0, 1.0])
			w = lerpf(float(pair[0]), float(pair[1]), p)
		weights.append(w)
		total += w
	var roll: float = rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0 and weights[i] > 0.0:
			return i
	return maxi(0, singles.size() - 1)

# Pencere için sabit (konum + yuva numarasından türeyen) süs planı: 0-2 giriş. Boş dizi = süssüz pencere.
# Aynı rastgele zar refah basamağına göre eşiklenir, bu yüzden refah arttıkça pencereler tek tek süslenir.
func _build_decor_plan(index: int, half_open: bool) -> Array:
	_ensure_decor_library()
	var plan: Array = []
	var singles: Array = _decor_library[1]
	var wides: Array = _decor_library[2]
	var p: float = float(_prosperity_bucket()) / float(PROSPERITY_BUCKETS)
	var empty_chance: float = lerpf(DECOR_EMPTY_CHANCE_POOR, DECOR_EMPTY_CHANCE_RICH, p)
	var wide_chance: float = lerpf(DECOR_WIDE_CHANCE_POOR, DECOR_WIDE_CHANCE_RICH, p)
	var pair_chance: float = lerpf(DECOR_PAIR_CHANCE_POOR, DECOR_PAIR_CHANCE_RICH, p)
	var pos: Vector2 = global_position if is_inside_tree() else position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("decor%s_%s_%d" % ["_half" if half_open else "", str(pos.round()), index])
	var roll: float = rng.randf()
	if roll < empty_chance:
		return plan
	if half_open:
		# Yarı açık pencerede sadece menteşe tarafındaki açık yarı görünür: tek yarım süs, öbür yarıya konmaz.
		if singles.is_empty():
			return plan
		plan.append(_make_decor_entry(singles[_pick_single(singles, rng, p)], false, rng))
		return plan
	if roll < empty_chance + wide_chance and not wides.is_empty():
		plan.append(_make_decor_entry(wides[rng.randi() % wides.size()], false, rng))
		return plan
	if singles.is_empty():
		return plan
	var first_idx: int = _pick_single(singles, rng, p)
	var swap_first: bool = rng.randf() < 0.5
	plan.append(_make_decor_entry(singles[first_idx], swap_first, rng))
	if singles.size() > 1 and rng.randf() < pair_chance:
		var second_idx: int = _pick_single(singles, rng, p, first_idx)
		plan.append(_make_decor_entry(singles[second_idx], not swap_first, rng))
	return plan

# Açık pencerenin üstüne süs sprite'larını koyar, pencere açık değilse gizler.
# Rüzgârda sallanan (asılı) bir süs görünüyorsa true döner.
func _set_window_decor(index: int, window: Sprite2D, state: int) -> bool:
	var sprites: Array = _window_decor[index]
	var plan: Array = []
	if state == 2:
		if _decor_plans[index] == null:
			_decor_plans[index] = _build_decor_plan(index, false)
		plan = _decor_plans[index]
	elif state == 1:
		if _decor_half_plans[index] == null:
			_decor_half_plans[index] = _build_decor_plan(index, true)
		plan = _decor_half_plans[index]
	if plan.is_empty():
		for s in sprites:
			(s as Sprite2D).visible = false
		return false
	var swaying: bool = false
	while sprites.size() < plan.size():
		var s := Sprite2D.new()
		s.name = "WindowDecor%d" % sprites.size()
		s.centered = false
		window.add_child(s)
		sprites.append(s)
	for k in sprites.size():
		var s: Sprite2D = sprites[k]
		if k >= plan.size():
			s.visible = false
			continue
		var entry: Dictionary = plan[k]
		s.texture = entry["tex"]
		s.modulate = entry["tint"]
		# Pencere sprite'ı gibi aynı kutuya oturur (offset.x pencerenin menteşe tarafına göre); süs yarı tarafı
		# pencerenin kendi çevirmesi ve "öbür yarı" bayrağıyla belirlenir.
		s.flip_h = window.flip_h != bool(entry["swap"])
		# Süs tuvali (85 px) pencerenin menteşe kenarına hizalanır: yarı açık pencere 67 px olduğu için
		# pencerenin kendi offset'i yerine süsün kendi genişliği kullanılır.
		s.offset = Vector2(-float(s.texture.get_width()) if window.flip_h else 0.0, 0)
		s.position = Vector2(0, DECOR_CANVAS_OFFSET_Y)
		s.visible = true
		if SWAY_KINDS.has(String(entry["kind"])):
			s.material = _get_sway_material(s.texture)
			swaying = swaying or s.material != null
		else:
			s.material = null
	return swaying

# Doku başına paylaşılan sallanma materyali: çizimin dikey sınırları dokunun alfa kanalından bulunur.
static func _get_sway_material(tex: Texture2D) -> ShaderMaterial:
	if _sway_materials.has(tex):
		return _sway_materials[tex]
	var mat: ShaderMaterial = null
	var shader := load(SWAY_SHADER_PATH) as Shader
	var img: Image = tex.get_image()
	if shader != null and img != null:
		if img.is_compressed():
			img.decompress()
		var top_y: int = img.get_height()
		var bottom_y: int = -1
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					top_y = mini(top_y, y)
					bottom_y = maxi(bottom_y, y)
		if bottom_y >= top_y:
			mat = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("top_v", float(top_y) / float(img.get_height()))
			mat.set_shader_parameter("bottom_v", float(bottom_y + 1) / float(img.get_height()))
			mat.set_shader_parameter("tex_size", Vector2(img.get_width(), img.get_height()))
	_sway_materials[tex] = mat
	return mat

# Rüzgâr gücüne göre tüm sallanma materyallerinin genliğini ve hızını bir kez/kare günceller.
static func _update_sway_materials() -> void:
	var frame: int = Engine.get_process_frames()
	if frame == _sway_last_frame:
		return
	_sway_last_frame = frame
	var wind: float = 0.0
	var tree := Engine.get_main_loop() as SceneTree
	var weather: Node = tree.root.get_node_or_null("WeatherManager") if tree != null else null
	if weather != null and "wind_strength" in weather:
		wind = clampf(float(weather.wind_strength), 0.0, 1.0)
	var amp: float = SWAY_BASE_AMPLITUDE + wind * SWAY_WIND_AMPLITUDE
	var spd: float = SWAY_BASE_SPEED + wind * SWAY_WIND_SPEED
	for mat in _sway_materials.values():
		if mat != null:
			(mat as ShaderMaterial).set_shader_parameter("amplitude_px", amp)
			(mat as ShaderMaterial).set_shader_parameter("speed", spd)

func _process(delta: float) -> void:
	_update_sway_materials()
	var t: float = Time.get_ticks_msec() / 1000.0
	var intensity: float = _night_intensity()
	var any_visible: bool = false
	for light in _window_lights:
		if light == null or not light.visible:
			continue
		var on: bool = bool(light.get_meta("target_on", false))
		var fade: float = move_toward(float(light.get_meta("fade", 0.0)), 1.0 if on else 0.0, delta / LIGHT_FADE_SECONDS)
		light.set_meta("fade", fade)
		if not on and fade <= 0.0:
			light.visible = false
			continue
		any_visible = true
		var phase: float = float(light.get_meta("phase", 0.0))
		var flicker: float = sin(t * 6.3 + phase) * 0.6 + sin(t * 13.7 + phase * 2.1) * 0.4
		light.modulate.a = fade * intensity * (1.0 - FLICKER_STRENGTH * 0.5 + flicker * FLICKER_STRENGTH * 0.5)
	# Işık yoksa ve sallanan süs de yoksa işlemeyi apply_window_states yeniden açana kadar durdur.
	if not any_visible and not _has_swaying_decor:
		set_process(false)

static func _is_arch_pixel(c: Color) -> bool:
	return c.a > 0.5 and c.r8 == ARCH_COLOR_R8 and c.g8 == ARCH_COLOR_G8 and c.b8 == ARCH_COLOR_B8

# Pencere dokusundaki bağlantılı koyu kemer bölgesini bulup ona sıcak bir gradyan dolgu doku üretir (doku başına önbellekli).
# Kemer bulunamazsa (kapalı pencere) null döner.
static func _get_light_texture(window_tex: Texture2D, top: Color, bottom: Color) -> Texture2D:
	if _light_texture_cache.has(window_tex):
		return _light_texture_cache[window_tex]
	var result: Texture2D = null
	var img: Image = window_tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var w: int = img.get_width()
		var h: int = img.get_height()
		var seed_pos := Vector2i(int(w * ARCH_SEED_X_RATIO), h / 2)
		if _is_arch_pixel(img.get_pixelv(seed_pos)):
			var mask := Image.create(w, h, false, Image.FORMAT_RGBA8)
			var visited := PackedByteArray()
			visited.resize(w * h)
			var stack: Array[Vector2i] = [seed_pos]
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
					continue
				var idx: int = p.y * w + p.x
				if visited[idx] == 1:
					continue
				visited[idx] = 1
				if not _is_arch_pixel(img.get_pixelv(p)):
					continue
				mask.set_pixelv(p, top.lerp(bottom, float(p.y) / float(max(1, h - 1))))
				stack.append(Vector2i(p.x + 1, p.y))
				stack.append(Vector2i(p.x - 1, p.y))
				stack.append(Vector2i(p.x, p.y + 1))
				stack.append(Vector2i(p.x, p.y - 1))
			result = ImageTexture.create_from_image(mask)
	_light_texture_cache[window_tex] = result
	return result

func get_window_count() -> int:
	return _window_sprites.size()
