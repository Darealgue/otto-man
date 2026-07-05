extends Node2D
class_name ForestLevelGenerator

signal level_started
signal level_completed

@export var current_level: int = 1
@export var unit_size: int = 2048
@export var spawn_ahead_count: int = 6
@export var despawn_distance: float = 8192.0
@export var prob_continue: float = 0.84
@export var prob_up: float = 0.08
@export var prob_down: float = 0.08
@export var min_row: int = -2
@export var max_row: int = 2
@export var window_left_count: int = 3
@export var window_right_count: int = 3
@export var prob_wide_ramp: float = 0.5
@export var debug_enabled: bool = false
@export var debug_rate_ms: int = 250
@export var forest_enemy_spawn_chance: float = 1.0
@export var forest_enemy_min_distance: float = 170.0
## How many "chunk widths" away from the forest start (either direction) before enemy level increases by 1.
@export var forest_chunks_per_enemy_level: int = 3
## Approximate horizontal size of one forest segment for distance→level (linear 2x1 uses 2 * unit_size).
@export var forest_enemy_chunk_width_px: float = 0.0
@export var forest_enemy_max_level: int = 12
## Gatherable resources (wood/stone/water/food): expect one spawn every N chunks on average.
@export var forest_resource_spawn_min_chunks: int = 2
@export var forest_resource_spawn_max_chunks: int = 3
@export var chunk_postprocess_per_frame: int = 1
@export var chunk_postprocess_min_distance_px: float = 1024.0
@export var ramp_cooldown_segments: int = 2
@export_enum("forest", "mountain", "river") var biome_type: String = "forest"

@onready var _forest_exit_portal_scene: PackedScene = load("res://chunks/forest/ForestExitPortal.tscn")
@onready var _tree_interactable_scene: PackedScene = load("res://interactables/forest/TreeInteractable.tscn")
@onready var _rock_interactable_scene: PackedScene = load("res://interactables/forest/RockInteractable.tscn")
@onready var _well_interactable_scene: PackedScene = load("res://interactables/forest/WellInteractable.tscn")
@onready var _bush_interactable_scene: PackedScene = load("res://interactables/forest/BushInteractable.tscn")

# Resource spawning
var _resource_spawn_timer: int = 0
var _resource_scenes: Array[PackedScene] = []

var _forest_exit_portal: Node2D = null
var _forest_start_chunk: Node2D = null

var player: Node2D
var active_chunks: Array[Node2D] = []
var current_row: int = 0
var last_end_x: float = 0.0

# Overview camera (zoom-out) like dungeon
var overview_camera: Camera2D
var is_overview_active: bool = false

# Archive for backtracking support
var chunk_entries: Array[Dictionary] = [] # { "key": String, "position": Vector2, "size": Vector2 }
var index_to_node: Dictionary = {} # entry_index -> Node2D (only for currently active ones)
var first_active_index: int = 0
var last_active_index: int = -1
var min_discovered_index: int = 0
var max_discovered_index: int = -1
var _last_dbg_ms: int = 0
var _last_dbg_text: String = ""
var _forest_tree_reserved_px: Array[Vector2] = [] # global x-range reservations for trees across chunks
var _decor_spawn_queue: Array = [] # queued decoration spawn jobs to spread over frames
var _chunk_postprocess_queue: Array[Dictionary] = [] # { "node": Node2D, "phase": int }
var _decor_spawner: DecorationSpawner
var _spawn_config: SpawnConfig
var _ramp_cooldown_next: int = 0
var _ramp_cooldown_prev: int = 0
var _river_ripple_effect: Node = null
var _river_water_sprite: Sprite2D = null
var _prev_player_x_for_river: float = NAN
var _tutorial_interactables: Array[Node] = []
var _tutorial_chunks_seeded: Dictionary = {}
const TUTORIAL_TARGET_WOOD: int = 3
const TUTORIAL_TARGET_FOOD: int = 3

const DEBUG_FOREST_ENEMIES: bool = false
## Ağaç zemini sapmasını görmek için; konsolu şişirir — iş bitince false yap.
const DEBUG_FOREST_TREE_SPAWN: bool = false
const FOREST_DECOR_GLOBAL_Y_OFFSET: float = -10.0
const FOREST_FLOWER_SPAWN_CHANCE: float = 0.22
const FOREST_BUTTERFLY_SCENE: PackedScene = preload("res://decoration/forest/forest_butterfly.tscn")
const FOREST_BUTTERFLIES_PER_CHUNK_MIN: int = 2
const FOREST_BUTTERFLIES_PER_CHUNK_MAX: int = 5
const FOREST_BUTTERFLY_MIN_CLEARANCE: float = 95.0
const FOREST_BUTTERFLY_MAX_CLEARANCE: float = 320.0
const FOREST_FIREFLY_SCENE: PackedScene = preload("res://decoration/forest/forest_firefly.tscn")
const FOREST_CAMP_NIGHT_ADAPTER_SCRIPT: Script = preload("res://decoration/forest/forest_camp_night_adapter.gd")
const FOREST_MUSHROOM_SPAWN_CHANCE: float = 0.045
const FOREST_MUSHROOMS_PER_CHUNK_MAX: int = 3
const FOREST_CAMP_SPAWN_CHANCE: float = 0.72
const FOREST_FIREFLY_PER_CHUNK_MIN: int = 3
const FOREST_FIREFLY_PER_CHUNK_MAX: int = 6
const FOREST_FIREFLY_MIN_CLEARANCE: float = 55.0
const FOREST_FIREFLY_MAX_CLEARANCE: float = 180.0
const FOREST_ENEMY_LAYER_NAME := "decor_anchor"
var _forest_tree_debug_seq: int = 0
const DEBUG_UNDERGROUND_FOREST_DECOR: bool = true
var _underground_scan_accum_s: float = 0.0
var _reported_buried_decor_ids: Dictionary = {}

var scenes := {
	# Each key holds an array of variants
	"start": [preload("res://chunks/forest/start_2x1.tscn")],
	"linear": [
		preload("res://chunks/forest/linear_2x1.tscn"),
		preload("res://chunks/forest/linear_2x1-2.tscn"),
		preload("res://chunks/forest/linear_2x1-3.tscn"),
		preload("res://chunks/forest/linear_2x1-4.tscn")
	],
	"ramp_up": [
		preload("res://chunks/forest/ramp_up_1x2.tscn"),
		preload("res://chunks/forest/ramp_up_1x2-2.tscn"),
		preload("res://chunks/forest/ramp_up_1x2-3.tscn"),
		preload("res://chunks/forest/ramp_up_1x2-4.tscn")
	],
	"ramp_down": [
		preload("res://chunks/forest/ramp_down_1x2.tscn"),
		preload("res://chunks/forest/ramp_down_1x2-2.tscn"),
		preload("res://chunks/forest/ramp_down_1x2-3.tscn"),
		preload("res://chunks/forest/ramp_down_1x2-4.tscn")
	],
	"ramp_up_wide": [
		preload("res://chunks/forest/ramp_up_2x2.tscn"),
		preload("res://chunks/forest/ramp_up_2x2-2.tscn"),
		preload("res://chunks/forest/ramp_up_2x2-3.tscn"),
		preload("res://chunks/forest/ramp_up_2x2-4.tscn")
	],
	"ramp_down_wide": [
		preload("res://chunks/forest/ramp_down_2x2.tscn"),
		preload("res://chunks/forest/ramp_down_2x2-2.tscn"),
		preload("res://chunks/forest/ramp_down_2x2-3.tscn"),
		preload("res://chunks/forest/ramp_down_2x2-4.tscn")
	]
}

func _ready() -> void:
	add_to_group("level_generator")
	player = get_tree().get_first_node_in_group("player")
	_spawn_config = SpawnConfig.new()
	_apply_biome_settings_from_payload()
	
	# Initialize resource scenes
	_resource_scenes = _build_resource_scene_pool_for_biome()
	_resource_spawn_timer = randi_range(
		mini(forest_resource_spawn_min_chunks, forest_resource_spawn_max_chunks),
		maxi(forest_resource_spawn_min_chunks, forest_resource_spawn_max_chunks)
	)
	
	_spawn_initial_path()
	_setup_overview_camera()
	_setup_day_night_system()
	_setup_biome_visual_overlays()
	# Persistent spawner to avoid creating one per decoration
	_decor_spawner = DecorationSpawner.new()
	add_child(_decor_spawner)
	_spawn_or_move_player_to_start()
	level_started.emit()

func _apply_biome_settings_from_payload() -> void:
	var scene_manager: Node = get_node_or_null("/root/SceneManager")
	if scene_manager != null and scene_manager.has_method("get_current_payload"):
		var payload: Dictionary = scene_manager.call("get_current_payload")
		var incoming: String = String(payload.get("biome_type", "")).to_lower()
		if incoming == "forest" or incoming == "mountain" or incoming == "river":
			biome_type = incoming
	var tm := get_node_or_null("/root/TutorialManager")
	var is_tutorial_forest: bool = tm != null and tm.is_village_tutorial_active() and tm.village_core_step == 1
	match biome_type:
		"forest":
			prob_continue = 1.0
			prob_up = 0.0
			prob_down = 0.0
			min_row = 0
			max_row = 0
			forest_enemy_spawn_chance = 0.0 if is_tutorial_forest else 1.0
		"mountain":
			# Foothills start at row 0; path only climbs upward into the mountain.
			prob_continue = 0.0
			prob_up = 1.0
			prob_down = 0.0
			min_row = -3
			max_row = 0
			forest_enemy_spawn_chance = 0.85
		"river":
			prob_continue = 1.0
			prob_up = 0.0
			prob_down = 0.0
			min_row = 0
			max_row = 0
			forest_enemy_spawn_chance = 0.0
		_:
			biome_type = "forest"

func _build_resource_scene_pool_for_biome() -> Array[PackedScene]:
	match biome_type:
		"forest":
			return [_tree_interactable_scene, _bush_interactable_scene]
		"mountain":
			return [_tree_interactable_scene, _rock_interactable_scene]
		"river":
			return [_tree_interactable_scene, _bush_interactable_scene]
		_:
			return [_tree_interactable_scene, _bush_interactable_scene]

func _setup_biome_visual_overlays() -> void:
	if biome_type != "river":
		return
	var water_tex: Texture2D = load("res://assets/Sprite-0001.png") as Texture2D
	if water_tex != null:
		_river_water_sprite = Sprite2D.new()
		_river_water_sprite.name = "RiverWater"
		_river_water_sprite.z_index = 20
		_river_water_sprite.texture = water_tex
		_river_water_sprite.position = Vector2(0.0, 1260.0)
		# Koy sahnesindeki suyla ayni doku hissi: genis ve nispeten ince bant.
		_river_water_sprite.scale = Vector2(67.3438, 1.45469)
		var water_mat: ShaderMaterial = _build_river_water_reflection_material()
		if water_mat != null:
			_river_water_sprite.material = water_mat
		add_child(_river_water_sprite)
	var ripple_script := load("res://village/scripts/WaterRippleEffect.gd") as Script
	if ripple_script == null:
		return
	_river_ripple_effect = Node2D.new()
	_river_ripple_effect.name = "RiverRippleEffect"
	_river_ripple_effect.set_script(ripple_script)
	_river_ripple_effect.set("allow_outside_village", true)
	_river_ripple_effect.set("lock_splashes_to_world", true)
	_river_ripple_effect.set("surface_motion_strength", 0.0)
	_river_ripple_effect.set("water_sprite_path", NodePath(""))
	_river_ripple_effect.set("water_area", Rect2(-20000.0, 1140.0, 40000.0, 260.0))
	add_child(_river_ripple_effect)

## Akarsu su bandi ve ripple dünya X=0'a sabitlenmişti; oyuncu ilerleyince tek chunk'ta kalıyordu.
func _sync_river_water_overlay_to_player(delta: float) -> void:
	if biome_type != "river":
		return
	if player == null or not is_instance_valid(player):
		return
	var px: float = player.global_position.x
	var player_vx: float = 0.0
	if not is_nan(_prev_player_x_for_river) and delta > 0.00001:
		player_vx = (px - _prev_player_x_for_river) / delta
	_prev_player_x_for_river = px
	if _river_water_sprite != null and is_instance_valid(_river_water_sprite):
		var gy: float = _river_water_sprite.global_position.y
		_river_water_sprite.global_position = Vector2(px, gy)
	if _river_ripple_effect != null and is_instance_valid(_river_ripple_effect):
		var ripple_nd := _river_ripple_effect as Node2D
		if ripple_nd != null:
			var ry: float = ripple_nd.global_position.y
			ripple_nd.global_position = Vector2(px, ry)
			# Kamera/oyuncu hareketine ters his: saga kosarken damlalar sola akar gibi.
			ripple_nd.set("surface_motion_velocity", Vector2(-player_vx, 0.0))

func _build_river_water_reflection_material() -> ShaderMaterial:
	var shader_res: Shader = load("res://village/scenes/water_reflection.gdshader") as Shader
	if shader_res == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader_res
	# VillageScene.tscn ile birebir ton.
	mat.set_shader_parameter("water_color", Color(5.05373e-07, 0.148499, 0.213102, 1.0))
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.1154
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 8
	noise.fractal_gain = 0.2
	noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.seamless_blend_skirt = 1.0
	noise_tex.bump_strength = 32.0
	noise_tex.noise = noise
	mat.set_shader_parameter("wave_noise", noise_tex)
	return mat

func _physics_process(_delta: float) -> void:
	if not player:
		return
	_sync_river_water_overlay_to_player(_delta)
	if DEBUG_UNDERGROUND_FOREST_DECOR:
		_underground_scan_accum_s += _delta
		if _underground_scan_accum_s >= 0.5:
			_underground_scan_accum_s = 0.0
			_scan_nearby_for_buried_forest_decor()
	_sweep_invalid_active_chunks()
	_sort_active_by_x()
	_enforce_player_window()
	if is_overview_active:
		_update_overview_camera_fit()
	# Process a small budget of decoration spawns per frame to avoid hitches
	_process_decor_spawn_queue()
	_process_chunk_postprocess_queue()

func _process(_delta: float) -> void:
	# Also run in _process for non-physics frames
	_process_decor_spawn_queue()
	_process_chunk_postprocess_queue()

func _unhandled_input(event: InputEvent) -> void:
	if not DEBUG_UNDERGROUND_FOREST_DECOR:
		return
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.pressed and not key_ev.echo and key_ev.ctrl_pressed and key_ev.shift_pressed and key_ev.keycode == KEY_U:
			_debug_dump_nearby_forest_decor_metrics()

func _process_decor_spawn_queue() -> void:
	var budget := 8
	while budget > 0 and _decor_spawn_queue.size() > 0:
		var job: Dictionary = _decor_spawn_queue.pop_front()
		var name: String = String(job.get("name", ""))
		var pos: Vector2 = job.get("pos", Vector2.ZERO)
		var parent_node = job.get("parent", null)
		
		if name.is_empty():
			budget -= 1
			continue
			
		# If parent is specified but invalid (freed), skip spawning
		if parent_node != null and not is_instance_valid(parent_node):
			continue
			
		if not _spawn_forest_decor_from_job(job):
			budget -= 1
			continue
		budget -= 1


func _spawn_forest_decor_from_job(job: Dictionary) -> bool:
	var name: String = String(job.get("name", ""))
	var pos: Vector2 = job.get("pos", Vector2.ZERO)
	var parent_node = job.get("parent", null)
	if name.is_empty():
		return false
	if parent_node != null and not is_instance_valid(parent_node):
		return false
	var node := _decor_spawner.create_decoration_instance(name, DecorationConfig.DecorationType.BACKGROUND)
	if node == null:
		return false
	if parent_node != null and is_instance_valid(parent_node):
		parent_node.add_child(node)
	else:
		add_child(node)
	node.global_position = pos
	_apply_spawned_forest_decor(node, name, job)
	return true


func _apply_spawned_forest_decor(node: Node2D, name: String, job: Dictionary) -> void:
	var effective_job: Dictionary = job
	if name.begins_with("forest_") or name in ["camp1", "camp2"]:
		node.global_position.y += FOREST_DECOR_GLOBAL_Y_OFFSET
		effective_job = job.duplicate(true)
		var exp_y := float(effective_job.get("expected_floor_y", node.global_position.y))
		effective_job["expected_floor_y"] = exp_y + FOREST_DECOR_GLOBAL_Y_OFFSET
	if name == "forest_tree" or name == "forest_trunk":
		_forest_tree_measure_and_fix(node, effective_job, "immediate")
		_forest_tree_spawn_followup(node, effective_job.duplicate(true))
	if name.begins_with("forest_"):
		_report_underground_forest_decor_if_any(node, effective_job)
	var is_forest_light_decor := (
		DecorationConfig.is_forest_lighting_decor(name)
		or name == "forest_glow_mushroom"
	)
	if name in ["camp1", "camp2", "forest_glow_mushroom"]:
		node.set_meta("skip_post_place_fixup", true)
	if is_forest_light_decor and FOREST_CAMP_NIGHT_ADAPTER_SCRIPT and name in ["camp1", "camp2"]:
		var camp_adapter := Node.new()
		camp_adapter.name = "ForestCampNightAdapter"
		camp_adapter.set_script(FOREST_CAMP_NIGHT_ADAPTER_SCRIPT)
		node.add_child(camp_adapter)
	if node is CanvasItem:
		(node as CanvasItem).z_as_relative = false if is_forest_light_decor else false
		(node as CanvasItem).z_index = 2 if is_forest_light_decor else -5
	var spr: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
	if spr and not is_forest_light_decor:
		spr.z_as_relative = true
		spr.z_index = 0
	var anim: AnimatedSprite2D = node.get_node_or_null("Anim") as AnimatedSprite2D
	if anim and not is_forest_light_decor:
		anim.z_as_relative = true
		anim.z_index = 0

func _queue_chunk_postprocess(chunk_node: Node2D) -> void:
	if chunk_node == null or not is_instance_valid(chunk_node):
		return
	for entry in _chunk_postprocess_queue:
		if not (entry is Dictionary):
			continue
		var existing = entry.get("node", null)
		if existing != null and existing == chunk_node:
			return
	_chunk_postprocess_queue.append({ "node": chunk_node, "phase": 0 })

func _chunk_distance_to_player_x(chunk_node: Node2D) -> float:
	if chunk_node == null or not is_instance_valid(chunk_node):
		return INF
	if player == null or not is_instance_valid(player):
		return 0.0
	var px := player.global_position.x
	var start_x := chunk_node.global_position.x
	var end_x := start_x + _get_size(chunk_node).x
	if px >= start_x and px <= end_x:
		return 0.0
	if px < start_x:
		return start_x - px
	return px - end_x

