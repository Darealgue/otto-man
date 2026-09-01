extends CanvasLayer
## Bottom-right progress indicator for the AI-villagers model download.
##
## Lives as a child of the AiVillagers autoload rather than inside any scene, so it survives
## every scene change — the download runs across the menu, the village, dungeons and the world
## map, and the indicator has to follow it without being rebuilt or losing state.
##
## Deliberately small and non-blocking: the whole point of the design is that the player keeps
## playing while 7.5 GB arrives. It shows itself when there is something to report and hides
## again afterwards.

## Design-space size; the CanvasLayer follows the project's stretch settings.
const PANEL_WIDTH := 360.0
const MARGIN := 18.0
## The village's resource bar (VillageStatusUI's TopBarPanel) is anchored to the BOTTOM of the
## screen and is 56px tall, so an 18px bottom margin puts the chip straight behind it. The player
## spends most of the download in the village, so the chip has to clear that bar plus a gap.
const BOTTOM_MARGIN := 78.0
## Tall enough for the title, a two-line detail (bytes + time remaining), the "you can keep
## playing" hint and the bar. When this was 92px the progress bar overflowed the panel and was
## simply not visible; the hint line added on 2026-08-31 needs another ~34px on top of that.
const PANEL_HEIGHT := 172.0
## How long the finished/failed message lingers before the chip fades out.
const READY_LINGER_SEC := 9.0
const FAILED_LINGER_SEC := 14.0
const FADE_SEC := 0.5
## Rate is averaged over this many one-second samples so the ETA does not jitter every frame.
const RATE_SAMPLES := 12

enum Mode { HIDDEN, DOWNLOADING, VERIFYING, LOADING, READY, FAILED }

var _mode: int = Mode.HIDDEN
var _panel: PanelContainer = null
var _title_label: Label = null
var _detail_label: Label = null
## "Bu sırada oynamaya devam edebilirsiniz." — ilk playtest (2026-08-31): oyuncu ilerleme
## çubuğunu bir yükleme ekranı sanıp indirme bitene kadar bekledi. Bu satır indirme/doğrulama
## /model yükleme boyunca görünür, hazır ve hata durumlarında gizlenir.
var _hint_label: Label = null
var _bar: ProgressBar = null

var _rate_samples: Array[float] = []
var _last_sample_time := 0.0
var _last_sample_bytes := 0
var _linger_left := 0.0
var _fading := false


func _ready() -> void:
	# VillageScene stacks CanvasLayers up to 210, so the original 90 left the chip buried under the
	# village UI. 240 puts it above everything the game normally shows while the download runs.
	layer = 240
	_build()
	_apply_mode(Mode.HIDDEN)
	set_process(true)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -(PANEL_WIDTH + MARGIN)
	_panel.offset_right = -MARGIN
	_panel.offset_top = -(BOTTOM_MARGIN + PANEL_HEIGHT)
	_panel.offset_bottom = -BOTTOM_MARGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ParchmentTextures.apply_large_panel_style(_panel, 12)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	margin.add_child(col)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0))
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title_label)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 12)
	_detail_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74, 1.0))
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_label)

	_hint_label = Label.new()
	_hint_label.text = tr("ai.chip.keep_playing")
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.72, 0.90, 0.66, 1.0))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Explicit styles: the default theme's ProgressBar is nearly invisible against the dark
	# parchment panel, which made it look like the bar was missing entirely.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.08, 1.0)
	bg.border_color = Color(0.45, 0.38, 0.26, 1.0)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.82, 0.45, 1.0)
	fill.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_bar)


# --- public API, driven by AiVillagers ---

func show_downloading() -> void:
	_apply_mode(Mode.DOWNLOADING)


func show_verifying() -> void:
	_apply_mode(Mode.VERIFYING)


func show_loading() -> void:
	_apply_mode(Mode.LOADING)


func show_ready() -> void:
	_apply_mode(Mode.READY)


func show_failed() -> void:
	_apply_mode(Mode.FAILED)


func hide_chip() -> void:
	_apply_mode(Mode.HIDDEN)


