extends Node2D

const MEDIEVAL_THEME = preload("res://resources/medieval_theme.tres")
const SQRT3: float = 1.7320508
const HEX_SIZE: float = 26.0
const TILE_WIDTH: float = 64.0
const TILE_HEIGHT: float = 64.0
const TILE_HEADROOM: float = 16.0
const TILE_DEAD_BOTTOM: float = 16.0
const TILE_TOP_SURFACE: float = 32.0
const HEX_STEP_X: float = 48.0
const HEX_STEP_Y: float = 32.0
const ZOOM_STEP: float = 0.1
## Godot 4 Camera2D.zoom: BUYUK deger = yakin (buyuk karolar), KUCUK = uzak (genis alan).
## En uzaga (haritayi kucuk goster); onceki varsayilan giris ~0.6 bundan oteye inilmez.
const ZOOM_FARTHEST: float = 0.6
## En yakin (varsayilan harita girisi).
const ZOOM_CLOSEST: float = 1.6
const CURSOR_TOP_HALF_WIDTH: float = 30.0
const CURSOR_TOP_HALF_HEIGHT: float = 12.0
const CURSOR_HOLD_DELAY_SEC: float = 0.38
const CURSOR_REPEAT_INTERVAL_SEC: float = 0.075
const CAMERA_FOLLOW_SNAP_DISTANCE: float = 900.0
## Kritik sonumlemeli yay (rad/s). Dusuk = daha yumusak kamera; yuksek = daha hizli oturma.
const CAMERA_FOLLOW_OMEGA: float = 3.85
## Hedefe bu kadar yaklasinca tam kilitle (mikro titreme onleme).
const CAMERA_FOLLOW_SNAP_EPS: float = 1.35
const CAMERA_FOLLOW_VEL_MAX: float = 3400.0
const PATH_PREVIEW_DEBOUNCE_SEC: float = 0.12
## Imleci hizli gezdirirken her hex'te _update_status_label() agir; en fazla bu aralikla yenile.
const CURSOR_STATUS_LABEL_MIN_INTERVAL_SEC: float = 0.12
const TRAVEL_PAWN_HEX_DURATION_SEC: float = 0.28
# WorldManager._get_hex_neighbors ile aynı axial komşu sırası (indeks -> dq,dr).
const AKARSU_NEIGHBOR_DIRS: Array = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)
]
## Harita ozel; InputMap ile baglanir — sabit harf kodlama yok.
const ACTION_WM_ZOOM_OUT := "world_map_zoom_out"
const ACTION_WM_ZOOM_IN := "world_map_zoom_in"
const ACTION_WM_TOGGLE_ROUTE := "world_map_toggle_route_mode"
const ACTION_WM_DEBUG_HEX := "world_map_debug_hex_overlay"
const ACTION_WM_DEBUG_RIVERS := "world_map_debug_rivers_overlay"
const ACTION_WM_CYCLE_UNIT_PREV := "world_map_cycle_unit_prev"
const ACTION_WM_CYCLE_UNIT_NEXT := "world_map_cycle_unit_next"
const ACTION_WM_FOCUS_UNIT := "world_map_focus_selected_unit"

var _world_manager: Node = null
var _cursor_q: int = 0
var _cursor_r: int = 0
var _status_label: Label = null
var _camera: Camera2D = null
var _camera_follow_target: Vector2 = Vector2.ZERO
var _camera_follow_vel: Vector2 = Vector2.ZERO
var _world_map_font_cached: Font = null
## Komşu köy olay rozeti: _draw icinde WorldManager sorgusu yapma; harita invalid olunca yeniden doldurulur.
var _settlement_incident_draw_cache: Dictionary = {}
var _settlement_incident_draw_cache_valid: bool = false
var _unsecured_cargo_cached: bool = false
var _unsecured_cargo_cache_valid: bool = false
var _last_marker_arrays_signature: int = -0x7f000001
var _cursor_key_repeat_left: float = 0.0
# Basili ok kombinasyonu (h,v); zigzag adimlari dq,dr ile degistigi icin buna gore kilitlenir.
var _cursor_locked_key_hv: Vector2i = Vector2i(999999, 999999)
# Sadece sol/sag (dikey yok): gorselde duz yatay icin (+1,-1)/(+1,0) veya (-1,0)/(-1,+1) sirasi.
var _cursor_h_zig_phase: bool = false
# Tek tiklamada zigzag devam etsin: son basilan saf yatay yon (-1 / 1). Tus birakilinca sifirlanmaz.
var _cursor_h_last_horizontal_sign: int = 0
# Ilk uzun bekleme bitip otomatik tekrar basladiktan sonra true; yon degisince hizi sifirlamamak icin.
var _cursor_in_fast_repeat: bool = false
var _terrain_textures: Dictionary = {}
var _debug_tile_overlay: bool = false
var _debug_akarsu_overlay: bool = false
var _route_mode: String = "shortest"
var _preview_path: Array[Dictionary] = []
var _preview_minutes: int = 0
var _preview_incident_risk: float = 0.0
var _preview_risk_label: String = "Dusuk"
var _active_unit_markers: Array[Dictionary] = []
var _mission_objective_markers: Array[Dictionary] = []
var _travel_event_dialog: AcceptDialog = null
var _travel_outcome_dialog: AcceptDialog = null
var _pending_travel_event_data: Dictionary = {}
var _travel_event_intro_text: String = ""
var _travel_dice_animating: bool = false
var _travel_event_result_ready: bool = false
var _travel_dice_left_label: Label = null
var _travel_dice_right_label: Label = null
var _travel_event_info_label: Label = null
var _travel_event_result_label: Label = null
var _dungeon_entry_dialog: ConfirmationDialog = null
var _high_risk_move_dialog: ConfirmationDialog = null
var _settlement_aid_confirm_dialog: ConfirmationDialog = null
var _settlement_action_menu: PopupMenu = null
var _player_map_mission_window: Window = null
var _player_map_mission_vbox: VBoxContainer = null
var _player_map_mission_pending_q: int = 0
var _player_map_mission_pending_r: int = 0
var _expedition_pack_modal: CanvasLayer = null
var _exp_row_hboxes: Array[HBoxContainer] = []
var _exp_pack_row: int = 0
var _exp_lr_left_hold: float = 0.0
var _exp_lr_left_acc: float = 0.0
var _exp_lr_right_hold: float = 0.0
var _exp_lr_right_acc: float = 0.0
var _exp_amt_food: int = 0
var _exp_amt_water: int = 0
var _exp_amt_medicine: int = 0
var _exp_amt_gold: int = 0
var _exp_max_food: int = 0
var _exp_max_water: int = 0
var _exp_max_medicine: int = 0
var _exp_max_gold: int = 0
const EXP_PACK_REPEAT_RAMP_SEC: float = 0.5
const EXP_PACK_REPEAT_INTERVAL_SLOW: float = 0.3
const EXP_PACK_REPEAT_INTERVAL_FAST: float = 0.045
const _EXP_PACK_KEYS = ["food", "water", "medicine", "world_gold"]
const _EXP_PACK_TITLES = ["Yiyecek", "Su", "Ilac", "Cep altini (kasa)"]
var _pending_target_q: int = 0
var _pending_target_r: int = 0
var _pending_settlement_id: String = ""
var _pending_settlement_name: String = ""
var _pending_settlement_distance: int = 0
var _markers_refresh_accum: float = 0.0
var _selected_unit_index: int = -1
var _cached_world_map_state: Dictionary = {}
var _world_map_state_cache_valid: bool = false
var _sorted_draw_tiles: Array[Dictionary] = []
var _sorted_draw_tiles_dirty: bool = true
var _path_preview_dirty: bool = false
var _path_preview_debounce_left: float = 0.0
var _cursor_status_label_pending: bool = false
var _cursor_status_label_throttle: float = 0.0
## Durum satirindaki tus ipuclari: klavye mi gamepad mi (son etkilesim).
var _world_map_hints_use_gamepad: bool = false
# Yolculuk olayi cozuldu, hedefe yurume tamamlanana kadar sonucu burada tutar.
var _pending_travel_event_resolution: Dictionary = {}
# Sonuc popup'i kapandiktan sonra yuruyusu surdur (anim diyalog ustunde kosmasin).
var _travel_resume_after_outcome_ack: bool = false
var _travel_anim_active: bool = false
var _travel_anim_path: Array = []
var _travel_anim_dest_index: int = 1
var _travel_anim_t: float = 0.0

func _invalidate_world_map_state_cache() -> void:
	_world_map_state_cache_valid = false
	_sorted_draw_tiles_dirty = true
	_settlement_incident_draw_cache_valid = false
	_unsecured_cargo_cache_valid = false

func _get_world_map_state_cached() -> Dictionary:
	if not _world_map_state_cache_valid:
		if _world_manager and _world_manager.has_method("get_world_map_state"):
			_cached_world_map_state = _world_manager.get_world_map_state()
		else:
			_cached_world_map_state = {}
		_world_map_state_cache_valid = true
	return _cached_world_map_state

func _get_sorted_draw_tiles() -> Array[Dictionary]:
	if not _sorted_draw_tiles_dirty:
		return _sorted_draw_tiles
	_sorted_draw_tiles.clear()
	var state: Dictionary = _get_world_map_state_cached()
	var tiles: Dictionary = state.get("tiles", {})
	for key in tiles.keys():
		var tile: Dictionary = tiles[key]
		_sorted_draw_tiles.append(tile)
	_sorted_draw_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ay: float = _axial_to_pixel(int(a.get("q", 0)), int(a.get("r", 0))).y
		var by: float = _axial_to_pixel(int(b.get("q", 0)), int(b.get("r", 0))).y
		return ay < by
	)
	_sorted_draw_tiles_dirty = false
	return _sorted_draw_tiles

func _schedule_path_preview_refresh() -> void:
	_path_preview_dirty = true
	_path_preview_debounce_left = PATH_PREVIEW_DEBOUNCE_SEC

func _flush_path_preview_now() -> void:
	_path_preview_dirty = false
	_path_preview_debounce_left = 0.0
	_refresh_path_preview()

func _ready() -> void:
	_world_manager = get_node_or_null("/root/WorldManager")
	_camera = get_node_or_null("Camera2D")
	if _camera:
		_camera.zoom = Vector2(ZOOM_CLOSEST, ZOOM_CLOSEST)
	_status_label = get_node_or_null("CanvasLayer/StatusLabel")
	if _status_label and MEDIEVAL_THEME:
		_status_label.theme = MEDIEVAL_THEME
	_load_terrain_textures()
	if _world_manager and _world_manager.has_method("get_world_map_state"):
		_invalidate_world_map_state_cache()
		var state: Dictionary = _get_world_map_state_cached()
		var pos: Dictionary = state.get("player_pos", {"q": 0, "r": 0})
		_cursor_q = int(pos.get("q", 0))
		_cursor_r = int(pos.get("r", 0))
		_focus_camera_on_cursor()
		if _camera:
			_camera.global_position = _camera_follow_target
			_camera_follow_vel = Vector2.ZERO
		if _world_manager.has_signal("world_map_updated") and not _world_manager.world_map_updated.is_connected(_on_world_map_updated):
			_world_manager.world_map_updated.connect(_on_world_map_updated)
		if _world_manager.has_signal("world_map_travel_event") and not _world_manager.world_map_travel_event.is_connected(_on_world_map_travel_event):
			_world_manager.world_map_travel_event.connect(_on_world_map_travel_event)
	_setup_travel_event_dialog()
	_setup_travel_outcome_dialog()
	_setup_dungeon_entry_dialog()
	_setup_high_risk_move_dialog()
	_setup_settlement_aid_confirm_dialog()
	_setup_settlement_action_menu()
	_setup_player_map_mission_window()
	_setup_expedition_pack_modal()
	var ps0: Node = get_node_or_null("/root/PlayerStats")
	if ps0 and ps0.has_signal("world_expedition_supplies_changed"):
		ps0.world_expedition_supplies_changed.connect(_on_world_expedition_supplies_changed)
	_refresh_path_preview()
	_refresh_active_unit_markers()
	_last_marker_arrays_signature = _marker_arrays_signature()
	_update_status_label()
	queue_redraw()

func _exit_tree() -> void:
	if _world_manager and _world_manager.has_signal("world_map_updated") and _world_manager.world_map_updated.is_connected(_on_world_map_updated):
		_world_manager.world_map_updated.disconnect(_on_world_map_updated)
	if _world_manager and _world_manager.has_signal("world_map_travel_event") and _world_manager.world_map_travel_event.is_connected(_on_world_map_travel_event):
		_world_manager.world_map_travel_event.disconnect(_on_world_map_travel_event)
	var ps_ex: Node = get_node_or_null("/root/PlayerStats")
	if ps_ex and ps_ex.has_signal("world_expedition_supplies_changed") and ps_ex.world_expedition_supplies_changed.is_connected(_on_world_expedition_supplies_changed):
		ps_ex.world_expedition_supplies_changed.disconnect(_on_world_expedition_supplies_changed)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _update_world_map_hint_device_from_event(event):
		_update_status_label()


func _unhandled_input(event: InputEvent) -> void:
	if _expedition_pack_modal and _expedition_pack_modal.visible:
		if event.is_action_pressed("ui_cancel"):
			_expedition_pack_modal.hide()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept"):
			_on_expedition_pack_confirm_pressed()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up"):
			_exp_pack_row = maxi(0, _exp_pack_row - 1)
			_highlight_exp_pack_rows()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down"):
			_exp_pack_row = mini(_exp_row_hboxes.size() - 1, _exp_pack_row + 1)
			_highlight_exp_pack_rows()
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		return
	if _player_map_mission_window and _player_map_mission_window.visible and event.is_action_pressed("ui_cancel"):
		_on_player_map_mission_cancel_pressed()
		get_viewport().set_input_as_handled()
		return
	if _is_blocking_world_map_ui_open():
		# Let popup/dialog consume input first.
		if not event.is_action_pressed("ui_cancel"):
			return
	if event.is_action_pressed("ui_cancel"):
		if not _is_blocking_world_map_ui_open():
			if _player_on_own_village_hex():
				var scene_manager: Node = get_node_or_null("/root/SceneManager")
				if scene_manager and scene_manager.has_method("change_to_village"):
					scene_manager.change_to_village({"source": "world_map"})
			else:
				_update_status_label("Koye donmek icin once kendi koy hex ine var.")
			get_viewport().set_input_as_handled()
		return
	# Numpad Enter hem ui_accept ile cakisir; haritayi acan tus haritayi da kapatsin.
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed("open_world_map"):
		if _player_on_own_village_hex():
			var scene_manager_wm: Node = get_node_or_null("/root/SceneManager")
			if scene_manager_wm and scene_manager_wm.has_method("change_to_village"):
				scene_manager_wm.change_to_village({"source": "world_map"})
		else:
			_update_status_label("Koye donmek icin once kendi koy hex ine var.")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		if _travel_anim_active:
			return
		_confirm_move_to_cursor()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed("attack_heavy"):
		if _try_enter_village_from_combat_action():
			get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed("block"):
		if _try_enter_village_from_combat_action():
			get_viewport().set_input_as_handled()
			return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed("attack"):
		_try_open_expedition_pack_dialog()
		get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed(ACTION_WM_ZOOM_OUT):
		_adjust_zoom(-ZOOM_STEP)
		get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed(ACTION_WM_ZOOM_IN):
		_adjust_zoom(ZOOM_STEP)
		get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed(ACTION_WM_TOGGLE_ROUTE):
		_route_mode = "safest" if _route_mode == "shortest" else "shortest"
		_refresh_path_preview()
		_update_status_label()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed(ACTION_WM_DEBUG_HEX):
		_debug_tile_overlay = not _debug_tile_overlay
		_refresh_path_preview()
		_update_status_label()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed(ACTION_WM_DEBUG_RIVERS):
		_debug_akarsu_overlay = not _debug_akarsu_overlay
		_update_status_label()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed(ACTION_WM_CYCLE_UNIT_PREV):
		_cycle_selected_unit(-1)
		get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed(ACTION_WM_CYCLE_UNIT_NEXT):
		_cycle_selected_unit(1)
		get_viewport().set_input_as_handled()
		return
	if not _is_blocking_world_map_ui_open() and event.is_action_pressed(ACTION_WM_FOCUS_UNIT):
		_focus_selected_unit()
		get_viewport().set_input_as_handled()
		return

func _process(delta: float) -> void:
	if _travel_anim_active:
		_travel_anim_t += delta / TRAVEL_PAWN_HEX_DURATION_SEC
		while _travel_anim_t >= 1.0 and _travel_anim_active:
			_travel_anim_t -= 1.0
			_travel_anim_on_segment_finished()
		_camera_follow_target = _get_player_visual_pixel_pos()
		queue_redraw()
	else:
		if _expedition_pack_modal != null and _expedition_pack_modal.visible:
			_update_expedition_pack_left_right_repeat(delta)
		_update_cursor_key_navigation(delta)
	_update_camera_follow(delta)
	if _path_preview_dirty:
		_path_preview_debounce_left -= delta
		if _path_preview_debounce_left <= 0.0:
			_path_preview_dirty = false
			_refresh_path_preview()
			queue_redraw()
			_cursor_status_label_pending = true
			_cursor_status_label_throttle = 0.0
	_markers_refresh_accum += delta
	if _markers_refresh_accum >= 0.5:
		_markers_refresh_accum = 0.0
		_refresh_active_unit_markers()
		var sig: int = _marker_arrays_signature()
		if sig != _last_marker_arrays_signature:
			_last_marker_arrays_signature = sig
			queue_redraw()
	_cursor_status_label_throttle = maxf(0.0, _cursor_status_label_throttle - delta)
	if _cursor_status_label_pending and _cursor_status_label_throttle <= 0.0:
		_cursor_status_label_pending = false
		_cursor_status_label_throttle = CURSOR_STATUS_LABEL_MIN_INTERVAL_SEC
		_update_status_label()

func _draw() -> void:
	if not _world_manager or not _world_manager.has_method("get_world_map_state"):
		return
	_ensure_settlement_incident_draw_cache()
	var sorted_tiles: Array[Dictionary] = _get_sorted_draw_tiles()
	var cull_tiles: bool = _camera != null
	var vis_world: Rect2 = _get_visible_world_rect_for_map_cull() if cull_tiles else Rect2()
	for tile in sorted_tiles:
		var q: int = int(tile.get("q", 0))
		var r: int = int(tile.get("r", 0))
		var center: Vector2 = _axial_to_pixel(q, r)
		if cull_tiles and not vis_world.has_point(center):
			continue
		_draw_terrain_tile(center, tile, q, r)
		var poi: String = String(tile.get("poi_type", ""))
		if poi == "player_village" or poi == "neighbor_village" or poi == "dungeon":
			var poi_color: Color = Color(1, 1, 1, 0.9)
			if poi == "player_village":
				poi_color = Color(1.0, 0.95, 0.35, 1.0)
			elif poi == "dungeon":
				poi_color = Color(0.9, 0.25, 0.2, 1.0)
			draw_circle(center, 5.0, poi_color)
		if poi == "neighbor_village":
			_draw_settlement_incident_marker(center, tile)
		if String(tile.get("travel_feature", "")) == "kopru":
			draw_circle(center, 2.8, Color(0.85, 0.65, 0.35, 1.0))
	_draw_active_unit_markers()
	_draw_mission_objective_markers()
	_draw_path_preview()
	var player_center: Vector2 = _get_player_visual_pixel_pos()
	draw_circle(player_center, 7.0, Color(0.15, 0.95, 0.95, 1.0))
	if _get_has_unsecured_cargo_cached():
		_draw_unsecured_cargo_icon(player_center + Vector2(14.0, -18.0))
	var cursor_center: Vector2 = _axial_to_pixel(_cursor_q, _cursor_r)
	draw_polyline(
		_hex_top_surface_points(cursor_center, CURSOR_TOP_HALF_WIDTH, CURSOR_TOP_HALF_HEIGHT),
		Color(1.0, 1.0, 1.0, 0.95),
		2.8,
		true
	)

func _on_world_map_updated() -> void:
	_invalidate_world_map_state_cache()
	_flush_path_preview_now()
	_refresh_active_unit_markers()
	_last_marker_arrays_signature = _marker_arrays_signature()
	_update_status_label()
	queue_redraw()

func _try_move_cursor(dq: int, dr: int) -> bool:
	var nq: int = _cursor_q + dq
	var nr: int = _cursor_r + dr
	if _has_tile(nq, nr):
		_cursor_q = nq
		_cursor_r = nr
		_schedule_path_preview_refresh()
		_cursor_status_label_pending = true
		_focus_camera_on_cursor()
		return true
	return false

