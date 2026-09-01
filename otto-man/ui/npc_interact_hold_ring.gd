class_name NpcInteractHoldRing
extends Control

## Köylü etkileşim tuşu etrafında basılı tutma ilerlemesi.
##
## İlk playtest (2026-08-31): "etkileşim tuşuna nerede basılı tutacağını nerede basıp
## bırakacağını anlamak zor". Köyde kural şu: NPC ile konuşmak tuşu BASILI TUTMAYI, bina /
## kamp ateşi gibi şeylerse KISA BASMAYI ister (bkz. player.gd
## _process_village_interaction_hold). Halka eskiden yalnızca oyuncu tuşa bastıktan sonra
## görünüyordu, yani ipucu ancak doğru tuşu zaten bulmuş oyuncuya gösteriliyordu.
##
## Artık halka ok ikonu görünür olduğu sürece HEP çizilir: soluk halka "bu hedef basılı tutmak
## istiyor" demek, dolan altın yay ise ilerlemedir. Basılı tutma gerektirmeyen hedeflerde
## (bina, kamp ateşi, portal) halka hiç yok — ikisi bir bakışta ayrılıyor.

const RING_SIZE := 34.0
const LINE_WIDTH := 2.5
const START_ANGLE := -PI * 0.5
const RING_COLOR_BG := Color(0.95, 0.93, 0.88, 0.28)
const RING_COLOR_FG := Color(0.95, 0.78, 0.35, 1.0)
const DECAY_SPEED := 8.0

var _target_progress := 0.0
var _display_progress := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(RING_SIZE, RING_SIZE)
	size = Vector2(RING_SIZE, RING_SIZE)
	# Ebeveyni (ok ikonu / etkileşim butonu) zaten menzil dışında gizleniyor; halkanın kendi
	# görünürlüğünü kapatmıyoruz ki "basılı tut" işareti ipucuyla birlikte gelsin.
	visible = true
	set_process(true)


## control artık bu ring'in PARENT'ı (bkz. NpcOverheadUi.attach_hold_ring) — kendi local
## uzayında ortalanıyoruz, control'ün position'ı (kendi ebeveynine göre) alakasız.
func sync_to_control(control: Control) -> void:
	if control == null:
		return
	position = control.size * 0.5 - size * 0.5


func sync_to_button(button: Control) -> void:
	sync_to_control(button)


func set_progress(ratio: float) -> void:
	_target_progress = clampf(ratio, 0.0, 1.0)


func _process(delta: float) -> void:
	var prev := _display_progress
	if _target_progress >= _display_progress:
		_display_progress = _target_progress
	else:
		_display_progress = move_toward(_display_progress, _target_progress, delta * DECAY_SPEED)
	if not is_equal_approx(prev, _display_progress):
		queue_redraw()
	if _target_progress <= 0.0 and _display_progress <= 0.001:
		_display_progress = 0.0


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - LINE_WIDTH * 0.5
	draw_arc(center, radius, 0.0, TAU, 48, RING_COLOR_BG, LINE_WIDTH, true)
	if _display_progress <= 0.001:
		return
	var end_angle := START_ANGLE + TAU * _display_progress
	var point_count := maxi(8, int(48.0 * _display_progress))
	draw_arc(center, radius, START_ANGLE, end_angle, point_count, RING_COLOR_FG, LINE_WIDTH, true)