func _process_chunk_postprocess_queue() -> void:
	var budget := maxi(1, chunk_postprocess_per_frame)
	while budget > 0 and _chunk_postprocess_queue.size() > 0:
		# Always process the nearest queued chunk first to avoid visible pop-in.
		var best_idx := 0
		var best_dist := INF
		for i in range(_chunk_postprocess_queue.size()):
			var candidate = _chunk_postprocess_queue[i]
			if not (candidate is Dictionary):
				continue
			var candidate_node = (candidate as Dictionary).get("node", null)
			if candidate_node == null or not is_instance_valid(candidate_node):
				continue
			if not (candidate_node is Node2D):
				continue
			var cn: Node2D = candidate_node
			var d := _chunk_distance_to_player_x(cn)
			if d < best_dist:
				best_dist = d
				best_idx = i
		var raw_entry = _chunk_postprocess_queue.pop_at(best_idx)
		if not (raw_entry is Dictionary):
			budget -= 1
			continue
		var entry: Dictionary = raw_entry
		var raw_node = entry.get("node", null)
		if raw_node == null or not is_instance_valid(raw_node):
			budget -= 1
			continue
		if not (raw_node is Node2D):
			budget -= 1
			continue
		var chunk_node: Node2D = raw_node
		# If chunk is still far from player, postpone heavy scans.
		if player != null and is_instance_valid(player):
			var near_enough := _chunk_distance_to_player_x(chunk_node) <= chunk_postprocess_min_distance_px
			if not near_enough:
				_chunk_postprocess_queue.append(entry)
				budget -= 1
				continue
		var phase := int(entry.get("phase", 0))
		# Split heavy processing across frames: decor first, enemies next.
		if phase <= 0:
			_populate_forest_decorations_for_chunk(chunk_node)
			_chunk_postprocess_queue.append({ "node": chunk_node, "phase": 1 })
		else:
			_populate_forest_enemies_for_chunk(chunk_node)
			_tutorial_maybe_spawn_in_chunk(chunk_node)
		budget -= 1

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		toggle_camera()
	if event.is_action_pressed("dump_level_debug"):
		_debug_dump_active_chunks("manual")
	# Mirror village time controls: 1/2/3 to set time scale, T to cycle
	if event is InputEventKey and event.pressed and not event.is_echo():
		var tm = get_node_or_null("/root/TimeManager")
		if event.keycode == KEY_1:
			if tm and tm.has_method("set_time_scale_index"):
				tm.set_time_scale_index(0)
		elif event.keycode == KEY_2:
			if tm and tm.has_method("set_time_scale_index"):
				tm.set_time_scale_index(1)
		elif event.keycode == KEY_3:
			if tm and tm.has_method("set_time_scale_index"):
				tm.set_time_scale_index(2)
		elif event.keycode == KEY_T:
			if tm and tm.has_method("cycle_time_scale"):
				tm.cycle_time_scale()

func toggle_camera() -> void:
	is_overview_active = !is_overview_active
	if is_overview_active:
		_update_overview_camera_fit()
		if overview_camera:
			overview_camera.make_current()
	elif player and player.has_node("Camera2D"):
		var cam = player.get_node("Camera2D")
		if cam and cam is Camera2D:
			(cam as Camera2D).enabled = true
			(cam as Camera2D).make_current()

func _spawn_initial_path() -> void:
	active_chunks.clear()
	current_row = 0
	last_end_x = 0.0
	chunk_entries.clear()
	index_to_node.clear()
	first_active_index = 0
	last_active_index = -1
	_forest_start_chunk = null
	var start: Node2D = _spawn_scene("start")
	start.position = Vector2(0, _row_to_y(current_row))
	start.set_meta("is_start_chunk", true)  # Mark as start chunk to prevent forest_tree spawn
	# Decoration spawn'ları aktif - ama forest_tree spawn'ı engellenecek
	active_chunks.append(start)
	# Debug dumps disabled for cleaner logs - uncomment if needed
	# _debug_dump_chunk_nodes("start_chunk_spawn", start)
	# _debug_dump_tilemap_summary(start, "start_chunk_spawn")
	var start_idx: int = _record_entry(start, "start")
	first_active_index = 0
	last_active_index = 0
	min_discovered_index = 0
	max_discovered_index = 0
	last_end_x = start.position.x + _get_size(start).x
	_forest_start_chunk = start
	_attach_forest_exit_portal(start)
	for i in range(spawn_ahead_count - 1):
		_add_next_segment()
	_add_prev_segment()
	_sort_active_by_x()
	_tutorial_force_spawn_resources()

func _attach_forest_exit_portal(start_chunk: Node2D) -> void:
	if _forest_exit_portal_scene == null:
		return
	if _forest_exit_portal and is_instance_valid(_forest_exit_portal):
		_forest_exit_portal.queue_free()
	_forest_exit_portal = _forest_exit_portal_scene.instantiate() as Node2D
	if _forest_exit_portal == null:
		return
	add_child(_forest_exit_portal)
	var base_position := start_chunk.global_position if start_chunk else Vector2.ZERO
	var offset := Vector2(float(unit_size) * 0.25, -160.0)
	_forest_exit_portal.global_position = base_position + offset


func _tutorial_force_spawn_resources() -> void:
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null or not tm.is_village_tutorial_active() or tm.village_core_step != 1:
		return
	var right_chunk: Node2D = null
	var left_chunk: Node2D = null
	for chunk in active_chunks:
		if chunk == _forest_start_chunk:
			continue
		if chunk.position.x > 0.0:
			if right_chunk == null or chunk.position.x < right_chunk.position.x:
				right_chunk = chunk
		elif chunk.position.x < 0.0:
			if left_chunk == null or chunk.position.x > left_chunk.position.x:
				left_chunk = chunk
	if right_chunk:
		_tutorial_spawn_interactables_in_chunk(right_chunk, _tree_interactable_scene, 5)
		_tutorial_chunks_seeded[right_chunk.get_instance_id()] = true
	if left_chunk:
		_tutorial_spawn_interactables_in_chunk(left_chunk, _bush_interactable_scene, 5)
		_tutorial_chunks_seeded[left_chunk.get_instance_id()] = true
	var ps := get_node_or_null("/root/PlayerStats")
	if ps and ps.has_signal("carried_resources_changed"):
		if not ps.carried_resources_changed.is_connected(_on_tutorial_resources_changed):
			ps.carried_resources_changed.connect(_on_tutorial_resources_changed)
		if ps.has_method("get_carried_resources"):
			_on_tutorial_resources_changed(ps.get_carried_resources())


func _is_tutorial_forest_run() -> bool:
	var tm := get_node_or_null("/root/TutorialManager")
	return tm != null and tm.is_village_tutorial_active() and tm.village_core_step == 1


func _tutorial_get_carried_counts() -> Vector2i:
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null or not ps.has_method("get_carried_resources"):
		return Vector2i(0, 0)
	var totals: Dictionary = ps.get_carried_resources()
	return Vector2i(int(totals.get("wood", 0)), int(totals.get("food", 0)))


func _tutorial_maybe_spawn_in_chunk(chunk: Node2D) -> void:
	if not _is_tutorial_forest_run():
		return
	if chunk == null or not is_instance_valid(chunk):
		return
	if chunk == _forest_start_chunk or chunk.get_meta("is_start_chunk", false):
		return
	var chunk_id: int = chunk.get_instance_id()
	if _tutorial_chunks_seeded.has(chunk_id):
		return
	_tutorial_chunks_seeded[chunk_id] = true
	var counts := _tutorial_get_carried_counts()
	var wood: int = counts.x
	var food: int = counts.y
	if _forest_start_chunk == null:
		return
	var start_x: float = _forest_start_chunk.position.x
	if chunk.position.x > start_x + 10.0:
		if wood < TUTORIAL_TARGET_WOOD:
			_tutorial_spawn_interactables_in_chunk(chunk, _tree_interactable_scene, 2)
	elif chunk.position.x < start_x - 10.0:
		if food < TUTORIAL_TARGET_FOOD:
			_tutorial_spawn_interactables_in_chunk(chunk, _bush_interactable_scene, 2)
	else:
		if wood < TUTORIAL_TARGET_WOOD:
			_tutorial_spawn_interactables_in_chunk(chunk, _tree_interactable_scene, 1)
		if food < TUTORIAL_TARGET_FOOD:
			_tutorial_spawn_interactables_in_chunk(chunk, _bush_interactable_scene, 1)


func _tutorial_register_interactable(node: Node) -> void:
	if node == null:
		return
	_tutorial_prune_interactables()
	_tutorial_interactables.append(node)


func _tutorial_prune_interactables() -> void:
	var kept: Array[Node] = []
	for node in _tutorial_interactables:
		if is_instance_valid(node):
			kept.append(node)
	_tutorial_interactables = kept


func _tutorial_spawn_interactables_in_chunk(chunk: Node2D, scene: PackedScene, count: int) -> void:
	if chunk == null or scene == null:
		return
	var tile_map = chunk.find_child("TileMapLayer", true, false)
	if not tile_map:
		return
	var tile_set = tile_map.get("tile_set") as TileSet
	if not tile_set:
		return
	var floor_cells: Array[Vector2i] = _forest_collect_resource_floor_cells(
		tile_map, tile_set, chunk, "decor_anchor", 40.0, 40.0
	)
	if floor_cells.is_empty():
		return
	floor_cells.shuffle()
	var tile_size: Vector2i = tile_set.tile_size
	var spawned: int = 0
	var used_positions: Array[Vector2] = []
	for cell in floor_cells:
		if spawned >= count:
			break
		var cell_local: Vector2 = tile_map.map_to_local(cell)
		var spawn_pos: Vector2 = cell_local
		spawn_pos.y -= float(tile_size.y) * 0.5
		spawn_pos.y += 5.0
		var too_close: bool = false
		for existing in used_positions:
			if spawn_pos.distance_to(existing) < 120.0:
				too_close = true
				break
		if too_close:
			continue
		var instance: Node2D = scene.instantiate() as Node2D
		if instance == null:
			continue
		instance.position = spawn_pos
		if "base_hits_required" in instance:
			instance.base_hits_required = 1
		if "difficulty_level" in instance:
			instance.difficulty_level = 1
		chunk.add_child(instance)
		_tutorial_register_interactable(instance)
		used_positions.append(spawn_pos)
		spawned += 1


func _on_tutorial_resources_changed(totals: Dictionary) -> void:
	var tm := get_node_or_null("/root/TutorialManager")
	if tm == null or not tm.is_village_tutorial_active() or tm.village_core_step != 1:
		return
	var wood: int = int(totals.get("wood", 0))
	var food: int = int(totals.get("food", 0))
	var wood_done: bool = wood >= TUTORIAL_TARGET_WOOD
	var food_done: bool = food >= TUTORIAL_TARGET_FOOD
	if wood_done and food_done:
		tm.mark_tutorial_forest_gather_complete()
		tm.set_objective(tr("tutorial.forest.complete"))
		_tutorial_disable_all_interactables()
	elif wood_done:
		tm.set_objective(tr("tutorial.forest.need_food") % [mini(wood, TUTORIAL_TARGET_WOOD), TUTORIAL_TARGET_WOOD, food, TUTORIAL_TARGET_FOOD])
		_tutorial_disable_interactables_of_type("forest_woodcut")
	elif food_done:
		tm.set_objective(tr("tutorial.forest.need_wood") % [wood, TUTORIAL_TARGET_WOOD, mini(food, TUTORIAL_TARGET_FOOD), TUTORIAL_TARGET_FOOD])
		_tutorial_disable_interactables_of_type("forest_food")
	else:
		tm.set_objective(tr("tutorial.forest.progress") % [wood, TUTORIAL_TARGET_WOOD, food, TUTORIAL_TARGET_FOOD])


func _tutorial_disable_interactables_of_type(kind: String) -> void:
	_tutorial_prune_interactables()
	for node in _tutorial_interactables:
		if not is_instance_valid(node):
			continue
		if node is BaseInteractable and String(node.minigame_kind) == kind:
			node.set_interactable_enabled(false)


func _tutorial_disable_all_interactables() -> void:
	_tutorial_prune_interactables()
	for node in _tutorial_interactables:
		if is_instance_valid(node) and node is BaseInteractable:
			node.set_interactable_enabled(false)


func _forest_on_resource_spawn_chunk(chunk: Node2D) -> void:
	if chunk == null or not is_instance_valid(chunk):
		return
	if chunk.get_meta("is_start_chunk", false):
		return
	var tm := get_node_or_null("/root/TutorialManager")
	if tm != null and tm.is_village_tutorial_active() and tm.village_core_step == 1:
		return
	_resource_spawn_timer -= 1
	if debug_enabled:
		print("[ForestGenerator] resource chunks until spawn: ", _resource_spawn_timer)
	if _resource_spawn_timer > 0:
		return
	var lo := mini(forest_resource_spawn_min_chunks, forest_resource_spawn_max_chunks)
	var hi := maxi(forest_resource_spawn_min_chunks, forest_resource_spawn_max_chunks)
	if _spawn_random_resource(chunk):
		_resource_spawn_timer = randi_range(lo, hi)
	else:
		_resource_spawn_timer = 1
	_maybe_spawn_expedition_loot_pickups(chunk)


func _maybe_spawn_expedition_loot_pickups(chunk: Node2D) -> void:
	if chunk == null or not is_instance_valid(chunk):
		return
	if randf() > 0.42:
		return
	var tile_map := chunk.find_child("TileMapLayer", true, false) as TileMapLayer
	if tile_map == null:
		return
	var tile_set: TileSet = tile_map.tile_set
	if tile_set == null:
		return
	var chunk_size := _get_size(chunk)
	var candidates := _forest_collect_resource_floor_cells(
		tile_map, tile_set, chunk, "decor_anchor", 96.0, chunk_size.x - 96.0
	)
	if candidates.is_empty():
		return
	var spawn_count := randi_range(1, 2)
	for _i in spawn_count:
		var cell: Vector2i = candidates[randi() % candidates.size()]
		var pickup := ExpeditionLootPickup.new()
		match biome_type:
			"mountain":
				pickup.loot_type = ExpeditionLootType.HERB_BUNDLE
			_:
				pickup.loot_type = ExpeditionLootType.SKY_FEATHER if randf() < 0.7 else ExpeditionLootType.HERB_BUNDLE
		pickup.position = tile_map.map_to_local(cell) + Vector2(0, -36)
		chunk.add_child(pickup)