func _player_on_own_village_hex() -> bool:
	if _world_manager == null or not _world_manager.has_method("is_player_on_own_village_hex"):
		return false
	return bool(_world_manager.call("is_player_on_own_village_hex"))

func _should_enter_own_village_on_move_confirm() -> bool:
	if not _player_on_own_village_hex():
		return false
	var st: Dictionary = _get_world_map_state_cached()
	var pq: int = int(st.get("player_pos", {}).get("q", -9999999))
	var pr: int = int(st.get("player_pos", {}).get("r", -9999999))
	return _cursor_q == pq and _cursor_r == pr

func _enter_player_village_from_world_map() -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.has_method("change_to_village"):
		scene_manager.change_to_village({"source": "world_map", "reason": "player_village_entry"})

func _try_enter_village_from_combat_action() -> bool:
	if _travel_anim_active:
		return false
	if not _player_on_own_village_hex():
		return false
	_enter_player_village_from_world_map()
	return true

func _confirm_move_to_cursor() -> void:
	if _travel_anim_active:
		return
	_flush_path_preview_now()
	if _should_enter_own_village_on_move_confirm():
		_enter_player_village_from_world_map()
		return
	if _should_prompt_high_risk_departure():
		_show_high_risk_move_dialog()
		return
	_execute_travel_to_cursor()

func _get_player_visual_pixel_pos() -> Vector2:
	if _travel_anim_active and _travel_anim_path.size() >= 2:
		var di: int = int(clampf(float(_travel_anim_dest_index), 1.0, float(_travel_anim_path.size() - 1)))
		var from_n: Dictionary = _travel_anim_path[di - 1]
		var to_n: Dictionary = _travel_anim_path[di]
		var fq: int = int(from_n.get("q", 0))
		var fr: int = int(from_n.get("r", 0))
		var tq: int = int(to_n.get("q", 0))
		var tr: int = int(to_n.get("r", 0))
		var u: float = smoothstep(0.0, 1.0, clampf(_travel_anim_t, 0.0, 1.0))
		var a: Vector2 = _axial_to_pixel(fq, fr)
		var b: Vector2 = _axial_to_pixel(tq, tr)
		return a.lerp(b, u)
	var state: Dictionary = _get_world_map_state_cached()
	var player_pos: Dictionary = state.get("player_pos", {"q": 0, "r": 0})
	return _axial_to_pixel(int(player_pos.get("q", 0)), int(player_pos.get("r", 0)))

func _travel_anim_stop() -> void:
	_travel_anim_active = false
	_travel_anim_path.clear()
	_travel_anim_dest_index = 1
	_travel_anim_t = 0.0

func _travel_anim_on_segment_finished() -> void:
	if not _world_manager or not _world_manager.has_method("advance_world_travel_step"):
		_travel_anim_stop()
		return
	var adv: Dictionary = _world_manager.advance_world_travel_step()
	if not bool(adv.get("ok", false)):
		_travel_anim_stop()
		_invalidate_world_map_state_cache()
		_camera_follow_target = _get_player_visual_pixel_pos()
		if String(adv.get("reason", "")) != "no_session":
			_update_status_label("Yolculuk kesildi.")
		queue_redraw()
		return
	if bool(adv.get("event_triggered", false)):
		_travel_anim_stop()
		_invalidate_world_map_state_cache()
		_camera_follow_target = _get_player_visual_pixel_pos()
		_pending_travel_event_resolution = {}
		_update_status_label("Yolculuk olayi: karar bekleniyor.")
		queue_redraw()
		return
	if bool(adv.get("done", false)):
		_travel_anim_stop()
		_invalidate_world_map_state_cache()
		_camera_follow_target = _get_player_visual_pixel_pos()
		_pending_travel_event_resolution = {}
		_update_status_label()
		var _st_done: Dictionary = _get_world_map_state_cached()
		var _pq: int = int(_st_done.get("player_pos", {}).get("q", _cursor_q))
		var _pr: int = int(_st_done.get("player_pos", {}).get("r", _cursor_r))
		_try_resolve_player_map_missions_at(_pq, _pr)
		_focus_camera_on_cursor()
		_try_prompt_dungeon_entry_at_player_pos()
		_try_prompt_settlement_actions_at_player_pos()
		queue_redraw()
		return
	_travel_anim_dest_index += 1
	if _travel_anim_dest_index >= _travel_anim_path.size():
		_travel_anim_stop()
		queue_redraw()
		return

func _execute_travel_to_cursor() -> void:
	if not _world_manager or not _world_manager.has_method("move_player_on_world_map"):
		return
	if not _world_manager.has_method("begin_world_travel_session"):
		return
	_pending_target_q = _cursor_q
	_pending_target_r = _cursor_r
	var result: Dictionary = _world_manager.begin_world_travel_session(_cursor_q, _cursor_r, _route_mode)
	var ok: bool = bool(result.get("ok", false))
	if not ok:
		_pending_travel_event_resolution = {}
		_update_status_label("Yolculuk yapilamadi (yol yok veya gecersiz hedef).")
		return
	var path: Array = result.get("path", [])
	if path.size() <= 1:
		_update_status_label("Zaten bu hedeftesin.")
		_try_resolve_player_map_missions_at(_cursor_q, _cursor_r)
		queue_redraw()
		return
	_travel_anim_path = path.duplicate()
	_travel_anim_dest_index = 1
	_travel_anim_t = 0.0
	_travel_anim_active = true
	_camera_follow_target = _get_player_visual_pixel_pos()
	queue_redraw()

func _should_prompt_high_risk_departure() -> bool:
	if _preview_path.size() < 2:
		return false
	if _preview_risk_label != "Yuksek":
		return false
	return _get_has_unsecured_cargo_cached()

func _show_high_risk_move_dialog() -> void:
	if _high_risk_move_dialog == null:
		_execute_travel_to_cursor()
		return
	var risk_pct: int = int(round(_preview_incident_risk * 100.0))
	_high_risk_move_dialog.dialog_text = "Bu rota YUKSEK riskli (~%%%d olay) ve teslim edilmemis yuk tasiyorsun.\nYine de yola cikilsin mi?" % risk_pct
	_high_risk_move_dialog.popup_centered(Vector2i(560, 180))

func _has_tile(q: int, r: int) -> bool:
	if _world_manager == null or not _world_manager.has_method("get_world_map_state"):
		return false
	var state: Dictionary = _get_world_map_state_cached()
	var tiles: Dictionary = state.get("tiles", {})
	return tiles.has(str(q) + "," + str(r))

func _focus_camera_on_cursor() -> void:
	_camera_follow_target = _axial_to_pixel(_cursor_q, _cursor_r)

func _update_camera_follow(delta: float) -> void:
	if _camera == null:
		return
	var target: Vector2 = _camera_follow_target
	var pos: Vector2 = _camera.global_position
	var dist: float = pos.distance_to(target)
	if dist > CAMERA_FOLLOW_SNAP_DISTANCE:
		_camera.global_position = target
		_camera_follow_vel = Vector2.ZERO
		return
	if dist < CAMERA_FOLLOW_SNAP_EPS:
		_camera.global_position = target
		_camera_follow_vel = Vector2.ZERO
		return
	var w: float = CAMERA_FOLLOW_OMEGA
	var accel: Vector2 = w * w * (target - pos) - 2.0 * w * _camera_follow_vel
	_camera_follow_vel += accel * delta
	if _camera_follow_vel.length_squared() > CAMERA_FOLLOW_VEL_MAX * CAMERA_FOLLOW_VEL_MAX:
		_camera_follow_vel = _camera_follow_vel.limit_length(CAMERA_FOLLOW_VEL_MAX)
	_camera.global_position = pos + _camera_follow_vel * delta

func _get_cursor_key_hv() -> Vector2i:
	var h: int = 0
	if Input.is_action_pressed("ui_right"):
		h += 1
	if Input.is_action_pressed("ui_left"):
		h -= 1
	var v: int = 0
	if Input.is_action_pressed("ui_down"):
		v += 1
	if Input.is_action_pressed("ui_up"):
		v -= 1
	return Vector2i(h, v)

func _get_axial_step_from_cursor_keys() -> Vector2i:
	var hv: Vector2i = _get_cursor_key_hv()
	var h: int = hv.x
	var v: int = hv.y
	if h == 0 and v == 0:
		return Vector2i(0, 0)
	if h != 0 and v != 0:
		_cursor_h_zig_phase = false
	if h != 0 and v == 0:
		if h > 0:
			return Vector2i(1, -1) if not _cursor_h_zig_phase else Vector2i(1, 0)
		return Vector2i(-1, 0) if not _cursor_h_zig_phase else Vector2i(-1, 1)
	if h == 0:
		return Vector2i(0, -1) if v < 0 else Vector2i(0, 1)
	match Vector2i(h, v):
		Vector2i(1, -1):
			return Vector2i(1, -1)
		Vector2i(1, 1):
			return Vector2i(1, 0)
		Vector2i(-1, 1):
			return Vector2i(-1, 1)
		Vector2i(-1, -1):
			return Vector2i(-1, 0)
		_:
			return Vector2i(0, 0)

func _update_cursor_key_navigation(delta: float) -> void:
	if _is_blocking_world_map_ui_open():
		_cursor_locked_key_hv = Vector2i(999999, 999999)
		_cursor_in_fast_repeat = false
		return
	var hv: Vector2i = _get_cursor_key_hv()
	if hv == Vector2i(0, 0):
		_cursor_locked_key_hv = Vector2i(999999, 999999)
		_cursor_in_fast_repeat = false
		return
	var nav_redraw: bool = false
	var pure_horizontal: bool = (hv.x != 0 and hv.y == 0)
	var step: Vector2i
	if hv != _cursor_locked_key_hv:
		var old_hv: Vector2i = _cursor_locked_key_hv
		var was_pure_h: bool = (old_hv.x != 0 and old_hv.y == 0)
		if pure_horizontal:
			var old_sentinel: bool = abs(old_hv.x) > 900000 or abs(old_hv.y) > 900000
			if old_sentinel:
				if _cursor_h_last_horizontal_sign != 0 and hv.x != _cursor_h_last_horizontal_sign:
					_cursor_h_zig_phase = false
			elif not was_pure_h or old_hv.x != hv.x:
				_cursor_h_zig_phase = false
		step = _get_axial_step_from_cursor_keys()
		if step == Vector2i(0, 0):
			_cursor_locked_key_hv = Vector2i(999999, 999999)
			_cursor_in_fast_repeat = false
			return
		var moved_once: bool = _try_move_cursor(step.x, step.y)
		nav_redraw = nav_redraw or moved_once
		if moved_once and pure_horizontal:
			_cursor_h_zig_phase = not _cursor_h_zig_phase
			_cursor_h_last_horizontal_sign = hv.x
		_cursor_locked_key_hv = hv
		if _cursor_in_fast_repeat:
			_cursor_key_repeat_left = CURSOR_REPEAT_INTERVAL_SEC
		else:
			_cursor_key_repeat_left = CURSOR_HOLD_DELAY_SEC
		if nav_redraw:
			queue_redraw()
		return
	_cursor_key_repeat_left -= delta
	while _cursor_key_repeat_left <= 0.0:
		step = _get_axial_step_from_cursor_keys()
		if step == Vector2i(0, 0):
			break
		var moved_rep: bool = _try_move_cursor(step.x, step.y)
		nav_redraw = nav_redraw or moved_rep
		if moved_rep and pure_horizontal:
			_cursor_h_zig_phase = not _cursor_h_zig_phase
			_cursor_h_last_horizontal_sign = hv.x
		_cursor_key_repeat_left += CURSOR_REPEAT_INTERVAL_SEC
		_cursor_in_fast_repeat = true
	if nav_redraw:
		queue_redraw()


func _update_world_map_hint_device_from_event(event: InputEvent) -> bool:
	var prev: bool = _world_map_hints_use_gamepad
	if event is InputEventJoypadButton and event.pressed:
		_world_map_hints_use_gamepad = true
	elif event is InputEventKey and event.pressed and not event.is_echo():
		_world_map_hints_use_gamepad = false
	elif event is InputEventMouseButton and event.pressed:
		_world_map_hints_use_gamepad = false
	return prev != _world_map_hints_use_gamepad


func _wm_input_hint(action_name: String, max_events: int = 1) -> String:
	if not InputMap.has_action(action_name):
		return "?"
	var evs: Array = InputMap.action_get_events(action_name)
	if evs.is_empty():
		return "?"
	var want_joy: bool = _world_map_hints_use_gamepad
	var parts: PackedStringArray = PackedStringArray()
	for ev_any in evs:
		var ev: InputEvent = ev_any as InputEvent
		var match_device: bool = false
		if want_joy:
			match_device = ev is InputEventJoypadButton or ev is InputEventJoypadMotion
		else:
			match_device = ev is InputEventKey or ev is InputEventMouseButton
		if match_device:
			parts.append(ev.as_text())
			if parts.size() >= max_events:
				break
	if parts.is_empty():
		for ev_any2 in evs:
			parts.append((ev_any2 as InputEvent).as_text())
			if parts.size() >= max_events:
				break
	return " / ".join(parts)


func _build_world_map_control_help_lines() -> PackedStringArray:
	var dev_lbl: String = "Gamepad" if _world_map_hints_use_gamepad else "Klavye"
	var out: PackedStringArray = PackedStringArray()
	out.append("[Kontroller: %s] Imlec: yon tusu | Git %s | Zoom %s %s | Rota %s" % [
		dev_lbl,
		_wm_input_hint("ui_accept"),
		_wm_input_hint(ACTION_WM_ZOOM_OUT),
		_wm_input_hint(ACTION_WM_ZOOM_IN),
		_wm_input_hint(ACTION_WM_TOGGLE_ROUTE),
	])
	out.append(
		"Koy gir %s %s | Erzak %s | Don(koy hex) %s %s"
		% [
			_wm_input_hint("attack_heavy"),
			_wm_input_hint("block"),
			_wm_input_hint("attack"),
			_wm_input_hint("ui_cancel"),
			_wm_input_hint("open_world_map"),
		]
	)
	out.append(
		"Ekip %s %s | Odak %s | DBG %s %s"
		% [
			_wm_input_hint(ACTION_WM_CYCLE_UNIT_PREV),
			_wm_input_hint(ACTION_WM_CYCLE_UNIT_NEXT),
			_wm_input_hint(ACTION_WM_FOCUS_UNIT),
			_wm_input_hint(ACTION_WM_DEBUG_HEX),
			_wm_input_hint(ACTION_WM_DEBUG_RIVERS),
		]
	)
	return out


func _update_status_label(extra_line: String = "") -> void:
	if not _status_label or not _world_manager:
		return
	var state: Dictionary = _get_world_map_state_cached()
	var pos: Dictionary = state.get("player_pos", {"q": 0, "r": 0})
	var carry_summary: String = _build_carry_summary_text()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Dunya Haritasi")
	for ctl_line: String in _build_world_map_control_help_lines():
		lines.append(ctl_line)
	lines.append("Rota: %s | Tahmini sure: %d dk" % [_route_mode, _preview_minutes])
	lines.append(_build_risk_status_line())
	lines.append(carry_summary)
	if _get_has_unsecured_cargo_cached():
		lines.append("UYARI: Teslim edilmemis yuk tasiyorsun. Koye ulasmadan kaybedebilirsin.")
	var living_world_line: String = _build_living_world_status_line()
	if not living_world_line.is_empty():
		lines.append(living_world_line)
	var role_buffs_line: String = _build_role_buffs_status_line()
	if not role_buffs_line.is_empty():
		lines.append(role_buffs_line)
	var alliance_line: String = _build_alliance_status_line()
	if not alliance_line.is_empty():
		lines.append(alliance_line)
	lines.append("Aktif gorev ekipleri: %d" % _active_unit_markers.size())
	if _selected_unit_index >= 0 and _selected_unit_index < _active_unit_markers.size():
		var selected_unit: Dictionary = _active_unit_markers[_selected_unit_index]
		lines.append("Secili Ekip: %s (%s)" % [
			String(selected_unit.get("cariye_name", "Ekip")),
			String(selected_unit.get("mission_name", "Gorev"))
		])
	if _camera:
		lines.append("Zoom: %.2f (%.2f–%.2f)" % [_camera.zoom.x, ZOOM_FARTHEST, ZOOM_CLOSEST])
	var tile: Dictionary = _get_tile(_cursor_q, _cursor_r)
	if not tile.is_empty():
		lines.append("Secili Hex: %s | POI: %s | Ozellik: %s" % [
			String(tile.get("terrain_type", "?")),
			String(tile.get("poi_type", "-")),
			String(tile.get("travel_feature", "-"))
		])
	if _debug_tile_overlay:
		lines.append("DEBUG hex acik | Oyuncu q=%d r=%d | Imlec q=%d r=%d" % [int(pos.get("q", 0)), int(pos.get("r", 0)), _cursor_q, _cursor_r])
	if _debug_akarsu_overlay:
		lines.append("DEBUG akarsu: kenar no | mor=ea turuncu=eb | yesil=akarsu komusu | kirmizi cizgi=komsu ile uc boslugu")
	if not extra_line.is_empty():
		lines.append(extra_line)
	_status_label.text = "\n".join(lines)
	_apply_status_label_risk_color()

func _build_risk_status_line() -> String:
	var risk_icon: String = "●"
	match _preview_risk_label:
		"Dusuk":
			risk_icon = "🟢"
		"Orta":
			risk_icon = "🟡"
		"Yuksek":
			risk_icon = "🔴"
		_:
			risk_icon = "●"
	return "%s Rota riski: %s (olay: ~%%%d)" % [risk_icon, _preview_risk_label, int(round(_preview_incident_risk * 100.0))]

func _apply_status_label_risk_color() -> void:
	if _status_label == null:
		return
	_status_label.add_theme_color_override("font_color", _get_preview_risk_color())

func _build_living_world_status_line() -> String:
	if _world_manager == null or not _world_manager.has_method("get_world_settlement_incidents"):
		return ""
	var incidents: Array = _world_manager.call("get_world_settlement_incidents")
	if incidents.is_empty():
		return ""
	var visible_incidents: Array[Dictionary] = []
	for incident in incidents:
		if not (incident is Dictionary):
			continue
		if bool(incident.get("resolved", false)):
			continue
		var settlement_id: String = String(incident.get("settlement_id", ""))
		if settlement_id.is_empty():
			continue
		if _world_manager.has_method("is_settlement_discovered") and not bool(_world_manager.call("is_settlement_discovered", settlement_id)):
			continue
		visible_incidents.append(incident)
	if visible_incidents.is_empty():
		return ""
	var summary_parts: PackedStringArray = PackedStringArray()
	for i in range(min(2, visible_incidents.size())):
		var incident: Dictionary = visible_incidents[i]
		summary_parts.append("%s: %s" % [
			String(incident.get("settlement_name", "?")),
			_format_incident_type_label(String(incident.get("type", "")))
		])
	var prefix: String = "Komsu durumu"
	if visible_incidents.size() > 2:
		return "%s (%d aktif): %s ..." % [prefix, visible_incidents.size(), ", ".join(summary_parts)]
	return "%s: %s" % [prefix, ", ".join(summary_parts)]

func _format_incident_type_label(incident_type: String) -> String:
	match incident_type:
		"wolf_attack":
			return "kurt baskini"
		"harvest_failure":
			return "kitlik"
		"migrant_wave":
			return "goc dalgasi"
		"bandit_road":
			return "yol haydutlari"
		"plague_scare":
			return "hastalik kaygisi"
		_:
			return incident_type

