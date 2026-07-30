class_name PulsingHighlight
extends Control
## Reusable "pulsing energy" attention highlight for tutorial popups and similar UI.
## A glowing warm-orange border that pulses once (a couple of quick breaths) when new content
## arrives, then settles into a steady static glow until stop_pulse() is called. The highlight's
## own rect never grows or shrinks — only the glow's brightness/spread animates — so it reads as
## living energy, not a resizing frame.
##
## The "glow" is faked with several border-only StyleBoxFlat rings drawn at increasing size and
## decreasing alpha (StyleBoxFlat's own shadow_size draws a solid filled silhouette, not a soft
## blur, so it can't be used directly for this).
##
## Not size-bound to its own parent: call follow(target) to have it track another Control's
## position/size every frame (use this when the parent is a layout Container that might fight
## over child sizing/clipping, e.g. PanelContainer). Otherwise it anchors full-rect to whatever
## it's parented to.
##
## Usage: var h := preload("res://ui/PulsingHighlight.gd").new(); target.get_parent().add_child(h)
## h.follow(target)  # or just parent it directly under a plain Control and skip this
## h.pulse_once_then_hold() / h.stop_pulse()

@export var pulse_color: Color = Color(1.0, 0.62, 0.05) ## warm "legendary" orange-gold
@export var min_alpha: float = 0.3
@export var max_alpha: float = 1.0
@export var pulse_period: float = 0.9
@export var pulse_cycles: float = 1.6 ## how many breaths to animate before settling static
@export var border_width: int = 3
@export var corner_radius: int = 14
@export var glow_min_size: float = 4.0
@export var glow_max_size: float = 16.0
@export var glow_layers: int = 3

var _t: float = 0.0
var _animating: bool = false
var _style: StyleBoxFlat
var _follow_target: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0, 0, 0, 0)
	_style.shadow_size = 0
	_style.anti_aliasing = true
	visible = false
	set_process(false)


## Track another Control's position/size every frame instead of relying on this node's own
## anchors — use when parented to a layout Container (e.g. PanelContainer) whose internal
## sizing/clipping behavior for extra children isn't reliable.
func follow(target: Control) -> void:
	_follow_target = target
	_sync_to_target()


func _sync_to_target() -> void:
	if not is_instance_valid(_follow_target):
		return
	position = _follow_target.position
	size = _follow_target.size


## Plays a short pulse burst, then settles into a static glow that holds until stop_pulse().
func pulse_once_then_hold() -> void:
	_t = 0.0
	_animating = true
	visible = true
	set_process(true)
	queue_redraw()


func stop_pulse() -> void:
	visible = false
	_animating = false
	set_process(false)


func _process(delta: float) -> void:
	if is_instance_valid(_follow_target):
		_sync_to_target()
	if _animating:
		_t += delta
		if _t >= pulse_period * pulse_cycles:
			_animating = false
	queue_redraw()
	# Once settled, only keep processing if there's a moving target to track — a static,
	# non-following highlight has nothing left to compute every frame.
	if not _animating and not is_instance_valid(_follow_target):
		set_process(false)


func _draw() -> void:
	if _style == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var phase: float = (sin(_t * TAU / maxf(0.05, pulse_period)) * 0.5 + 0.5) if _animating else 1.0
	var alpha := lerpf(min_alpha, max_alpha, phase)
	var glow := lerpf(glow_min_size, glow_max_size, phase)
	# Soft outer layers first (wide, faint bands), then a crisp bright ring at the exact edge.
	for i in range(glow_layers, 0, -1):
		var frac := float(i) / float(glow_layers)
		var expand := glow * frac
		var layer_alpha := alpha * 0.3 * (1.0 + (1.0 - frac))
		_style.set_border_width_all(int(round(6.0 + 8.0 * frac)))
		_style.set_corner_radius_all(int(corner_radius + expand))
		_style.border_color = Color(pulse_color.r, pulse_color.g, pulse_color.b, clampf(layer_alpha, 0.0, 1.0))
		draw_style_box(_style, Rect2(-expand, -expand, size.x + expand * 2.0, size.y + expand * 2.0))
	_style.set_border_width_all(border_width)
	_style.set_corner_radius_all(corner_radius)
	_style.border_color = Color(pulse_color.r, pulse_color.g, pulse_color.b, alpha)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