func _forest_collect_resource_floor_cells(
	tile_map: Node,
	tile_set: TileSet,
	chunk: Node2D,
	decor_layer_name: String,
	min_x_pad: float,
	max_x_pad: float
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var used_cells = tile_map.get_used_cells()
	var chunk_size := _get_size(chunk)
	var min_x_local := min_x_pad
	var max_x_local := chunk_size.x - max_x_pad
	if max_x_local < min_x_local + 32.0:
		min_x_local = 32.0
		max_x_local = maxf(min_x_local + 32.0, chunk_size.x - 32.0)

	for cell in used_cells:
		var td: TileData = tile_map.get_cell_tile_data(cell)
		if not td:
			continue
		var tag = td.get_custom_data(decor_layer_name)
		if typeof(tag) != TYPE_STRING:
			continue
		var tag_s := String(tag)
		if tag_s == "forest_floor_surface" or tag_s == "floor_surface" or tag_s == "floor":
			var cell_local_pos = tile_map.map_to_local(cell)
			if cell_local_pos.x >= min_x_local and cell_local_pos.x <= max_x_local:
				var cell_above = cell + Vector2i(0, -1)
				var cell_above2 = cell + Vector2i(0, -2)
				if tile_map.get_cell_source_id(cell_above) == -1 and tile_map.get_cell_source_id(cell_above2) == -1:
					out.append(cell)
	return out


func _spawn_random_resource(chunk: Node2D) -> bool:
	print("[ForestGenerator] Attempting to spawn random resource in chunk: ", chunk.name)
	if _resource_scenes.is_empty():
		print("[ForestGenerator] FAIL: _resource_scenes is empty")
		return false
	
	# Get TileMap and TileSet to scan used cells (decoration style)
	var tile_map = chunk.find_child("TileMapLayer", true, false)
	if not tile_map:
		print("[ForestGenerator] FAIL: TileMapLayer not found in chunk")
		return false
	
	var tile_set = tile_map.get("tile_set") as TileSet
	if not tile_set:
		print("[ForestGenerator] FAIL: TileSet not found")
		return false

	# Find custom data layer index for decor anchors
	var decor_layer_name := "decor_anchor"
	var decor_layer_index := -1
	for i in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(i) == decor_layer_name:
			decor_layer_index = i
			break
	
	if decor_layer_index == -1:
		print("[ForestGenerator] FAIL: 'decor_anchor' custom data layer not found in TileSet")
		return false

	var valid_floor_cells: Array[Vector2i] = _forest_collect_resource_floor_cells(
		tile_map, tile_set, chunk, decor_layer_name, 280.0, 280.0
	)
	if valid_floor_cells.is_empty():
		valid_floor_cells = _forest_collect_resource_floor_cells(
			tile_map, tile_set, chunk, decor_layer_name, 32.0, 32.0
		)

	if valid_floor_cells.is_empty():
		print("[ForestGenerator] FAIL: No valid floor cells found in chunk via tag scan")
		return false

	# Pick a random valid cell
	var target_cell = valid_floor_cells.pick_random()
	
	# Pick a random resource scene
	var scene: PackedScene = _resource_scenes.pick_random()
	if not scene:
		print("[ForestGenerator] FAIL: picked scene is null")
		return false
		
	var resource_node = scene.instantiate() as Node2D
	if not resource_node:
		print("[ForestGenerator] FAIL: failed to instantiate resource")
		return false
	
	chunk.add_child(resource_node)
	# map_to_local koordinati tile_map local'idir; chunk local'e cevirmezsek bazı
	# chunk varyantlarında kaynaklar zeminin altında kalabiliyor.
	var tile_size = tile_set.tile_size
	var target_local_pos = tile_map.map_to_local(target_cell)
	var spawn_pos = target_local_pos
	spawn_pos.y -= tile_size.y * 0.5
	spawn_pos.y += 5.0
	resource_node.position = spawn_pos
	
	print("[ForestGenerator] SUCCESS: Spawned resource ", resource_node.name, " in chunk ", chunk.name, " at local ", resource_node.position)
	return true


func _spawn_debug_resource_nodes(start_chunk: Node2D) -> void:
	print("[ForestDebug] 🔧 _spawn_debug_resource_nodes called")
	if start_chunk == null:
		print("[ForestDebug] ❌ ERROR: start_chunk is null!")
		return
	print("[ForestDebug] ✅ start_chunk found: ", start_chunk.name, " at ", start_chunk.global_position)
	if Engine.is_editor_hint():
		print("[ForestDebug] ⚠️ Skipping spawn in editor")
		return
	
	# Find tile map to get proper Y positions
	var tile_map = start_chunk.find_child("TileMapLayer", true, false)
	var tile_size := Vector2(64, 64)  # Default tile size
	if tile_map != null:
		print("[ForestDebug] ✅ TileMapLayer found")
		var tile_set = tile_map.get("tile_set") as TileSet
		if tile_set:
			tile_size = tile_set.tile_size
			print("[ForestDebug] Tile size: ", tile_size)
	else:
		print("[ForestDebug] ⚠️ TileMapLayer not found, using default tile size")
	
	# Calculate proper Y position based on tile positions
	# Use the same logic as decoration spawning: find floor tiles and use their center
	var floor_y := 0.0
	if tile_map != null:
		var used_cells: Array[Vector2i] = tile_map.get_used_cells()
		var decor_layer_name := "decor_anchor"
		
		# Find a floor tile (with decor_anchor tag) to anchor to
		var floor_cell: Vector2i = Vector2i.ZERO
		var found_floor := false
		for cell in used_cells:
			var td: TileData = tile_map.get_cell_tile_data(cell) as TileData
			if td == null:
				continue
			var tag = td.get_custom_data(decor_layer_name)
			if typeof(tag) == TYPE_STRING:
				var tag_s := String(tag)
				if tag_s == "forest_floor_surface" or tag_s == "floor_surface":
					floor_cell = cell
					found_floor = true
					break
		
		if found_floor:
			# Use the same calculation as _forest_compute_span_center
			# Tile center = to_global(map_to_local(cell)) + tile_size * 0.5
			var tile_center: Vector2 = tile_map.to_global(tile_map.map_to_local(floor_cell)) + tile_size * 0.5
			# Decorations spawn at center - 30, but we'll use center - 25 (like decoration code does)
			floor_y = tile_center.y - 25.0
			print("[ForestDebug] ✅ Calculated floor_y: ", floor_y, " from floor tile at cell ", floor_cell, " center ", tile_center)
		else:
			# Fallback: use first tile if no floor tag found
			if used_cells.size() > 0:
				var sample_cell := used_cells[0]
				var tile_center: Vector2 = tile_map.to_global(tile_map.map_to_local(sample_cell)) + tile_size * 0.5
				floor_y = tile_center.y - 25.0
				print("[ForestDebug] ⚠️ No floor tag found, using first tile. floor_y: ", floor_y)
			else:
				print("[ForestDebug] ⚠️ No used cells found in TileMapLayer")
	else:
		print("[ForestDebug] ⚠️ Using default floor_y: 0.0")
	
	var holder := Node2D.new()
	holder.name = "ResourceDebugNodes"
	start_chunk.add_child(holder)
	print("[ForestDebug] ✅ Created holder node: ", holder.name, " as child of ", start_chunk.name)
	print("[ForestDebug] Holder global position: ", holder.global_position)
	
	var placements := [
		{"scene_path": "res://interactables/forest/TreeInteractable.tscn", "pos": Vector2(320, floor_y), "color": "brown"},
		{"scene_path": "res://interactables/forest/RockInteractable.tscn", "pos": Vector2(640, floor_y), "color": "gray"},
		{"scene_path": "res://interactables/forest/WellInteractable.tscn", "pos": Vector2(960, floor_y), "color": "blue"},
		{"scene_path": "res://interactables/forest/BushInteractable.tscn", "pos": Vector2(1280, floor_y), "color": "green"},
	]
	
	print("[ForestDebug] 📋 Spawning ", placements.size(), " placeholder interactables...")
	for i in range(placements.size()):
		var entry = placements[i]
		var scene_path := String(entry.get("scene_path", ""))
		var expected_pos: Vector2 = entry.get("pos", Vector2.ZERO)
		var color_name: String = entry.get("color", "unknown")
		
		print("[ForestDebug] [", i+1, "/", placements.size(), "] Processing: ", scene_path)
		
		if scene_path.is_empty():
			print("[ForestDebug] ❌ Missing path in placement: ", entry)
			continue
		
		var scene: PackedScene = ResourceLoader.load(scene_path, "PackedScene")
		if scene == null:
			print("[ForestDebug] ❌ Could not load scene: ", scene_path)
			continue
		print("[ForestDebug] ✅ Scene loaded: ", scene_path)
		
		var instance: Node = scene.instantiate()
		if instance == null:
			print("[ForestDebug] ❌ Could not instantiate scene: ", scene_path)
			continue
		print("[ForestDebug] ✅ Instance created: ", instance.name, " (class: ", instance.get_class(), ")")
		
		holder.add_child(instance)
		print("[ForestDebug] ✅ Added to holder as child #", holder.get_child_count())
		
		# Position relative to start_chunk (local position)
		var global_pos: Vector2 = expected_pos
		instance.global_position = global_pos  # Set global position directly
		print("[ForestDebug] ✅ Set global_position to: ", global_pos)
		
		# Verify position was set
		var actual_pos: Vector2 = instance.global_position
		if actual_pos.distance_to(global_pos) > 0.1:
			print("[ForestDebug] ⚠️ Position mismatch! Expected: ", global_pos, " Actual: ", actual_pos)
		else:
			print("[ForestDebug] ✅ Position verified: ", actual_pos)
		
		if instance is BaseInteractable:
			print("[ForestDebug] ✅ Instance is BaseInteractable")
			var interactable: BaseInteractable = instance as BaseInteractable
			interactable.require_interact_press = true  # Etkileşim tuşu ile aktifleşsin
			print("[ForestDebug] ✅ Set require_interact_press = true")
			
			if instance.has_method("set_placeholder_mode"):
				instance.call("set_placeholder_mode", true)
				print("[ForestDebug] ✅ Called set_placeholder_mode(true)")
			else:
				print("[ForestDebug] ⚠️ Instance does not have set_placeholder_mode method")
			
			# Check if placeholder visual was applied
			if instance.has_method("get") and instance.get("placeholder_mode"):
				print("[ForestDebug] ✅ placeholder_mode is true")
			else:
				print("[ForestDebug] ⚠️ placeholder_mode might not be set correctly")
		else:
			print("[ForestDebug] ⚠️ Instance is NOT BaseInteractable! Class: ", instance.get_class())
		
		# Check visibility
		if instance is Node2D:
			var node2d: Node2D = instance as Node2D
			print("[ForestDebug] Instance visible: ", node2d.visible, " modulate: ", node2d.modulate)
		
		# Check for visual children
		var sprite_nodes: Array[Node] = []
		_find_visual_nodes_recursive(instance, sprite_nodes)
		print("[ForestDebug] Found ", sprite_nodes.size(), " visual nodes:")
		for vis_node in sprite_nodes:
			if vis_node is Node2D:
				var vis2d: Node2D = vis_node as Node2D
				print("[ForestDebug]   - ", vis_node.name, " (", vis_node.get_class(), ") visible=", vis2d.visible, " pos=", vis2d.global_position)
		
		print("[ForestDebug] ✅ Completed spawn for ", color_name, " placeholder at ", actual_pos)
		print("[ForestDebug] ---")
	
	print("[ForestDebug] 🎉 Finished spawning all debug resource nodes. Holder has ", holder.get_child_count(), " children")
	print("[ForestDebug] Holder final global position: ", holder.global_position)
	print("[ForestDebug] Start chunk final children count: ", start_chunk.get_child_count())

func _find_visual_nodes_recursive(node: Node, result: Array[Node]) -> void:
	if node is Sprite2D or node is AnimatedSprite2D or node is Polygon2D or node is ColorRect or node is TextureRect:
		result.append(node)
	for child: Node in node.get_children():
		_find_visual_nodes_recursive(child, result)

func _debug_dump_chunk_nodes(label: String, chunk: Node) -> void:
	if not debug_enabled:
		return
	if chunk == null:
		print("[ForestDebug] Chunk dump ", label, ": <null>")
		return
	print("[ForestDebug] Chunk dump ", label, ": ", chunk.name, " class=", chunk.get_class(), " children=", chunk.get_child_count())
	_debug_dump_node_recursive(chunk, "", 0, 4)

func _find_all_sprites_in_area(root: Node, min_pos: Vector2, max_pos: Vector2) -> void:
	if root == null:
		return
	_find_sprites_recursive(root, min_pos, max_pos, 0, 10)

func _find_sprites_recursive(node: Node, min_pos: Vector2, max_pos: Vector2, depth: int, max_depth: int) -> void:
	if depth > max_depth:
		return
	if node is Node2D:
		var node2d: Node2D = node as Node2D
		var global_pos: Vector2 = node2d.global_position
		if global_pos.x >= min_pos.x and global_pos.x <= max_pos.x and global_pos.y >= min_pos.y and global_pos.y <= max_pos.y:
			if node is Sprite2D:
				var spr: Sprite2D = node as Sprite2D
				var tex_path: String = ""
				if spr.texture:
					tex_path = spr.texture.resource_path
				print("    [FOUND SPRITE2D] ", node.name, " class=", node.get_class(), " global_pos=", global_pos, " texture=", tex_path, " visible=", spr.visible, " parent=", node.get_parent().name if node.get_parent() else "null")
			elif node is AnimatedSprite2D:
				var asp: AnimatedSprite2D = node as AnimatedSprite2D
				var frames_path: String = ""
				if asp.sprite_frames:
					frames_path = asp.sprite_frames.resource_path
				print("    [FOUND ANIMATEDSPRITE2D] ", node.name, " class=", node.get_class(), " global_pos=", global_pos, " sprite_frames=", frames_path, " visible=", asp.visible, " parent=", node.get_parent().name if node.get_parent() else "null")
	for child: Node in node.get_children():
		_find_sprites_recursive(child, min_pos, max_pos, depth + 1, max_depth)

func _debug_dump_node_recursive(node: Node, prefix: String, depth: int, max_depth: int) -> void:
	if depth > max_depth:
		return
	var indent: String = ""
	for i in range(depth):
		indent += "  "
	var pos_str: String = ""
	var global_str: String = ""
	if node is Node2D:
		var node2d: Node2D = node as Node2D
		pos_str = " pos=" + str(node2d.position)
		global_str = " global=" + str(node2d.global_position)
	var class_str: String = " class=" + node.get_class()
	# Check for visual/sprite nodes
	var visual_info: String = ""
	if node is Sprite2D:
		var spr: Sprite2D = node as Sprite2D
		var tex_path: String = ""
		if spr.texture:
			tex_path = spr.texture.resource_path
		visual_info = " [Sprite2D texture=" + tex_path + " visible=" + str(spr.visible) + "]"
	elif node is AnimatedSprite2D:
		var asp: AnimatedSprite2D = node as AnimatedSprite2D
		visual_info = " [AnimatedSprite2D sprite_frames=" + (asp.sprite_frames.resource_path if asp.sprite_frames else "null") + "]"
	elif node is TextureRect:
		var tr: TextureRect = node as TextureRect
		var tex_path: String = ""
		if tr.texture:
			tex_path = tr.texture.resource_path
		visual_info = " [TextureRect texture=" + tex_path + "]"
	print(indent, prefix, node.name, class_str, pos_str, global_str, visual_info)
	for child: Node in node.get_children():
		_debug_dump_node_recursive(child, "• ", depth + 1, max_depth)

func _debug_dump_tilemap_summary(chunk: Node, label: String) -> void:
	if not debug_enabled:
		return
	if chunk == null:
		return
	var tile_map := chunk.find_child("TileMapLayer", true, false)
	if tile_map == null or not (tile_map is TileMapLayer):
		return
	var tm: TileMapLayer = tile_map as TileMapLayer
	var counts: Dictionary = {}
	var first_pos: Dictionary = {}
	var tile_scenes: Dictionary = {}  # Track tiles with scene instances
	var tile_textures: Dictionary = {}  # Track tile texture paths
	for cell in tm.get_used_cells():
		var source_id: int = tm.get_cell_source_id(cell)
		var atlas_coords: Vector2i = tm.get_cell_atlas_coords(cell)
		var alt_id: int = tm.get_cell_alternative_tile(cell)
		var key: String = "%s|%s|%s" % [str(source_id), str(atlas_coords), str(alt_id)]
		var current_count: int = int(counts.get(key, 0))
		counts[key] = current_count + 1
		if not first_pos.has(key):
			first_pos[key] = cell
			# Get texture path for this tile
			var source: TileSetSource = tm.tile_set.get_source(source_id)
			if source and source is TileSetAtlasSource:
				var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
				var texture: Texture2D = atlas_source.texture
				if texture:
					tile_textures[key] = texture.resource_path
			# Check if this tile has a scene instance
			var tile_data: TileData = tm.get_cell_tile_data(cell) as TileData
			if tile_data:
				# In Godot 4, check for scene instance via alternative_tile
				# Scene instances are typically alternative tiles
				if alt_id != 0:
					if source and source is TileSetAtlasSource:
						var atlas_source_for_scene: TileSetAtlasSource = source as TileSetAtlasSource
						# Try to get scene from alternative tile
						# This is a workaround - Godot 4 API may differ
						tile_scenes[key] = "alt_id=" + str(alt_id)
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b) -> bool:
		return int(counts.get(a, 0)) > int(counts.get(b, 0))
	)
	print("[ForestDebug] TileMap summary ", label, ": entries=", counts.size())
	var limit: int = min(12, keys.size())
	for i in range(limit):
		var key: String = String(keys[i])
		var cell_pos: Vector2i = first_pos[key] as Vector2i
		var count_value: int = int(counts.get(key, 0))
		var scene_info: String = ""
		if tile_scenes.has(key):
			scene_info = " " + tile_scenes[key]
		var texture_info: String = ""
		if tile_textures.has(key):
			texture_info = " texture=" + tile_textures[key]
		print("  • ", key, " count=", count_value, " sample_cell=", cell_pos, texture_info, scene_info)
	if keys.size() > limit:
		print("  • ... (", keys.size() - limit, " more)")
	# Also check for any direct child nodes of TileMapLayer that might be scene instances
	var tilemap_children: int = tm.get_child_count()
	if tilemap_children > 0:
		print("[ForestDebug] TileMapLayer has ", tilemap_children, " direct children (possible scene instances):")
		for child: Node in tm.get_children():
			var child_pos: Vector2 = Vector2.ZERO
			if child is Node2D:
				child_pos = (child as Node2D).global_position
			print("  • ", child.name, " class=", child.get_class(), " global_pos=", child_pos)
	# Also check for tiles in starter chunk area that might be trees
	if label.contains("start"):
		print("[ForestDebug] Checking for tree-like tiles in starter chunk area (x: -500 to 4500):")
		var tree_tiles_found: int = 0
		for cell in tm.get_used_cells():
			var world_pos: Vector2 = tm.map_to_local(cell)
			var global_pos: Vector2 = tm.to_global(world_pos)
			if global_pos.x >= -500 and global_pos.x <= 4500:
				var source_id: int = tm.get_cell_source_id(cell)
				var atlas_coords: Vector2i = tm.get_cell_atlas_coords(cell)
				var alt_id: int = tm.get_cell_alternative_tile(cell)
				var key: String = "%s|%s|%s" % [str(source_id), str(atlas_coords), str(alt_id)]
				var texture_path: String = ""
				if tile_textures.has(key):
					texture_path = tile_textures[key]
					# Check if texture path contains "tree" or "forest"
					# But also check atlas coordinates - trees are usually in specific atlas positions
					# Limit output to first 20 matches to avoid spam
					if (texture_path.to_lower().contains("tree") or texture_path.to_lower().contains("forest")) and tree_tiles_found < 20:
						print("  [FOUND TREE-LIKE TILE] cell=", cell, " global_pos=", global_pos, " atlas_coords=", atlas_coords, " texture=", texture_path)
						tree_tiles_found += 1
		if tree_tiles_found >= 20:
			print("  [ForestDebug] ... (more tree-like tiles found, limiting output)")

func _remove_underground_tree_tiles(chunk: Node2D) -> void:
	if chunk == null:
		return
	# Start chunk'ın solunda x=500-1500 aralığı
	var min_x: float = 500.0
	var max_x: float = 1500.0
	
	# NOTE: Tile'ları kaldırmıyoruz çünkü karakter boşluğa düşüyor
	# Sadece decoration node'larını (ağaç görselleri) kaldırıyoruz
	
	# 1. ForestLevelGenerator'ın child'ları arasında decoration node'larını kaldır
	# (Decoration'lar ForestLevelGenerator'a direkt child olarak ekleniyor)
	var decoration_nodes_to_remove: Array[Node] = []
	for child: Node in get_children():
		if child is Node2D:
			var child2d: Node2D = child as Node2D
			var global_pos: Vector2 = child2d.global_position
			if global_pos.x >= min_x and global_pos.x <= max_x:
				# Check if this is a decoration node (has "decoration_type" meta or is in background_decor group)
				var is_decoration: bool = false
				if child.has_meta("decoration_type"):
					is_decoration = true
				elif child.is_in_group("background_decor"):
					is_decoration = true
				# Also check if it has a Sprite child (typical decoration structure)
				elif child.find_child("Sprite", true, false) != null:
					is_decoration = true
				# Check for forest decoration names
				var name_lower: String = child.name.to_lower()
				if name_lower.contains("forest") or name_lower.contains("tree") or name_lower.contains("bush") or name_lower.contains("trunk") or name_lower.contains("grass") or name_lower.contains("rock"):
					is_decoration = true
				# EXCLUDE ForestExitPortal - it's not a decoration!
				if name_lower.contains("portal") or name_lower.contains("exit"):
					is_decoration = false
				if is_decoration:
					decoration_nodes_to_remove.append(child)
					if debug_enabled:
						print("[ForestDebug] Found decoration node to remove: ", child.name, " at ", global_pos)
	
	# 2b. Start chunk'ın içindeki decoration node'larını da kaldır
	if chunk != null:
		var chunk_children: Array[Node] = []
		_collect_all_children_recursive(chunk, chunk_children)
		for child: Node in chunk_children:
			if child is Node2D:
				var child2d: Node2D = child as Node2D
				var global_pos: Vector2 = child2d.global_position
				if global_pos.x >= min_x and global_pos.x <= max_x:
					# Skip TileMapLayer, ConnectionPoints, and ForestExitPortal
					var name_lower: String = child.name.to_lower()
					if name_lower.contains("tilemap") or name_lower.contains("connection") or name_lower.contains("portal") or name_lower.contains("exit"):
						continue
					# Check if this is a decoration node
					var is_decoration: bool = false
					if child.has_meta("decoration_type"):
						is_decoration = true
					elif child.is_in_group("background_decor"):
						is_decoration = true
					# Check for Sprite2D or AnimatedSprite2D children (decoration visuals)
					elif child.find_child("Sprite", true, false) != null:
						is_decoration = true
					else:
						# Check if any child is a Sprite2D or AnimatedSprite2D
						for grandchild: Node in child.get_children():
							if grandchild is Sprite2D or grandchild is AnimatedSprite2D:
								is_decoration = true
								break
					# Check for forest decoration names
					if name_lower.contains("forest") or name_lower.contains("tree") or name_lower.contains("bush") or name_lower.contains("trunk") or name_lower.contains("grass") or name_lower.contains("rock"):
						is_decoration = true
					if is_decoration:
						decoration_nodes_to_remove.append(child)
						if debug_enabled:
							print("[ForestDebug] Found decoration node in start chunk to remove: ", child.name, " at ", global_pos)
			# Also check for direct Sprite2D/AnimatedSprite2D nodes in the chunk
			elif child is Sprite2D or child is AnimatedSprite2D:
				var sprite: Node2D = child as Node2D
				var global_pos: Vector2 = sprite.global_position
				if global_pos.x >= min_x and global_pos.x <= max_x:
					# Skip if it's part of ForestExitPortal or other important nodes
					var parent: Node = sprite.get_parent()
					if parent != null:
						var parent_name_lower: String = parent.name.to_lower()
						if parent_name_lower.contains("portal") or parent_name_lower.contains("exit") or parent_name_lower.contains("tilemap") or parent_name_lower.contains("connection"):
							continue
					decoration_nodes_to_remove.append(child)
					if debug_enabled:
						print("[ForestDebug] Found Sprite2D/AnimatedSprite2D in start chunk to remove: ", child.name, " at ", global_pos)
	
	# Remove decoration nodes
	for node in decoration_nodes_to_remove:
		if is_instance_valid(node):
			if debug_enabled:
				print("[ForestDebug] Removing decoration node: ", node.name, " at ", (node as Node2D).global_position)
			node.queue_free()
	
	if decoration_nodes_to_remove.size() > 0:
		print("[ForestDebug] Removed ", decoration_nodes_to_remove.size(), " decoration nodes from start chunk area (x: ", min_x, " to ", max_x, ")")
	
	# 3. Queue'daki bu aralıktaki spawn job'larını temizle
	var queue_filtered: Array = []
	var queue_removed: int = 0
	for job in _decor_spawn_queue:
		var pos: Vector2 = job.get("pos", Vector2.ZERO)
		if pos.x < min_x or pos.x > max_x:
			queue_filtered.append(job)
		else:
			queue_removed += 1
			if debug_enabled:
				print("[ForestDebug] Removed queued decoration spawn: ", job.get("name", ""), " at ", pos)
	_decor_spawn_queue = queue_filtered
	if queue_removed > 0:
		print("[ForestDebug] Removed ", queue_removed, " queued decoration spawns from start chunk area")