func _build_alliance_status_line() -> String:
	if _world_manager == null:
		return ""
	var alliances: Array = []
	if _world_manager.has_method("get_all_player_alliances"):
		alliances = _world_manager.call("get_all_player_alliances")
	var hostile: Array = []
	if _world_manager.has_method("get_player_hostile_settlements"):
		hostile = _world_manager.call("get_player_hostile_settlements")
	var has_alliances: bool = alliances is Array and not alliances.is_empty()
	var has_hostile: bool = hostile is Array and not hostile.is_empty()
	if not has_alliances and not has_hostile:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if has_alliances:
		var crisis_calls: PackedStringArray = PackedStringArray()
		for entry in alliances:
			if not (entry is Dictionary):
				continue
			if not bool(entry.get("aid_call_active", false)):
				continue
			var name: String = String(entry.get("settlement_name", "?"))
			var reason: String = String(entry.get("aid_call_reason", "kriz"))
			crisis_calls.append("%s (%s)" % [name, reason])
		if crisis_calls.is_empty():
			parts.append("Muttefikler: %d (sakin)" % alliances.size())
		else:
			parts.append("Muttefik yardim cagrisi: %s" % ", ".join(crisis_calls))
		# Gunluk tribute tahmini (sadece eligible muttefik varsa goster)
		if _world_manager.has_method("get_estimated_daily_alliance_tribute"):
			var trib: Dictionary = _world_manager.call("get_estimated_daily_alliance_tribute")
			var elig: int = int(trib.get("eligible_count", 0))
			if elig > 0:
				var gold: int = int(trib.get("gold", 0))
				var food_avg: float = float(trib.get("food_avg", 0.0))
				if food_avg >= 0.5:
					parts.append("Tribute: ~%d altin + ~%.1f erzak/gun (%d/%d)" % [gold, food_avg, elig, alliances.size()])
				else:
					parts.append("Tribute: ~%d altin/gun (%d/%d)" % [gold, elig, alliances.size()])
	if has_hostile:
		var hostile_names: PackedStringArray = PackedStringArray()
		for h in hostile:
			if h is Dictionary:
				hostile_names.append(String(h.get("settlement_name", "?")))
		if not hostile_names.is_empty():
			if hostile_names.size() <= 3:
				parts.append("Dusman koyler: %s" % ", ".join(hostile_names))
			else:
				parts.append("Dusman koyler: %d (%s ...)" % [hostile_names.size(), ", ".join(hostile_names.slice(0, 3))])
	return " | ".join(parts)

func _build_role_buffs_status_line() -> String:
	if _world_manager == null or not _world_manager.has_method("get_living_world_role_modifiers"):
		return ""
	var mods: Dictionary = _world_manager.call("get_living_world_role_modifiers")
	if mods.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if float(mods.get("wolf_severity_mult", 1.0)) < 1.0:
		parts.append("komutan")
	if float(mods.get("incident_duration_mult", 1.0)) < 1.0:
		parts.append("diplomat")
	if float(mods.get("undiscovered_news_chance", 0.30)) > 0.30:
		parts.append("ajan")
	if int(mods.get("food_drift_bonus", 0)) > 0:
		parts.append("tuccar")
	if float(mods.get("harvest_failure_severity_mult", 1.0)) < 0.999:
		parts.append("alim")
	if float(mods.get("plague_population_loss_mult", 1.0)) < 0.999:
		parts.append("tibbiyeci")
	if parts.is_empty():
		return ""
	return "Cariye etkileri: " + ", ".join(parts)

func _build_settlement_status_text(settlement_id: String) -> String:
	if _world_manager == null or settlement_id.is_empty():
		return ""
	if not _world_manager.has_method("get_settlement_state"):
		return ""
	var state: Dictionary = _world_manager.call("get_settlement_state", settlement_id)
	if state.is_empty():
		return ""
	var population: int = int(state.get("population", 0))
	var food_stock: int = int(state.get("food_stock", 0))
	var security: int = int(state.get("security", 0))
	var stability: int = int(state.get("stability", 0))
	var summary: String = "Durum: nufus %d | erzak %d | guvenlik %d | istikrar %d" % [
		population, food_stock, security, stability
	]
	var economy: Dictionary = state.get("economy_profile", {})
	if not economy.is_empty():
		var economy_label: String = String(economy.get("label", ""))
		var produces: Array = economy.get("produces", [])
		var scarce: Array = economy.get("scarce", [])
		var economy_parts: PackedStringArray = PackedStringArray()
		if not economy_label.is_empty():
			economy_parts.append(economy_label)
		if produces is Array and not produces.is_empty():
			economy_parts.append("uretim: " + ", ".join(produces))
		if scarce is Array and not scarce.is_empty():
			economy_parts.append("eksik: " + ", ".join(scarce))
		if not economy_parts.is_empty():
			summary += "\nEkonomi: " + " | ".join(economy_parts)
	if _world_manager.has_method("get_active_settlement_incident"):
		var incident: Dictionary = _world_manager.call("get_active_settlement_incident", settlement_id)
		if not incident.is_empty():
			summary += "\nAktif kriz: %s" % _format_incident_type_label(String(incident.get("type", "")))
	if _world_manager.has_method("get_active_event_chain_for_settlement"):
		var chain: Dictionary = _world_manager.call("get_active_event_chain_for_settlement", settlement_id)
		if not chain.is_empty():
			summary += "\nAktif zincir: %s (%s)" % [
				String(chain.get("chain_type", "")),
				String(chain.get("stage", ""))
			]
	if _world_manager.has_method("get_active_migrations_for_settlement"):
		var migrations: Dictionary = _world_manager.call("get_active_migrations_for_settlement", settlement_id)
		var incoming: Array = migrations.get("incoming", [])
		var outgoing: Array = migrations.get("outgoing", [])
		if not incoming.is_empty():
			var first_in: Dictionary = incoming[0]
			summary += "\nGelen goc: %s'tan ~%d kisi" % [
				String(first_in.get("source_name", "?")),
				int(first_in.get("total", 0))
			]
		if not outgoing.is_empty():
			var first_out: Dictionary = outgoing[0]
			summary += "\nGiden goc: %s'a ~%d kisi" % [
				String(first_out.get("target_name", "?")),
				int(first_out.get("total", 0))
			]
	if _world_manager.has_method("get_settlement_diplomacy_summary"):
		var diplo_list: Array = _world_manager.call("get_settlement_diplomacy_summary", settlement_id)
		if not diplo_list.is_empty():
			var lines: PackedStringArray = PackedStringArray()
			for entry in diplo_list:
				if not (entry is Dictionary):
					continue
				lines.append("%s: %s" % [
					String(entry.get("other_name", "?")),
					_format_diplomacy_state_label(String(entry.get("state", "")))
				])
			if not lines.is_empty():
				summary += "\nDiplomasi: " + ", ".join(lines)
	# Ittifak rozeti
	if _world_manager.has_method("is_player_allied") and bool(_world_manager.call("is_player_allied", settlement_id)):
		summary += "\n[Muttefik]"
		var aid_active_local: bool = false
		if _world_manager.has_method("get_player_alliance"):
			var alliance: Dictionary = _world_manager.call("get_player_alliance", settlement_id)
			if bool(alliance.get("aid_call_active", false)):
				aid_active_local = true
				var reason: String = String(alliance.get("aid_call_reason", "kriz"))
				summary += " | Yardim cagrisi aktif: %s" % reason
		# Tribute uygunlugu (kriz yoksa)
		if not aid_active_local:
			var stability_local: int = int(state.get("stability", 0))
			var food_local: int = int(state.get("food_stock", 0))
			if stability_local >= 50 and food_local >= 80:
				summary += "\nTribute aktif: gunluk pasif altin/erzak"
			else:
				summary += "\nTribute pasif: stabilite/erzak yetersiz"
		# Defansif destek uygunlugu
		if _world_manager.has_method("get_alliance_defender_eligibility"):
			var def_info: Dictionary = _world_manager.call("get_alliance_defender_eligibility", settlement_id)
			if bool(def_info.get("eligible", false)):
				summary += "\nDefans hazir: %d/%d hex menzil" % [int(def_info.get("distance", 0)), int(def_info.get("max_range", 0))]
			else:
				var reason_label: String = _format_alliance_defender_reason(String(def_info.get("reason", "")))
				if not reason_label.is_empty():
					summary += "\nDefans hazir degil: %s" % reason_label
	# Hostility rozeti (oyuncuya dusmanca)
	elif _world_manager.has_method("is_settlement_hostile_to_player") and bool(_world_manager.call("is_settlement_hostile_to_player", settlement_id)):
		var rel_score: int = 0
		if _world_manager.has_method("get_relation"):
			rel_score = int(_world_manager.call("get_relation", "Köy", String(state.get("name", settlement_id))))
		summary += "\n[Sana karsi dusmanca] iliski: %d" % rel_score
		summary += "\nBaskin riski + yakin hex'lerde yol riski yukselir."
	# Mudahale ipucu
	var intervention_hints: PackedStringArray = PackedStringArray()
	if _world_manager.has_method("get_war_support_options"):
		var ws_options: Array = _world_manager.call("get_war_support_options", settlement_id)
		if ws_options is Array and not ws_options.is_empty():
			intervention_hints.append("savasta destek")
	if _world_manager.has_method("get_mediation_options"):
		var med_options: Array = _world_manager.call("get_mediation_options", settlement_id)
		if med_options is Array and not med_options.is_empty():
			intervention_hints.append("aracilik")
	if _world_manager.has_method("get_alliance_proposal_options"):
		var ap_options: Array = _world_manager.call("get_alliance_proposal_options", settlement_id)
		if ap_options is Array and not ap_options.is_empty():
			intervention_hints.append("ittifak")
	if not intervention_hints.is_empty():
		summary += "\nMudahale: " + ", ".join(intervention_hints)
	return summary

func _format_alliance_defender_reason(reason: String) -> String:
	match reason:
		"in_crisis":
			return "muttefik krizde"
		"low_food":
			return "erzak yetersiz"
		"low_security":
			return "guvenlik dusuk"
		"out_of_range":
			return "menzil disi"
		"no_player_village":
			return "koy konumu yok"
		"":
			return ""
		_:
			return reason

func _format_diplomacy_state_label(state: String) -> String:
	match state:
		"tension":
			return "gergin"
		"cold_war":
			return "soguk savas"
		"open_war":
			return "savas"
		"ceasefire":
			return "ateskes"
		"peace":
			return "baris"
		_:
			return state

func _build_carry_summary_text() -> String:
	var health_text: String = "Can: ?"
	var dungeon_gold_text: String = "Zindan altini: 0"
	var carried_text: String = "Tasinan kaynak: yok"
	var expedition_text: String = "Yol cantasi: bos"
	var rescued_text: String = "Kurtarilan: 0/0"
	var survival_text: String = "Dayanim: ?"
	
	var ps = get_node_or_null("/root/PlayerStats")
	if ps and ps.has_method("get_current_health") and ps.has_method("get_max_health"):
		var hp: float = float(ps.get_current_health())
		var hp_max: float = float(ps.get_max_health())
		health_text = "Can: %.0f/%.0f" % [hp, hp_max]
		if ps.has_method("get_carried_resources"):
			var carried: Dictionary = ps.get_carried_resources()
			var parts: PackedStringArray = PackedStringArray()
			for k in carried.keys():
				var amount: int = int(carried[k])
				if amount > 0:
					parts.append("%s:%d" % [String(k), amount])
			if not parts.is_empty():
				carried_text = "Tasinan kaynak: " + ", ".join(parts)
		if ps.has_method("get_world_expedition_supplies"):
			var ex: Dictionary = ps.call("get_world_expedition_supplies")
			var eparts: PackedStringArray = PackedStringArray()
			for ek in ["food", "water", "medicine", "world_gold"]:
				var am: int = int(ex.get(ek, 0))
				if am > 0:
					var lab: String = "altin" if ek == "world_gold" else ek
					eparts.append("%s:%d" % [lab, am])
			if not eparts.is_empty():
				expedition_text = "Yol cantasi: " + ", ".join(eparts)
		if ps.has_method("get_world_expedition_survival_forecast"):
			var fc: Dictionary = ps.call("get_world_expedition_survival_forecast")
			var m_any: int = int(fc.get("minutes_until_any_hp_loss", 0))
			var m_food: int = int(fc.get("minutes_until_food_hp_loss", 0))
			var m_water: int = int(fc.get("minutes_until_water_hp_loss", 0))
			survival_text = "Dayanim: can kaybina ~%s | aclik ~%s | susuzluk ~%s" % [
				_format_minutes_short(maxi(0, m_any)),
				_format_minutes_short(maxi(0, m_food)),
				_format_minutes_short(maxi(0, m_water))
			]
	
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gpd and "dungeon_gold" in gpd:
		dungeon_gold_text = "Zindan altini: %d" % int(gpd.get("dungeon_gold"))
	
	var drs = get_node_or_null("/root/DungeonRunState")
	if drs:
		var villagers: Array = drs.get("pending_rescued_villagers") if "pending_rescued_villagers" in drs else []
		var cariyes: Array = drs.get("pending_rescued_cariyes") if "pending_rescued_cariyes" in drs else []
		rescued_text = "Kurtarilan: %d koylu / %d cariye" % [villagers.size(), cariyes.size()]
	
	return "%s | %s | %s | %s | %s | %s" % [health_text, dungeon_gold_text, carried_text, expedition_text, survival_text, rescued_text]

func _get_has_unsecured_cargo_cached() -> bool:
	if _unsecured_cargo_cache_valid:
		return _unsecured_cargo_cached
	_unsecured_cargo_cached = _compute_has_unsecured_cargo()
	_unsecured_cargo_cache_valid = true
	return _unsecured_cargo_cached

func _compute_has_unsecured_cargo() -> bool:
	var ps = get_node_or_null("/root/PlayerStats")
	if ps and ps.has_method("get_world_expedition_total_weight_score"):
		if int(ps.call("get_world_expedition_total_weight_score")) > 0:
			return true
	if ps and ps.has_method("get_carried_resources"):
		var carried: Dictionary = ps.get_carried_resources()
		for key in carried.keys():
			if int(carried[key]) > 0:
				return true
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gpd and "dungeon_gold" in gpd and int(gpd.get("dungeon_gold")) > 0:
		return true
	var drs = get_node_or_null("/root/DungeonRunState")
	if drs:
		var villagers: Array = drs.get("pending_rescued_villagers") if "pending_rescued_villagers" in drs else []
		var cariyes: Array = drs.get("pending_rescued_cariyes") if "pending_rescued_cariyes" in drs else []
		if villagers.size() > 0 or cariyes.size() > 0:
			return true
	return false

func _ensure_settlement_incident_draw_cache() -> void:
	if _settlement_incident_draw_cache_valid:
		return
	_settlement_incident_draw_cache.clear()
	_settlement_incident_draw_cache_valid = true
	if _world_manager == null or not _world_manager.has_method("get_active_settlement_incident"):
		return
	var state: Dictionary = _get_world_map_state_cached()
	var tiles: Dictionary = state.get("tiles", {})
	for key in tiles.keys():
		var tv: Variant = tiles[key]
		if not (tv is Dictionary):
			continue
		var tile: Dictionary = tv
		if String(tile.get("poi_type", "")) != "neighbor_village":
			continue
		var sid: String = String(tile.get("settlement_id", ""))
		if sid.is_empty() or _settlement_incident_draw_cache.has(sid):
			continue
		if not bool(tile.get("discovered", false)):
			_settlement_incident_draw_cache[sid] = {}
			continue
		var incident: Dictionary = _world_manager.call("get_active_settlement_incident", sid)
		if incident.is_empty():
			_settlement_incident_draw_cache[sid] = {}
		else:
			_settlement_incident_draw_cache[sid] = _pack_incident_marker_payload(incident)

func _pack_incident_marker_payload(incident: Dictionary) -> Dictionary:
	var incident_type: String = String(incident.get("type", ""))
	var marker_color: Color = Color(1.0, 0.65, 0.2, 0.95)
	var glyph: String = "!"
	match incident_type:
		"wolf_attack":
			marker_color = Color(0.95, 0.35, 0.3, 0.95)
			glyph = "W"
		"harvest_failure":
			marker_color = Color(0.95, 0.78, 0.25, 0.95)
			glyph = "H"
		"migrant_wave":
			marker_color = Color(0.5, 0.7, 1.0, 0.95)
			glyph = "G"
		"bandit_road":
			marker_color = Color(0.75, 0.35, 0.95, 0.95)
			glyph = "B"
		"plague_scare":
			marker_color = Color(0.55, 0.85, 0.45, 0.95)
			glyph = "P"
		_:
			marker_color = Color(1.0, 0.65, 0.2, 0.95)
			glyph = "!"
	return {"glyph": glyph, "color": marker_color}

func _draw_unsecured_cargo_icon(icon_pos: Vector2) -> void:
	# Basit "yük/uyarı" ikonu: sarı daire + ünlem.
	draw_circle(icon_pos, 8.0, Color(1.0, 0.88, 0.2, 0.95))
	draw_circle(icon_pos, 8.0, Color(0.12, 0.12, 0.08, 0.9), false, 1.6)
	var font: Font = _get_world_map_font()
	draw_string(
		font,
		icon_pos + Vector2(-2.5, 4.0),
		"!",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		Color(0.12, 0.12, 0.08, 1.0)
	)

func _draw_settlement_incident_marker(center: Vector2, tile: Dictionary) -> void:
	var settlement_id: String = String(tile.get("settlement_id", ""))
	if settlement_id.is_empty():
		return
	var discovered: bool = bool(tile.get("discovered", false))
	if not discovered:
		return
	var payload: Variant = _settlement_incident_draw_cache.get(settlement_id, null)
	if payload == null or not (payload is Dictionary):
		return
	var pd: Dictionary = payload
	if pd.is_empty():
		return
	var marker_color: Color = pd["color"] as Color
	var glyph: String = String(pd.get("glyph", "!"))
	var marker_pos: Vector2 = center + Vector2(10.0, -16.0)
	draw_circle(marker_pos, 7.5, marker_color)
	draw_circle(marker_pos, 7.5, Color(0.1, 0.08, 0.05, 0.9), false, 1.4)
	var font: Font = _get_world_map_font()
	draw_string(
		font,
		marker_pos + Vector2(-3.0, 4.0),
		glyph,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		Color(0.1, 0.08, 0.05, 1.0)
	)

func _is_blocking_world_map_ui_open() -> bool:
	if _travel_event_dialog and _travel_event_dialog.visible:
		return true
	if _travel_outcome_dialog and _travel_outcome_dialog.visible:
		return true
	if _dungeon_entry_dialog and _dungeon_entry_dialog.visible:
		return true
	if _high_risk_move_dialog and _high_risk_move_dialog.visible:
		return true
	if _settlement_aid_confirm_dialog and _settlement_aid_confirm_dialog.visible:
		return true
	if _settlement_action_menu and _settlement_action_menu.visible:
		return true
	if _player_map_mission_window and _player_map_mission_window.visible:
		return true
	if _expedition_pack_modal and _expedition_pack_modal.visible:
		return true
	return false

func _get_tile(q: int, r: int) -> Dictionary:
	if _world_manager == null or not _world_manager.has_method("get_world_map_state"):
		return {}
	var state: Dictionary = _get_world_map_state_cached()
	var tiles: Dictionary = state.get("tiles", {})
	var key: String = str(q) + "," + str(r)
	if tiles.has(key):
		return tiles[key]
	return {}

func _get_tile_color(tile: Dictionary) -> Color:
	var terrain: String = String(tile.get("terrain_type", "ova"))
	var discovered: bool = bool(tile.get("discovered", false))
	var visible: bool = bool(tile.get("visible", false))
	var color: Color = Color(0.42, 0.67, 0.35, 1.0)
	match terrain:
		"deniz":
			color = Color(0.19, 0.39, 0.72, 1.0)
		"orman":
			color = Color(0.16, 0.46, 0.21, 1.0)
		"dag":
			color = Color(0.48, 0.48, 0.5, 1.0)
		"akarsu":
			color = Color(0.56, 0.73, 0.38, 1.0)
		_:
			color = Color(0.56, 0.73, 0.38, 1.0)
	if not discovered:
		color = color.darkened(0.75)
	elif not visible:
		color = color.darkened(0.35)
	return color

func _hex_points(center: Vector2, size: float) -> PackedVector2Array:
	var k: float = size / HEX_SIZE
	var hw: float = CURSOR_TOP_HALF_WIDTH * k
	var hh: float = CURSOR_TOP_HALF_HEIGHT * k
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		pts.append(_squashed_hex_corner(center, hw, hh, i))
	pts.append(pts[0])
	return pts

## Izometrik/parlak tile mantigi: imlec `_hex_top_surface_points` ile ayni basik altigen (ust-alt kirpik).
func _squashed_hex_corner(center: Vector2, half_w: float, half_h: float, idx: int) -> Vector2:
	match posmod(idx, 6):
		0:
			return center + Vector2(-half_w * 0.5, -half_h)
		1:
			return center + Vector2(half_w * 0.5, -half_h)
		2:
			return center + Vector2(half_w, 0.0)
		3:
			return center + Vector2(half_w * 0.5, half_h)
		4:
			return center + Vector2(-half_w * 0.5, half_h)
		5:
			return center + Vector2(-half_w, 0.0)
		_:
			return center

func _squashed_hex_edge_midpoint(center: Vector2, half_w: float, half_h: float, edge_idx: int) -> Vector2:
	var i: int = posmod(edge_idx, 6)
	var c0: Vector2 = _squashed_hex_corner(center, half_w, half_h, i)
	var c1: Vector2 = _squashed_hex_corner(center, half_w, half_h, i + 1)
	return (c0 + c1) * 0.5

