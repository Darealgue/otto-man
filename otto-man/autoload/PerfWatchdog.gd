extends CanvasLayer

## Performans izleyici (donma/yavaşlama teşhisi):
##   - Yavaş kareler (>= SLOW_FRAME_MSEC) kare süresi + sahne durumuyla (düşman, mermi, düğüm sayısı, aktif item'lar) user://logs/perf_log.txt'ye yazılır.
##   - Her saniye durum user://logs/perf_heartbeat.txt'ye yazılır; oyun donarsa (ana thread FREEZE_SECONDS boyunca kare üretmezse) ayrı bir
##     izleme thread'i perf_log.txt'ye "FREEZE" satırı + son bilinen durumu ekler. Donma sonrası bu dosyaya bakılır.
##   - F3 (yalnızca editörde): sağ üstte FPS / kare süresi / düşman / mermi / düğüm göstergesi.
## Maliyeti küçüktür: kare başına birkaç toplama, saniyede bir durum örneği.

const SLOW_FRAME_MSEC: float = 120.0
const HEARTBEAT_SEC: float = 1.0
const FREEZE_SECONDS: float = 3.0
const MAX_LOG_BYTES: int = 512 * 1024
const MAX_SLOW_LOGS_PER_MINUTE: int = 20
const LOG_PATH: String = "user://logs/perf_log.txt"
const HEARTBEAT_PATH: String = "user://logs/perf_heartbeat.txt"

var _last_tick_usec: int = 0
var _beat_timer: float = 0.0
var _acc_frames: int = 0
var _acc_ms_sum: float = 0.0
var _acc_ms_max: float = 0.0
var _slow_logged_this_minute: int = 0
var _minute_start_msec: int = 0
var _label: Label = null
var _hud_on: bool = false

var _mutex := Mutex.new()
var _snapshot: String = "(henüz yok)"
var _main_tick_msec: int = 0
var _thread: Thread = null
var _thread_run: bool = true
var _freeze_reported: bool = false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	_last_tick_usec = Time.get_ticks_usec()
	_main_tick_msec = Time.get_ticks_msec()
	_minute_start_msec = _main_tick_msec
	_label = Label.new()
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -330.0
	_label.offset_right = -10.0
	_label.offset_top = 8.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)
	_thread = Thread.new()
	_thread.start(_watch_loop)


func _exit_tree() -> void:
	_thread_run = false
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("editor"):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_hud_on = not _hud_on
		_label.visible = _hud_on


func _process(delta: float) -> void:
	var now_us: int = Time.get_ticks_usec()
	var ms: float = float(now_us - _last_tick_usec) / 1000.0
	_last_tick_usec = now_us
	_mutex.lock()
	_main_tick_msec = Time.get_ticks_msec()
	_mutex.unlock()
	_freeze_reported = false
	_acc_frames += 1
	_acc_ms_sum += ms
	_acc_ms_max = maxf(_acc_ms_max, ms)
	if ms >= SLOW_FRAME_MSEC:
		_log_slow_frame(ms)
	_beat_timer += delta
	if _beat_timer >= HEARTBEAT_SEC:
		_beat_timer = 0.0
		_heartbeat()


func _state_line() -> String:
	var tree := get_tree()
	var scene_path: String = "?"
	var enemies: int = 0
	var projectiles: int = 0
	if tree != null:
		if tree.current_scene != null:
			scene_path = String(tree.current_scene.scene_file_path)
		enemies = tree.get_nodes_in_group("enemies").size()
		projectiles = tree.get_nodes_in_group("player_projectiles").size()
	var items: PackedStringArray = PackedStringArray()
	var im := get_node_or_null("/root/ItemManager")
	if im != null and "active_items" in im:
		for it in im.active_items:
			if it != null and "item_id" in it:
				items.append(String(it.item_id))
	return "scene=%s enemies=%d player_projectiles=%d nodes=%d orphans=%d objects=%d items=[%s]" % [
		scene_path, enemies, projectiles,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		",".join(items),
	]


func _heartbeat() -> void:
	var avg: float = _acc_ms_sum / maxf(float(_acc_frames), 1.0)
	var line: String = "t=%d avg_ms=%.1f max_ms=%.1f fps=%d %s" % [
		Time.get_ticks_msec() / 1000, avg, _acc_ms_max, int(Engine.get_frames_per_second()), _state_line()]
	_mutex.lock()
	_snapshot = line
	_mutex.unlock()
	if _hud_on and _label != null:
		var tree := get_tree()
		_label.text = "FPS %d   kare %.1f ms (maks %.0f)\ndüşman %d   mermi %d\ndüğüm %d   yetim %d" % [
			int(Engine.get_frames_per_second()), avg, _acc_ms_max,
			tree.get_nodes_in_group("enemies").size() if tree != null else 0,
			tree.get_nodes_in_group("player_projectiles").size() if tree != null else 0,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))]
	var f := FileAccess.open(HEARTBEAT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line(line)
		f.close()
	_acc_frames = 0
	_acc_ms_sum = 0.0
	_acc_ms_max = 0.0


func _log_slow_frame(ms: float) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _minute_start_msec > 60000:
		_minute_start_msec = now_msec
		_slow_logged_this_minute = 0
	if _slow_logged_this_minute >= MAX_SLOW_LOGS_PER_MINUTE:
		return
	_slow_logged_this_minute += 1
	_append_log("SLOW t=%d frame_ms=%.0f %s" % [now_msec / 1000, ms, _state_line()])


func _append_log(line: String) -> void:
	var f: FileAccess = null
	if FileAccess.file_exists(LOG_PATH):
		f = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if f != null and f.get_length() > MAX_LOG_BYTES:
			f.close()
			f = FileAccess.open(LOG_PATH, FileAccess.WRITE)   # çok büyüdü: baştan başla
		elif f != null:
			f.seek_end()
	else:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line(line)
	f.close()


## Ayrı thread: ana thread FREEZE_SECONDS boyunca kare üretmezse donmayı kaydeder (oyun kilitliyken yalnız bu thread yazabilir).
func _watch_loop() -> void:
	while _thread_run:
		OS.delay_msec(500)
		_mutex.lock()
		var since: int = Time.get_ticks_msec() - _main_tick_msec
		var snap: String = _snapshot
		_mutex.unlock()
		if float(since) / 1000.0 >= FREEZE_SECONDS and not _freeze_reported:
			_freeze_reported = true
			_append_log("FREEZE ana thread %.1f sn'dir kare üretmiyor. Son durum: %s" % [float(since) / 1000.0, snap])