func _collect_all_children_recursive(node: Node, result: Array[Node]) -> void:
	for child: Node in node.get_children():
		result.append(child)
		_collect_all_children_recursive(child, result)

func _spawn_ahead_as_needed() -> void:
	var need_until: float = player.global_position.x + float(unit_size) * 6.0
	while last_end_x < need_until:
		_add_next_segment()

func _spawn_left_as_needed() -> void:
	if active_chunks.size() == 0:
		return
	# Spawn left until we cover at least just beyond the cleanup cutoff,
	# otherwise freshly spawned chunks could be immediately cleaned up.
	var cutoff: float = player.global_position.x - despawn_distance
	var target_left: float = cutoff + float(unit_size) * 2.0
	while active_chunks.size() > 0 and active_chunks[0].position.x > target_left:
		_add_prev_segment()

func _enforce_player_window() -> void:
	if active_chunks.size() == 0:
		return
	_sort_active_by_x()
	var player_idx: int = _find_player_chunk_index()
	# Window debug messages disabled for cleaner logs
	# if debug_enabled:
	#	var left_idx_dbg := (int(active_chunks[0].get_meta("entry_index")) if active_chunks.size()>0 and active_chunks[0].has_meta("entry_index") else -1)
	#	var right_idx_dbg := (int(active_chunks.back().get_meta("entry_index")) if active_chunks.size()>0 and active_chunks.back().has_meta("entry_index") else -1)
	#	_dbg("[Window] start: player_idx=%s size=%s left_x=%s right_x=%s left_idx=%s right_idx=%s discovered=[%s..%s]" % [
	#		str(player_idx), str(active_chunks.size()),
	#		str(active_chunks[0].position.x if active_chunks.size()>0 else 0),
	#		str(active_chunks.back().position.x if active_chunks.size()>0 else 0),
	#		str(left_idx_dbg), str(right_idx_dbg), str(min_discovered_index), str(max_discovered_index)
	#	])
	# Ensure enough on the right
	var safety := 32
	while (active_chunks.size() - 1 - player_idx) < window_right_count and safety > 0:
		if not _restore_right_once():
			_add_next_segment()
		_sort_active_by_x()
		player_idx = _find_player_chunk_index()
		safety -= 1
	# Ensure enough on the left
	safety = 32
	while player_idx < window_left_count and safety > 0:
		var before_left_x := (active_chunks[0].position.x if active_chunks.size() > 0 else 0.0)
		var before_count := active_chunks.size()
		if not _restore_left_once():
			# Debug messages disabled for cleaner logs
			# if debug_enabled:
			#	_dbg("[Window] left: restore failed -> add_prev (left generation)")
			_add_prev_segment()
		_sort_active_by_x()
		player_idx = _find_player_chunk_index()
		# If nothing changed, break to avoid infinite loop
		if active_chunks.size() == before_count and (active_chunks.size() == 0 or is_equal_approx(active_chunks[0].position.x, before_left_x)):
			# Debug messages disabled for cleaner logs
			# if debug_enabled:
			#	_dbg("[Window] left: no progress -> break")
			break
		safety -= 1
		# Debug messages disabled for cleaner logs
		# if debug_enabled:
		#	var l_idx := (int(active_chunks[0].get_meta("entry_index")) if active_chunks.size()>0 and active_chunks[0].has_meta("entry_index") else -1)
		#	_dbg("[Window] left: player_idx=%s size=%s left_idx=%s" % [str(player_idx), str(active_chunks.size()), str(l_idx)])
	# Trim extras on the left
	safety = 32
	while player_idx > window_left_count and safety > 0:
		# Debug messages disabled for cleaner logs
		# if debug_enabled:
		#	_dbg("[Trim] remove leftmost")
		_remove_leftmost_chunk()
		_sort_active_by_x()
		player_idx = _find_player_chunk_index()
		safety -= 1
	# Trim extras on the right
	safety = 32
	while (active_chunks.size() - 1 - player_idx) > window_right_count and safety > 0:
		# Debug messages disabled for cleaner logs
		# if debug_enabled:
		#	_dbg("[Trim] remove rightmost")
		_remove_rightmost_chunk()
		_sort_active_by_x()
		player_idx = _find_player_chunk_index()
		safety -= 1

func _cleanup_behind() -> void:
	var cutoff: float = player.global_position.x - despawn_distance
	while active_chunks.size() > 0:
		_sort_active_by_x()
		var c: Node2D = active_chunks[0]
		if c == null or not is_instance_valid(c):
			active_chunks.remove_at(0)
			continue
		if c.global_position.x + _get_size(c).x >= cutoff:
			break
		# remove oldest chunk but keep archive
		var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else first_active_index)
		if is_instance_valid(c):
			c.queue_free()
		active_chunks.remove_at(0)
		index_to_node.erase(idx)
		first_active_index = max(first_active_index, idx + 1)

func _add_next_segment() -> void:
	_sort_active_by_x()
	var prev: Node2D = active_chunks.back()
	if _ramp_cooldown_next > 0:
		_ramp_cooldown_next -= 1
		_place_continue(prev)
		return
	# Derive the current row from the last chunk's y to avoid drift after window removals
	current_row = int(round(prev.position.y / float(unit_size)))
	var roll: float = randf()
	var up_allowed: bool = current_row > min_row
	var down_allowed: bool = current_row < max_row
	if biome_type == "mountain":
		down_allowed = false
	var p_cont: float = prob_continue
	var p_up: float = (prob_up if up_allowed else 0.0)
	var p_down: float = (prob_down if down_allowed else 0.0)
	var total: float = p_cont + p_up + p_down
	if total <= 0.0:
		p_cont = 1.0; p_up = 0.0; p_down = 0.0; total = 1.0
	roll *= total
	if roll < p_cont:
		_place_continue(prev)
	elif roll < p_cont + p_up:
		_place_up(prev)
	else:
		_place_down(prev)

func _add_prev_segment() -> void:
	if active_chunks.size() == 0:
		return
	_sort_active_by_x()
	var first: Node2D = active_chunks[0]
	if _ramp_cooldown_prev > 0:
		_ramp_cooldown_prev -= 1
		_place_continue_left(first, int(round(first.position.y / float(unit_size))))
		return
	# Use first's row to keep path flat unless a ramp is chosen
	var row_est: int = int(round(first.position.y / float(unit_size)))
	var roll: float = randf()
	var up_allowed: bool = row_est > min_row
	var down_allowed: bool = row_est < max_row
	if biome_type == "mountain":
		down_allowed = false
		if row_est >= 0:
			up_allowed = false  # flat foothills west of the start chunk
	var p_cont: float = prob_continue
	var p_up: float = (prob_up if up_allowed else 0.0)
	var p_down: float = (prob_down if down_allowed else 0.0)
	var total: float = p_cont + p_up + p_down
	if total <= 0.0:
		p_cont = 1.0; p_up = 0.0; p_down = 0.0; total = 1.0
	roll *= total
	if roll < p_cont:
		_place_continue_left(first, row_est)
	elif roll < p_cont + p_up:
		_place_up_left(first, row_est)
	else:
		_place_down_left(first, row_est)

func _estimate_row_for_left(first: Node2D) -> int:
	# Estimate the "current path row" from the leftmost chunk strictly by geometry
	var top_row: int = int(round(first.position.y / float(unit_size)))
	var h_units: int = int(round(_get_size(first).y / float(unit_size)))
	if h_units < 1:
		h_units = 1
	# Use the bottom row index of the chunk, which matches straight path alignment
	return top_row + (h_units - 1)

func _remove_leftmost_chunk() -> void:
	if active_chunks.size() == 0:
		return
	_sort_active_by_x()
	var c: Node2D = active_chunks[0]
	var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else first_active_index)
	if is_instance_valid(c):
		c.queue_free()
	active_chunks.remove_at(0)
	index_to_node.erase(idx)
	first_active_index = max(first_active_index, idx + 1)

func _remove_rightmost_chunk() -> void:
	if active_chunks.size() == 0:
		return
	_sort_active_by_x()
	var c: Node2D = active_chunks.back()
	var idx: int = int(c.get_meta("entry_index") if c.has_meta("entry_index") else last_active_index)
	if is_instance_valid(c):
		c.queue_free()
	active_chunks.remove_at(active_chunks.size() - 1)
	index_to_node.erase(idx)
	# Recompute last_end_x from new rightmost
	if active_chunks.size() > 0:
		var r: Node2D = active_chunks.back()
		last_end_x = r.position.x + _get_size(r).x
	else:
		last_end_x = 0.0

func _find_player_chunk_index() -> int:
	var px: float = player.global_position.x
	var best_idx: int = 0
	var best_dist: float = INF
	for i in range(active_chunks.size()):
		var ch: Node2D = active_chunks[i]
		if ch == null or not is_instance_valid(ch):
			continue
		var sz: Vector2 = _get_size(ch)
		var start_x: float = ch.position.x
		var end_x: float = start_x + sz.x
		if px >= start_x and px <= end_x:
			return i
		var center_x: float = start_x + sz.x * 0.5
		var d: float = abs(px - center_x)
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx

func _place_continue(prev: Node2D) -> void:
	var next: Node2D = _spawn_scene("linear")
	var prev_right: Vector2 = _get_conn_global(prev, "right")
	var next_left_local: Vector2 = _get_conn_local(next, "left")
	next.position = prev_right - next_left_local
	active_chunks.append(next)
	var prev_idx := int(prev.get_meta("entry_index") if prev.has_meta("entry_index") else -1)
	var new_idx := _record_entry(next, "linear")
	if prev_idx != -1:
		_link_after(prev_idx, new_idx)
	last_end_x = next.position.x + _get_size(next).x
	
	_forest_on_resource_spawn_chunk(next)
	
	if debug_enabled:
		_debug_dump_active_chunks("place_continue")

func _place_continue_left(first: Node2D, row_est: int) -> void:
	var next: Node2D = _spawn_scene("linear")
	var first_left: Vector2 = _get_conn_global(first, "left")
	var next_right_local: Vector2 = _get_conn_local(next, "right")
	# Align next.right to first.left so it sits to the left
	next.position = first_left - next_right_local
	active_chunks.insert(0, next)
	var first_idx := int(first.get_meta("entry_index") if first.has_meta("entry_index") else -1)
	var next_idx := _record_entry(next, "linear")
	if first_idx != -1:
		_link_before(first_idx, next_idx)
	_forest_on_resource_spawn_chunk(next)
	if debug_enabled:
		_debug_dump_active_chunks("place_continue_left")

func _place_up(prev: Node2D) -> void:
	var ramp_key: String = ("ramp_up_wide" if randf() < prob_wide_ramp else "ramp_up")
	var ramp: Node2D = _spawn_scene(ramp_key)
	# Align prev.right to ramp.left
	var prev_right: Vector2 = _get_conn_global(prev, "right")
	var ramp_left_local: Vector2 = _get_conn_local(ramp, "left")
	ramp.position = prev_right - ramp_left_local
	active_chunks.append(ramp)
	var prev_idx := int(prev.get_meta("entry_index") if prev.has_meta("entry_index") else -1)
	var ramp_idx := _record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Align ramp.right to next.left (top connection on ramp_up)
	var ramp_right: Vector2 = _get_conn_global(ramp, "right")
	var next_left_local: Vector2 = _get_conn_local(next, "left")
	next.position = ramp_right - next_left_local
	active_chunks.append(next)
	var next_idx := _record_entry(next, "linear")
	if prev_idx != -1:
		_link_after(prev_idx, ramp_idx)
	_link_after(ramp_idx, next_idx)
	_forest_on_resource_spawn_chunk(ramp)
	_forest_on_resource_spawn_chunk(next)
	# Debug messages disabled for cleaner logs
	# if debug_enabled:
	#	var expected_y := _get_conn_global(ramp, "right").y - _get_conn_local(next, "left").y + next.position.y
	#	print("[PlaceUp] prev_y=", prev.position.y, " ramp=", ramp_key, " next_y=", next.position.y)
	current_row -= 1
	_ramp_cooldown_next = maxi(_ramp_cooldown_next, ramp_cooldown_segments)
	last_end_x = next.position.x + _get_size(next).x
	if debug_enabled:
		_debug_dump_active_chunks("place_up")

func _place_up_left(first: Node2D, row_est: int) -> void:
	var ramp_key: String = ("ramp_down_wide" if randf() < prob_wide_ramp else "ramp_down")
	var ramp: Node2D = _spawn_scene(ramp_key)
	# Align ramp.right to first.left
	var first_left: Vector2 = _get_conn_global(first, "left")
	var ramp_right_local: Vector2 = _get_conn_local(ramp, "right")
	ramp.position = first_left - ramp_right_local
	active_chunks.insert(0, ramp)
	var first_idx := int(first.get_meta("entry_index") if first.has_meta("entry_index") else -1)
	var ramp_idx := _record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Align next.right to ramp.left (top connection on ramp_down to the left)
	var ramp_left: Vector2 = _get_conn_global(ramp, "left")
	var next_right_local: Vector2 = _get_conn_local(next, "right")
	next.position = ramp_left - next_right_local
	active_chunks.insert(0, next)
	var next_idx := _record_entry(next, "linear")
	if first_idx != -1:
		# Link spatially: next (leftmost) -> ramp -> first
		_link_before(first_idx, next_idx)
		_link_before(first_idx, ramp_idx)
	_forest_on_resource_spawn_chunk(next)
	_forest_on_resource_spawn_chunk(ramp)
	# Debug messages disabled for cleaner logs
	# if debug_enabled:
	#	print("[PlaceUpLeft] first_y=", first.position.y, " ramp=", ramp_key, " next_y=", next.position.y)
	if debug_enabled:
		_debug_dump_active_chunks("place_up_left")
	_ramp_cooldown_prev = maxi(_ramp_cooldown_prev, ramp_cooldown_segments)

func _place_down(prev: Node2D) -> void:
	var ramp_key: String = ("ramp_down_wide" if randf() < prob_wide_ramp else "ramp_down")
	var ramp: Node2D = _spawn_scene(ramp_key)
	# Align prev.right to ramp.left (top connection on ramp_down)
	var prev_right: Vector2 = _get_conn_global(prev, "right")
	var ramp_left_local: Vector2 = _get_conn_local(ramp, "left")
	ramp.position = prev_right - ramp_left_local
	active_chunks.append(ramp)
	var prev_idx := int(prev.get_meta("entry_index") if prev.has_meta("entry_index") else -1)
	var ramp_idx := _record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Align ramp.right to next.left (bottom connection on ramp_down)
	var ramp_right: Vector2 = _get_conn_global(ramp, "right")
	var next_left_local: Vector2 = _get_conn_local(next, "left")
	next.position = ramp_right - next_left_local
	active_chunks.append(next)
	var next_idx := _record_entry(next, "linear")
	if prev_idx != -1:
		_link_after(prev_idx, ramp_idx)
	_link_after(ramp_idx, next_idx)
	_forest_on_resource_spawn_chunk(ramp)
	_forest_on_resource_spawn_chunk(next)
	# Debug messages disabled for cleaner logs
	# if debug_enabled:
	#	print("[PlaceDown] prev_y=", prev.position.y, " ramp=", ramp_key, " next_y=", next.position.y)
	current_row += 1
	_ramp_cooldown_next = maxi(_ramp_cooldown_next, ramp_cooldown_segments)
	last_end_x = next.position.x + _get_size(next).x
	if debug_enabled:
		_debug_dump_active_chunks("place_down")

func _place_down_left(first: Node2D, row_est: int) -> void:
	var ramp_key: String = ("ramp_up_wide" if randf() < prob_wide_ramp else "ramp_up")
	var ramp: Node2D = _spawn_scene(ramp_key)
	# Align ramp.right to first.left (top connection on ramp_up to the left)
	var first_left: Vector2 = _get_conn_global(first, "left")
	var ramp_right_local: Vector2 = _get_conn_local(ramp, "right")
	ramp.position = first_left - ramp_right_local
	active_chunks.insert(0, ramp)
	var first_idx := int(first.get_meta("entry_index") if first.has_meta("entry_index") else -1)
	var ramp_idx := _record_entry(ramp, ramp_key)
	var next: Node2D = _spawn_scene("linear")
	# Align next.right to ramp.left (bottom connection on ramp_up)
	var ramp_left: Vector2 = _get_conn_global(ramp, "left")
	var next_right_local: Vector2 = _get_conn_local(next, "right")
	next.position = ramp_left - next_right_local
	active_chunks.insert(0, next)
	var next_idx := _record_entry(next, "linear")
	if first_idx != -1:
		# Link spatially: next (leftmost) -> ramp -> first
		_link_before(first_idx, next_idx)
		_link_before(first_idx, ramp_idx)
	_forest_on_resource_spawn_chunk(next)
	_forest_on_resource_spawn_chunk(ramp)
	# Debug messages disabled for cleaner logs
	# if debug_enabled:
	#	print("[PlaceDownLeft] prev_y=", first.position.y, " ramp=", ramp_key, " next_y=", next.position.y)
	if debug_enabled:
		_debug_dump_active_chunks("place_down_left")
	_ramp_cooldown_prev = maxi(_ramp_cooldown_prev, ramp_cooldown_segments)


func _spawn_scene(key: String) -> Node2D:
	var scene: PackedScene = null
	var arr = scenes.get(key, [])
	if typeof(arr) == TYPE_ARRAY and (arr as Array).size() > 0:
		var i := randi() % (arr as Array).size()
		scene = (arr as Array)[i]
	else:
		# Backward compatibility if a single PackedScene was left
		scene = scenes.get(key, null)
		if typeof(scene) != TYPE_OBJECT:
			return null
	var inst: Node2D = scene.instantiate() as Node2D
	add_child(inst)
	# Force unit_size sync to avoid per-scene mismatches
	_apply_unit_size(inst)
	# Queue expensive chunk setup to be processed with per-frame budget.
	_queue_chunk_postprocess(inst)
	return inst

func _get_size(node: Node2D) -> Vector2:
	# All forest chunks provide size via unit_size and size_in_units
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	if node.has_method("get_chunk_size"):
		return node.call("get_chunk_size") as Vector2
	# Fallback to unit grid if missing
	return Vector2(2 * unit_size, unit_size)

func _row_to_y(row: int) -> float:
	return row * unit_size

func get_spawn_position() -> Vector2:
	if _forest_start_chunk != null and is_instance_valid(_forest_start_chunk):
		var sz := _get_size(_forest_start_chunk)
		return Vector2(_forest_start_chunk.position.x + unit_size * 0.5, _forest_start_chunk.position.y + sz.y - unit_size * 0.5)
	if active_chunks.is_empty():
		return Vector2.ZERO
	var first := active_chunks[0]
	var sz := _get_size(first)
	return Vector2(first.position.x + unit_size * 0.5, first.position.y + sz.y - unit_size * 0.5)