func _squashed_hex_edge_outward_normal(center: Vector2, half_w: float, half_h: float, edge_idx: int) -> Vector2:
	var i: int = posmod(edge_idx, 6)
	var c0: Vector2 = _squashed_hex_corner(center, half_w, half_h, i)
	var c1: Vector2 = _squashed_hex_corner(center, half_w, half_h, i + 1)
	var edge_vec: Vector2 = c1 - c0
	if edge_vec.length_squared() < 0.0001:
		return Vector2.UP
	var tang: Vector2 = edge_vec.normalized()
	var perp: Vector2 = Vector2(-tang.y, tang.x)
	var mid: Vector2 = (c0 + c1) * 0.5
	if perp.dot(mid - center) < 0.0:
		perp = -perp
	return perp

func _hex_half_dims_for_radius(radius: float) -> Vector2:
	var k: float = radius / HEX_SIZE
	return Vector2(CURSOR_TOP_HALF_WIDTH * k, CURSOR_TOP_HALF_HEIGHT * k)

func _hex_edge_midpoint(center: Vector2, radius: float, edge_idx: int) -> Vector2:
	var dim: Vector2 = _hex_half_dims_for_radius(radius)
	return _squashed_hex_edge_midpoint(center, dim.x, dim.y, edge_idx)

func _hex_axial_delta_to_pixel_dir(dq: int, dr: int) -> Vector2:
	var v: Vector2 = Vector2(HEX_STEP_X * float(dq), HEX_STEP_Y * (float(dr) + float(dq) * 0.5))
	if v.length_squared() < 0.0001:
		return Vector2.RIGHT
	return v.normalized()

func _shared_hex_edge_midpoint_between(qa: int, ra: int, qb: int, rb: int, radius: float) -> Vector2:
	var dq: int = qb - qa
	var dr: int = rb - ra
	var ca: Vector2 = _axial_to_pixel(qa, ra)
	var ei: int = _hex_edge_index_toward_axial_delta(ca, dq, dr, radius)
	return _hex_edge_midpoint(ca, radius, ei)

## Iki karo ortak kenarinda tek dunya noktasi; komsudan da cizilince uc uca bulusur.
func _canonical_shared_seam_world(qa: int, ra: int, qb: int, rb: int, radius: float) -> Vector2:
	var pa: Vector2 = _shared_hex_edge_midpoint_between(qa, ra, qb, rb, radius)
	var pb: Vector2 = _shared_hex_edge_midpoint_between(qb, rb, qa, ra, radius)
	return (pa + pb) * 0.5

func _hex_edge_index_toward_axial_delta(center: Vector2, dq: int, dr: int, radius: float) -> int:
	var to_n: Vector2 = _hex_axial_delta_to_pixel_dir(dq, dr)
	var dim: Vector2 = _hex_half_dims_for_radius(radius)
	var hw: float = dim.x
	var hh: float = dim.y
	var best_e: int = 0
	var best_dot: float = -10.0
	for e in range(6):
		var outward: Vector2 = _squashed_hex_edge_outward_normal(center, hw, hh, e)
		var d: float = outward.dot(to_n)
		if d > best_dot:
			best_dot = d
			best_e = e
	return best_e

func _akarsu_edge_toward_neighbor(center: Vector2, q: int, r: int, dq: int, dr: int, radius: float) -> int:
	return _hex_edge_index_toward_axial_delta(center, dq, dr, radius)

func _hex_top_surface_points(center: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	# Basik altigen: `_squashed_hex_corner` ile ayni (imlec / akarsu / rota kenarlari).
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		pts.append(_squashed_hex_corner(center, half_w, half_h, i))
	pts.append(pts[0])
	return pts

func _axial_to_pixel(q: int, r: int) -> Vector2:
	# Spacing tuned for 64x48 art footprint (flat-top style with overlap).
	var x: float = HEX_STEP_X * float(q)
	var y: float = HEX_STEP_Y * (float(r) + float(q) * 0.5)
	return Vector2(x, y)

## Kamera gorunumu disinda kalan hexleri cizmeyi atla (imleci surerken draw_texture yuku).
func _get_visible_world_rect_for_map_cull() -> Rect2:
	if _camera == null:
		return Rect2()
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2()
	var half: Vector2 = vp.get_visible_rect().size * 0.5 / _camera.zoom
	var c: Vector2 = _camera.get_screen_center_position()
	var pad: float = maxf(TILE_WIDTH, TILE_HEIGHT) * 0.5 + 24.0
	var ext: Vector2 = half + Vector2(pad, pad)
	return Rect2(c - ext, ext * 2.0)

func _compute_akarsu_river_geometry(center: Vector2, q: int, r: int, radius: float) -> Dictionary:
	var ak_dirs: Array[int] = []
	var neighbor_terrain: Array[String] = []
	for i in range(AKARSU_NEIGHBOR_DIRS.size()):
		var d: Vector2i = AKARSU_NEIGHBOR_DIRS[i]
		var nt: Dictionary = _get_tile(q + d.x, r + d.y)
		var tt: String = String(nt.get("terrain_type", ""))
		if tt.is_empty():
			tt = "-"
		neighbor_terrain.append(tt)
		if tt == "akarsu":
			ak_dirs.append(i)
	ak_dirs.sort()
	var edge_a: int = 0
	var edge_b: int = 0
	var fork_mode: bool = ak_dirs.size() >= 3
	var branch_edges: Array[int] = []
	if fork_mode:
		for ad in ak_dirs:
			var dd: Vector2i = AKARSU_NEIGHBOR_DIRS[int(ad)]
			var ei: int = _hex_edge_index_toward_axial_delta(center, dd.x, dd.y, radius)
			branch_edges.append(ei)
		if not branch_edges.is_empty():
			edge_a = branch_edges[0]
			edge_b = branch_edges[branch_edges.size() - 1]
	elif ak_dirs.size() == 2:
		var pair: Vector2i = Vector2i(ak_dirs[0], ak_dirs[1])
		var d_lo: Vector2i = AKARSU_NEIGHBOR_DIRS[pair.x]
		var d_hi: Vector2i = AKARSU_NEIGHBOR_DIRS[pair.y]
		edge_a = _hex_edge_index_toward_axial_delta(center, d_lo.x, d_lo.y, radius)
		edge_b = _hex_edge_index_toward_axial_delta(center, d_hi.x, d_hi.y, radius)
	elif ak_dirs.size() == 1:
		var d0: Vector2i = AKARSU_NEIGHBOR_DIRS[ak_dirs[0]]
		edge_a = _hex_edge_index_toward_axial_delta(center, d0.x, d0.y, radius)
		edge_b = (edge_a + 3) % 6
	else:
		var h: int = hash(Vector2i(q, r))
		edge_a = abs(h) % 6
		edge_b = (edge_a + 3) % 6
	if not fork_mode:
		if edge_a == edge_b:
			edge_b = (edge_a + 2) % 6
	var p0: Vector2 = center
	var p2: Vector2 = center
	if fork_mode and ak_dirs.size() >= 1:
		var df0: Vector2i = AKARSU_NEIGHBOR_DIRS[ak_dirs[0]]
		var df1: Vector2i = AKARSU_NEIGHBOR_DIRS[ak_dirs[ak_dirs.size() - 1]]
		p0 = _canonical_shared_seam_world(q, r, q + df0.x, r + df0.y, radius)
		p2 = _canonical_shared_seam_world(q, r, q + df1.x, r + df1.y, radius)
	elif ak_dirs.size() == 2:
		var d_lo: Vector2i = AKARSU_NEIGHBOR_DIRS[ak_dirs[0]]
		var d_hi: Vector2i = AKARSU_NEIGHBOR_DIRS[ak_dirs[1]]
		p0 = _canonical_shared_seam_world(q, r, q + d_lo.x, r + d_lo.y, radius)
		p2 = _canonical_shared_seam_world(q, r, q + d_hi.x, r + d_hi.y, radius)
	elif ak_dirs.size() == 1:
		var d0: Vector2i = AKARSU_NEIGHBOR_DIRS[ak_dirs[0]]
		p0 = _canonical_shared_seam_world(q, r, q + d0.x, r + d0.y, radius)
		p2 = _hex_edge_midpoint(center, radius, edge_b)
	else:
		p0 = _hex_edge_midpoint(center, radius, edge_a)
		p2 = _hex_edge_midpoint(center, radius, edge_b)
	return {
		"ak_dirs": ak_dirs,
		"fork_mode": fork_mode,
		"branch_edges": branch_edges,
		"edge_a": edge_a,
		"edge_b": edge_b,
		"p0": p0,
		"p2": p2,
		"neighbor_terrain": neighbor_terrain,
	}

func _draw_akarsu_debug_overlay(center: Vector2, q: int, r: int, geom: Dictionary) -> void:
	var radius: float = HEX_SIZE
	var font: Font = _get_world_map_font()
	var ak_dirs: Variant = geom.get("ak_dirs", [])
	var edge_a: int = int(geom.get("edge_a", 0))
	var edge_b: int = int(geom.get("edge_b", 0))
	var fork_mode: bool = bool(geom.get("fork_mode", false))
	var branch_edges: Variant = geom.get("branch_edges", [])
	var nterr: Variant = geom.get("neighbor_terrain", [])
	for e in range(6):
		var em: Vector2 = _hex_edge_midpoint(center, radius, e)
		var tick: Color = Color(0.75, 0.75, 0.8, 0.9)
		if fork_mode and branch_edges is Array:
			var on_branch: bool = false
			for be in branch_edges:
				if int(be) == e:
					on_branch = true
					break
			if on_branch:
				tick = Color(0.35, 0.95, 1.0, 1.0)
		elif e == edge_a:
			tick = Color(0.95, 0.25, 1.0, 1.0)
		elif e == edge_b:
			tick = Color(1.0, 0.55, 0.1, 1.0)
		draw_circle(em, 3.4, tick)
		draw_arc(em, 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.35), 1.0, true)
		draw_string(font, em + Vector2(-4.0, 3.0), str(e), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 1.0, 1.0, 0.95))
	for i in range(6):
		var d: Vector2i = AKARSU_NEIGHBOR_DIRS[i]
		var n_center: Vector2 = _axial_to_pixel(q + d.x, r + d.y)
		var is_ak: bool = false
		if ak_dirs is Array:
			for ad in ak_dirs:
				if int(ad) == i:
					is_ak = true
					break
		var lc: Color = Color(0.15, 0.92, 0.4, 0.55) if is_ak else Color(0.45, 0.45, 0.5, 0.22)
		var lw: float = 1.8 if is_ak else 0.7
		draw_line(center, n_center, lc, lw)
	if ak_dirs is Array:
		for ad in ak_dirs:
			var di: int = int(ad)
			var d: Vector2i = AKARSU_NEIGHBOR_DIRS[di]
			var p_canon: Vector2 = _canonical_shared_seam_world(q, r, q + d.x, r + d.y, radius)
			var p_rev: Vector2 = _canonical_shared_seam_world(q + d.x, r + d.y, q, r, radius)
			var gap: float = p_canon.distance_to(p_rev)
			var seam_ok: bool = gap < 8.0
			var seam_col: Color = Color(0.25, 0.98, 0.55, 0.92) if seam_ok else Color(1.0, 0.2, 0.25, 0.95)
			draw_line(p_canon, p_rev, seam_col, 2.2)
			var mid_pt: Vector2 = (p_canon + p_rev) * 0.5
			draw_string(font, mid_pt + Vector2(-10.0, -6.0), "%.0f" % gap, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, seam_col)
	var terr_bits: PackedStringArray = PackedStringArray()
	if nterr is Array:
		for ti in range(min(6, nterr.size())):
			var short_t: String = str(nterr[ti]).substr(0, 1)
			terr_bits.append("%d:%s" % [ti, short_t])
	var fork_lbl: String = "fork" if fork_mode else "tek"
	var lbl: String = "q%d r%d |%s ea%d eb%d| %s" % [q, r, fork_lbl, edge_a, edge_b, ",".join(terr_bits)]
	draw_string(font, center + Vector2(-HEX_SIZE - 2.0, HEX_SIZE + 8.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(1.0, 0.95, 0.35, 0.98))

func _draw_akarsu_river_overlay(center: Vector2, q: int, r: int, tile_modulate: Color) -> void:
	# Tam HEX_SIZE: ic ice kirpik altigenle komsu karo dikişleri cakisir (HEX_SIZE-1 bosluk birakiyordu).
	var radius: float = HEX_SIZE
	var geom: Dictionary = _compute_akarsu_river_geometry(center, q, r, radius)
	var deep: Color = Color(0.08, 0.34, 0.58, 0.94) * tile_modulate
	var mid_c: Color = Color(0.16, 0.48, 0.78, 0.82) * tile_modulate
	var rim: Color = Color(0.58, 0.86, 1.0, 0.48) * tile_modulate
	if bool(geom.get("fork_mode", false)):
		var hub: Vector2 = center
		var akd: Variant = geom.get("ak_dirs", [])
		var seen_nk: Dictionary = {}
		if akd is Array:
			for ad in akd:
				var di: int = int(ad)
				var dd: Vector2i = AKARSU_NEIGHBOR_DIRS[di]
				var nq: int = q + dd.x
				var nr: int = r + dd.y
				var nk: String = str(nq) + "," + str(nr)
				if seen_nk.has(nk):
					continue
				seen_nk[nk] = true
				var seam: Vector2 = _canonical_shared_seam_world(q, r, nq, nr, radius)
				var seg: PackedVector2Array = PackedVector2Array([hub, seam])
				draw_polyline(seg, deep, 6.2, true)
				draw_polyline(seg, mid_c, 3.4, true)
				draw_polyline(seg, rim, 1.5, true)
	else:
		var p0: Vector2 = geom.get("p0", center)
		var p2: Vector2 = geom.get("p2", center)
		# Kenar-kenar kiris kopuk "cubuk" gorunur; merkez uzerinden tek hat.
		var pts: PackedVector2Array = PackedVector2Array([p0, center, p2])
		draw_polyline(pts, deep, 6.2, true)
		draw_polyline(pts, mid_c, 3.4, true)
		draw_polyline(pts, rim, 1.5, true)
	if _debug_akarsu_overlay:
		_draw_akarsu_debug_overlay(center, q, r, geom)

func _draw_terrain_tile(center: Vector2, tile: Dictionary, q: int, r: int) -> void:
	var terrain: String = String(tile.get("terrain_type", "ova"))
	var discovered: bool = bool(tile.get("discovered", false))
	var visible: bool = bool(tile.get("visible", false))
	var modulate_color: Color = Color(1, 1, 1, 1)
	if not discovered:
		modulate_color = Color(0.28, 0.28, 0.28, 1.0)
	elif not visible:
		modulate_color = Color(0.62, 0.62, 0.62, 1.0)
	if terrain == "deniz":
		modulate_color.a *= 0.8

	var tex_key: String = "ova" if terrain == "akarsu" else terrain
	var tex: Texture2D = _terrain_textures.get(tex_key, null)
	var draw_pos: Vector2 = _tile_draw_position(center)
	if tex == null:
		# Fallback for missing art.
		var fc_tile: Dictionary = tile.duplicate(true)
		if terrain == "akarsu":
			fc_tile["terrain_type"] = "ova"
		var fallback_color: Color = _get_tile_color(fc_tile)
		if terrain == "deniz":
			fallback_color.a *= 0.8
		draw_colored_polygon(_hex_points(center, HEX_SIZE - 1.0), fallback_color)
		draw_polyline(_hex_points(center, HEX_SIZE), Color(0.08, 0.08, 0.08, 0.45), 1.6, true)
		if terrain == "akarsu":
			_draw_akarsu_river_overlay(center, q, r, modulate_color)
		if _debug_tile_overlay:
			_draw_tile_debug_overlay(center, draw_pos, q, r)
		return
	draw_texture(tex, draw_pos, modulate_color)
	if terrain == "akarsu":
		_draw_akarsu_river_overlay(center, q, r, modulate_color)
	if _debug_tile_overlay:
		_draw_tile_debug_overlay(center, draw_pos, q, r)

func _load_terrain_textures() -> void:
	_terrain_textures.clear()
	_terrain_textures["ova"] = load("res://Tile set/Hex Tiles/hex_ova.png")
	_terrain_textures["orman"] = load("res://Tile set/Hex Tiles/hex_orman.png")
	_terrain_textures["dag"] = load("res://Tile set/Hex Tiles/hex_dag.png")
	_terrain_textures["deniz"] = load("res://Tile set/Hex Tiles/hex_deniz.png")

func _adjust_zoom(delta: float) -> void:
	if not _camera:
		return
	var target: float = clampf(_camera.zoom.x + delta, ZOOM_FARTHEST, ZOOM_CLOSEST)
	_camera.zoom = Vector2(target, target)
	_update_status_label()

func _refresh_path_preview() -> void:
	_preview_path.clear()
	_preview_minutes = 0
	_preview_incident_risk = 0.0
	_preview_risk_label = "Dusuk"
	if not _world_manager or not _world_manager.has_method("get_world_map_state"):
		return
	if not _world_manager.has_method("find_world_map_path"):
		return
	var state: Dictionary = _get_world_map_state_cached()
	var pos: Dictionary = state.get("player_pos", {"q": 0, "r": 0})
	var result: Dictionary = _world_manager.find_world_map_path(
		int(pos.get("q", 0)),
		int(pos.get("r", 0)),
		_cursor_q,
		_cursor_r,
		_route_mode
	)
	if bool(result.get("ok", false)):
		var raw_path: Array = result.get("path", [])
		var typed_path: Array[Dictionary] = []
		for node in raw_path:
			if node is Dictionary:
				typed_path.append(node)
		_preview_path = typed_path
		_preview_minutes = int(result.get("minutes", 0))
		_estimate_preview_route_risk()

func _draw_path_preview() -> void:
	if _preview_path.size() < 2:
		return
	var radius: float = HEX_SIZE - 1.0
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(_preview_path.size() - 1):
		var node_a: Dictionary = _preview_path[i]
		var node_b: Dictionary = _preview_path[i + 1]
		var qa: int = int(node_a.get("q", 0))
		var ra: int = int(node_a.get("r", 0))
		var qb: int = int(node_b.get("q", 0))
		var rb: int = int(node_b.get("r", 0))
		points.append(_shared_hex_edge_midpoint_between(qa, ra, qb, rb, radius))
	if points.size() < 2:
		for node in _preview_path:
			var q: int = int(node.get("q", 0))
			var r: int = int(node.get("r", 0))
			points.append(_axial_to_pixel(q, r))
	draw_polyline(points, _get_preview_risk_color(), 3.5, false)

func _get_preview_risk_color() -> Color:
	match _preview_risk_label:
		"Dusuk":
			return Color(0.35, 0.95, 0.45, 0.92)
		"Orta":
			return Color(1.0, 0.84, 0.2, 0.92)
		"Yuksek":
			return Color(1.0, 0.35, 0.3, 0.95)
		_:
			return Color(0.85, 0.85, 0.85, 0.9)

func _estimate_preview_route_risk() -> void:
	if _preview_path.size() <= 1:
		_preview_incident_risk = 0.0
		_preview_risk_label = "Dusuk"
		return
	var stay_safe_prob: float = 1.0
	var cargo_mult: float = 1.0
	if _world_manager and _world_manager.has_method("_compute_cargo_risk_multiplier"):
		# WorldManager tarafındaki mevcut risk eğrisiyle aynı hesap kullanılsın.
		cargo_mult = float(_world_manager.call("_compute_cargo_risk_multiplier"))
	var tiles: Dictionary = _get_world_map_state_cached().get("tiles", {})
	var wm_bonus_cache: Dictionary = {}
	for i in range(1, _preview_path.size()):
		var node: Dictionary = _preview_path[i]
		var q: int = int(node.get("q", 0))
		var r: int = int(node.get("r", 0))
		var tk: String = str(q) + "," + str(r)
		var tile: Dictionary = {}
		var tv: Variant = tiles.get(tk, null)
		if tv is Dictionary:
			tile = tv
		var step_chance: float = _estimate_step_incident_chance_for_hex(tile, q, r, wm_bonus_cache)
		step_chance *= clampf(cargo_mult, 1.0, 2.0)
		step_chance = clampf(step_chance, 0.0, 0.95)
		stay_safe_prob *= (1.0 - step_chance)
	_preview_incident_risk = clampf(1.0 - stay_safe_prob, 0.0, 0.99)
	if _preview_incident_risk < 0.22:
		_preview_risk_label = "Dusuk"
	elif _preview_incident_risk < 0.48:
		_preview_risk_label = "Orta"
	else:
		_preview_risk_label = "Yuksek"

func _wm_step_threat_bonuses(q: int, r: int, cache: Dictionary) -> float:
	var key: String = str(q) + "," + str(r)
	if cache.has(key):
		return float(cache[key])
	var b: float = 0.0
	if _world_manager and _world_manager.has_method("_get_settlement_incident_threat_bonus"):
		b += float(_world_manager.call("_get_settlement_incident_threat_bonus", q, r))
	if _world_manager and _world_manager.has_method("get_hostile_settlement_threat_bonus"):
		b += float(_world_manager.call("get_hostile_settlement_threat_bonus", q, r))
	cache[key] = b
	return b

func _estimate_step_incident_chance_for_hex(tile: Dictionary, q: int, r: int, wm_bonus_cache: Dictionary) -> float:
	var terrain: String = String(tile.get("terrain_type", "ova"))
	var chance: float = 0.045
	match terrain:
		"orman":
			chance = 0.065
		"dag":
			chance = 0.09
		"akarsu":
			chance = 0.075
		_:
			chance = 0.045
	if String(tile.get("travel_feature", "")) == "kopru":
		chance *= 0.6
	chance += _wm_step_threat_bonuses(q, r, wm_bonus_cache)
	if _route_mode == "safest":
		chance *= 0.85
	return clampf(chance, 0.0, 0.95)

func _refresh_active_unit_markers() -> void:
	_active_unit_markers.clear()
	_mission_objective_markers.clear()
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("get_world_map_active_unit_markers"):
		var raw_markers: Array = mm.call("get_world_map_active_unit_markers")
		var typed_markers: Array[Dictionary] = []
		for m in raw_markers:
			if m is Dictionary:
				typed_markers.append(m)
		_active_unit_markers = typed_markers
	if mm and mm.has_method("get_world_map_mission_objective_markers"):
		var raw_obj: Array = mm.call("get_world_map_mission_objective_markers")
		for ob in raw_obj:
			if ob is Dictionary:
				_mission_objective_markers.append(ob)
	if _active_unit_markers.is_empty():
		_selected_unit_index = -1
	else:
		_selected_unit_index = clampi(_selected_unit_index, 0, _active_unit_markers.size() - 1)

func _marker_arrays_signature() -> int:
	var h: int = (_active_unit_markers.size() << 20) ^ (_mission_objective_markers.size() << 10) ^ _selected_unit_index
	var i: int = 0
	while i < 8 and i < _active_unit_markers.size():
		var m: Dictionary = _active_unit_markers[i]
		h ^= int(m.get("q", 0)) * 374761 + int(m.get("r", 0)) * 668263 + int(m.get("origin_q", 0)) * 911 + int(m.get("target_q", 0)) * 313
		i += 1
	i = 0
	while i < 6 and i < _mission_objective_markers.size():
		var om: Dictionary = _mission_objective_markers[i]
		h ^= int(om.get("q", 0)) * 131071 + int(om.get("r", 0)) * 163
		i += 1
	return h

func _draw_active_unit_markers() -> void:
	var label_lines: PackedStringArray = PackedStringArray()
	for marker_index in range(_active_unit_markers.size()):
		var marker: Dictionary = _active_unit_markers[marker_index]
		var unit_type: String = String(marker.get("unit_type", "mission_team"))
		var is_selected_marker: bool = marker_index == _selected_unit_index
		var oq: int = int(marker.get("origin_q", 0))
		var orr: int = int(marker.get("origin_r", 0))
		var tq: int = int(marker.get("target_q", oq))
		var tr: int = int(marker.get("target_r", orr))
		var cq: int = int(marker.get("q", oq))
		var cr: int = int(marker.get("r", orr))
		var origin_pos: Vector2 = _axial_to_pixel(oq, orr)
		var target_pos: Vector2 = _axial_to_pixel(tq, tr)
		var current_pos: Vector2 = _axial_to_pixel(cq, cr)
		var line_color: Color = Color(0.55, 0.8, 1.0, 0.35)
		var unit_color: Color = Color(0.95, 0.55, 0.2, 1.0)
		var arrow_color: Color = Color(1.0, 0.9, 0.3, 1.0)
		if unit_type == "returning_team":
			line_color = Color(0.65, 1.0, 0.65, 0.35)
			unit_color = Color(0.25, 0.95, 0.45, 1.0)
			arrow_color = Color(0.85, 1.0, 0.85, 1.0)
		draw_line(origin_pos, target_pos, line_color, 2.4 if is_selected_marker else 1.2)
		# Distinct marker body for outbound/returning teams.
		if unit_type == "returning_team":
			draw_rect(Rect2(current_pos - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), unit_color, true)
		else:
			draw_circle(current_pos, 5.0, unit_color)
		if is_selected_marker:
			draw_circle(current_pos, 8.0, Color(1.0, 1.0, 0.75, 0.25))
		var dir: Vector2 = (target_pos - current_pos).normalized()
		if dir.length() < 0.001:
			dir = Vector2.RIGHT
		var p1: Vector2 = current_pos + dir * 7.0
		var ortho: Vector2 = Vector2(-dir.y, dir.x)
		var p2: Vector2 = current_pos - dir * 4.0 + ortho * 3.2
		var p3: Vector2 = current_pos - dir * 4.0 - ortho * 3.2
		draw_colored_polygon(PackedVector2Array([p1, p2, p3]), arrow_color)
		# Show compact labels only for teams close to current cursor tile.
		if abs(cq - _cursor_q) <= 1 and abs(cr - _cursor_r) <= 1:
			var name: String = String(marker.get("cariye_name", "Ekip"))
			var mname: String = String(marker.get("mission_name", "Gorev"))
			var prefix: String = "↩ " if unit_type == "returning_team" else "→ "
			label_lines.append("%s%s: %s" % [prefix, name, mname])
	if not label_lines.is_empty():
		var base_pos: Vector2 = _axial_to_pixel(_cursor_q, _cursor_r) + Vector2(20.0, -34.0)
		var text := "\n".join(label_lines)
		var bg_size: Vector2 = Vector2(340.0, float(24 * label_lines.size()) + 12.0)
		draw_rect(Rect2(base_pos - Vector2(8.0, 18.0), bg_size), Color(0.06, 0.08, 0.1, 0.75), true)
		draw_rect(Rect2(base_pos - Vector2(8.0, 18.0), bg_size), Color(0.8, 0.9, 1.0, 0.35), false, 1.0)
		var font: Font = _get_world_map_font()
		draw_string(font, base_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.95, 0.98, 1.0, 1.0))

