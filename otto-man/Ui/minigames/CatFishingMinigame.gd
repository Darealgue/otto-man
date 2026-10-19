extends "res://ui/minigames/MinigameBase.gd"

## Stardew Valley tarzı balık tutma (kedi için): dikey bir çubukta bir balık rastgele yukarı aşağı kaçar; etkileşim tuşunu
## (ya da sol tık) basılı tutunca yeşil yakalama alanı yükselir, bırakınca düşer. Balık alanın içindeyken sağdaki ilerleme çubuğu
## dolar, dışındayken boşalır. Dolarsa 1 balık tutulur (kediye gider), boşalırsa ya da süre biterse balık kaçar.
## Kod ile çizilir (çizim gerekmez); balık simgesi ve renkler sonra elle çizimle değiştirilebilir.

const BAR_SIZE: Vector2 = Vector2(46.0, 340.0)
const PROGRESS_WIDTH: float = 14.0
const START_PROGRESS: float = 0.35
const TIME_LIMIT: float = 55.0

# Yakalama alanı fiziği (çubuk uzunluğu 1.0 kabul edilir).
const ZONE_ACCEL_UP: float = 2.1
const ZONE_GRAVITY: float = 1.65
const ZONE_MAX_SPEED: float = 0.92
const ZONE_BOUNCE: float = 0.25

# Balık hareketi: aralıklarla yeni hedef seçer, hedefe doğru süzülür; ara sıra hızlı atılır.
const FISH_RETARGET_MIN: float = 0.85
const FISH_RETARGET_MAX: float = 1.95
const FISH_DART_SPEED: float = 0.8

## Zorluk seviyeleri (context "difficulty": 1 kolay, 2 orta, 3 zor; balığı tutan kedi tarafı rastgele seçer):
## zone: yakalama alanı yüksekliği, fish_speed: balığın süzülme hızı, dart: ani atılma olasılığı,
## gain/loss: balık alanın içindeyken/dışındayken ilerlemenin saniyedeki artış/azalışı, start: başlangıç ilerlemesi, time: süre.
const DIFFICULTY: Dictionary = {
	1: {"zone": 0.38, "fish_speed": 0.32, "dart": 0.10, "gain": 0.27, "loss": 0.10, "start": 0.45, "time": 58.0},
	2: {"zone": 0.32, "fish_speed": 0.41, "dart": 0.19, "gain": 0.235, "loss": 0.135, "start": 0.38, "time": 54.0},
	3: {"zone": 0.29, "fish_speed": 0.45, "dart": 0.23, "gain": 0.225, "loss": 0.15, "start": 0.35, "time": 52.0},
}

const BG_COLOR: Color = Color(0.05, 0.07, 0.1, 0.88)
const BORDER_COLOR: Color = Color(0.55, 0.5, 0.4, 1.0)
const ZONE_COLOR: Color = Color(0.35, 0.85, 0.45, 0.65)
const ZONE_EDGE_COLOR: Color = Color(0.6, 1.0, 0.65, 0.95)

var _zone_pos: float = 0.2       # alanın alt kenarı (0 = çubuğun dibi)
var _zone_vel: float = 0.0
var _fish_pos: float = 0.6
var _fish_target: float = 0.6
var _fish_timer: float = 0.5
var _difficulty: int = 2
var _zone_h: float = 0.25
var _fish_speed: float = 0.55
var _dart_chance: float = 0.35
var _gain: float = 0.20
var _loss: float = 0.19
var _fish_speed_now: float = 0.55
var _progress: float = START_PROGRESS
var _time_left: float = TIME_LIMIT
var _armed: bool = false         # oyunu başlatan tuş basışı bırakılana kadar girdi sayılmaz
var _view: Control = null
var _in_zone: bool = false


## Çizim: oyun durumunu okuyan Control.
class _View extends Control:
	var game: Node = null

	func _draw() -> void:
		if game == null or not is_instance_valid(game):
			return
		game._paint(self)


func _on_minigame_ready() -> void:
	pause_game = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = _View.new()
	_view.game = self
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_difficulty = clampi(int(get_context_value("difficulty", 2)), 1, 3)
	var d: Dictionary = DIFFICULTY[_difficulty]
	_zone_h = float(d["zone"])
	_fish_speed = float(d["fish_speed"])
	_fish_speed_now = _fish_speed
	_dart_chance = float(d["dart"])
	_gain = float(d["gain"])
	_loss = float(d["loss"])
	_progress = float(d["start"])
	_time_left = float(d["time"])
	_fish_target = randf_range(0.15, 0.85)
	_fish_timer = randf_range(FISH_RETARGET_MIN, FISH_RETARGET_MAX)
	set_process(true)