func _spawn_or_move_player_to_start() -> void:
	var spawn_pos: Vector2 = get_spawn_position()
	if player == null:
		var player_scene: PackedScene = load("res://player/player.tscn") as PackedScene
		if player_scene:
			player = player_scene.instantiate() as Node2D
			if player:
				player.name = "Player"
				add_child(player)
	if player:
		player.global_position = spawn_pos
		if player.has_node("Camera2D"):
			var cam = player.get_node("Camera2D")
			if cam and cam is Camera2D:
				# Attach simple forest camera behavior if not already attached
				if cam.get_script() == null or not String(cam.get_script().resource_path).ends_with("ForestSimpleCamera.gd"):
					var cam_script := load("res://levels/ForestSimpleCamera.gd")
					if cam_script:
						cam.set_script(cam_script)
						# Defaults tuned for forest
						cam.set("bias_ground_y", -120.0)
						cam.set("bias_air_y", -40.0)
						cam.set("bias_jump_center_y", -10.0)
						cam.set("smooth_speed", 6.0)
						cam.set("offset_smooth_speed", 8.0)
						# Ensure the runtime-attached script initializes
						if cam.has_method("force_init"):
							cam.call("force_init")
						# Keep debug off for normal play
						cam.set("debug", false)
				(cam as Camera2D).enabled = true
				(cam as Camera2D).make_current()

func _setup_overview_camera() -> void:
	overview_camera = Camera2D.new()
	add_child(overview_camera)
	# Do not enable by default to avoid stealing current camera; toggle via hotkey
	overview_camera.enabled = false
	_update_overview_camera_fit()
	if is_overview_active:
		overview_camera.make_current()

func _update_overview_camera_fit() -> void:
	if not overview_camera:
		return
	if active_chunks.is_empty():
		overview_camera.position = Vector2.ZERO
		overview_camera.zoom = Vector2.ONE
		return
	var merged: Rect2
	var first_set: bool = false
	for c in active_chunks:
		if c == null or not is_instance_valid(c) or not (c is Node2D):
			continue
		var sz: Vector2 = _get_size(c)
		var r := Rect2(c.position, sz)
		if not first_set:
			merged = r
			first_set = true
		else:
			merged = merged.merge(r)
	var center := merged.position + merged.size * 0.5
	overview_camera.position = center
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var zoom_x: float = viewport_size.x / max(merged.size.x, 1.0)
	var zoom_y: float = viewport_size.y / max(merged.size.y, 1.0)
	var ratio: float = min(zoom_x, zoom_y) * 0.9
	overview_camera.zoom = Vector2(ratio, ratio)

# --- Day/Night system (mirror of village) ---
func _setup_day_night_system() -> void:
	# Avoid duplicating background if already exists
	if get_node_or_null("ParallaxBackground"):
		return
	var pb := ParallaxBackground.new()
	pb.name = "ParallaxBackground"
	pb.layer = -1
	add_child(pb)

	# Sky gradient
	var sky_layer := ParallaxLayer.new()
	sky_layer.name = "sky"
	sky_layer.z_index = -100
	sky_layer.motion_scale = Vector2(0.0, 0.0)
	pb.add_child(sky_layer)
	var sky_sprite := Sprite2D.new()
	sky_sprite.name = "Sky"
	# Use a simple gradient texture similar to village defaults
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	grad.set_color(0, Color(0.5, 0.7, 1.0, 1.0))
	grad.set_color(1, Color(0.75, 0.95, 1.0, 1.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	# Ensure vertical gradient (top -> bottom), like village
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	sky_sprite.texture = grad_tex
	# Keep parallax sky for compatibility, but also add a screen-space sky to guarantee coverage
	# Parallax sprite (large, world-space) - match village size
	sky_sprite.centered = false
	sky_sprite.position = Vector2(-1, -748.501)
	sky_sprite.scale = Vector2(124.844, 26.5781)
	sky_layer.add_child(sky_sprite)
	# Screen-space sky using CanvasLayer + TextureRect (fills viewport)
	var sky_canvas := CanvasLayer.new()
	sky_canvas.name = "SkyCanvas"
	sky_canvas.layer = -1000
	add_child(sky_canvas)
	var sky_rect := TextureRect.new()
	sky_rect.name = "SkyRect"
	sky_rect.texture = grad_tex
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky_canvas.add_child(sky_rect)

	# Stars layer
	var stars_layer := ParallaxLayer.new()
	stars_layer.name = "StarsLayer"
	stars_layer.z_index = -40
	stars_layer.motion_scale = Vector2(0.001, 0.001)
	stars_layer.position = Vector2(10, 642)
	pb.add_child(stars_layer)
	# StarsContainer from village
	var stars_container := Node2D.new()
	stars_container.name = "StarsContainer"
	var stars_script := load("res://village/scripts/StarsContainer.gd")
	if stars_script:
		stars_container.set_script(stars_script)
		# Mirror village defaults
		stars_container.set("num_stars", 200)
		stars_container.set("center", Vector2(800, 0))
		stars_container.set("max_radius", 1000.0)
		stars_container.set("min_speed", 0.005)
		stars_container.set("max_speed", 0.008)
		var star_tex := load("res://village/assets/star/star1.png")
		if star_tex:
			stars_container.set("star_texture", star_tex)
	stars_layer.add_child(stars_container)

	# Background tint CanvasModulate for day-night controller to adjust
	var bg_tint := CanvasModulate.new()
	bg_tint.name = "BackgroundTint"
	bg_tint.z_index = -50
	pb.add_child(bg_tint)

	# Celestial path (sun/moon)
	var celestial_layer := ParallaxLayer.new()
	celestial_layer.name = "CelestialLayer"
	celestial_layer.z_index = -30
	celestial_layer.motion_scale = Vector2(0.001, 0.001)
	celestial_layer.position = Vector2(10, 642)
	pb.add_child(celestial_layer)
	var path := Path2D.new()
	path.name = "SunMoonPath"
	path.position = Vector2(599, -98)
	path.scale = Vector2(0.543478, 0.543478)
	var curve := Curve2D.new()
	# Arc approximating village path
	curve.add_point(Vector2(-1200, 200))
	curve.add_point(Vector2(-800, -200))
	curve.add_point(Vector2(-400, -600))
	curve.add_point(Vector2(0, -800))
	curve.add_point(Vector2(400, -600))
	curve.add_point(Vector2(800, -200))
	curve.add_point(Vector2(1200, 200))
	path.curve = curve
	celestial_layer.add_child(path)
	var sun_follow := PathFollow2D.new(); sun_follow.name = "SunFollower"; path.add_child(sun_follow)
	var sun_sprite := Sprite2D.new(); sun_sprite.name = "SunSprite"; sun_follow.add_child(sun_sprite); sun_sprite.scale = Vector2(0.6, 0.6)
	var sun_tex = load("res://village/assets/sun,moon/sun.png")
	if sun_tex:
		sun_sprite.texture = sun_tex
	var moon_follow := PathFollow2D.new(); moon_follow.name = "MoonFollower"; path.add_child(moon_follow)
	var moon_sprite := Sprite2D.new(); moon_sprite.name = "MoonSprite"; moon_follow.add_child(moon_sprite); moon_sprite.scale = Vector2(0.6, 0.6)
	var moon_tex = load("res://village/assets/sun,moon/moon.png")
	if moon_tex:
		moon_sprite.texture = moon_tex
	# Match village parallax feel (slight movement with camera)
	celestial_layer.motion_scale = Vector2(0.001, 0.001)
	# Basic small lights (optional; can be left disabled)
	var sun_light := PointLight2D.new(); sun_light.name = "PointLight2D"; sun_follow.add_child(sun_light); sun_light.visible = false
	sun_light.texture_scale = 10.05
	var moon_light := PointLight2D.new(); moon_light.name = "PointLight2D"; moon_follow.add_child(moon_light); moon_light.visible = false
	moon_light.texture_scale = 5.76

	# DayNightController
	var dnc := CanvasModulate.new()
	dnc.name = "DayNightController"
	# Ensure it modulates the whole canvas and sits behind gameplay
	dnc.z_index = -200
	# Attach script and configure BEFORE adding to tree so _ready sees NodePaths
	var script := load("res://village/scripts/DayNightController.gd")
	if script:
		dnc.set_script(script)
		# Exported fields wiring via NodePaths
		dnc.set("sky_gradient_resource", grad_tex)
		dnc.set("transition_speed", 0.3)
		dnc.set("sun_follower_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/SunFollower"))
		dnc.set("moon_follower_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/MoonFollower"))
		dnc.set("sun_sprite_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/SunFollower/SunSprite"))
		dnc.set("moon_sprite_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/MoonFollower/MoonSprite"))
		dnc.set("sun_light_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/SunFollower/PointLight2D"))
		dnc.set("moon_light_path", NodePath("../ParallaxBackground/CelestialLayer/SunMoonPath/MoonFollower/PointLight2D"))
		dnc.set("sun_sunset_hour", 19.5)
		dnc.set("moon_set_hour", 6.0)
		dnc.set("celestial_fade_duration", 0.3)
	# Add to tree last -> triggers _ready with correct paths
	add_child(dnc)

	# --- Biome Parallax ---
	const MOUNTAIN_PARALLAX_DIR := "res://background/parallax/forest parallax/mountain/"
	match biome_type:
		"mountain":
			var mountain_1_layer := ParallaxLayer.new()
			mountain_1_layer.name = "MountainBiomMountain1"
			mountain_1_layer.z_index = -11
			mountain_1_layer.position = Vector2(0, -280)
			mountain_1_layer.motion_scale = Vector2(0.10, 0.02)
			pb.add_child(mountain_1_layer)
			var mountain_1_sprite := Sprite2D.new()
			mountain_1_sprite.name = "Mountain1Sprite"
			var mountain_1_tex := load(MOUNTAIN_PARALLAX_DIR + "mountain_biom_mountain1.png")
			if mountain_1_tex:
				mountain_1_sprite.texture = mountain_1_tex
			mountain_1_sprite.centered = false
			mountain_1_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			mountain_1_layer.add_child(mountain_1_sprite)
			if mountain_1_tex and mountain_1_tex is Texture2D:
				mountain_1_layer.motion_mirroring = Vector2(float((mountain_1_tex as Texture2D).get_width()), 0.0)

			var mountain_2_layer := ParallaxLayer.new()
			mountain_2_layer.name = "MountainBiomMountain2"
			mountain_2_layer.z_index = -12
			mountain_2_layer.position = Vector2(0, -200)
			mountain_2_layer.motion_scale = Vector2(0.05, 0.0)
			pb.add_child(mountain_2_layer)
			var mountain_2_sprite := Sprite2D.new()
			mountain_2_sprite.name = "Mountain2Sprite"
			var mountain_2_tex := load(MOUNTAIN_PARALLAX_DIR + "mountain_biom_mountain2.png")
			if mountain_2_tex:
				mountain_2_sprite.texture = mountain_2_tex
			mountain_2_sprite.centered = false
			mountain_2_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			mountain_2_layer.add_child(mountain_2_sprite)
			if mountain_2_tex and mountain_2_tex is Texture2D:
				mountain_2_layer.motion_mirroring = Vector2(float((mountain_2_tex as Texture2D).get_width()), 0.0)

			var mtn_trees_3_layer := ParallaxLayer.new()
			mtn_trees_3_layer.name = "MountainBiomTrees3"
			mtn_trees_3_layer.z_index = -9
			mtn_trees_3_layer.position = Vector2(0, -400)
			mtn_trees_3_layer.motion_scale = Vector2(0.30, 0.10)
			pb.add_child(mtn_trees_3_layer)
			var mtn_trees_3_sprite := Sprite2D.new()
			mtn_trees_3_sprite.name = "MtnTrees3Sprite"
			var mtn_trees_3_tex := load(MOUNTAIN_PARALLAX_DIR + "mountain_biom_trees3.png")
			if mtn_trees_3_tex:
				mtn_trees_3_sprite.texture = mtn_trees_3_tex
			mtn_trees_3_sprite.centered = false
			mtn_trees_3_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			mtn_trees_3_layer.add_child(mtn_trees_3_sprite)
			if mtn_trees_3_tex and mtn_trees_3_tex is Texture2D:
				mtn_trees_3_layer.motion_mirroring = Vector2(float((mtn_trees_3_tex as Texture2D).get_width()), 0.0)

			var mtn_trees_2_layer := ParallaxLayer.new()
			mtn_trees_2_layer.name = "MountainBiomTrees2"
			mtn_trees_2_layer.z_index = -7
			mtn_trees_2_layer.position = Vector2(0, -460)
			mtn_trees_2_layer.motion_scale = Vector2(0.48, 0.22)
			pb.add_child(mtn_trees_2_layer)
			var mtn_trees_2_sprite := Sprite2D.new()
			mtn_trees_2_sprite.name = "MtnTrees2Sprite"
			var mtn_trees_2_tex := load(MOUNTAIN_PARALLAX_DIR + "mountain_biom_trees2.png")
			if mtn_trees_2_tex:
				mtn_trees_2_sprite.texture = mtn_trees_2_tex
			mtn_trees_2_sprite.centered = false
			mtn_trees_2_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			mtn_trees_2_layer.add_child(mtn_trees_2_sprite)
			if mtn_trees_2_tex and mtn_trees_2_tex is Texture2D:
				mtn_trees_2_layer.motion_mirroring = Vector2(float((mtn_trees_2_tex as Texture2D).get_width()), 0.0)

			var mtn_trees_1_layer := ParallaxLayer.new()
			mtn_trees_1_layer.name = "MountainBiomTrees1"
			mtn_trees_1_layer.z_index = -5
			mtn_trees_1_layer.position = Vector2(0, -520)
			mtn_trees_1_layer.motion_scale = Vector2(0.65, 0.28)
			pb.add_child(mtn_trees_1_layer)
			var mtn_trees_1_sprite := Sprite2D.new()
			mtn_trees_1_sprite.name = "MtnTrees1Sprite"
			var mtn_trees_1_tex := load(MOUNTAIN_PARALLAX_DIR + "mountain_biom_trees1.png")
			if mtn_trees_1_tex:
				mtn_trees_1_sprite.texture = mtn_trees_1_tex
			mtn_trees_1_sprite.centered = false
			mtn_trees_1_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			mtn_trees_1_layer.add_child(mtn_trees_1_sprite)
			if mtn_trees_1_tex and mtn_trees_1_tex is Texture2D:
				mtn_trees_1_layer.motion_mirroring = Vector2(float((mtn_trees_1_tex as Texture2D).get_width()), 0.0)
		"forest":
			var mountains_layer := ParallaxLayer.new()
			mountains_layer.name = "ForestMountains"
			mountains_layer.z_index = -12
			mountains_layer.position = Vector2(0, -200)
			mountains_layer.motion_scale = Vector2(0.05, 0.0)
			pb.add_child(mountains_layer)
			var mountains_sprite := Sprite2D.new()
			mountains_sprite.name = "MountainsSprite"
			var mountains_tex := load("res://background/parallax/forest parallax/forest parallax mountain.png")
			if mountains_tex:
				mountains_sprite.texture = mountains_tex
			mountains_sprite.centered = false
			mountains_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			mountains_layer.add_child(mountains_sprite)
			if mountains_tex and mountains_tex is Texture2D:
				var mw := (mountains_tex as Texture2D).get_width()
				mountains_layer.motion_mirroring = Vector2(float(mw), 0.0)

			var trees_layer := ParallaxLayer.new()
			trees_layer.name = "ForestTrees"
			trees_layer.z_index = -9
			trees_layer.position = Vector2(0, -350)
			trees_layer.motion_scale = Vector2(0.15, 0.060)
			pb.add_child(trees_layer)
			var trees_sprite := Sprite2D.new()
			trees_sprite.name = "TreesSprite"
			var trees_tex := load("res://background/parallax/forest parallax/forest parallax trees.png")
			if trees_tex:
				trees_sprite.texture = trees_tex
			trees_sprite.centered = false
			trees_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			trees_layer.add_child(trees_sprite)
			if trees_tex and trees_tex is Texture2D:
				var tw := (trees_tex as Texture2D).get_width()
				trees_layer.motion_mirroring = Vector2(float(tw), 0.0)

			var trees_front_layer := ParallaxLayer.new()
			trees_front_layer.name = "ForestTreesFront"
			trees_front_layer.z_index = -8
			trees_front_layer.position = Vector2(0, -400)
			trees_front_layer.motion_scale = Vector2(0.35, 0.100)
			pb.add_child(trees_front_layer)
			var trees_front_sprite := Sprite2D.new()
			trees_front_sprite.name = "TreesFrontSprite"
			var trees_front_tex := load("res://background/parallax/forest parallax/forest parallax trees_front.png")
			if trees_front_tex:
				trees_front_sprite.texture = trees_front_tex
			trees_front_sprite.centered = false
			trees_front_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			trees_front_layer.add_child(trees_front_sprite)
			if trees_front_tex and trees_front_tex is Texture2D:
				var tfw := (trees_front_tex as Texture2D).get_width()
				trees_front_layer.motion_mirroring = Vector2(float(tfw), 0.0)
		_:
			var mountains_layer := ParallaxLayer.new()
			mountains_layer.name = "ForestMountains"
			mountains_layer.z_index = -12
			mountains_layer.position = Vector2(0, -200)
			mountains_layer.motion_scale = Vector2(0.05, 0.0)
			pb.add_child(mountains_layer)
			var mountains_sprite := Sprite2D.new()
			mountains_sprite.name = "MountainsSprite"
			var mountains_tex := load("res://background/parallax/forest parallax/forest parallax mountain.png")
			if mountains_tex:
				mountains_sprite.texture = mountains_tex
			mountains_sprite.centered = false
			mountains_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			mountains_layer.add_child(mountains_sprite)
			if mountains_tex and mountains_tex is Texture2D:
				var mw := (mountains_tex as Texture2D).get_width()
				mountains_layer.motion_mirroring = Vector2(float(mw), 0.0)

			var trees_layer := ParallaxLayer.new()
			trees_layer.name = "ForestTrees"
			trees_layer.z_index = -9
			trees_layer.position = Vector2(0, -350)
			trees_layer.motion_scale = Vector2(0.15, 0.060)
			pb.add_child(trees_layer)
			var trees_sprite := Sprite2D.new()
			trees_sprite.name = "TreesSprite"
			var trees_tex := load("res://background/parallax/forest parallax/forest parallax trees.png")
			if trees_tex:
				trees_sprite.texture = trees_tex
			trees_sprite.centered = false
			trees_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			trees_layer.add_child(trees_sprite)
			if trees_tex and trees_tex is Texture2D:
				var tw := (trees_tex as Texture2D).get_width()
				trees_layer.motion_mirroring = Vector2(float(tw), 0.0)

			var trees_front_layer := ParallaxLayer.new()
			trees_front_layer.name = "ForestTreesFront"
			trees_front_layer.z_index = -8
			trees_front_layer.position = Vector2(0, -400)
			trees_front_layer.motion_scale = Vector2(0.35, 0.100)
			pb.add_child(trees_front_layer)
			var trees_front_sprite := Sprite2D.new()
			trees_front_sprite.name = "TreesFrontSprite"
			var trees_front_tex := load("res://background/parallax/forest parallax/forest parallax trees_front.png")
			if trees_front_tex:
				trees_front_sprite.texture = trees_front_tex
			trees_front_sprite.centered = false
			trees_front_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			trees_front_layer.add_child(trees_front_sprite)
			if trees_front_tex and trees_front_tex is Texture2D:
				var tfw := (trees_front_tex as Texture2D).get_width()
				trees_front_layer.motion_mirroring = Vector2(float(tfw), 0.0)

	if biome_type == "forest":
		var biom_trees_1_layer := ParallaxLayer.new()
		biom_trees_1_layer.name = "ForestBiomTrees1"
		biom_trees_1_layer.z_index = -5
		biom_trees_1_layer.position = Vector2(0, -520)
		biom_trees_1_layer.motion_scale = Vector2(0.70, 0.28)
		pb.add_child(biom_trees_1_layer)
		var biom_trees_1_sprite := Sprite2D.new()
		biom_trees_1_sprite.name = "BiomTrees1Sprite"
		var biom_trees_1_tex := load("res://background/parallax/forest parallax/forest_biom_trees_1.png")
		if biom_trees_1_tex:
			biom_trees_1_sprite.texture = biom_trees_1_tex
		biom_trees_1_sprite.centered = false
		biom_trees_1_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		biom_trees_1_layer.add_child(biom_trees_1_sprite)
		if biom_trees_1_tex and biom_trees_1_tex is Texture2D:
			var b1w := (biom_trees_1_tex as Texture2D).get_width()
			biom_trees_1_layer.motion_mirroring = Vector2(float(b1w), 0.0)

		var biom_trees_2_layer := ParallaxLayer.new()
		biom_trees_2_layer.name = "ForestBiomTrees2"
		biom_trees_2_layer.z_index = -6
		biom_trees_2_layer.position = Vector2(0, -510)
		biom_trees_2_layer.motion_scale = Vector2(0.58, 0.22)
		pb.add_child(biom_trees_2_layer)
		var biom_trees_2_sprite := Sprite2D.new()
		biom_trees_2_sprite.name = "BiomTrees2Sprite"
		var biom_trees_2_tex := load("res://background/parallax/forest parallax/forest_biom_trees_2.png")
		if biom_trees_2_tex:
			biom_trees_2_sprite.texture = biom_trees_2_tex
		biom_trees_2_sprite.centered = false
		biom_trees_2_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		biom_trees_2_layer.add_child(biom_trees_2_sprite)
		if biom_trees_2_tex and biom_trees_2_tex is Texture2D:
			var b2w := (biom_trees_2_tex as Texture2D).get_width()
			biom_trees_2_layer.motion_mirroring = Vector2(float(b2w), 0.0)

		var biom_trees_3_layer := ParallaxLayer.new()
		biom_trees_3_layer.name = "ForestBiomTrees3"
		biom_trees_3_layer.z_index = -7
		biom_trees_3_layer.position = Vector2(0, -500)
		biom_trees_3_layer.motion_scale = Vector2(0.48, 0.12)
		pb.add_child(biom_trees_3_layer)
		var biom_trees_3_sprite := Sprite2D.new()
		biom_trees_3_sprite.name = "BiomTrees3Sprite"
		var biom_trees_3_tex := load("res://background/parallax/forest parallax/forest_biom_trees_3.png")
		if biom_trees_3_tex:
			biom_trees_3_sprite.texture = biom_trees_3_tex
		biom_trees_3_sprite.centered = false
		biom_trees_3_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		biom_trees_3_layer.add_child(biom_trees_3_sprite)
		if biom_trees_3_tex and biom_trees_3_tex is Texture2D:
			var b3w := (biom_trees_3_tex as Texture2D).get_width()
			biom_trees_3_layer.motion_mirroring = Vector2(float(b3w), 0.0)

	# Optional: simple clouds layer using same manager if available later
	# Cloud parallax layers - behind forest parallax but in front of CanvasModulate
	# Spawn behind mountains (-12)
	var layer_far := ParallaxLayer.new(); layer_far.name = "ParallaxLayerFar"; layer_far.z_index = -13; layer_far.position = Vector2(0, -1); layer_far.motion_scale = Vector2(0.0, 0.02); pb.add_child(layer_far)
	var layer_mid := ParallaxLayer.new(); layer_mid.name = "ParallaxLayerMid"; layer_mid.z_index = -13; layer_mid.position = Vector2(0, -1); layer_mid.motion_scale = Vector2(0.0, 0.02); pb.add_child(layer_mid)
	var layer_near := ParallaxLayer.new(); layer_near.name = "ParallaxLayerNear"; layer_near.z_index = -13; layer_near.position = Vector2(0, -1); layer_near.motion_scale = Vector2(0.0, 0.02); pb.add_child(layer_near)

	# CloudManager from village
	var cloud_manager := Node2D.new(); cloud_manager.name = "CloudManager"; cloud_manager.z_index = -3
	var cloud_script := load("res://levels/ForestCloudManager.gd")
	if cloud_script:
		cloud_manager.set_script(cloud_script)
		cloud_manager.set("cloud_scene", load("res://village/scenes/cloud.tscn"))
		cloud_manager.set("cloud_textures", [
			load("res://village/assets/clouds/cloud1.png"),
			load("res://village/assets/clouds/cloud2.png"),
			load("res://village/assets/clouds/cloud3.png"),
			load("res://village/assets/clouds/cloud4.png"),
			load("res://village/assets/clouds/cloud5.png"),
			load("res://village/assets/clouds/cloud6.png"),
			load("res://village/assets/clouds/cloud7.png"),
			load("res://village/assets/clouds/cloud8.png")
		])
		cloud_manager.set("parallax_layer_paths", [
			NodePath("../ParallaxBackground/ParallaxLayerFar"),
			NodePath("../ParallaxBackground/ParallaxLayerMid"),
			NodePath("../ParallaxBackground/ParallaxLayerNear")
		])
		cloud_manager.set("min_spawn_interval", 5.0)
		cloud_manager.set("max_spawn_interval", 20.0)
		cloud_manager.set("cloud_y_position_min", -275.0)
		cloud_manager.set("cloud_y_position_max", -175.0)
	add_child(cloud_manager)
	# Kick one immediate spawn to verify visibility without relying on timer init
	cloud_manager.call_deferred("_spawn_cloud")
	
	# RainEffect ekle (yağmur sistemi için)
	var rain_effect_scene := load("res://village/scenes/RainEffect.tscn") as PackedScene
	if rain_effect_scene:
		var rain_effect: Node2D = rain_effect_scene.instantiate() as Node2D
		if rain_effect:
			rain_effect.name = "RainEffect"
			rain_effect.position = Vector2(0, -800)  # Köy sahnesindekiyle aynı pozisyon
			add_child(rain_effect)
			print("[ForestLevelGenerator] RainEffect added to forest scene")
	
	# Uçuşan yapraklar (rüzgar yönüne uygun; leaf_textures leaves klasöründen otomatik yüklenir)
	var fl_script := load("res://village/scripts/FlyingLeavesController.gd") as GDScript
	var leaf_scene := load("res://village/scenes/FlyingLeaf.tscn") as PackedScene
	if fl_script and leaf_scene:
		var fl_controller := Node2D.new()
		fl_controller.name = "FlyingLeavesController"
		fl_controller.set_script(fl_script)
		fl_controller.set("leaf_scene", leaf_scene)
		fl_controller.z_index = 22
		add_child(fl_controller)