func _apply_mode(mode: int) -> void:
	_mode = mode
	_fading = false
	if not is_instance_valid(_panel):
		return
	_panel.modulate.a = 1.0
	_panel.visible = mode != Mode.HIDDEN
	# Hazır/hata satırları zaten ne yapılacağını söylüyor; ipucu yalnızca beklemenin
	# gereksiz olduğu aşamalarda anlamlı.
	_hint_label.text = tr("ai.chip.keep_playing")
	_hint_label.visible = mode == Mode.DOWNLOADING or mode == Mode.VERIFYING or mode == Mode.LOADING

	match mode:
		Mode.DOWNLOADING:
			_title_label.text = tr("ai.chip.downloading.title")
			_bar.visible = true
			_reset_rate_tracking()
		Mode.VERIFYING:
			_title_label.text = tr("ai.chip.verifying.title")
			_detail_label.text = tr("ai.chip.verifying.detail")
			_bar.visible = true
		Mode.LOADING:
			_title_label.text = tr("ai.chip.loading.title")
			_detail_label.text = tr("ai.chip.loading.detail")
			_bar.visible = true
			_bar.value = 1.0
		Mode.READY:
			_title_label.text = tr("ai.chip.ready.title")
			_detail_label.text = tr("ai.chip.ready.detail")
			_bar.visible = false
			_linger_left = READY_LINGER_SEC
		Mode.FAILED:
			_title_label.text = tr("ai.chip.failed.title")
			_detail_label.text = tr("ai.chip.failed.detail")
			_bar.visible = false
			_linger_left = FAILED_LINGER_SEC


func _process(delta: float) -> void:
	match _mode:
		Mode.DOWNLOADING:
			_tick_downloading()
		Mode.VERIFYING:
			_tick_verifying()
		Mode.READY, Mode.FAILED:
			_tick_linger(delta)


func _tick_downloading() -> void:
	var ai := get_parent()
	if ai == null:
		return
	var downloaded := int(ai.call("get_downloaded_bytes"))
	var total := int(ai.call("get_total_bytes"))
	_bar.value = float(ai.call("get_download_progress"))
	_detail_label.text = "%s / %s\n%s" % [
		_format_bytes(downloaded), _format_bytes(total), _eta_text(downloaded, total)
	]


func _tick_verifying() -> void:
	var ai := get_parent()
	if ai == null:
		return
	if ai.has_method("get_verify_progress"):
		_bar.value = float(ai.call("get_verify_progress"))


func _tick_linger(delta: float) -> void:
	if _fading:
		return
	_linger_left -= delta
	if _linger_left > 0.0:
		return
	_fading = true
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_SEC)
	tween.finished.connect(func() -> void:
		if _mode == Mode.READY or _mode == Mode.FAILED:
			_apply_mode(Mode.HIDDEN)
	)


func _reset_rate_tracking() -> void:
	_rate_samples.clear()
	_last_sample_time = 0.0
	_last_sample_bytes = 0


## Averages recent throughput rather than using an instantaneous figure, which on a real
## connection swings wildly enough to make the estimate useless.
func _eta_text(downloaded: int, total: int) -> String:
	var now := Time.get_ticks_msec() / 1000.0
	if _last_sample_time <= 0.0:
		_last_sample_time = now
		_last_sample_bytes = downloaded
		return tr("ai.chip.eta_unknown")

	var elapsed := now - _last_sample_time
	if elapsed >= 1.0:
		var rate := float(downloaded - _last_sample_bytes) / elapsed
		if rate > 0.0:
			_rate_samples.append(rate)
			if _rate_samples.size() > RATE_SAMPLES:
				_rate_samples.pop_front()
		_last_sample_time = now
		_last_sample_bytes = downloaded

	if _rate_samples.is_empty():
		return tr("ai.chip.eta_unknown")

	var sum := 0.0
	for r in _rate_samples:
		sum += r
	var avg := sum / float(_rate_samples.size())
	if avg <= 0.0:
		return tr("ai.chip.eta_unknown")

	var remaining := maxf(0.0, float(total - downloaded))
	var seconds := remaining / avg
	if seconds >= 3600.0:
		return tr("ai.chip.eta_hours") % int(round(seconds / 3600.0))
	var minutes := int(ceil(seconds / 60.0))
	return tr("ai.chip.eta_minutes") % maxi(minutes, 1)


func _format_bytes(bytes: int) -> String:
	var gb := float(bytes) / 1073741824.0
	if gb >= 1.0:
		return "%.1f GB" % gb
	var mb := float(bytes) / 1048576.0
	return "%.0f MB" % mb