func _draw_mission_objective_markers() -> void:
	if _mission_objective_markers.is_empty():
		return
	var font: Font = _get_world_map_font()
	for om in _mission_objective_markers:
		var mq: int = int(om.get("q", 0))
		var mr: int = int(om.get("r", 0))
		var center: Vector2 = _axial_to_pixel(mq, mr)
		var badge: Vector2 = center + Vector2(2.0, -20.0)
		draw_circle(badge, 11.0, Color(0.1, 0.08, 0.05, 0.88))
		draw_arc(badge, 10.0, 0.0, TAU, 28, Color(1.0, 0.75, 0.12, 1.0), 2.2, true)
		draw_string(font, badge + Vector2(1.0, -14.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.9, 0.2, 1.0))

func _try_resolve_player_map_missions_at(q: int, r: int) -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm == null:
		return
	if mm.has_method("get_player_map_strategy_missions_at_hex"):
		var strat_var: Variant = mm.call("get_player_map_strategy_missions_at_hex", q, r)
		if strat_var is Array and strat_var.size() > 0:
			_player_map_mission_pending_q = q
			_player_map_mission_pending_r = r
			_fill_player_map_mission_window(strat_var[0])
			if _player_map_mission_window:
				_player_map_mission_window.popup_centered(Vector2i(560, 440))
			queue_redraw()
			return
	if mm.has_method("try_complete_player_missions_at_hex"):
		var n: int = int(mm.call("try_complete_player_missions_at_hex", q, r))
		if n > 0:
			_update_status_label("%d gorev hedefte tamamlandi." % n)
			queue_redraw()

func _cycle_selected_unit(step: int) -> void:
	if _active_unit_markers.is_empty():
		_selected_unit_index = -1
		_update_status_label("Secilebilir ekip yok.")
		return
	if _selected_unit_index < 0:
		_selected_unit_index = 0
	else:
		_selected_unit_index = (_selected_unit_index + step) % _active_unit_markers.size()
	if _selected_unit_index < 0:
		_selected_unit_index += _active_unit_markers.size()
	_focus_selected_unit()
	_update_status_label()
	queue_redraw()

func _focus_selected_unit() -> void:
	if _selected_unit_index < 0 or _selected_unit_index >= _active_unit_markers.size():
		return
	var unit: Dictionary = _active_unit_markers[_selected_unit_index]
	var q: int = int(unit.get("q", _cursor_q))
	var r: int = int(unit.get("r", _cursor_r))
	_cursor_q = q
	_cursor_r = r
	_focus_camera_on_cursor()
	_schedule_path_preview_refresh()
	_cursor_status_label_pending = true
	_cursor_status_label_throttle = 0.0
	queue_redraw()

func _setup_travel_event_dialog() -> void:
	if _travel_event_dialog != null:
		return
	_travel_event_dialog = AcceptDialog.new()
	if MEDIEVAL_THEME:
		_travel_event_dialog.theme = MEDIEVAL_THEME
	_travel_event_dialog.dialog_hide_on_ok = false
	_travel_event_dialog.popup_window = false
	_travel_event_dialog.borderless = true
	_travel_event_dialog.unresizable = true
	_travel_event_dialog.exclusive = true
	_travel_event_dialog.min_size = Vector2i(560, 340)
	_travel_event_dialog.size = Vector2i(560, 340)
	_travel_event_dialog.title = "Yolculuk Olayi"
	_travel_event_dialog.dialog_text = ""
	_travel_event_dialog.get_ok_button().text = "Zar At"
	_travel_event_dialog.confirmed.connect(_on_travel_event_roll_dice)
	var content := VBoxContainer.new()
	content.name = "TravelDiceContent"
	content.add_theme_constant_override("separation", 8)
	content.custom_minimum_size = Vector2(500, 140)
	_travel_event_dialog.add_child(content)
	_travel_event_info_label = Label.new()
	_travel_event_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_travel_event_info_label.max_lines_visible = 4
	content.add_child(_travel_event_info_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	var lp := PanelContainer.new()
	lp.custom_minimum_size = Vector2(96, 96)
	row.add_child(lp)
	_travel_dice_left_label = Label.new()
	_travel_dice_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel_dice_left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_travel_dice_left_label.add_theme_font_size_override("font_size", 24)
	_travel_dice_left_label.custom_minimum_size = Vector2(92, 92)
	lp.add_child(_travel_dice_left_label)
	var rp := PanelContainer.new()
	rp.custom_minimum_size = Vector2(96, 96)
	row.add_child(rp)
	_travel_dice_right_label = Label.new()
	_travel_dice_right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel_dice_right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_travel_dice_right_label.add_theme_font_size_override("font_size", 24)
	_travel_dice_right_label.custom_minimum_size = Vector2(92, 92)
	rp.add_child(_travel_dice_right_label)
	_travel_event_result_label = Label.new()
	_travel_event_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_travel_event_result_label.max_lines_visible = 4
	content.add_child(_travel_event_result_label)
	var layer: CanvasLayer = get_node_or_null("CanvasLayer")
	if layer:
		layer.add_child(_travel_event_dialog)
	else:
		add_child(_travel_event_dialog)

func _setup_travel_outcome_dialog() -> void:
	if _travel_outcome_dialog != null:
		return
	_travel_outcome_dialog = AcceptDialog.new()
	if MEDIEVAL_THEME:
		_travel_outcome_dialog.theme = MEDIEVAL_THEME
	_travel_outcome_dialog.title = "Yol sonucu"
	_travel_outcome_dialog.dialog_text = ""
	_travel_outcome_dialog.get_ok_button().text = "Tamam"
	if not _travel_outcome_dialog.visibility_changed.is_connected(_on_travel_outcome_visibility_changed):
		_travel_outcome_dialog.visibility_changed.connect(_on_travel_outcome_visibility_changed)
	var layer_o: CanvasLayer = get_node_or_null("CanvasLayer")
	if layer_o:
		layer_o.add_child(_travel_outcome_dialog)
	else:
		add_child(_travel_outcome_dialog)

func _on_travel_outcome_visibility_changed() -> void:
	if _travel_outcome_dialog == null or _travel_outcome_dialog.visible:
		return
	if _travel_resume_after_outcome_ack:
		_travel_resume_after_outcome_ack = false
		_confirm_move_to_cursor()

func _show_travel_outcome_popup(body: String, title: String = "Yol sonucu", resume_travel_after_ack: bool = false) -> void:
	if body.strip_edges().is_empty():
		return
	if _travel_outcome_dialog == null:
		_setup_travel_outcome_dialog()
	if _travel_outcome_dialog == null:
		return
	_travel_resume_after_outcome_ack = resume_travel_after_ack
	_travel_outcome_dialog.title = title
	_travel_outcome_dialog.dialog_text = body.strip_edges()
	_travel_outcome_dialog.popup_centered(Vector2i(540, 380))

func _show_travel_outcome_popup_or_resume_travel(body: String, title: String = "Yol sonucu") -> void:
	if body.strip_edges().is_empty():
		_confirm_move_to_cursor()
	else:
		_show_travel_outcome_popup(body, title, true)

func _close_travel_event_dialog() -> void:
	if _travel_event_dialog == null:
		return
	_travel_event_dialog.hide()
	# Eski popup odagi kalmasin; outcome popup odagi net alsin.
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()

func _on_world_map_travel_event(event_data: Dictionary) -> void:
	if _travel_event_dialog == null:
		return
	if _travel_outcome_dialog and _travel_outcome_dialog.visible:
		_travel_outcome_dialog.hide()
	_travel_dice_animating = false
	_travel_event_result_ready = false
	_pending_travel_event_data = event_data.duplicate(true)
	_apply_travel_event_dialog_content(event_data)
	_travel_event_dialog.size = Vector2i(560, 340)
	_travel_event_dialog.popup_centered_clamped(Vector2i(560, 340))
	_focus_travel_event_primary_button()

func _on_travel_event_roll_dice() -> void:
	if _travel_event_result_ready:
		_close_travel_event_dialog()
		_pending_travel_event_data.clear()
		_travel_event_result_ready = false
		_confirm_move_to_cursor()
		return
	if _travel_dice_animating:
		return
	_travel_dice_animating = true
	var ok_btn: Button = _travel_event_dialog.get_ok_button() if _travel_event_dialog else null
	if ok_btn:
		ok_btn.disabled = true
		ok_btn.text = "Atiliyor..."
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var final_d1: int = rng.randi_range(1, 6)
	var final_d2: int = rng.randi_range(1, 6)
	for _i in range(10):
		var a: int = rng.randi_range(1, 6)
		var b: int = rng.randi_range(1, 6)
		_set_travel_event_dice_preview(a, b, true)
		await get_tree().create_timer(0.045).timeout
	_set_travel_event_dice_preview(final_d1, final_d2, false)
	var outcome_body: String = ""
	if _world_manager and not _pending_travel_event_data.is_empty():
		var resolution: Dictionary = {}
		if _world_manager.has_method("apply_world_map_travel_event_with_dice"):
			resolution = _world_manager.apply_world_map_travel_event_with_dice(_pending_travel_event_data, final_d1, final_d2)
		elif _world_manager.has_method("apply_world_map_travel_event_dice_roll"):
			resolution = _world_manager.apply_world_map_travel_event_dice_roll(_pending_travel_event_data)
		_pending_travel_event_resolution = resolution.duplicate(true)
		outcome_body = _format_travel_outcome_for_popup(_pending_travel_event_resolution)
	_travel_event_result_ready = true
	_travel_dice_animating = false
	if _travel_event_result_label:
		_travel_event_result_label.text = outcome_body
	if ok_btn:
		ok_btn.disabled = false
		ok_btn.text = "Devam"
		ok_btn.grab_focus()

func _apply_travel_event_dialog_content(event_data: Dictionary) -> void:
	if _travel_event_dialog == null:
		return
	var terrain: String = String(event_data.get("terrain", "ova"))
	var headline := _get_travel_event_headline(terrain, event_data)
	var msg: String = String(event_data.get("message", "Yolda bir olayla karsilastin."))
	if msg.length() > 120:
		msg = msg.substr(0, 120) + "..."
	var cargo_mult: float = float(event_data.get("cargo_risk_multiplier", 1.0))
	_travel_event_dialog.title = headline
	_travel_event_intro_text = (
		"%s\n\n"
		+ "Yuk riski carpani: x%.2f"
	) % [msg, cargo_mult]
	if _travel_event_info_label:
		_travel_event_info_label.text = _travel_event_intro_text + "\n\nZar At."
	if _travel_event_result_label:
		_travel_event_result_label.text = ""
	_set_travel_event_dice_preview(1, 1, false)
	var ok_btn: Button = _travel_event_dialog.get_ok_button()
	if ok_btn:
		ok_btn.disabled = false
		ok_btn.text = "Zar At"
		_apply_button_risk_color(ok_btn, "Orta")

func _dice_face_glyph(v: int) -> String:
	match clampi(v, 1, 6):
		1:
			return "· · ·\n· ● ·\n· · ·"
		2:
			return "● · ·\n· · ·\n· · ●"
		3:
			return "● · ·\n· ● ·\n· · ●"
		4:
			return "● · ●\n· · ·\n● · ●"
		5:
			return "● · ●\n· ● ·\n● · ●"
		_:
			return "● · ●\n● · ●\n● · ●"

func _set_travel_event_dice_preview(d1: int, d2: int, rolling: bool) -> void:
	if _travel_event_dialog == null:
		return
	if _travel_dice_left_label:
		_travel_dice_left_label.text = _dice_face_glyph(d1)
	if _travel_dice_right_label:
		_travel_dice_right_label.text = _dice_face_glyph(d2)
	if _travel_event_info_label:
		if rolling:
			_travel_event_info_label.text = _travel_event_intro_text + "\n\nZarlar donuyor..."
		else:
			_travel_event_info_label.text = _travel_event_intro_text + "\n\nZarlar hazir."

func _focus_travel_event_primary_button() -> void:
	if _travel_event_dialog == null:
		return
	var ok_btn: Button = _travel_event_dialog.get_ok_button()
	if ok_btn == null:
		return
	ok_btn.focus_mode = Control.FOCUS_ALL
	ok_btn.grab_focus()
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()
		ok_btn.grab_focus()

func _format_travel_outcome_for_popup(resolution: Dictionary) -> String:
	var full: String = _format_travel_outcome_for_player(resolution, true)
	var lines: PackedStringArray = full.split("\n")
	if lines.size() <= 4:
		return full
	var clipped: PackedStringArray = PackedStringArray()
	for i in range(4):
		clipped.append(lines[i])
	clipped.append("...")
	return "\n".join(clipped)

func _get_travel_event_headline(terrain: String, event_data: Dictionary = {}) -> String:
	var linked_name: String = String(event_data.get("linked_settlement_name", ""))
	if not linked_name.is_empty():
		return "Komsu Gerilimi (%s)" % linked_name
	match terrain:
		"orman":
			return "Orman Pususu"
		"dag":
			return "Dag Gecidi Cokusu"
		"akarsu":
			return "Akarsu Gecisi Krizi"
		_:
			return "Yol Olayi"

func _build_travel_effect_preview(effect: Dictionary, cargo_snapshot: Dictionary = {}) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var extra_minutes: int = int(effect.get("extra_minutes", 0))
	if extra_minutes > 0:
		parts.append("+%d dk" % extra_minutes)
	var hp_frac: float = float(effect.get("health_loss_fraction", 0.0))
	if hp_frac > 0.0:
		parts.append("can -%%%d" % int(round(hp_frac * 100.0)))
	var carried_frac: float = float(effect.get("carried_resource_loss_fraction", 0.0))
	if carried_frac > 0.0:
		parts.append("kaynak -%%%d" % int(round(carried_frac * 100.0)))
	var dg_frac: float = float(effect.get("dungeon_gold_loss_fraction", 0.0))
	if dg_frac > 0.0:
		parts.append("zindan altini -%%%d" % int(round(dg_frac * 100.0)))
	var rescued_frac: float = float(effect.get("rescued_loss_fraction", 0.0))
	if rescued_frac > 0.0:
		parts.append("kurtarilan -%%%d" % int(round(rescued_frac * 100.0)))
	var gold_delta: int = int(effect.get("gold_delta", 0))
	if gold_delta < 0:
		parts.append("%d altin" % gold_delta)
	elif gold_delta > 0:
		parts.append("+%d altin" % gold_delta)
	var estimates: PackedStringArray = _estimate_effect_losses(effect, cargo_snapshot)
	if not estimates.is_empty():
		parts.append("tahmini: " + ", ".join(estimates))
	if parts.is_empty():
		return "ek etki yok"
	return ", ".join(parts)

func _get_current_cargo_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"current_health": 0.0,
		"max_health": 0.0,
		"carried_total": 0,
		"dungeon_gold": 0,
		"rescued_total": 0
	}
	var ps = get_node_or_null("/root/PlayerStats")
	if ps:
		if ps.has_method("get_current_health"):
			snapshot["current_health"] = float(ps.get_current_health())
		if ps.has_method("get_max_health"):
			snapshot["max_health"] = float(ps.get_max_health())
		if ps.has_method("get_carried_resources"):
			var carried: Dictionary = ps.get_carried_resources()
			var total: int = 0
			for key in carried.keys():
				total += max(0, int(carried[key]))
			snapshot["carried_total"] = total
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gpd and "dungeon_gold" in gpd:
		snapshot["dungeon_gold"] = max(0, int(gpd.get("dungeon_gold")))
	var drs = get_node_or_null("/root/DungeonRunState")
	if drs:
		var villagers: Array = drs.get("pending_rescued_villagers") if "pending_rescued_villagers" in drs else []
		var cariyes: Array = drs.get("pending_rescued_cariyes") if "pending_rescued_cariyes" in drs else []
		snapshot["rescued_total"] = villagers.size() + cariyes.size()
	return snapshot