# --- Backtracking helpers ---
func _record_entry(node: Node2D, key: String) -> int:
	var entry: Dictionary = {
		"key": key,
		"position": node.position,
		"size": _get_size(node),
		"left": _get_conn_local(node, "left"),
		"right": _get_conn_local(node, "right"),
		"up": _get_conn_local(node, "up"),
		"down": _get_conn_local(node, "down"),
		"seed": randi(), # keep per-entry seed if stochastic content appears later
		"prev": -1,
		"next": -1,
		"scene_path": (node.get_scene_file_path() if node.has_method("get_scene_file_path") else "")
	}
	chunk_entries.append(entry)
	var idx: int = chunk_entries.size() - 1
	node.set_meta("entry_index", idx)
	index_to_node[idx] = node
	last_active_index = idx
	max_discovered_index = max(max_discovered_index, idx)
	if debug_enabled:
		_dbg("[Archive] added idx=" + str(idx) + " key=" + key + " pos=" + str(node.position))
	return idx

func _link_after(prev_idx: int, new_idx: int) -> void:
	if prev_idx >= 0 and prev_idx < chunk_entries.size():
		chunk_entries[prev_idx]["next"] = new_idx
	if new_idx >= 0 and new_idx < chunk_entries.size():
		chunk_entries[new_idx]["prev"] = prev_idx

func _link_before(target_idx: int, new_idx: int) -> void:
	var old_prev := -1
	if target_idx >= 0 and target_idx < chunk_entries.size():
		old_prev = int(chunk_entries[target_idx].get("prev", -1))
		chunk_entries[target_idx]["prev"] = new_idx
	if new_idx >= 0 and new_idx < chunk_entries.size():
		chunk_entries[new_idx]["next"] = target_idx
		chunk_entries[new_idx]["prev"] = old_prev
	if old_prev != -1:
		chunk_entries[old_prev]["next"] = new_idx

func _ensure_back_coverage() -> void:
	if active_chunks.size() == 0:
		return
	var need_from_x: float = player.global_position.x - float(unit_size) * 6.0
	while active_chunks.size() > 0 and active_chunks[0].position.x > need_from_x and first_active_index > 0:
		var idx: int = first_active_index - 1
		var node: Node2D = _spawn_from_archive(idx)
		if node:
			active_chunks.insert(0, node)
			first_active_index = idx
		else:
			break

func _spawn_from_archive(idx: int) -> Node2D:
	if idx < 0 or idx >= chunk_entries.size():
		return null
	if index_to_node.has(idx):
		var cached = index_to_node[idx]
		if cached != null and is_instance_valid(cached):
			return cached
	var entry: Dictionary = chunk_entries[idx]
	var key: String = String(entry.get("key", "linear"))
	var scene: PackedScene = null
	var stored_path: String = String(entry.get("scene_path", ""))
	if stored_path != "":
		scene = load(stored_path) as PackedScene
	else:
		var arr = scenes.get(key, [])
		if typeof(arr) == TYPE_ARRAY and (arr as Array).size() > 0:
			scene = (arr as Array)[randi() % (arr as Array).size()]
	if not scene:
		return null
	var inst: Node2D = scene.instantiate() as Node2D
	add_child(inst)
	inst.position = entry.get("position", Vector2.ZERO)
	inst.set_meta("entry_index", idx)
	_apply_unit_size(inst)
	# Rebuild archived chunk content gradually to avoid frame spikes.
	_queue_chunk_postprocess(inst)
	# Optional future: apply stored seed to any stochastic sub-systems in the chunk
	if inst.has_method("set_meta") and entry.has("seed"):
		inst.set_meta("seed", entry["seed"]) 
	# Restore connection anchors if needed
	var leftp := inst.get_node_or_null("ConnectionPoints/left")
	if leftp and leftp is Node2D:
		(leftp as Node2D).position = entry.get("left", (leftp as Node2D).position)
	var rightp := inst.get_node_or_null("ConnectionPoints/right")
	if rightp and rightp is Node2D:
		(rightp as Node2D).position = entry.get("right", (rightp as Node2D).position)
	var upp := inst.get_node_or_null("ConnectionPoints/up")
	if upp and upp is Node2D:
		(upp as Node2D).position = entry.get("up", (upp as Node2D).position)
	var downp := inst.get_node_or_null("ConnectionPoints/down")
	if downp and downp is Node2D:
		(downp as Node2D).position = entry.get("down", (downp as Node2D).position)
	index_to_node[idx] = inst
	return inst

func _sweep_invalid_active_chunks() -> void:
	for i in range(active_chunks.size() - 1, -1, -1):
		var n := active_chunks[i]
		if n == null or not is_instance_valid(n):
			active_chunks.remove_at(i)

func _sort_active_by_x() -> void:
	if active_chunks.size() <= 1:
		return
	active_chunks.sort_custom(Callable(self, "_cmp_by_x"))

func _cmp_by_x(a, b) -> bool:
	if a == null or not is_instance_valid(a):
		return true
	if b == null or not is_instance_valid(b):
		return false
	return (a as Node2D).position.x < (b as Node2D).position.x
# Apply generator unit_size to known chunk types
func _apply_unit_size(inst: Node2D) -> void:
	if inst is ForestLinearChunk:
		(inst as ForestLinearChunk).unit_size = unit_size
	elif inst is ForestRampChunk:
		(inst as ForestRampChunk).unit_size = unit_size

# Try restore one chunk from archive to the left of current leftmost
func _restore_left_once() -> bool:
	if active_chunks.size() == 0:
		return false
	var left_node: Node2D = active_chunks[0]
	var left_idx: int = int(left_node.get_meta("entry_index") if left_node.has_meta("entry_index") else -1)
	if left_idx < 0 or left_idx >= chunk_entries.size():
		if debug_enabled:
			_dbg("[RestoreLeft] no more left to restore (left_idx<=0)")
		return false
	var target_idx: int = int(chunk_entries[left_idx].get("prev", -1))
	if target_idx == -1:
		if debug_enabled:
			_dbg("[RestoreLeft] prev link is -1 for left_idx=" + str(left_idx))
		return false
	# If prev is known but not discovered yet (index >= chunk_entries.size()), stop
	if target_idx >= chunk_entries.size():
		if debug_enabled:
			_dbg("[RestoreLeft] prev link points beyond discovered: target_idx=" + str(target_idx))
		return false
	if index_to_node.has(target_idx):
		var cached = index_to_node[target_idx]
		if cached != null and is_instance_valid(cached):
			if not active_chunks.has(cached):
				active_chunks.insert(0, cached)
				if debug_enabled:
					_dbg("[RestoreLeft] target alive but not active, inserted idx=" + str(target_idx))
			else:
				if debug_enabled:
					_dbg("[RestoreLeft] target already active idx=" + str(target_idx))
			return true
	var node: Node2D = _spawn_from_archive(target_idx)
	if node:
		active_chunks.insert(0, node)
		first_active_index = min(first_active_index, target_idx)
		if debug_enabled:
			_dbg("[RestoreLeft] restored idx=" + str(target_idx))
		return true
	if debug_enabled:
		_dbg("[RestoreLeft] failed to spawn idx=" + str(target_idx))
	return false

# Try restore one chunk from archive to the right of current rightmost
func _restore_right_once() -> bool:
	if active_chunks.size() == 0:
		return false
	var right_node: Node2D = active_chunks.back()
	var right_idx: int = int(right_node.get_meta("entry_index") if right_node.has_meta("entry_index") else -1)
	if right_idx < 0 or right_idx >= chunk_entries.size():
		return false
	var target_idx: int = int(chunk_entries[right_idx].get("next", -1))
	if target_idx == -1:
		if debug_enabled:
			_dbg("[RestoreRight] next link is -1 for right_idx=" + str(right_idx))
		return false
	var node: Node2D = _spawn_from_archive(target_idx)
	if node:
		active_chunks.append(node)
		last_end_x = node.position.x + _get_size(node).x
		if debug_enabled:
			_dbg("[RestoreRight] restored idx=" + str(target_idx))
		return true
	if debug_enabled:
		_dbg("[RestoreRight] failed idx=" + str(target_idx))
	return false

# --- Debug helpers ---
func _debug_dump_active_chunks(reason: String) -> void:
	if not debug_enabled:
		return
	print("\n[ForestDebug] Dump due to:", reason)
	var px := -1.0
	if player != null and is_instance_valid(player):
		px = player.global_position.x
	print("  player.x=", px, " current_row=", current_row, " window L/R=", window_left_count, "/", window_right_count)
	for i in range(active_chunks.size()):
		var n: Node2D = active_chunks[i]
		var key := _get_chunk_key(n)
		var sz := _get_size(n)
		var row := int(round(n.position.y / float(unit_size)))
		var cons := _get_chunk_connections(n)
		print("  [", i, "] key=", key, " pos=", n.position, " size=", sz, " row=", row, " cons=", cons)
	print("  last_end_x=", last_end_x, " entries=", chunk_entries.size(), " first_active_index=", first_active_index, " last_active_index=", last_active_index)

func _dbg(msg: String) -> void:
	if not debug_enabled:
		return
	var now := Time.get_ticks_msec()
	if msg == _last_dbg_text and now - _last_dbg_ms < debug_rate_ms:
		return
	_last_dbg_text = msg
	_last_dbg_ms = now
	print(msg)

func _get_chunk_key(n: Node2D) -> String:
	if n.has_meta("entry_index"):
		var idx: int = int(n.get_meta("entry_index"))
		if idx >= 0 and idx < chunk_entries.size():
			var e := chunk_entries[idx]
			return String(e.get("key", "unknown"))
	if "scene_file_path" in n:
		return String(n.scene_file_path).get_file().get_basename()
	return n.get_class()

func _get_chunk_connections(n: Node2D) -> Array:
	var result: Array = []
	if n.has_method("get_available_connections"):
		var arr = n.call("get_available_connections")
		if typeof(arr) == TYPE_ARRAY:
			for d in arr:
				result.append(str(d))
			return result
	# Fallback: try reading a `connections` property if exposed
	var cons = null
	if n.has_method("get"):
		cons = n.get("connections")
	if cons is Array:
		for d in cons:
			result.append(str(d))
	return result

# --- Connection point helpers ---
func _get_conn_global(n: Node2D, name: String) -> Vector2:
	var node := n.get_node_or_null("ConnectionPoints/" + name)
	if node and node is Node2D:
		return (node as Node2D).global_position
	# Fallback to default midpoints if not present
	var sz := _get_size(n)
	match name:
		"left":
			return n.global_position + Vector2(0, sz.y * 0.5)
		"right":
			return n.global_position + Vector2(sz.x, sz.y * 0.5)
		"up":
			return n.global_position + Vector2(sz.x * 0.5, 0)
		"down":
			return n.global_position + Vector2(sz.x * 0.5, sz.y)
	return n.global_position

func _get_conn_local(n: Node2D, name: String) -> Vector2:
	var node := n.get_node_or_null("ConnectionPoints/" + name)
	if node and node is Node2D:
		return (node as Node2D).position
	# Fallback to default midpoints in local space
	var sz := _get_size(n)
	match name:
		"left":
			return Vector2(0, sz.y * 0.5)
		"right":
			return Vector2(sz.x, sz.y * 0.5)
		"up":
			return Vector2(sz.x * 0.5, 0)
		"down":
			return Vector2(sz.x * 0.5, sz.y)
	return Vector2.ZERO