func _holding() -> bool:
	return Input.is_action_pressed("interact") or Input.is_action_pressed("ui_up") \
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _process(delta: float) -> void:
	if is_finished():
		return
	if not _armed:
		if not _holding():
			_armed = true
	var holding: bool = _armed and _holding()
	# Alan: basılıyken yukarı ivmelenir, bırakınca düşer; uçlara çarpınca hafif zıplar.
	var accel: float = ZONE_ACCEL_UP if holding else -ZONE_GRAVITY
	_zone_vel = clampf(_zone_vel + accel * delta, -ZONE_MAX_SPEED, ZONE_MAX_SPEED)
	_zone_pos += _zone_vel * delta
	var max_pos: float = 1.0 - _zone_h
	if _zone_pos <= 0.0:
		_zone_pos = 0.0
		_zone_vel = maxf(0.0, -_zone_vel * ZONE_BOUNCE)
	elif _zone_pos >= max_pos:
		_zone_pos = max_pos
		_zone_vel = minf(0.0, -_zone_vel * ZONE_BOUNCE)
	# Balık
	_fish_timer -= delta
	if _fish_timer <= 0.0:
		_fish_timer = randf_range(FISH_RETARGET_MIN, FISH_RETARGET_MAX)
		_fish_target = randf_range(0.06, 0.94)
		_fish_speed_now = FISH_DART_SPEED if randf() < _dart_chance else _fish_speed
	_fish_pos = move_toward(_fish_pos, _fish_target, _fish_speed_now * delta)
	# İlerleme
	_in_zone = _fish_pos >= _zone_pos and _fish_pos <= _zone_pos + _zone_h
	_progress += (_gain if _in_zone else -_loss) * delta
	_time_left -= delta
	if _progress >= 1.0:
		_progress = 1.0
		finish(true, {"fish": 1, "difficulty": _difficulty, "cat_path": String(get_context_value("cat_path", ""))})
	elif _progress <= 0.0 or _time_left <= 0.0:
		finish(false, {"fish": 0, "difficulty": _difficulty, "cat_path": String(get_context_value("cat_path", ""))})
	if is_instance_valid(_view):
		_view.queue_redraw()


## Çubuk, yakalama alanı, balık ve ilerleme çubuğu (ekranın sağ ortasında) çizilir.
func _paint(c: Control) -> void:
	var vp: Vector2 = c.get_viewport_rect().size
	var origin: Vector2 = Vector2(vp.x * 0.5 + 230.0, vp.y * 0.5 - BAR_SIZE.y * 0.5)
	var bar := Rect2(origin, BAR_SIZE)
	c.draw_rect(Rect2(bar.position - Vector2(4, 4), bar.size + Vector2(PROGRESS_WIDTH + 18, 8)), BG_COLOR)
	c.draw_rect(bar, Color(0.12, 0.2, 0.3, 1.0))
	c.draw_rect(bar, BORDER_COLOR, false, 2.0)
	# Yakalama alanı (çubukta alt = 0)
	var zone_top: float = bar.end.y - (_zone_pos + _zone_h) * bar.size.y
	var zone_rect := Rect2(Vector2(bar.position.x + 3, zone_top), Vector2(bar.size.x - 6, _zone_h * bar.size.y))
	c.draw_rect(zone_rect, ZONE_COLOR)
	c.draw_rect(zone_rect, ZONE_EDGE_COLOR, false, 2.0)
	# Balık
	var fish_center := Vector2(bar.position.x + bar.size.x * 0.5, bar.end.y - _fish_pos * bar.size.y)
	_draw_fish(c, fish_center, 1.0)
	# İlerleme çubuğu (sağda)
	var prog := Rect2(Vector2(bar.end.x + 10, bar.position.y), Vector2(PROGRESS_WIDTH, bar.size.y))
	c.draw_rect(prog, Color(0.1, 0.1, 0.12, 1.0))
	var fill_h: float = _progress * prog.size.y
	var fill_color: Color = Color(0.9, 0.3, 0.25).lerp(Color(0.4, 0.9, 0.4), _progress)
	c.draw_rect(Rect2(Vector2(prog.position.x, prog.end.y - fill_h), Vector2(prog.size.x, fill_h)), fill_color)
	c.draw_rect(prog, BORDER_COLOR, false, 2.0)
	# Zorluk göstergesi: çubuğun üstünde 1-3 küçük nokta (3 nokta = zor balık, daha çok bağ puanı).
	for i in range(_difficulty):
		c.draw_circle(Vector2(bar.position.x + bar.size.x * 0.5 + (float(i) - float(_difficulty - 1) * 0.5) * 12.0, bar.position.y - 14.0), 4.0, Color(1.0, 0.85, 0.35))
	# Yukarı ok (basılı tut ipucu)
	var arrow_c := Vector2(bar.position.x + bar.size.x * 0.5, bar.end.y + 22.0)
	c.draw_colored_polygon(PackedVector2Array([arrow_c + Vector2(0, -8), arrow_c + Vector2(9, 6), arrow_c + Vector2(-9, 6)]), Color(0.9, 0.9, 0.85, 0.9))


## Küçük gümüş balık (kod çizimi): gövde, kuyruk ve göz. Kediye ait istek simgesi (CatFishIcon) da aynı şekli kullanır.
static func _draw_fish(c: CanvasItem, center: Vector2, scale: float) -> void:
	var body := PackedVector2Array()
	for i in range(13):
		var a: float = TAU * float(i) / 12.0
		body.append(center + Vector2(cos(a) * 10.0, sin(a) * 5.0) * scale)
	c.draw_colored_polygon(body, Color(0.62, 0.78, 0.88))
	var tail := PackedVector2Array([
		center + Vector2(8, 0) * scale, center + Vector2(15, -6) * scale, center + Vector2(15, 6) * scale])
	c.draw_colored_polygon(tail, Color(0.5, 0.68, 0.82))
	c.draw_circle(center + Vector2(-5, -1) * scale, 1.3 * scale, Color(0.05, 0.05, 0.08))