func _estimate_effect_losses(effect: Dictionary, cargo_snapshot: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur_hp: float = float(cargo_snapshot.get("current_health", 0.0))
	var max_hp: float = float(cargo_snapshot.get("max_health", 0.0))
	var hp_frac: float = float(effect.get("health_loss_fraction", 0.0))
	if hp_frac > 0.0 and max_hp > 0.0 and cur_hp > 0.0:
		var hp_loss: int = int(maxf(1.0, floor(max_hp * hp_frac)))
		hp_loss = mini(hp_loss, int(cur_hp - 1.0))
		if hp_loss > 0:
			out.append("-~%d can" % hp_loss)
	var carried_total: int = int(cargo_snapshot.get("carried_total", 0))
	var carried_frac: float = float(effect.get("carried_resource_loss_fraction", 0.0))
	if carried_frac > 0.0 and carried_total > 0:
		out.append("-~%d kaynak" % int(floor(float(carried_total) * carried_frac)))
	var dg: int = int(cargo_snapshot.get("dungeon_gold", 0))
	var dg_frac: float = float(effect.get("dungeon_gold_loss_fraction", 0.0))
	if dg_frac > 0.0 and dg > 0:
		out.append("-~%d z-altin" % int(floor(float(dg) * dg_frac)))
	var rescued_total: int = int(cargo_snapshot.get("rescued_total", 0))
	var rescued_frac: float = float(effect.get("rescued_loss_fraction", 0.0))
	if rescued_frac > 0.0 and rescued_total > 0:
		out.append("-~%d kurtarilan" % int(floor(float(rescued_total) * rescued_frac)))
	return out

func _classify_risk(effect: Dictionary) -> String:
	var score: float = 0.0
	score += float(effect.get("health_loss_fraction", 0.0)) * 100.0
	score += float(effect.get("carried_resource_loss_fraction", 0.0)) * 55.0
	score += float(effect.get("dungeon_gold_loss_fraction", 0.0)) * 45.0
	score += float(effect.get("rescued_loss_fraction", 0.0)) * 65.0
	score += float(effect.get("extra_minutes", 0.0)) * 0.35
	var gold_delta: int = int(effect.get("gold_delta", 0))
	if gold_delta < 0:
		score += minf(20.0, absf(float(gold_delta)) * 0.8)
	if score < 18.0:
		return "Dusuk"
	if score < 38.0:
		return "Orta"
	return "Yuksek"


func _apply_button_risk_color(button: Button, risk: String) -> void:
	if button == null:
		return
	match risk:
		"Dusuk":
			button.modulate = Color(0.78, 1.0, 0.78, 1.0)
		"Orta":
			button.modulate = Color(1.0, 0.96, 0.7, 1.0)
		"Yuksek":
			button.modulate = Color(1.0, 0.78, 0.78, 1.0)
		_:
			button.modulate = Color(1, 1, 1, 1)

func _setup_dungeon_entry_dialog() -> void:
	if _dungeon_entry_dialog != null:
		return
	_dungeon_entry_dialog = ConfirmationDialog.new()
	if MEDIEVAL_THEME:
		_dungeon_entry_dialog.theme = MEDIEVAL_THEME
	_dungeon_entry_dialog.title = "Zindan Girisi"
	_dungeon_entry_dialog.dialog_text = "Zindan hexine vardin. Zindana girmek istiyor musun?"
	_dungeon_entry_dialog.get_ok_button().text = "Gir"
	_dungeon_entry_dialog.get_cancel_button().text = "Vazgec"
	_dungeon_entry_dialog.confirmed.connect(_on_dungeon_entry_confirmed)
	_dungeon_entry_dialog.canceled.connect(_on_dungeon_entry_canceled)
	var layer: CanvasLayer = get_node_or_null("CanvasLayer")
	if layer:
		layer.add_child(_dungeon_entry_dialog)
	else:
		add_child(_dungeon_entry_dialog)

func _try_prompt_dungeon_entry_at_player_pos() -> void:
	if _dungeon_entry_dialog == null or _world_manager == null or not _world_manager.has_method("get_world_map_state"):
		return
	var state: Dictionary = _get_world_map_state_cached()
	var pos: Dictionary = state.get("player_pos", {"q": 0, "r": 0})
	var tile: Dictionary = _get_tile(int(pos.get("q", 0)), int(pos.get("r", 0)))
	if String(tile.get("poi_type", "")) == "dungeon":
		_dungeon_entry_dialog.popup_centered(Vector2i(520, 180))

func _on_dungeon_entry_confirmed() -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager and scene_manager.has_method("change_to_dungeon"):
		scene_manager.change_to_dungeon({"source": "world_map"})

func _on_dungeon_entry_canceled() -> void:
	_update_status_label("Zindan girisi iptal edildi.")

func _setup_high_risk_move_dialog() -> void:
	if _high_risk_move_dialog != null:
		return
	_high_risk_move_dialog = ConfirmationDialog.new()
	if MEDIEVAL_THEME:
		_high_risk_move_dialog.theme = MEDIEVAL_THEME
	_high_risk_move_dialog.title = "Tehlikeli Rota Uyarisi"
	_high_risk_move_dialog.dialog_text = "Bu rota riskli. Emin misin?"
	_high_risk_move_dialog.get_ok_button().text = "Riske Gir"
	_high_risk_move_dialog.get_cancel_button().text = "Bekle"
	_high_risk_move_dialog.confirmed.connect(_on_high_risk_move_confirmed)
	_high_risk_move_dialog.canceled.connect(_on_high_risk_move_canceled)
	var layer: CanvasLayer = get_node_or_null("CanvasLayer")
	if layer:
		layer.add_child(_high_risk_move_dialog)
	else:
		add_child(_high_risk_move_dialog)

func _on_high_risk_move_confirmed() -> void:
	_execute_travel_to_cursor()

func _on_high_risk_move_canceled() -> void:
	_update_status_label("Tehlikeli rota iptal edildi.")

var _pending_aid_option: Dictionary = {}
var _pending_war_support_option: Dictionary = {}
var _pending_mediation_option: Dictionary = {}
var _pending_alliance_propose_option: Dictionary = {}
var _pending_alliance_break_option: Dictionary = {}
# Hangi tip mudahale onayda? "aid" | "war_support" | "mediation" | "alliance_propose" | "alliance_break"
var _pending_aid_kind: String = ""

func _setup_settlement_action_menu() -> void:
	if _settlement_action_menu != null:
		return
	_settlement_action_menu = PopupMenu.new()
	if MEDIEVAL_THEME:
		_settlement_action_menu.theme = MEDIEVAL_THEME
	_settlement_action_menu.add_item("Ticaret Baslat", 1)
	_settlement_action_menu.add_item("Diplomasi Girisimi", 2)
	_settlement_action_menu.add_item("Asker Gonder (Baskin)", 3)
	_settlement_action_menu.add_item("Yardim Gonder", 4)
	_settlement_action_menu.add_item("Savasta Destek", 5)
	_settlement_action_menu.add_item("Aracilik Yap", 6)
	_settlement_action_menu.add_item("Ittifak Onerisi", 7)
	_settlement_action_menu.add_item("Ittifaki Boz", 8)
	_settlement_action_menu.add_item("Ofansif Baskin", 10)
	_settlement_action_menu.add_separator()
	_settlement_action_menu.add_item("Vazgec", 9)
	_settlement_action_menu.id_pressed.connect(_on_settlement_action_selected)
	var layer: CanvasLayer = get_node_or_null("CanvasLayer")
	if layer:
		layer.add_child(_settlement_action_menu)
	else:
		add_child(_settlement_action_menu)

func _try_prompt_settlement_actions_at_player_pos() -> void:
	if _settlement_action_menu == null or _world_manager == null or not _world_manager.has_method("get_world_map_state"):
		return
	var state: Dictionary = _get_world_map_state_cached()
	var pos: Dictionary = state.get("player_pos", {"q": 0, "r": 0})
	var tile: Dictionary = _get_tile(int(pos.get("q", 0)), int(pos.get("r", 0)))
	if String(tile.get("poi_type", "")) != "neighbor_village":
		return
	_pending_settlement_id = String(tile.get("settlement_id", ""))
	_pending_settlement_name = String(tile.get("settlement_name", "Komsu Koy"))
	var target_q: int = int(tile.get("q", 0))
	var target_r: int = int(tile.get("r", 0))
	_pending_settlement_distance = int(_hex_distance(int(pos.get("q", 0)), int(pos.get("r", 0)), target_q, target_r))
	var trade_preview: Dictionary = _get_settlement_action_preview("trade")
	var diplomacy_preview: Dictionary = _get_settlement_action_preview("diplomacy")
	var raid_preview: Dictionary = _get_settlement_action_preview("raid")
	_settlement_action_menu.set_item_text(0, "Ticaret Baslat (Sure: ~%s | Risk: %s)" % [_format_minutes_short(int(trade_preview.get("duration_minutes", 0))), String(trade_preview.get("risk_level", "Dusuk"))])
	_settlement_action_menu.set_item_text(1, "Diplomasi Girisimi (Sure: ~%s | Risk: %s)" % [_format_minutes_short(int(diplomacy_preview.get("duration_minutes", 0))), String(diplomacy_preview.get("risk_level", "Dusuk"))])
	_settlement_action_menu.set_item_text(2, "Asker Gonder (Sure: ~%s | Risk: %s)" % [_format_minutes_short(int(raid_preview.get("duration_minutes", 0))), String(raid_preview.get("risk_level", "Orta"))])
	_refresh_aid_menu_item()
	_refresh_war_support_menu_item()
	_refresh_mediation_menu_item()
	_refresh_alliance_propose_menu_item()
	_refresh_alliance_break_menu_item()
	_refresh_offensive_raid_menu_item()
	_settlement_action_menu.position = Vector2i(40, 210)
	_settlement_action_menu.popup()
	var status_text: String = "%s: Ticaret/Diplomasi/Asker secimi yap." % _pending_settlement_name
	var detail_text: String = _build_settlement_status_text(_pending_settlement_id)
	if not detail_text.is_empty():
		status_text += "\n" + detail_text
	_update_status_label(status_text)

func _on_settlement_action_selected(action_id: int) -> void:
	match action_id:
		1:
			_execute_settlement_trade()
		2:
			_execute_settlement_diplomacy()
		3:
			_execute_settlement_raid()
		4:
			_execute_settlement_aid()
		5:
			_execute_settlement_war_support()
		6:
			_execute_settlement_mediation()
		7:
			_execute_settlement_alliance_propose()
		8:
			_execute_settlement_alliance_break()
		10:
			_execute_settlement_offensive_raid()
		_:
			_update_status_label("%s ile etkileşim iptal edildi." % _pending_settlement_name)

func _refresh_aid_menu_item() -> void:
	if _settlement_action_menu == null:
		return
	var aid_index: int = _find_settlement_menu_index_by_id(4)
	if aid_index < 0:
		return
	_pending_aid_option = {}
	if _world_manager == null or not _world_manager.has_method("get_settlement_aid_options"):
		_settlement_action_menu.set_item_text(aid_index, "Yardim Gonder (kriz yok)")
		_settlement_action_menu.set_item_disabled(aid_index, true)
		return
	var options: Array = _world_manager.call("get_settlement_aid_options", _pending_settlement_id)
	if not (options is Array) or options.is_empty():
		_settlement_action_menu.set_item_text(aid_index, "Yardim Gonder (kriz yok)")
		_settlement_action_menu.set_item_disabled(aid_index, true)
		return
	var option: Dictionary = options[0]
	_pending_aid_option = option
	var label: String = String(option.get("label", "Yardim Gonder"))
	var cost: Dictionary = option.get("cost", {})
	var cost_parts: PackedStringArray = PackedStringArray()
	if int(cost.get("gold", 0)) > 0:
		cost_parts.append("%d altin" % int(cost.get("gold", 0)))
	for resource_type in ["food", "wood", "stone", "water"]:
		var amount: int = int(cost.get(resource_type, 0))
		if amount > 0:
			cost_parts.append("%d %s" % [amount, resource_type])
	var summary: String = String(option.get("summary", ""))
	var menu_text: String = label
	if not cost_parts.is_empty():
		menu_text += " (-" + ", ".join(cost_parts) + ")"
	if not summary.is_empty():
		menu_text += " | " + summary
	_settlement_action_menu.set_item_text(aid_index, menu_text)
	var affordable: bool = false
	if _world_manager.has_method("can_afford_settlement_aid"):
		affordable = bool(_world_manager.call("can_afford_settlement_aid", option))
	_settlement_action_menu.set_item_disabled(aid_index, not affordable)

func _find_settlement_menu_index_by_id(target_id: int) -> int:
	if _settlement_action_menu == null:
		return -1
	for i in range(_settlement_action_menu.item_count):
		if _settlement_action_menu.get_item_id(i) == target_id:
			return i
	return -1

func _execute_settlement_aid() -> void:
	if _world_manager == null or not _world_manager.has_method("apply_settlement_aid"):
		_update_status_label("Yardim sistemi su an mevcut degil.")
		return
	if _pending_aid_option.is_empty():
		_update_status_label("Yardim icin uygun bir kriz yok.")
		return
	var option_id: String = String(_pending_aid_option.get("id", ""))
	if option_id.is_empty():
		_update_status_label("Yardim secimi tanimlanamadi.")
		return
	if _world_manager.has_method("can_afford_settlement_aid") and not bool(_world_manager.call("can_afford_settlement_aid", _pending_aid_option)):
		_update_status_label("Yardim icin yeterli kaynagin yok.")
		return
	_pending_aid_kind = "aid"
	if _settlement_aid_confirm_dialog == null:
		_perform_pending_intervention_now()
		return
	_settlement_aid_confirm_dialog.title = "Yardim Onayi"
	_settlement_aid_confirm_dialog.dialog_text = _build_aid_confirm_text(_pending_settlement_name, _pending_aid_option)
	_settlement_aid_confirm_dialog.popup_centered(Vector2i(560, 200))

func _execute_settlement_war_support() -> void:
	if _pending_war_support_option.is_empty():
		_update_status_label("Su an destek verilebilecek aktif savas yok.")
		return
	if _world_manager and _world_manager.has_method("can_afford_diplomatic_intervention") and not bool(_world_manager.call("can_afford_diplomatic_intervention", _pending_war_support_option)):
		_update_status_label("Savas destegi icin yeterli kaynagin yok.")
		return
	_pending_aid_kind = "war_support"
	if _settlement_aid_confirm_dialog == null:
		_perform_pending_intervention_now()
		return
	_settlement_aid_confirm_dialog.title = "Savas Destegi Onayi"
	_settlement_aid_confirm_dialog.dialog_text = _build_aid_confirm_text(_pending_settlement_name, _pending_war_support_option)
	_settlement_aid_confirm_dialog.popup_centered(Vector2i(560, 200))

func _execute_settlement_mediation() -> void:
	if _pending_mediation_option.is_empty():
		_update_status_label("Su an aracilik yapilabilecek bir gerilim yok.")
		return
	if _world_manager and _world_manager.has_method("can_afford_diplomatic_intervention") and not bool(_world_manager.call("can_afford_diplomatic_intervention", _pending_mediation_option)):
		_update_status_label("Aracilik icin yeterli kaynagin yok.")
		return
	_pending_aid_kind = "mediation"
	if _settlement_aid_confirm_dialog == null:
		_perform_pending_intervention_now()
		return
	_settlement_aid_confirm_dialog.title = "Aracilik Onayi"
	_settlement_aid_confirm_dialog.dialog_text = _build_aid_confirm_text(_pending_settlement_name, _pending_mediation_option)
	_settlement_aid_confirm_dialog.popup_centered(Vector2i(560, 200))

func _execute_settlement_alliance_propose() -> void:
	if _pending_alliance_propose_option.is_empty():
		_update_status_label("Bu koy zaten muttefik veya iliski cok dusuk.")
		return
	if _world_manager and _world_manager.has_method("can_afford_diplomatic_intervention") and not bool(_world_manager.call("can_afford_diplomatic_intervention", _pending_alliance_propose_option)):
		_update_status_label("Ittifak teklifi icin yeterli kaynagin yok.")
		return
	_pending_aid_kind = "alliance_propose"
	if _settlement_aid_confirm_dialog == null:
		_perform_pending_intervention_now()
		return
	_settlement_aid_confirm_dialog.title = "Ittifak Teklifi Onayi"
	_settlement_aid_confirm_dialog.dialog_text = _build_aid_confirm_text(_pending_settlement_name, _pending_alliance_propose_option)
	_settlement_aid_confirm_dialog.popup_centered(Vector2i(560, 200))

func _execute_settlement_alliance_break() -> void:
	if _pending_alliance_break_option.is_empty():
		_update_status_label("Bu koyle aktif ittifak yok.")
		return
	_pending_aid_kind = "alliance_break"
	if _settlement_aid_confirm_dialog == null:
		_perform_pending_intervention_now()
		return
	_settlement_aid_confirm_dialog.title = "Ittifak Bozma Onayi"
	_settlement_aid_confirm_dialog.dialog_text = _build_aid_confirm_text(_pending_settlement_name, _pending_alliance_break_option)
	_settlement_aid_confirm_dialog.popup_centered(Vector2i(560, 200))

func _refresh_alliance_propose_menu_item() -> void:
	if _settlement_action_menu == null:
		return
	var idx: int = _find_settlement_menu_index_by_id(7)
	if idx < 0:
		return
	_pending_alliance_propose_option = {}
	if _world_manager == null or not _world_manager.has_method("get_alliance_proposal_options"):
		_settlement_action_menu.set_item_text(idx, "Ittifak Onerisi (sistem yok)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	# Halihazirda muttefik mi?
	if _world_manager.has_method("is_player_allied") and bool(_world_manager.call("is_player_allied", _pending_settlement_id)):
		_settlement_action_menu.set_item_text(idx, "Ittifak Onerisi (zaten muttefik)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var options: Array = _world_manager.call("get_alliance_proposal_options", _pending_settlement_id)
	if not (options is Array) or options.is_empty():
		_settlement_action_menu.set_item_text(idx, "Ittifak Onerisi (gecersiz)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var option: Dictionary = options[0]
	# Iliski ek kontrolu (UI hint)
	var current_rel: int = 0
	if _world_manager.has_method("get_relation"):
		current_rel = int(_world_manager.call("get_relation", "Köy", _pending_settlement_name))
	var min_rel: int = 70
	if _world_manager.has_method("get") and "ALLIANCE_MIN_RELATION" in _world_manager:
		min_rel = int(_world_manager.get("ALLIANCE_MIN_RELATION"))
	_pending_alliance_propose_option = option
	var menu_text: String = _format_intervention_menu_text(option) + " (iliski: %d/%d)" % [current_rel, min_rel]
	_settlement_action_menu.set_item_text(idx, menu_text)
	var affordable: bool = false
	if _world_manager.has_method("can_afford_diplomatic_intervention"):
		affordable = bool(_world_manager.call("can_afford_diplomatic_intervention", option))
	_settlement_action_menu.set_item_disabled(idx, not (affordable and current_rel >= min_rel))

func _refresh_alliance_break_menu_item() -> void:
	if _settlement_action_menu == null:
		return
	var idx: int = _find_settlement_menu_index_by_id(8)
	if idx < 0:
		return
	_pending_alliance_break_option = {}
	if _world_manager == null or not _world_manager.has_method("get_alliance_break_options"):
		_settlement_action_menu.set_item_text(idx, "Ittifaki Boz (sistem yok)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var options: Array = _world_manager.call("get_alliance_break_options", _pending_settlement_id)
	if not (options is Array) or options.is_empty():
		_settlement_action_menu.set_item_text(idx, "Ittifaki Boz (muttefik degil)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var option: Dictionary = options[0]
	_pending_alliance_break_option = option
	_settlement_action_menu.set_item_text(idx, _format_intervention_menu_text(option))
	_settlement_action_menu.set_item_disabled(idx, false)

func _refresh_offensive_raid_menu_item() -> void:
	if _settlement_action_menu == null:
		return
	var idx: int = _find_settlement_menu_index_by_id(10)
	if idx < 0:
		return
	if _world_manager == null or not _world_manager.has_method("get_offensive_raid_options"):
		_settlement_action_menu.set_item_text(idx, "Ofansif Baskin (sistem yok)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var options: Array = _world_manager.call("get_offensive_raid_options", _pending_settlement_id)
	if not (options is Array) or options.is_empty():
		_settlement_action_menu.set_item_text(idx, "Ofansif Baskin (dusman degil)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var opt: Dictionary = options[0]
	var label: String = "Ofansif Baskin (%s | %d altin | %d/%d asker)" % [
		String(opt.get("difficulty", "medium")),
		int(opt.get("cost_gold", 0)),
		int(opt.get("current_soldiers", 0)),
		int(opt.get("min_soldiers", 0))
	]
	_settlement_action_menu.set_item_text(idx, label)
	_settlement_action_menu.set_item_disabled(idx, not bool(opt.get("enabled", false)))

func _execute_settlement_offensive_raid() -> void:
	if _world_manager == null or not _world_manager.has_method("get_offensive_raid_options"):
		_update_status_label("Ofansif baskin sistemi mevcut degil.")
		return
	var options: Array = _world_manager.call("get_offensive_raid_options", _pending_settlement_id)
	if not (options is Array) or options.is_empty() or not bool(options[0].get("enabled", false)):
		var reason: String = options[0].get("reason", "Yetersiz") if not options.is_empty() else "Dusman degil"
		_update_status_label("Ofansif baskin yapilamaz: %s" % reason)
		return
	_pending_aid_kind = "offensive_raid"
	var opt: Dictionary = options[0]
	var confirm_text: String = "%s koyune baskin duzenlenmek uzere.\nMaliyet: %d altin\nGerekli asker: %d\nZorluk: %s\nBaskin basarili olursa: altin/erzak ganimeti + hedef zayiflar\nBasarisiz olursa: asker kaybi + iliski kotulesmesi\n\nDevam edilsin mi?" % [
		_pending_settlement_name,
		int(opt.get("cost_gold", 0)),
		int(opt.get("min_soldiers", 0)),
		String(opt.get("difficulty", "medium"))
	]
	if _settlement_aid_confirm_dialog == null:
		_perform_pending_intervention_now()
		return
	_settlement_aid_confirm_dialog.title = "Ofansif Baskin Onayi"
	_settlement_aid_confirm_dialog.dialog_text = confirm_text
	_settlement_aid_confirm_dialog.get_ok_button().text = "Baskin Emri"
	_settlement_aid_confirm_dialog.popup_centered(Vector2i(560, 280))

func _perform_offensive_raid_now() -> void:
	if _world_manager == null or not _world_manager.has_method("launch_offensive_raid"):
		_update_status_label("Ofansif baskin sistemi mevcut degil.")
		return
	var result: Dictionary = _world_manager.call("launch_offensive_raid", _pending_settlement_id)
	if bool(result.get("success", false)):
		_update_status_label("Ofansif baskin gorevi olusturuldu! Cariye atayarak gorevi baslat.")
	else:
		_update_status_label("Baskin yapilamadi: %s" % String(result.get("reason", "bilinmeyen")))
	if _settlement_aid_confirm_dialog:
		_settlement_aid_confirm_dialog.get_ok_button().text = "Yardim Gonder"

func _refresh_war_support_menu_item() -> void:
	if _settlement_action_menu == null:
		return
	var idx: int = _find_settlement_menu_index_by_id(5)
	if idx < 0:
		return
	_pending_war_support_option = {}
	if _world_manager == null or not _world_manager.has_method("get_war_support_options"):
		_settlement_action_menu.set_item_text(idx, "Savasta Destek (savas yok)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var options: Array = _world_manager.call("get_war_support_options", _pending_settlement_id)
	if not (options is Array) or options.is_empty():
		_settlement_action_menu.set_item_text(idx, "Savasta Destek (savas yok)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var option: Dictionary = options[0]
	_pending_war_support_option = option
	_settlement_action_menu.set_item_text(idx, _format_intervention_menu_text(option))
	var affordable: bool = false
	if _world_manager.has_method("can_afford_diplomatic_intervention"):
		affordable = bool(_world_manager.call("can_afford_diplomatic_intervention", option))
	_settlement_action_menu.set_item_disabled(idx, not affordable)

func _refresh_mediation_menu_item() -> void:
	if _settlement_action_menu == null:
		return
	var idx: int = _find_settlement_menu_index_by_id(6)
	if idx < 0:
		return
	_pending_mediation_option = {}
	if _world_manager == null or not _world_manager.has_method("get_mediation_options"):
		_settlement_action_menu.set_item_text(idx, "Aracilik Yap (gerilim yok)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var options: Array = _world_manager.call("get_mediation_options", _pending_settlement_id)
	if not (options is Array) or options.is_empty():
		_settlement_action_menu.set_item_text(idx, "Aracilik Yap (gerilim yok)")
		_settlement_action_menu.set_item_disabled(idx, true)
		return
	var option: Dictionary = options[0]
	_pending_mediation_option = option
	_settlement_action_menu.set_item_text(idx, _format_intervention_menu_text(option))
	var affordable: bool = false
	if _world_manager.has_method("can_afford_diplomatic_intervention"):
		affordable = bool(_world_manager.call("can_afford_diplomatic_intervention", option))
	_settlement_action_menu.set_item_disabled(idx, not affordable)

func _format_intervention_menu_text(option: Dictionary) -> String:
	var label: String = String(option.get("label", "Mudahale"))
	var cost: Dictionary = option.get("cost", {})
	var cost_parts: PackedStringArray = PackedStringArray()
	if int(cost.get("gold", 0)) > 0:
		cost_parts.append("%d altin" % int(cost.get("gold", 0)))
	for resource_type in ["food", "wood", "stone", "water"]:
		var amount: int = int(cost.get(resource_type, 0))
		if amount > 0:
			cost_parts.append("%d %s" % [amount, resource_type])
	var summary: String = String(option.get("summary", ""))
	var menu_text: String = label
	if not cost_parts.is_empty():
		menu_text += " (-" + ", ".join(cost_parts) + ")"
	if not summary.is_empty():
		menu_text += " | " + summary
	return menu_text

func _perform_settlement_aid_now() -> void:
	if _world_manager == null or not _world_manager.has_method("apply_settlement_aid"):
		return
	if _pending_aid_option.is_empty():
		return
	var option_id: String = String(_pending_aid_option.get("id", ""))
	if option_id.is_empty():
		return
	var result: Dictionary = _world_manager.call("apply_settlement_aid", _pending_settlement_id, option_id)
	if not bool(result.get("ok", false)):
		var reason: String = String(result.get("reason", ""))
		match reason:
			"cannot_afford":
				_update_status_label("Yardim icin yeterli kaynagin yok.")
			"no_active_incident":
				_update_status_label("Bu koyde su an yardim gerektiren bir kriz yok.")
			"invalid_option":
				_update_status_label("Bu kriz turu icin yardim secenegi yok.")
			_:
				_update_status_label("Yardim uygulanamadi.")
		return
	var summary: String = String(result.get("summary", "Yardim uygulandi."))
	_update_status_label(summary)
	queue_redraw()

func _setup_settlement_aid_confirm_dialog() -> void:
	if _settlement_aid_confirm_dialog != null:
		return
	_settlement_aid_confirm_dialog = ConfirmationDialog.new()
	if MEDIEVAL_THEME:
		_settlement_aid_confirm_dialog.theme = MEDIEVAL_THEME
	_settlement_aid_confirm_dialog.title = "Yardim Onayi"
	_settlement_aid_confirm_dialog.dialog_text = "Yardim gondermek istedigine emin misin?"
	_settlement_aid_confirm_dialog.get_ok_button().text = "Yardim Gonder"
	_settlement_aid_confirm_dialog.get_cancel_button().text = "Vazgec"
	_settlement_aid_confirm_dialog.confirmed.connect(_on_settlement_aid_confirmed)
	_settlement_aid_confirm_dialog.canceled.connect(_on_settlement_aid_canceled)
	var layer: CanvasLayer = get_node_or_null("CanvasLayer")
	if layer:
		layer.add_child(_settlement_aid_confirm_dialog)
	else:
		add_child(_settlement_aid_confirm_dialog)

func _setup_player_map_mission_window() -> void:
	if _player_map_mission_window != null:
		return
	var w := Window.new()
	w.title = "Görev — oyuncu seçimi"
	w.unresizable = true
	w.size = Vector2i(560, 440)
	w.transient = true
	w.exclusive = true
	w.unfocusable = false
	if MEDIEVAL_THEME:
		w.theme = MEDIEVAL_THEME
	w.close_requested.connect(_on_player_map_mission_cancel_pressed)
	w.visibility_changed.connect(_on_player_map_mission_window_visibility_changed)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	scroll.add_child(margin)
	w.add_child(scroll)
	var layer_pm: CanvasLayer = get_node_or_null("CanvasLayer")
	if layer_pm:
		layer_pm.add_child(w)
	else:
		add_child(w)
	_player_map_mission_window = w
	_player_map_mission_vbox = vbox
	w.hide()

func _clear_player_map_mission_vbox() -> void:
	if _player_map_mission_vbox == null:
		return
	while _player_map_mission_vbox.get_child_count() > 0:
		var c: Node = _player_map_mission_vbox.get_child(0)
		_player_map_mission_vbox.remove_child(c)
		c.free()

func _format_resource_cost_for_map_ui(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var name_map := {
		"wood": "Odun", "stone": "Taş", "food": "Yiyecek", "water": "Su",
		"medicine": "İlaç", "gold": "Altın", "bread": "Ekmek", "cloth": "Kumaş"
	}
	for k in cost.keys():
		var amount: int = int(cost[k])
		if amount <= 0:
			continue
		var label: String = str(name_map.get(str(k), str(k)))
		parts.append("%d %s" % [amount, label])
	return ", ".join(parts)

func _format_mission_strategy_button_label(row: Dictionary) -> String:
	var txt: String = str(row.get("text", ""))
	var cost: Dictionary = row.get("cost", {})
	var chance: float = float(row.get("success_chance", 0.0))
	var pct: int = int(round(clampf(chance, 0.0, 1.0) * 100.0))
	var cost_str: String = _format_resource_cost_for_map_ui(cost)
	if cost_str.is_empty():
		return "%s (~%%%d başarı)" % [txt, pct]
	return "%s\n→ %s • ~%%%d başarı" % [txt, cost_str, pct]

func _fill_player_map_mission_window(entry: Variant) -> void:
	if _player_map_mission_vbox == null:
		return
	_clear_player_map_mission_vbox()
	if not entry is Dictionary:
		return
	var ed: Dictionary = entry
	var title := Label.new()
	title.text = str(ed.get("mission_name", "Görev"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.focus_mode = Control.FOCUS_NONE
	_player_map_mission_vbox.add_child(title)
	var sub := Label.new()
	sub.text = "Köyden kaynak harcayarak bir yöntem seç. Başarı şansı yaklaşıktır; başarısızlıkta cezalar uygulanır."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(0.85, 0.9, 0.95, 1.0)
	sub.focus_mode = Control.FOCUS_NONE
	_player_map_mission_vbox.add_child(sub)
	var mission_id: String = str(ed.get("mission_id", ""))
	var rows: Array = ed.get("strategies", [])
	for row in rows:
		if not row is Dictionary:
			continue
		var rd: Dictionary = row
		var btn := Button.new()
		btn.text = _format_mission_strategy_button_label(rd)
		btn.disabled = not bool(rd.get("affordable", false))
		btn.focus_mode = Control.FOCUS_ALL
		var idx: int = int(rd.get("index", -1))
		btn.pressed.connect(_on_player_map_mission_strategy_chosen.bind(mission_id, idx))
		_player_map_mission_vbox.add_child(btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Vazgeç (şimdilik yapma)"
	cancel_btn.focus_mode = Control.FOCUS_ALL
	cancel_btn.pressed.connect(_on_player_map_mission_cancel_pressed)
	_player_map_mission_vbox.add_child(cancel_btn)
	var mission_buttons: Array[Button] = []
	for ch in _player_map_mission_vbox.get_children():
		if ch is Button:
			mission_buttons.append(ch as Button)
	for bi in range(mission_buttons.size()):
		var b: Button = mission_buttons[bi]
		if bi + 1 < mission_buttons.size():
			var nb: Button = mission_buttons[bi + 1]
			b.focus_neighbor_bottom = b.get_path_to(nb)
			nb.focus_neighbor_top = nb.get_path_to(b)
	call_deferred("_focus_player_map_mission_first_control")

func _on_player_map_mission_window_visibility_changed() -> void:
	if _player_map_mission_window and _player_map_mission_window.visible:
		call_deferred("_focus_player_map_mission_first_control")

func _focus_player_map_mission_first_control() -> void:
	if _player_map_mission_vbox == null:
		return
	var btns: Array[Button] = []
	for ch in _player_map_mission_vbox.get_children():
		if ch is Button:
			btns.append(ch as Button)
	for bb in btns:
		if not bb.disabled:
			bb.grab_focus()
			return
	if not btns.is_empty():
		btns.back().grab_focus()

func _finish_player_map_mission_flow_and_legacy() -> void:
	if _player_map_mission_window:
		_player_map_mission_window.hide()
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("try_complete_player_missions_at_hex"):
		var n: int = int(mm.call("try_complete_player_missions_at_hex", _player_map_mission_pending_q, _player_map_mission_pending_r))
		if n > 0:
			_update_status_label("%d görev hedefte tamamlandı." % n)
	queue_redraw()

func _on_player_map_mission_cancel_pressed() -> void:
	if _player_map_mission_window:
		_player_map_mission_window.hide()
	_finish_player_map_mission_flow_and_legacy()

func _on_player_map_mission_strategy_chosen(mission_id: String, strategy_index: int) -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("resolve_player_map_mission_with_strategy"):
		return
	if _player_map_mission_window:
		_player_map_mission_window.hide()
	var res: Dictionary = mm.call("resolve_player_map_mission_with_strategy", mission_id, strategy_index, _player_map_mission_pending_q, _player_map_mission_pending_r)
	if not bool(res.get("ok", false)):
		_update_status_label(str(res.get("reason", "İşlem yapılamadı.")))
		if mm.has_method("get_player_map_strategy_missions_at_hex"):
			var left: Variant = mm.call("get_player_map_strategy_missions_at_hex", _player_map_mission_pending_q, _player_map_mission_pending_r)
			if left is Array and left.size() > 0:
				_fill_player_map_mission_window(left[0])
				_player_map_mission_window.popup_centered(Vector2i(560, 440))
			else:
				_finish_player_map_mission_flow_and_legacy()
		else:
			_finish_player_map_mission_flow_and_legacy()
		return
	var ok_succ: bool = bool(res.get("successful", false))
	_update_status_label("Görev başarılı." if ok_succ else "Görev başarısız; harcadığın kaynak geri dönmez.")
	if mm.has_method("get_player_map_strategy_missions_at_hex"):
		var left2: Variant = mm.call("get_player_map_strategy_missions_at_hex", _player_map_mission_pending_q, _player_map_mission_pending_r)
		if left2 is Array and left2.size() > 0:
			_fill_player_map_mission_window(left2[0])
			_player_map_mission_window.popup_centered(Vector2i(560, 440))
		else:
			_finish_player_map_mission_flow_and_legacy()
	else:
		_finish_player_map_mission_flow_and_legacy()

func _on_world_expedition_supplies_changed(_t: Dictionary) -> void:
	_unsecured_cargo_cache_valid = false
	queue_redraw()
	_update_status_label()

func _try_open_expedition_pack_dialog() -> void:
	if _travel_anim_active:
		return
	if _world_manager == null or not _world_manager.has_method("is_player_on_own_village_hex"):
		return
	if not bool(_world_manager.call("is_player_on_own_village_hex")):
		_update_status_label(
			"Erzak: yalnizca kendi koy hex inde (%s). Koye gir: %s / %s veya %s (imlec oyuncuda)."
			% [
				_wm_input_hint("attack"),
				_wm_input_hint("attack_heavy"),
				_wm_input_hint("block"),
				_wm_input_hint("ui_accept"),
			]
		)
		return
	_setup_expedition_pack_modal()
	_exp_pack_row = 0
	_exp_lr_left_hold = 0.0
	_exp_lr_left_acc = 0.0
	_exp_lr_right_hold = 0.0
	_exp_lr_right_acc = 0.0
	_refresh_expedition_pack_limits_and_labels(true)
	if _expedition_pack_modal:
		_expedition_pack_modal.show()

func _highlight_exp_pack_rows() -> void:
	for i in range(_exp_row_hboxes.size()):
		var hb: HBoxContainer = _exp_row_hboxes[i]
		if hb == null or not is_instance_valid(hb):
			continue
		hb.modulate = Color(1.0, 1.0, 1.0, 1.0) if i == _exp_pack_row else Color(0.62, 0.62, 0.66, 1.0)

func _refresh_expedition_pack_limits_and_labels(reset_amounts: bool = false) -> void:
	if _exp_row_hboxes.is_empty():
		return
	var vm: Node = get_node_or_null("/root/VillageManager")
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var ex: Dictionary = {}
	if ps and ps.has_method("get_world_expedition_supplies"):
		ex = ps.call("get_world_expedition_supplies")
	var vf: int = int(vm.resource_levels.get("food", 0)) if vm else 0
	var vw: int = int(vm.resource_levels.get("water", 0)) if vm else 0
	var vm_: int = int(vm.resource_levels.get("medicine", 0)) if vm else 0
	var pack_caps: Dictionary = {}
	if ps and ps.has_method("get_world_expedition_pack_caps"):
		pack_caps = ps.call("get_world_expedition_pack_caps")
	else:
		pack_caps = {"food": 1, "water": 1, "medicine": 24, "world_gold": 2500}
	var cap_f: int = int(pack_caps.get("food", 1))
	var cap_w: int = int(pack_caps.get("water", 1))
	var cap_m: int = int(pack_caps.get("medicine", 24))
	var cap_g: int = int(pack_caps.get("world_gold", 2500))
	var cur_f: int = int(ex.get("food", 0))
	var cur_w: int = int(ex.get("water", 0))
	var cur_m: int = int(ex.get("medicine", 0))
	var cur_g: int = int(ex.get("world_gold", 0))
	_exp_max_food = maxi(0, mini(vf, cap_f - cur_f))
	_exp_max_water = maxi(0, mini(vw, cap_w - cur_w))
	_exp_max_medicine = maxi(0, mini(vm_, cap_m - cur_m))
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	var purse: int = int(gpd.gold) if gpd and "gold" in gpd else 0
	_exp_max_gold = maxi(0, mini(purse, cap_g - cur_g))
	if reset_amounts:
		_exp_amt_food = 0
		_exp_amt_water = 0
		_exp_amt_medicine = 0
		_exp_amt_gold = 0
	else:
		_exp_amt_food = clampi(_exp_amt_food, 0, _exp_max_food)
		_exp_amt_water = clampi(_exp_amt_water, 0, _exp_max_water)
		_exp_amt_medicine = clampi(_exp_amt_medicine, 0, _exp_max_medicine)
		_exp_amt_gold = clampi(_exp_amt_gold, 0, _exp_max_gold)
	var vals: Array = [
		[_exp_amt_food, _exp_max_food],
		[_exp_amt_water, _exp_max_water],
		[_exp_amt_medicine, _exp_max_medicine],
		[_exp_amt_gold, _exp_max_gold],
	]
	for i in range(mini(_exp_row_hboxes.size(), vals.size())):
		var hb: HBoxContainer = _exp_row_hboxes[i]
		if hb == null or hb.get_child_count() < 2:
			continue
		var vlab: Label = hb.get_child(1) as Label
		if vlab:
			vlab.text = "%d / %d" % [int(vals[i][0]), int(vals[i][1])]
	_highlight_exp_pack_rows()

func _update_expedition_pack_left_right_repeat(delta: float) -> void:
	if _expedition_pack_modal == null or not _expedition_pack_modal.visible or _exp_row_hboxes.is_empty():
		return
	var key: String = _EXP_PACK_KEYS[_exp_pack_row]
	if Input.is_action_just_pressed("ui_left"):
		_adjust_expedition_pack_amount(key, -1)
		_exp_lr_left_hold = 0.0
		_exp_lr_left_acc = 0.0
	elif Input.is_action_pressed("ui_left"):
		_exp_lr_left_hold += delta
		var interval_l: float = lerpf(
			EXP_PACK_REPEAT_INTERVAL_SLOW,
			EXP_PACK_REPEAT_INTERVAL_FAST,
			clampf(_exp_lr_left_hold / EXP_PACK_REPEAT_RAMP_SEC, 0.0, 1.0)
		)
		_exp_lr_left_acc += delta
		while _exp_lr_left_acc >= interval_l:
			_exp_lr_left_acc -= interval_l
			_adjust_expedition_pack_amount(key, -1)
	else:
		_exp_lr_left_hold = 0.0
		_exp_lr_left_acc = 0.0
	if Input.is_action_just_pressed("ui_right"):
		_adjust_expedition_pack_amount(key, 1)
		_exp_lr_right_hold = 0.0
		_exp_lr_right_acc = 0.0
	elif Input.is_action_pressed("ui_right"):
		_exp_lr_right_hold += delta
		var interval_r: float = lerpf(
			EXP_PACK_REPEAT_INTERVAL_SLOW,
			EXP_PACK_REPEAT_INTERVAL_FAST,
			clampf(_exp_lr_right_hold / EXP_PACK_REPEAT_RAMP_SEC, 0.0, 1.0)
		)
		_exp_lr_right_acc += delta
		while _exp_lr_right_acc >= interval_r:
			_exp_lr_right_acc -= interval_r
			_adjust_expedition_pack_amount(key, 1)
	else:
		_exp_lr_right_hold = 0.0
		_exp_lr_right_acc = 0.0

func _adjust_expedition_pack_amount(which: String, delta: int) -> void:
	match which:
		"food":
			_exp_amt_food = clampi(_exp_amt_food + delta, 0, _exp_max_food)
		"water":
			_exp_amt_water = clampi(_exp_amt_water + delta, 0, _exp_max_water)
		"medicine":
			_exp_amt_medicine = clampi(_exp_amt_medicine + delta, 0, _exp_max_medicine)
		"world_gold":
			_exp_amt_gold = clampi(_exp_amt_gold + delta, 0, _exp_max_gold)
		_:
			return
	_refresh_expedition_pack_limits_and_labels(false)

func _setup_expedition_pack_modal() -> void:
	if _expedition_pack_modal != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ExpeditionPackModal"
	layer.layer = 120
	layer.visible = false
	layer.visibility_changed.connect(_on_expedition_pack_modal_visibility_changed)
	var backdrop := ColorRect.new()
	backdrop.name = "ExpPackBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.58)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.focus_mode = Control.FOCUS_NONE
	layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.name = "ExpPackCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ExpPackPanel"
	panel.custom_minimum_size = Vector2(520, 340)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_NONE
	if MEDIEVAL_THEME:
		panel.theme = MEDIEVAL_THEME
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var title := Label.new()
	title.text = "Köyden erzak"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.focus_mode = Control.FOCUS_NONE
	v.add_child(title)
	var hint := Label.new()
	hint.text = "Yukari/Asagi: satir | Sol/Sag: miktar (basili tut: hizlanir) | Enter: Yanima al | Esc: Kapat\nFare ile kapatma yok. Yolda olaylar bu cantayi etkiler; kasa altini ayri."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.focus_mode = Control.FOCUS_NONE
	v.add_child(hint)
	_exp_row_hboxes.clear()
	for i in range(_EXP_PACK_TITLES.size()):
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		var tlab := Label.new()
		tlab.text = _EXP_PACK_TITLES[i]
		tlab.custom_minimum_size.x = 200
		tlab.focus_mode = Control.FOCUS_NONE
		hb.add_child(tlab)
		var vlab := Label.new()
		vlab.text = "0 / 0"
		vlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vlab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vlab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vlab.focus_mode = Control.FOCUS_NONE
		hb.add_child(vlab)
		v.add_child(hb)
		_exp_row_hboxes.append(hb)
	add_child(layer)
	_expedition_pack_modal = layer

func _on_expedition_pack_modal_visibility_changed() -> void:
	if _expedition_pack_modal and _expedition_pack_modal.visible:
		_exp_pack_row = clampi(_exp_pack_row, 0, maxi(0, _exp_row_hboxes.size() - 1))
		_highlight_exp_pack_rows()

func _on_expedition_pack_confirm_pressed() -> void:
	var vm: Node = get_node_or_null("/root/VillageManager")
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if vm == null or ps == null:
		return
	var bf: int = _exp_amt_food
	var bw: int = _exp_amt_water
	var bm: int = _exp_amt_medicine
	var bg: int = _exp_amt_gold
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if bg > 0:
		if gpd == null or int(gpd.gold) < bg:
			_update_status_label("Kasada yeterli altin yok.")
			return
	var cost_v: Dictionary = {}
	if bf > 0:
		cost_v["food"] = bf
	if bw > 0:
		cost_v["water"] = bw
	if bm > 0:
		cost_v["medicine"] = bm
	if not cost_v.is_empty():
		if not vm.has_method("can_afford_resources") or not bool(vm.call("can_afford_resources", cost_v)):
			_update_status_label("Koy stogu yetersiz.")
			return
		if not vm.has_method("spend_resources") or not bool(vm.call("spend_resources", cost_v)):
			_update_status_label("Erzak alinamadi.")
			return
	if bg > 0 and gpd:
		if gpd.has_method("add_gold"):
			gpd.add_gold(-bg)
		elif "gold" in gpd:
			gpd.gold = int(gpd.gold) - bg
	if ps.has_method("add_world_expedition_supplies"):
		var add_d: Dictionary = {}
		if bf > 0:
			add_d["food"] = bf
		if bw > 0:
			add_d["water"] = bw
		if bm > 0:
			add_d["medicine"] = bm
		if bg > 0:
			add_d["world_gold"] = bg
		if not add_d.is_empty():
			ps.call("add_world_expedition_supplies", add_d)
	if _expedition_pack_modal:
		_expedition_pack_modal.hide()
	_update_status_label("Erzak cantana eklendi.")
	queue_redraw()

func _on_settlement_aid_confirmed() -> void:
	_perform_pending_intervention_now()

func _on_settlement_aid_canceled() -> void:
	match _pending_aid_kind:
		"war_support":
			_update_status_label("Savas destegi iptal edildi.")
		"mediation":
			_update_status_label("Aracilik iptal edildi.")
		"offensive_raid":
			_update_status_label("Ofansif baskin iptal edildi.")
			if _settlement_aid_confirm_dialog:
				_settlement_aid_confirm_dialog.get_ok_button().text = "Yardim Gonder"
		_:
			_update_status_label("Yardim gonderme iptal edildi.")
	_pending_aid_kind = ""

func _perform_pending_intervention_now() -> void:
	match _pending_aid_kind:
		"war_support":
			_perform_war_support_now()
		"mediation":
			_perform_mediation_now()
		"alliance_propose":
			_perform_alliance_propose_now()
		"alliance_break":
			_perform_alliance_break_now()
		"offensive_raid":
			_perform_offensive_raid_now()
		_:
			_perform_settlement_aid_now()
	_pending_aid_kind = ""

func _perform_alliance_propose_now() -> void:
	if _world_manager == null or not _world_manager.has_method("propose_alliance"):
		_update_status_label("Ittifak sistemi su an mevcut degil.")
		return
	if _pending_alliance_propose_option.is_empty():
		_update_status_label("Ittifak teklifi hedefi belirlenemedi.")
		return
	var sid: String = String(_pending_alliance_propose_option.get("settlement_id", ""))
	if sid.is_empty():
		_update_status_label("Ittifak teklifi hedefi belirlenemedi.")
		return
	var result: Dictionary = _world_manager.call("propose_alliance", sid)
	_handle_intervention_result(result, "Ittifak teklifi uygulanamadi.")

func _perform_alliance_break_now() -> void:
	if _world_manager == null or not _world_manager.has_method("break_alliance"):
		_update_status_label("Ittifak sistemi su an mevcut degil.")
		return
	if _pending_alliance_break_option.is_empty():
		_update_status_label("Bozulacak ittifak bulunamadi.")
		return
	var sid: String = String(_pending_alliance_break_option.get("settlement_id", ""))
	if sid.is_empty():
		_update_status_label("Bozulacak ittifak bulunamadi.")
		return
	var result: Dictionary = _world_manager.call("break_alliance", sid)
	_handle_intervention_result(result, "Ittifak bozulamadi.")

func _perform_war_support_now() -> void:
	if _world_manager == null or not _world_manager.has_method("apply_war_support"):
		_update_status_label("Savas destegi sistemi su an mevcut degil.")
		return
	if _pending_war_support_option.is_empty():
		_update_status_label("Destek verilebilecek aktif savas yok.")
		return
	var supported_id: String = String(_pending_war_support_option.get("supported_id", ""))
	var opponent_id: String = String(_pending_war_support_option.get("opponent_id", ""))
	if supported_id.is_empty() or opponent_id.is_empty():
		_update_status_label("Savas destegi hedefi belirlenemedi.")
		return
	var result: Dictionary = _world_manager.call("apply_war_support", supported_id, opponent_id)
	_handle_intervention_result(result, "Savas destegi uygulanamadi.")

func _perform_mediation_now() -> void:
	if _world_manager == null or not _world_manager.has_method("apply_mediation"):
		_update_status_label("Aracilik sistemi su an mevcut degil.")
		return
	if _pending_mediation_option.is_empty():
		_update_status_label("Aracilik yapilabilecek bir gerilim yok.")
		return
	var a: String = String(_pending_mediation_option.get("between_a", ""))
	var b: String = String(_pending_mediation_option.get("between_b", ""))
	if a.is_empty() or b.is_empty():
		_update_status_label("Aracilik hedefi belirlenemedi.")
		return
	var result: Dictionary = _world_manager.call("apply_mediation", a, b)
	_handle_intervention_result(result, "Aracilik uygulanamadi.")

func _handle_intervention_result(result: Dictionary, fallback_msg: String) -> void:
	if not bool(result.get("ok", false)):
		var reason: String = String(result.get("reason", ""))
		match reason:
			"cannot_afford":
				_update_status_label("Mudahale icin yeterli kaynagin yok.")
			"not_at_war":
				_update_status_label("Bu koy su an aktif bir savasta degil.")
			"no_conflict":
				_update_status_label("Aracilik icin uygun bir gerilim/savas yok.")
			"already_allied":
				_update_status_label("Bu koy zaten muttefik.")
			"not_allied":
				_update_status_label("Bu koyle ittifak yok.")
			"relation_too_low":
				_update_status_label("Iliski cok dusuk, ittifak teklifi reddedildi.")
			"invalid_settlement":
				_update_status_label("Hedef koy gecersiz.")
			_:
				_update_status_label(fallback_msg)
		return
	var summary: String = String(result.get("summary", fallback_msg))
	_update_status_label(summary)
	queue_redraw()

func _build_aid_confirm_text(settlement_name: String, option: Dictionary) -> String:
	var label: String = String(option.get("label", "Yardim"))
	var summary: String = String(option.get("summary", ""))
	var cost: Dictionary = option.get("cost", {})
	var cost_parts: PackedStringArray = PackedStringArray()
	if int(cost.get("gold", 0)) > 0:
		cost_parts.append("%d altin" % int(cost.get("gold", 0)))
	for resource_type in ["food", "wood", "stone", "water"]:
		var amount: int = int(cost.get(resource_type, 0))
		if amount > 0:
			cost_parts.append("%d %s" % [amount, resource_type])
	var cost_text: String = "(maliyet yok)" if cost_parts.is_empty() else "Maliyet: " + ", ".join(cost_parts)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s icin %s" % [settlement_name, label])
	lines.append(cost_text)
	if not summary.is_empty():
		lines.append("Etki: " + summary)
	lines.append("Bu islem geri alinamaz.")
	return "\n".join(lines)

func _execute_settlement_trade() -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	var day: int = _get_current_day()
	if mm.has_method("create_world_map_action_mission"):
		mm.call("create_world_map_action_mission", "trade", _pending_settlement_id, _pending_settlement_name, day, _pending_settlement_distance)
	_update_status_label("%s icin ticaret gorevi olusturuldu." % _pending_settlement_name)

func _execute_settlement_diplomacy() -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	var day: int = _get_current_day()
	if mm.has_method("create_world_map_action_mission"):
		mm.call("create_world_map_action_mission", "diplomacy", _pending_settlement_id, _pending_settlement_name, day, _pending_settlement_distance)
	_update_status_label("%s icin diplomasi gorevi olusturuldu." % _pending_settlement_name)

func _execute_settlement_raid() -> void:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if not mm:
		return
	var tm: Node = get_node_or_null("/root/TimeManager")
	var day: int = _get_current_day()
	if mm.has_method("create_world_map_action_mission"):
		mm.call("create_world_map_action_mission", "raid", _pending_settlement_id, _pending_settlement_name, day, _pending_settlement_distance)
	_update_status_label("%s icin baskin gorevi olusturuldu." % _pending_settlement_name)

func _format_minutes_short(total_minutes: int) -> String:
	var hours: int = total_minutes / 60
	var mins: int = total_minutes % 60
	return "%dsa %02ddk" % [hours, mins]

func _get_settlement_action_preview(action_type: String) -> Dictionary:
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("get_world_map_action_preview"):
		return mm.call("get_world_map_action_preview", action_type, _pending_settlement_name, _pending_settlement_distance)
	return {"duration_minutes": 120, "risk_level": "Orta"}

func _get_current_day() -> int:
	var tm: Node = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("get_day"):
		return int(tm.call("get_day"))
	return 1

func _format_resource_name_tr(type_id: String) -> String:
	match type_id:
		"wood":
			return "Odun"
		"stone":
			return "Tas"
		"water":
			return "Su"
		"food":
			return "Erzak"
		_:
			return type_id

func _format_travel_outcome_for_player(resolution: Dictionary, include_choice_line: bool = true) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if include_choice_line:
		var choice: String = String(resolution.get("choice", ""))
		match choice:
			"dice":
				var d1: int = int(resolution.get("dice_d1", 0))
				var d2: int = int(resolution.get("dice_d2", 0))
				var ds: int = int(resolution.get("dice_sum", 0))
				if d1 > 0 and d2 > 0:
					lines.append("Zar: [%d] + [%d] = %d" % [d1, d2, ds])
			"continue":
				lines.append("Karar: Devam ettin.")
			"cancel":
				lines.append("Karar: Geri donme.")
			"drop":
				lines.append("Karar: Yuk biraktin.")
			_:
				pass
	var extra_minutes: int = int(resolution.get("extra_minutes", 0))
	if extra_minutes > 0:
		lines.append("Sure: +%d dk (oyun zamani ilerledi)." % extra_minutes)
	var card_text: String = String(resolution.get("card_text", ""))
	if not card_text.is_empty():
		lines.append("Olay: %s" % card_text)
	var gold_delta: int = int(resolution.get("gold_delta", 0))
	if gold_delta != 0:
		if gold_delta > 0:
			lines.append("Sefer altini (canta): +%d." % gold_delta)
		else:
			lines.append("Sefer altini (canta): %d." % gold_delta)
	var world_gold_lost: int = int(resolution.get("world_gold_lost", 0))
	if world_gold_lost > 0:
		lines.append("Sefer altini kaybi: -%d." % world_gold_lost)
	var ex_f: int = int(resolution.get("expedition_food_gained", 0))
	var ex_w: int = int(resolution.get("expedition_water_gained", 0))
	var ex_m: int = int(resolution.get("expedition_medicine_gained", 0))
	if ex_f > 0 or ex_w > 0 or ex_m > 0:
		var ex_parts: PackedStringArray = PackedStringArray()
		if ex_f > 0:
			ex_parts.append("yiyecek +%d" % ex_f)
		if ex_w > 0:
			ex_parts.append("su +%d" % ex_w)
		if ex_m > 0:
			ex_parts.append("ilac +%d" % ex_m)
		lines.append("Yol cantasi (yolda): " + ", ".join(ex_parts))
	var dungeon_gold_lost: int = int(resolution.get("dungeon_gold_lost", 0))
	if dungeon_gold_lost > 0:
		lines.append("Tasidigin zindan altini: -%d." % dungeon_gold_lost)
	var health_lost: float = float(resolution.get("health_lost", 0.0))
	if health_lost > 0.0:
		lines.append("Can kaybi: ~%.0f." % health_lost)
	var carried_losses: Variant = resolution.get("carried_losses", {})
	if carried_losses is Dictionary and not carried_losses.is_empty():
		var resource_parts: PackedStringArray = PackedStringArray()
		for res_type in carried_losses.keys():
			var amount: int = int(carried_losses[res_type])
			if amount > 0:
				resource_parts.append("%s -%d" % [_format_resource_name_tr(String(res_type)), amount])
		if not resource_parts.is_empty():
			lines.append("Tasinan kaynak: " + ", ".join(resource_parts))
	var rescued_losses: Variant = resolution.get("rescued_losses", {})
	if rescued_losses is Dictionary:
		var v_loss: int = int(rescued_losses.get("villagers", 0))
		var c_loss: int = int(rescued_losses.get("cariyes", 0))
		if v_loss > 0 or c_loss > 0:
			lines.append("Kurtarilanlar: %d koylu; %d cariye geride kaldi." % [v_loss, c_loss])
	if lines.is_empty():
		return "Net kayip gorunmuyor (veya risk sifirdi)."
	if include_choice_line and lines.size() == 1:
		return lines[0] + "\nSayilabilir kayip yok."
	return "\n".join(lines)

func _format_travel_event_resolution_text(resolution: Dictionary) -> String:
	return _format_travel_outcome_for_player(resolution, true)

func _hex_distance(aq: int, ar: int, bq: int, br: int) -> int:
	var asv: int = -aq - ar
	var bsv: int = -bq - br
	return int((abs(aq - bq) + abs(ar - br) + abs(asv - bsv)) / 2)

func _tile_draw_position(center: Vector2) -> Vector2:
	# Place center at the middle of the 32px top surface (not at dead-bottom boundary).
	var local_center_y: float = TILE_HEADROOM + TILE_TOP_SURFACE * 0.5
	return center - Vector2(TILE_WIDTH * 0.5, local_center_y)

func _draw_tile_debug_overlay(center: Vector2, draw_pos: Vector2, q: int, r: int) -> void:
	var full_rect := Rect2(draw_pos, Vector2(TILE_WIDTH, TILE_HEIGHT))
	var top_rect := Rect2(
		draw_pos + Vector2(0.0, TILE_HEADROOM),
		Vector2(TILE_WIDTH, TILE_TOP_SURFACE)
	)
	var dead_rect := Rect2(
		draw_pos + Vector2(0.0, TILE_HEIGHT - TILE_DEAD_BOTTOM),
		Vector2(TILE_WIDTH, TILE_DEAD_BOTTOM)
	)
	draw_rect(full_rect, Color(1.0, 1.0, 1.0, 0.06), true)
	draw_rect(full_rect, Color(1.0, 1.0, 1.0, 0.45), false, 1.0)
	draw_rect(top_rect, Color(0.2, 1.0, 0.2, 0.12), true)
	draw_rect(top_rect, Color(0.2, 1.0, 0.2, 0.7), false, 1.0)
	draw_rect(dead_rect, Color(1.0, 0.2, 0.2, 0.12), true)
	draw_rect(dead_rect, Color(1.0, 0.2, 0.2, 0.7), false, 1.0)
	draw_circle(center, 2.2, Color(1.0, 1.0, 0.2, 0.95))
	var font: Font = _get_world_map_font()
	draw_string(
		font,
		draw_pos + Vector2(2.0, 12.0),
		"%d,%d" % [q, r],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		10,
		Color(1, 1, 1, 0.9)
	)

func _get_world_map_font() -> Font:
	if _world_map_font_cached != null:
		return _world_map_font_cached
	if _status_label:
		var label_font: Font = _status_label.get_theme_default_font()
		if label_font:
			_world_map_font_cached = label_font
			return label_font
	_world_map_font_cached = ThemeDB.fallback_font
	return _world_map_font_cached