# --- Forest tile-based decoration pass (3-tile wide footprint) ---
func _populate_forest_decorations_for_chunk(chunk_node: Node2D) -> void:
	if chunk_node == null or not is_instance_valid(chunk_node):
		return
	var skip_decor: bool = chunk_node.get_meta("skip_forest_decor", false)
	if skip_decor:
		chunk_node.set_meta("forest_decor_done", true)
		return
	# Ensure we only populate once per chunk lifetime
	if chunk_node.get_meta("forest_decor_done", false):
		return
	var tile_map = chunk_node.find_child("TileMapLayer", true, false)
	if tile_map == null:
		return
	var tile_set: TileSet = null
	if tile_map.has_method("get"): # access as property via get("tile_set") to support TileMapLayer/TileMap
		tile_set = tile_map.get("tile_set")
	if tile_set == null:
		return
	# Find custom data layer index for decor anchors
	var decor_layer_name := "decor_anchor"
	var decor_layer_index := -1
	for i in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(i) == decor_layer_name:
			decor_layer_index = i
			break
	if decor_layer_index == -1:
		return
		
	# Setup deterministic RNG
	var chunk_seed: int = 0
	if chunk_node.has_meta("seed"):
		chunk_seed = int(chunk_node.get_meta("seed"))
	else:
		chunk_seed = randi()
		chunk_node.set_meta("seed", chunk_seed)
		
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed
		
	# Iterate cells and place forest decors on tagged anchors (TileMap layer 0)
	var used_cells: Array[Vector2i] = tile_map.get_used_cells()
	if used_cells.is_empty():
		chunk_node.set_meta("forest_decor_done", true)
		return
	# Prune old global reservations far behind the player
	if player and is_instance_valid(player):
		_forest_tree_prune_px(player.global_position.x - despawn_distance - float(unit_size) * 2.0)
	# Two-pass: first place wide forest_tree (6 tiles), then 3-tile decors
	var placed_span_centers := {} # key by center cell to avoid duplicates and avoid 3-wide overlapping with 6-wide
	# Enforce spacing only for trees: keep at least 2 tiles gap between 6-wide trees on the same row
	var tree_reserved_by_row := {} # row_y -> Array[Vector2i(start_x, end_x)] of reserved ranges
	# --- PASS 1: 6-wide tall trees ---
	for cell in used_cells:
		var td6: TileData = tile_map.get_cell_tile_data(cell) as TileData
		if td6 == null:
			continue
		var tag6 = td6.get_custom_data(decor_layer_name)
		if typeof(tag6) != TYPE_STRING:
			continue
		var tag6s := String(tag6)
		if tag6s != "forest_floor_surface" and tag6s != "floor_surface":
			continue
		# Need 6 consecutive cells: center +- 2 plus edges
		var left2 := cell + Vector2i(-2, 0)
		var left1 := cell + Vector2i(-1, 0)
		var right1 := cell + Vector2i(1, 0)
		var right2 := cell + Vector2i(2, 0)
		var right3 := cell + Vector2i(3, 0)
		# 6-wide span centered between cell and cell+1 (we'll anchor at cell+0.5)
		if not _forest_cell_has_decor_tag(tile_map, left2, decor_layer_name, tag6s):
			continue
		if not _forest_cell_has_decor_tag(tile_map, left1, decor_layer_name, tag6s):
			continue
		if not _forest_cell_has_decor_tag(tile_map, right1, decor_layer_name, tag6s):
			continue
		if not _forest_cell_has_decor_tag(tile_map, right2, decor_layer_name, tag6s):
			continue
		if not _forest_cell_has_decor_tag(tile_map, right3, decor_layer_name, tag6s):
			continue
		# Vertical clearance ~20 tiles
		if not _forest_has_vertical_clearance(tile_map, cell, 6, 20):
			continue
		# Spacing rule: ensure at least 2 tiles gap from previously placed trees around this row (±1)
		var row_y := cell.y
		var span_start_x := left2.x
		var span_end_x := right3.x
		var reserved_start_x := span_start_x - 2
		var reserved_end_x := span_end_x + 2
		var overlaps := false
		for ry in [row_y - 1, row_y, row_y + 1]:
			var existing_ranges: Array = tree_reserved_by_row.get(ry, [])
			for r in existing_ranges:
				if r is Vector2i:
					var rs := (r as Vector2i).x
					var re := (r as Vector2i).y
					if not (reserved_end_x < rs or reserved_start_x > re):
						overlaps = true
						break
			if overlaps:
				break
		if overlaps:
			continue
		# Global cross-chunk spacing in pixels (6 tiles width + 2-tile gap on both sides)
		var ts_vec: Vector2 = Vector2((tile_map.get("tile_set") as TileSet).tile_size)
		var center_left := left2
		var center_right := right3
		var center_px: Vector2 = _forest_compute_span_center(tile_map, center_left, center_right)
		var total_half_width_px: float = (ts_vec.x * 6.0) * 0.5 + (ts_vec.x * 2.0)
		var start_px: float = center_px.x - total_half_width_px
		var end_px: float = center_px.x + total_half_width_px
		if _forest_tree_overlaps_px(start_px, end_px):
			continue
		var key6 := str(cell.x, ":", cell.y, ":6")
		if placed_span_centers.has(key6):
			continue
		# Random gate to keep density low
		if rng.randf() > 0.12:
			continue
		# Queue big tree spawn (pooled spawner, spread over frames)
		var spawn6: Vector2 = center_px
		_forest_tree_debug_seq += 1
		_decor_spawn_queue.append({
			"name": "forest_tree",
			"pos": spawn6,
			"parent": chunk_node,
			"expected_floor_y": center_px.y,
			"anchor_cell": cell,
			"chunk_seed": chunk_seed,
			"chunk_name": chunk_node.name,
			"chunk_pos": chunk_node.global_position,
			"debug_seq": _forest_tree_debug_seq
		})
		placed_span_centers[key6] = true
		# Global reserve this x-interval to prevent overlaps from adjacent chunks
		_forest_tree_reserve_px(start_px, end_px)
		# Record reserved range for spacing on this row
		var row_ranges: Array = tree_reserved_by_row.get(row_y, [])
		row_ranges.append(Vector2i(reserved_start_x, reserved_end_x))
		tree_reserved_by_row[row_y] = row_ranges

	# --- PASS 2: 3-wide decors ---
	var rng_chance := 0.28 # overall placement chance per valid 3-tile span
	var placed_spans := {} # track 3-wide only to avoid duplicates within this pass
	for cell in used_cells:
		var td: TileData = tile_map.get_cell_tile_data(cell) as TileData
		if td == null:
			continue
		var tag = td.get_custom_data(decor_layer_name)
		if typeof(tag) != TYPE_STRING:
			continue
		var tag_s := String(tag)
		if tag_s != "forest_floor_surface" and tag_s != "floor_surface":
			continue
		# Validate 3-tile horizontal span centered at this cell
		var left := cell + Vector2i(-1, 0)
		var right := cell + Vector2i(1, 0)
		if not _forest_cell_has_decor_tag(tile_map, left, decor_layer_name, tag_s):
			continue
		if not _forest_cell_has_decor_tag(tile_map, right, decor_layer_name, tag_s):
			continue
		# Optional vertical clearance for taller assets (e.g., trunks)
		if not _forest_has_vertical_clearance(tile_map, cell, 3, 2):
			# Still allow low-profile assets if ground-only clearance fails; keep trying others
			pass
		# Random gate to reduce density
		if rng.randf() > rng_chance:
			continue
		# Avoid double placement on the same span
		var key := str(cell.x, ":", cell.y)
		if placed_spans.has(key):
			continue
		placed_spans[key] = true
		# Also avoid overlap near previously placed 6-wide trees (simple center proximity check)
		var key6a := str((cell.x - 1), ":", cell.y, ":6")
		var key6b := str(cell.x, ":", cell.y, ":6")
		var key6c := str((cell.x + 1), ":", cell.y, ":6")
		if placed_span_centers.has(key6a) or placed_span_centers.has(key6b) or placed_span_centers.has(key6c):
			continue
		# Pick a forest decor
		var decor_name: String = _forest_pick_decor_name(rng)
		if decor_name.is_empty():
			continue
		# Queue 3-wide decoration spawn
		var spawn_pos: Vector2 = _forest_compute_span_center(tile_map, left, right)
		var debug_seq_local: int = -1
		if decor_name == "forest_trunk":
			_forest_tree_debug_seq += 1
			debug_seq_local = _forest_tree_debug_seq
		_decor_spawn_queue.append({
			"name": decor_name,
			"pos": spawn_pos,
			"parent": chunk_node,
			"expected_floor_y": spawn_pos.y,
			"anchor_cell": cell,
			"chunk_seed": chunk_seed,
			"chunk_name": chunk_node.name,
			"chunk_pos": chunk_node.global_position,
			"debug_seq": debug_seq_local
		})

	# --- PASS 3: küçük çiçekler (yalnızca orman biomu) ---
	if biome_type == "forest":
		var flower_placed_cells := {}
		for cell_f in used_cells:
			var td_f: TileData = tile_map.get_cell_tile_data(cell_f) as TileData
			if td_f == null:
				continue
			var tag_f = td_f.get_custom_data(decor_layer_name)
			if typeof(tag_f) != TYPE_STRING:
				continue
			var tag_fs := String(tag_f)
			if tag_fs != "forest_floor_surface" and tag_fs != "floor_surface":
				continue
			if rng.randf() > FOREST_FLOWER_SPAWN_CHANCE:
				continue
			var flower_key := str(cell_f.x, ":", cell_f.y)
			if flower_placed_cells.has(flower_key):
				continue
			flower_placed_cells[flower_key] = true
			var ts_flower: Vector2 = Vector2(tile_set.tile_size)
			var flower_pos: Vector2 = _forest_compute_cell_floor_pos(tile_map, cell_f)
			flower_pos.x += rng.randf_range(-ts_flower.x * 0.28, ts_flower.x * 0.28)
			_decor_spawn_queue.append({
				"name": "forest_flower",
				"pos": flower_pos,
				"parent": chunk_node,
				"expected_floor_y": flower_pos.y,
				"anchor_cell": cell_f,
				"chunk_seed": chunk_seed,
				"chunk_name": chunk_node.name,
				"chunk_pos": chunk_node.global_position
			})

		if biome_type == "forest":
			_spawn_forest_butterflies_for_chunk(chunk_node, tile_map, rng, decor_layer_name)
			_spawn_forest_night_lighting_for_chunk(chunk_node, tile_map, rng, decor_layer_name)
			_spawn_forest_fireflies_for_chunk(chunk_node, tile_map, rng, decor_layer_name)

	# Mark done for this chunk
	chunk_node.set_meta("forest_decor_done", true)

func _spawn_forest_night_lighting_for_chunk(
	chunk_node: Node2D,
	tile_map,
	rng: RandomNumberGenerator,
	decor_layer_name: String
) -> void:
	if chunk_node.get_meta("is_start_chunk", false):
		return
	var used_cells: Array = tile_map.get_used_cells()
	if used_cells.is_empty():
		return
	var tile_set: TileSet = tile_map.tile_set
	if tile_set == null:
		return
	var placed_mushrooms: Array[Vector2] = []
	var placed_camps: Array[Vector2] = []
	var floor_cells: Array[Vector2i] = []
	for cell in used_cells:
		var td: TileData = tile_map.get_cell_tile_data(cell) as TileData
		if td == null:
			continue
		var tag = td.get_custom_data(decor_layer_name)
		if typeof(tag) != TYPE_STRING:
			continue
		var tag_s := String(tag)
		if tag_s != "forest_floor_surface" and tag_s != "floor_surface":
			continue
		floor_cells.append(cell)
	if floor_cells.is_empty():
		return
	floor_cells.shuffle()
	var chunk_seed: int = int(chunk_node.get_meta("chunk_seed", hash(chunk_node.name)))
	if rng.randf() <= FOREST_CAMP_SPAWN_CHANCE:
		var camp_attempts: int = mini(12, floor_cells.size())
		for i in range(camp_attempts):
			var camp_cell: Vector2i = floor_cells[(rng.randi() + i) % floor_cells.size()]
			var camp_pos: Vector2 = _forest_compute_cell_floor_pos(tile_map, camp_cell)
			var camp_name: String = "camp2" if rng.randf() < 0.55 else "camp1"
			if DecorationConfig.forest_lighting_too_close(camp_pos, placed_camps, DecorationConfig.FOREST_CAMP_MIN_DISTANCE_PX):
				continue
			_spawn_forest_decor_from_job({
				"name": camp_name,
				"pos": camp_pos,
				"parent": chunk_node,
				"expected_floor_y": camp_pos.y,
				"anchor_cell": camp_cell,
				"chunk_seed": chunk_seed,
				"chunk_name": chunk_node.name,
				"chunk_pos": chunk_node.global_position
			})
			placed_camps.append(camp_pos)
			break
	var mushrooms_spawned: int = 0
	for cell_m in floor_cells:
		if mushrooms_spawned >= FOREST_MUSHROOMS_PER_CHUNK_MAX:
			break
		if rng.randf() > FOREST_MUSHROOM_SPAWN_CHANCE:
			continue
		var mushroom_pos: Vector2 = _forest_compute_cell_floor_pos(tile_map, cell_m)
		var ts_m: Vector2 = Vector2(tile_set.tile_size)
		mushroom_pos.x += rng.randf_range(-ts_m.x * 0.22, ts_m.x * 0.22)
		if DecorationConfig.forest_lighting_too_close(mushroom_pos, placed_mushrooms):
			continue
		if not placed_camps.is_empty() and DecorationConfig.forest_lighting_too_close(mushroom_pos, placed_camps, 280.0):
			continue
		_spawn_forest_decor_from_job({
			"name": "forest_glow_mushroom",
			"pos": mushroom_pos,
			"parent": chunk_node,
			"expected_floor_y": mushroom_pos.y,
			"anchor_cell": cell_m,
			"chunk_seed": chunk_seed,
			"chunk_name": chunk_node.name,
			"chunk_pos": chunk_node.global_position
		})
		placed_mushrooms.append(mushroom_pos)
		mushrooms_spawned += 1


func _spawn_forest_fireflies_for_chunk(
	chunk_node: Node2D,
	tile_map,
	rng: RandomNumberGenerator,
	decor_layer_name: String
) -> void:
	if FOREST_FIREFLY_SCENE == null:
		return
	if chunk_node.get_meta("is_start_chunk", false):
		return
	var chunk_sz: Vector2 = _get_size(chunk_node)
	if chunk_sz.x < 320.0:
		return
	var floor_y: float = _forest_estimate_floor_y(tile_map, rng, decor_layer_name)
	if is_nan(floor_y):
		floor_y = chunk_node.global_position.y + chunk_sz.y * 0.35
	var count: int = rng.randi_range(FOREST_FIREFLY_PER_CHUNK_MIN, FOREST_FIREFLY_PER_CHUNK_MAX)
	var margin_x: float = 120.0
	var x0: float = chunk_node.global_position.x + margin_x
	var x1: float = chunk_node.global_position.x + chunk_sz.x - margin_x
	if x1 <= x0:
		x0 = chunk_node.global_position.x + 80.0
		x1 = chunk_node.global_position.x + chunk_sz.x - 80.0
	var y_top: float = floor_y - FOREST_FIREFLY_MAX_CLEARANCE
	var y_bottom: float = floor_y - FOREST_FIREFLY_MIN_CLEARANCE
	var fly_zone := Rect2(x0, y_top, maxf(32.0, x1 - x0), maxf(20.0, y_bottom - y_top))
	for _i in range(count):
		var inst: Node2D = FOREST_FIREFLY_SCENE.instantiate() as Node2D
		if inst == null:
			continue
		inst.set_meta("fly_zone", fly_zone)
		inst.set_meta("fly_floor_y", floor_y)
		inst.set_meta("fly_min_clearance", FOREST_FIREFLY_MIN_CLEARANCE)
		inst.set_meta("fly_max_clearance", FOREST_FIREFLY_MAX_CLEARANCE)
		if inst.has_method("configure_flight"):
			inst.call(
				"configure_flight",
				fly_zone,
				floor_y,
				FOREST_FIREFLY_MIN_CLEARANCE,
				FOREST_FIREFLY_MAX_CLEARANCE
			)
		chunk_node.add_child(inst)


func _spawn_forest_butterflies_for_chunk(
	chunk_node: Node2D,
	tile_map,
	rng: RandomNumberGenerator,
	decor_layer_name: String
) -> void:
	if FOREST_BUTTERFLY_SCENE == null:
		return
	var chunk_sz: Vector2 = _get_size(chunk_node)
	if chunk_sz.x < 320.0:
		return
	var floor_y: float = _forest_estimate_floor_y(tile_map, rng, decor_layer_name)
	if is_nan(floor_y):
		floor_y = chunk_node.global_position.y + chunk_sz.y * 0.35
	var count: int = rng.randi_range(FOREST_BUTTERFLIES_PER_CHUNK_MIN, FOREST_BUTTERFLIES_PER_CHUNK_MAX)
	var margin_x: float = 140.0
	var x0: float = chunk_node.global_position.x + margin_x
	var x1: float = chunk_node.global_position.x + chunk_sz.x - margin_x
	if x1 <= x0:
		x0 = chunk_node.global_position.x + 80.0
		x1 = chunk_node.global_position.x + chunk_sz.x - 80.0
	var y_top: float = floor_y - FOREST_BUTTERFLY_MAX_CLEARANCE
	var y_bottom: float = floor_y - FOREST_BUTTERFLY_MIN_CLEARANCE
	var fly_zone := Rect2(x0, y_top, maxf(32.0, x1 - x0), maxf(24.0, y_bottom - y_top))
	for _i in range(count):
		var inst: Node2D = FOREST_BUTTERFLY_SCENE.instantiate() as Node2D
		if inst == null:
			continue
		inst.set_meta("fly_zone", fly_zone)
		inst.set_meta("fly_floor_y", floor_y)
		inst.set_meta("fly_min_clearance", FOREST_BUTTERFLY_MIN_CLEARANCE)
		inst.set_meta("fly_max_clearance", FOREST_BUTTERFLY_MAX_CLEARANCE)
		chunk_node.add_child(inst)
		if inst.has_method("configure_flight"):
			inst.call(
				"configure_flight",
				fly_zone,
				floor_y,
				FOREST_BUTTERFLY_MIN_CLEARANCE,
				FOREST_BUTTERFLY_MAX_CLEARANCE
			)
		else:
			inst.global_position = Vector2(
				randf_range(x0, x1),
				randf_range(y_top, y_bottom)
			)

func _forest_estimate_floor_y(
	tile_map,
	rng: RandomNumberGenerator,
	decor_layer_name: String
) -> float:
	var used_cells: Array[Vector2i] = tile_map.get_used_cells()
	if used_cells.is_empty():
		return NAN
	var sum_y: float = 0.0
	var samples: int = 0
	var tries: int = 0
	while samples < 10 and tries < 48:
		tries += 1
		var cell: Vector2i = used_cells[rng.randi() % used_cells.size()]
		var td: TileData = tile_map.get_cell_tile_data(cell) as TileData
		if td == null:
			continue
		var tag = td.get_custom_data(decor_layer_name)
		if typeof(tag) != TYPE_STRING:
			continue
		var tag_s := String(tag)
		if tag_s != "forest_floor_surface" and tag_s != "floor_surface":
			continue
		sum_y += _forest_compute_cell_floor_pos(tile_map, cell).y
		samples += 1
	if samples <= 0:
		return NAN
	return sum_y / float(samples)

func _forest_cell_has_decor_tag(tile_map, cell: Vector2i, layer_name: String, expected: String) -> bool:
	var td: TileData = tile_map.get_cell_tile_data(cell) as TileData
	if td == null:
		return false
	var tag = td.get_custom_data(layer_name)
	if typeof(tag) != TYPE_STRING:
		return false
	var s := String(tag)
	return (s == expected or s == "forest_floor_surface" or s == "floor_surface")

func _forest_has_vertical_clearance(tile_map, center: Vector2i, w_tiles: int, h_tiles: int) -> bool:
	# Ensure empty space above the base row for tall decors across the span
	var half_left := int(floor((w_tiles - 1) / 2.0))
	var half_right := w_tiles - 1 - half_left
	for dy in range(1, h_tiles + 1):
		for dx in range(-half_left, half_right + 1):
			var c := center + Vector2i(dx, -dy)
			var sid: int = int(tile_map.get_cell_source_id(c))
			if sid != -1:
				return false
	return true

## Span ortası X; Y = span içindeki dolu zemin karolarının ÜST kenarı ortalaması (tek hucre outlier azaltır).
func _forest_compute_span_center(tile_map, left_cell: Vector2i, right_cell: Vector2i) -> Vector2:
	var ts: Vector2 = Vector2((tile_map.get("tile_set") as TileSet).tile_size)
	var left_tl: Vector2 = tile_map.to_global(tile_map.map_to_local(left_cell))
	var right_tl: Vector2 = tile_map.to_global(tile_map.map_to_local(right_cell))
	var left_cx: float = left_tl.x + ts.x * 0.5
	var right_cx: float = right_tl.x + ts.x * 0.5
	var mid_x: float = (left_cx + right_cx) * 0.5
	var x0: int = mini(left_cell.x, right_cell.x)
	var x1: int = maxi(left_cell.x, right_cell.x)
	var sum_top_y: float = 0.0
	var count_top: int = 0
	for cx in range(x0, x1 + 1):
		var c := Vector2i(cx, left_cell.y)
		if tile_map.get_cell_tile_data(c) == null:
			continue
		sum_top_y += tile_map.to_global(tile_map.map_to_local(c)).y
		count_top += 1
	var floor_top_y: float = left_tl.y
	if count_top > 0:
		floor_top_y = sum_top_y / float(count_top)
	return Vector2(mid_x, floor_top_y)

func _forest_compute_cell_floor_pos(tile_map, cell: Vector2i) -> Vector2:
	var ts: Vector2 = Vector2((tile_map.get("tile_set") as TileSet).tile_size)
	var top_left: Vector2 = tile_map.to_global(tile_map.map_to_local(cell))
	return Vector2(top_left.x + ts.x * 0.5, top_left.y)

func _forest_tree_sprite_bottom_global_y(spr: Sprite2D) -> float:
	if spr == null:
		return NAN
	var r: Rect2 = spr.get_rect()
	var bottom_center := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y)
	return spr.to_global(bottom_center).y

func _forest_tree_measure_and_fix(tree_node: Node2D, job: Dictionary, phase: String) -> void:
	if tree_node == null or not is_instance_valid(tree_node):
		return
	var decor_name: String = String(job.get("name", tree_node.name))
	var expected_floor_y: float = float(job.get("expected_floor_y", tree_node.global_position.y))
	var spr: Sprite2D = tree_node.get_node_or_null("Sprite") as Sprite2D
	var visual_bottom_y: float = _forest_tree_sprite_bottom_global_y(spr)
	if is_nan(visual_bottom_y):
		visual_bottom_y = tree_node.global_position.y
	var delta_y: float = expected_floor_y - visual_bottom_y
	var snap_threshold: float = 4.0
	var seq: int = int(job.get("debug_seq", -1))
	if DEBUG_FOREST_TREE_SPAWN:
		var always_line: bool = (phase == "immediate") or (abs(delta_y) > 0.75)
		if always_line:
			print("[ForestTree] type=", decor_name, " seq=", seq, " phase=", phase,
				" drift=", snapped(delta_y, 0.01),
				" exp_y=", snapped(expected_floor_y, 0.01),
				" bottom_y=", snapped(visual_bottom_y, 0.01),
				" root_y=", snapped(tree_node.global_position.y, 0.01),
				" chunk=", job.get("chunk_name", "?"),
				" chunk_pos=", job.get("chunk_pos", Vector2.ZERO),
				" anchor=", job.get("anchor_cell", Vector2i.ZERO))
	if abs(delta_y) > snap_threshold:
		tree_node.global_position.y += delta_y
		if DEBUG_FOREST_TREE_SPAWN:
			print("[ForestTree] SNAP type=", decor_name, " seq=", seq, " phase=", phase, " applied_dy=", snapped(delta_y, 0.01),
				" new_root_y=", snapped(tree_node.global_position.y, 0.01))

func _forest_tree_spawn_followup(tree_node: Node2D, job: Dictionary) -> void:
	if tree_node == null or not is_instance_valid(tree_node):
		return
	var instance_id: int = tree_node.get_instance_id()
	await get_tree().process_frame
	var n1: Node2D = instance_from_id(instance_id) as Node2D
	if n1 != null and is_instance_valid(n1):
		_forest_tree_measure_and_fix(n1, job, "frame+1")
	await get_tree().process_frame
	var n2: Node2D = instance_from_id(instance_id) as Node2D
	if n2 != null and is_instance_valid(n2):
		_forest_tree_measure_and_fix(n2, job, "frame+2")
	await get_tree().physics_frame
	var n3: Node2D = instance_from_id(instance_id) as Node2D
	if n3 != null and is_instance_valid(n3):
		_forest_tree_measure_and_fix(n3, job, "after_physics")

func _report_underground_forest_decor_if_any(node: Node2D, job: Dictionary) -> void:
	if not DEBUG_UNDERGROUND_FOREST_DECOR:
		return
	if node == null or not is_instance_valid(node):
		return
	var spr: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		return
	var expected_floor_y: float = float(job.get("expected_floor_y", node.global_position.y))
	var visual_bottom_y: float = _forest_tree_sprite_bottom_global_y(spr)
	if is_nan(visual_bottom_y):
		return
	# Sprite tabani beklenen zeminin belirgin altindaysa "gomulu" kabul et.
	var buried_px: float = visual_bottom_y - expected_floor_y
	if buried_px > 8.0:
		var tex_path: String = ""
		if spr.texture != null:
			tex_path = spr.texture.resource_path
		print("[ForestDecorSuspect] name=", node.name,
			" buried_px=", snapped(buried_px, 0.01),
			" expected_y=", snapped(expected_floor_y, 0.01),
			" bottom_y=", snapped(visual_bottom_y, 0.01),
			" root=", snapped(node.global_position.y, 0.01),
			" tex=", tex_path,
			" chunk=", job.get("chunk_name", "?"),
			" anchor=", job.get("anchor_cell", Vector2i.ZERO))

func _scan_nearby_for_buried_forest_decor() -> void:
	if player == null or not is_instance_valid(player):
		return
	for d in _collect_candidate_forest_decors():
		var dn: String = d.name.to_lower()
		if not dn.begins_with("forest_"):
			continue
		# Sadece oyuncu civarini tara, maliyet dusuk kalsin.
		if abs(d.global_position.x - player.global_position.x) > 1800.0:
			continue
		if abs(d.global_position.y - player.global_position.y) > 1200.0:
			continue
		var spr: Sprite2D = d.get_node_or_null("Sprite") as Sprite2D
		if spr == null:
			continue
		var bottom_y: float = _forest_tree_sprite_bottom_global_y(spr)
		if is_nan(bottom_y):
			continue
		var tile_ground_y: float = _sample_floor_top_y_from_chunk_tilemap(d)
		if is_nan(tile_ground_y):
			continue
		var buried_px: float = bottom_y - tile_ground_y
		if buried_px <= 8.0:
			continue
		var iid: int = d.get_instance_id()
		if _reported_buried_decor_ids.has(iid):
			continue
		_reported_buried_decor_ids[iid] = true
		var tex_path: String = ""
		if spr.texture != null:
			tex_path = spr.texture.resource_path
		print("[ForestDecorSuspectLive] name=", d.name,
			" buried_px=", snapped(buried_px, 0.01),
			" tile_ground_y=", snapped(tile_ground_y, 0.01),
			" bottom_y=", snapped(bottom_y, 0.01),
			" node_pos=", d.global_position,
			" z=", d.z_index,
			" tex=", tex_path)

func _collect_candidate_forest_decors() -> Array[Node2D]:
	var out: Array[Node2D] = []
	var seen: Dictionary = {}
	# 1) Normal background decor grubu
	for n in get_tree().get_nodes_in_group("background_decor"):
		if n is Node2D and is_instance_valid(n):
			var d := n as Node2D
			var id := d.get_instance_id()
			if not seen.has(id):
				seen[id] = true
				out.append(d)
	# 2) Guvenlik: aktif chunk altlarini da tara (gruba girmemis node kacmasin)
	for ch in active_chunks:
		if ch == null or not is_instance_valid(ch):
			continue
		var stack: Array[Node] = [ch]
		while stack.size() > 0:
			var cur: Node = stack.pop_back()
			for c in cur.get_children():
				stack.append(c)
				if c is Node2D:
					var d2 := c as Node2D
					if not is_instance_valid(d2):
						continue
					if not String(d2.name).to_lower().begins_with("forest_"):
						continue
					var id2 := d2.get_instance_id()
					if not seen.has(id2):
						seen[id2] = true
						out.append(d2)
	return out

func _debug_dump_nearby_forest_decor_metrics() -> void:
	if player == null or not is_instance_valid(player):
		return
	print("[ForestDecorDump] ===== START ===== player=", player.global_position)
	var count: int = 0
	for d in _collect_candidate_forest_decors():
		if abs(d.global_position.x - player.global_position.x) > 2200.0:
			continue
		var spr: Sprite2D = d.get_node_or_null("Sprite") as Sprite2D
		var bottom_y: float = _forest_tree_sprite_bottom_global_y(spr)
		var ground_y: float = _sample_floor_top_y_from_chunk_tilemap(d)
		var buried_px: float = NAN
		if not is_nan(bottom_y) and not is_nan(ground_y):
			buried_px = bottom_y - ground_y
		var tex_path: String = ""
		if spr != null and spr.texture != null:
			tex_path = spr.texture.resource_path
		print("[ForestDecorDump] name=", d.name,
			" x=", snapped(d.global_position.x, 0.01),
			" y=", snapped(d.global_position.y, 0.01),
			" bottom=", snapped(bottom_y, 0.01),
			" tile_ground=", snapped(ground_y, 0.01),
			" buried=", snapped(buried_px, 0.01),
			" tex=", tex_path)
		count += 1
		if count >= 40:
			break
	print("[ForestDecorDump] ===== END count=", count, " =====")

func _sample_floor_top_y_from_chunk_tilemap(node: Node2D) -> float:
	var chunk: Node = node
	var tile_map: Node = null
	while chunk != null and chunk != self:
		tile_map = chunk.find_child("TileMapLayer", true, false)
		if tile_map != null:
			break
		chunk = chunk.get_parent()
	if tile_map == null:
		return NAN
	if not tile_map.has_method("local_to_map") or not tile_map.has_method("map_to_local") or not tile_map.has_method("to_global") or not tile_map.has_method("to_local"):
		return NAN
	var local_on_map: Vector2 = tile_map.to_local(node.global_position)
	var center_cell: Vector2i = tile_map.local_to_map(local_on_map)
	var best_score: float = INF
	var best_y: float = NAN
	for dy in range(-8, 9):
		for dx in range(-2, 3):
			var c := center_cell + Vector2i(dx, dy)
			var td: TileData = tile_map.get_cell_tile_data(c) as TileData
			if td == null:
				continue
			var tag = td.get_custom_data("decor_anchor")
			if typeof(tag) != TYPE_STRING:
				continue
			var tag_s := String(tag)
			if tag_s != "forest_floor_surface" and tag_s != "floor_surface":
				continue
			var cell_top_y: float = tile_map.to_global(tile_map.map_to_local(c)).y
			var score: float = abs(float(dx)) * 5.0 + abs(float(dy))
			if score < best_score:
				best_score = score
				best_y = cell_top_y
	return best_y

func _forest_pick_decor_name(rng: RandomNumberGenerator = null) -> String:
	# Weighted random among registered forest background decors
	var cfg := DecorationConfig.new()
	var pool: Dictionary = cfg.get_decorations_for_type(DecorationConfig.DecorationType.BACKGROUND)
	var names = ["forest_bush", "forest_grass", "forest_trunk", "forest_rock"]
	var total := 0
	for n in names:
		if pool.has(n):
			var d: Dictionary = pool.get(n, {})
			total += int(d.get("weight", 1))
	if total <= 0:
		return ""
	var roll: int
	if rng:
		roll = rng.randi() % total
	else:
		roll = randi() % total
	var acc := 0
	for n in names:
		if pool.has(n):
			var d2: Dictionary = pool.get(n, {})
			acc += int(d2.get("weight", 1))
			if roll < acc:
				return n
	return names[0]

## Enemy level rises with horizontal distance from the start chunk (left or right), so streaming
## forest maps still scale difficulty without relying on global dungeon level.
func _forest_effective_enemy_level(chunk_node: Node2D) -> int:
	if chunk_node == null or not is_instance_valid(chunk_node):
		return 1
	if _forest_start_chunk == null or not is_instance_valid(_forest_start_chunk):
		return maxi(1, current_level)
	var start_sz := _get_size(_forest_start_chunk)
	var start_mid_x := _forest_start_chunk.global_position.x + start_sz.x * 0.5
	var ch_sz := _get_size(chunk_node)
	var chunk_mid_x := chunk_node.global_position.x + ch_sz.x * 0.5
	var dist_px := absf(chunk_mid_x - start_mid_x)
	var step := forest_enemy_chunk_width_px
	if step <= 0.0:
		step = float(unit_size) * 2.0
	if step < 1.0:
		step = 1.0
	var chunks_equiv := int(floor(dist_px / step))
	var per := maxi(1, forest_chunks_per_enemy_level)
	# Level 1 near the village/start; each `per` chunk-widths of travel (either direction) +1.
	var from_distance := 1 + (chunks_equiv / per)
	return clampi(from_distance, 1, maxi(1, forest_enemy_max_level))

func _populate_forest_enemies_for_chunk(chunk_node: Node2D) -> void:
	if chunk_node == null or not is_instance_valid(chunk_node):
		return
	if chunk_node.get_meta("forest_enemy_populated", false):
		return
	var _tm := get_node_or_null("/root/TutorialManager")
	if _tm != null and _tm.is_village_tutorial_active() and _tm.village_core_step == 1:
		chunk_node.set_meta("forest_enemy_populated", true)
		return

	var chunk_name := chunk_node.name.to_lower()
	var scene_path := chunk_node.scene_file_path.to_lower() if chunk_node.scene_file_path else ""
	if "start" in chunk_name or "start" in scene_path:
		chunk_node.set_meta("forest_enemy_populated", true)
		return

	var tile_map = chunk_node.find_child("TileMapLayer", true, false)
	if tile_map == null:
		chunk_node.set_meta("forest_enemy_populated", true)
		return

	var tile_set: TileSet = tile_map.get("tile_set")
	if tile_set == null:
		chunk_node.set_meta("forest_enemy_populated", true)
		return

	var used_cells: Array[Vector2i] = tile_map.get_used_cells()
	if used_cells.is_empty():
		chunk_node.set_meta("forest_enemy_populated", true)
		return

	var candidate_cells: Array[Vector2i] = []
	for cell in used_cells:
		var tile_data: TileData = tile_map.get_cell_tile_data(cell) as TileData
		if tile_data == null:
			continue
		var custom_data = tile_data.get_custom_data(FOREST_ENEMY_LAYER_NAME)
		if typeof(custom_data) != TYPE_STRING:
			continue
		var tag := String(custom_data)
		if tag != "forest_floor_surface" and tag != "floor_surface" and tag != "floor":
			continue
		if not _forest_enemy_has_spawn_span(tile_map, cell):
			continue
		if not _forest_enemy_has_height_clearance(tile_map, cell, 4):
			continue
		candidate_cells.append(cell)

	if candidate_cells.is_empty():
		chunk_node.set_meta("forest_enemy_populated", true)
		return

	var eff_level := _forest_effective_enemy_level(chunk_node)
	var spawn_rules := _spawn_config.get_spawn_count("forest", eff_level)
	var min_spawns := int(spawn_rules.get("min_spawns", 2))
	var max_spawns := int(spawn_rules.get("max_spawns", 4))
	var target_count := randi_range(min_spawns, max_spawns)
	# Scale with chunk surface density so streaming forest chunks feel populated.
	var density_bonus := int(floor(float(candidate_cells.size()) / 24.0))
	target_count += clampi(density_bonus, 0, 2)
	target_count = mini(target_count, candidate_cells.size())

	candidate_cells.shuffle()
	var spawned_positions: Array[Vector2] = []
	var spawned_count := 0
	var enemy_spawner_script: Script = load("res://enemy/tile_enemy_spawner.gd")

	for cell in candidate_cells:
		if spawned_count >= target_count:
			break

		var tile_size_v2: Vector2 = Vector2(tile_set.tile_size)
		var local_pos: Vector2 = tile_map.map_to_local(cell)
		var tile_center: Vector2 = tile_map.to_global(local_pos) + tile_size_v2 * 0.5
		var spawn_position := tile_center + Vector2(0.0, -150.0)

		var too_close := false
		for existing in spawned_positions:
			if spawn_position.distance_to(existing) < forest_enemy_min_distance:
				too_close = true
				break
		if too_close:
			continue

		var enemy_spawner := Node2D.new()
		enemy_spawner.set_script(enemy_spawner_script)
		enemy_spawner.set("current_level", eff_level)
		enemy_spawner.set("chunk_type", "forest")
		enemy_spawner.set("spawn_chance", forest_enemy_spawn_chance)
		enemy_spawner.global_position = spawn_position
		chunk_node.add_child(enemy_spawner)
		enemy_spawner.global_position = spawn_position
		enemy_spawner.call_deferred("activate")

		spawned_positions.append(spawn_position)
		spawned_count += 1

	if DEBUG_FOREST_ENEMIES:
		print("[ForestEnemy] Chunk ", chunk_node.name, " spawned ", spawned_count, " / ", target_count, " enemies")

	chunk_node.set_meta("forest_enemy_populated", true)

func _forest_enemy_has_spawn_span(tile_map, center_cell: Vector2i) -> bool:
	var check_cells := [
		center_cell + Vector2i(-1, 0),
		center_cell,
		center_cell + Vector2i(1, 0)
	]
	for check_cell in check_cells:
		var tile_data: TileData = tile_map.get_cell_tile_data(check_cell) as TileData
		if tile_data == null:
			return false
		var custom_data = tile_data.get_custom_data(FOREST_ENEMY_LAYER_NAME)
		if typeof(custom_data) != TYPE_STRING:
			return false
		var tag := String(custom_data)
		if tag != "forest_floor_surface" and tag != "floor_surface" and tag != "floor":
			return false
	return true

func _forest_enemy_has_height_clearance(tile_map, center_cell: Vector2i, min_height: int) -> bool:
	for i in range(1, min_height + 1):
		var check_cell := center_cell + Vector2i(0, -i)
		if tile_map.get_cell_source_id(check_cell) != -1:
			return false
	return true

# --- Global tree spacing helpers (pixel ranges across chunks) ---
func _forest_tree_prune_px(left_limit_px: float) -> void:
	var kept: Array[Vector2] = []
	for r in _forest_tree_reserved_px:
		if r is Vector2:
			var a := (r as Vector2).x
			var b := (r as Vector2).y
			if b >= left_limit_px:
				kept.append(r)
	_forest_tree_reserved_px = kept

func _forest_tree_overlaps_px(start_px: float, end_px: float) -> bool:
	for r in _forest_tree_reserved_px:
		if r is Vector2:
			var a := (r as Vector2).x
			var b := (r as Vector2).y
			if not (end_px < a or start_px > b):
				return true
	return false

func _forest_tree_reserve_px(start_px: float, end_px: float) -> void:
	_forest_tree_reserved_px.append(Vector2(start_px, end_px))
