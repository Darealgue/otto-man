extends "res://enemy/base_enemy.gd"
class_name ShieldCaptain

@export var max_health_override: float = 320.0
@export var move_speed: float = 60.0
@export var chase_speed: float = 90.0
@export var front_block_angle_deg: float = 110.0
@export var taunt_radius: float = 420.0
@export var cleave_damage: float = 18.0
@export var shove_force: float = 600.0
@export var bash_damage: float = 14.0
@export var bash_cooldown: float = 5.0
@export var cleave_cooldown: float = 2.8
@export var guard_max: float = 100.0
@export var guard_regen_combat: float = 4.5
@export var guard_regen_out: float = 10.0
@export var back_damage_multiplier: float = 1.5
@export var taunt_cooldown: float = 16.0
@export var shove_radius: float = 300.0
@export var vertical_tolerance: float = 60.0
@export var parry_cooldown: float = 6.0
@export var parry_window_duration: float = 0.25
@export var parry_recovery_duration: float = 0.8
@export var parry_trigger_range: float = 200.0
@export var anim_time_scale: float = 4.0
@export var counter_poke_damage: float = 10.0
@export var counter_poke_knockback: float = 400.0
@export var engage_stop_range: float = 90.0
@export var call_guards_cooldown: float = 14.0
@export var max_guards_active: int = 2
@export var guards_per_call: int = 2
@export var call_radius: float = 280.0
@export var call_telegraph_time: float = 0.9
@export var turn_dwell_duration: float = 1.0
@export var turn_min_dx: float = 36.0
@export var turn_cooldown: float = 0.6
@export var stun_frame_count: int = 6
@export var stun_frame_duration: float = 0.10

var facing_dir: int = 1
var block_cooldown: float = 0.0
const BLOCK_COOLDOWN := 0.8
var guard_value: float = 100.0
var bash_cd_timer: float = 0.0
var cleave_cd_timer: float = 0.0
var taunt_cd_timer: float = 0.0
var in_guard_break: bool = false
var in_parry_window: bool = false
var parry_cd_timer: float = 0.0
var movement_locked: bool = false
var call_cd_timer: float = 0.0
var summoned_guards: Array[Node] = []
var block_anim_timer: float = 0.0
var hurt_anim_timer: float = 0.0
var calling_guards: bool = false
var pending_turn: bool = false
var pending_turn_target_dir: int = 1
var turn_dwell_timer: float = 0.0
var turn_cd_timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var enemy_hitbox: EnemyHitbox = $Hitbox
@onready var enemy_hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@export var sprite_foot_margin_px: float = 2.0

func _ready() -> void:
	super._ready()
	# Ensure boss renders above ground tiles similar to other enemies
	z_index = 1
	# Ensure we handle our own death visuals and cleanup
	if has_signal("enemy_defeated"):
		connect("enemy_defeated", Callable(self, "_on_self_defeated"))
	_setup_sprite_frames()
	_update_sprite_offset()
	if stats:
		stats.max_health = max_health_override
		health = stats.max_health
	# simple idle
	change_behavior("idle")
	guard_value = guard_max

func _process(_delta: float) -> void:
	queue_redraw()

func _handle_child_behavior(delta: float) -> void:
	# If dead, stop all behavior and movement
	if current_behavior == "dead":
		velocity = Vector2.ZERO
		return
	# If in guard break, lock and play stun
	if in_guard_break:
		movement_locked = true
		velocity = Vector2.ZERO
		_play_anim_safe("stun")
		return
	# regen & cooldowns
	if not in_guard_break:
		var regen = guard_regen_combat if get_nearest_player_in_range() else guard_regen_out
		guard_value = clamp(guard_value + regen * delta, 0.0, guard_max)
	# reduce parry cooldown
	if parry_cd_timer > 0.0:
		parry_cd_timer -= delta
	if call_cd_timer > 0.0:
		call_cd_timer -= delta
	if bash_cd_timer > 0.0:
		bash_cd_timer -= delta
	if cleave_cd_timer > 0.0:
		cleave_cd_timer -= delta
	if taunt_cd_timer > 0.0:
		taunt_cd_timer -= delta
	if turn_cd_timer > 0.0:
		turn_cd_timer -= delta
	# timers for block visuals, hurt overlay, and cooldown
	if block_cooldown > 0.0:
		block_cooldown = max(0.0, block_cooldown - delta)
	if block_anim_timer > 0.0:
		block_anim_timer = max(0.0, block_anim_timer - delta)
	if hurt_anim_timer > 0.0:
		hurt_anim_timer = max(0.0, hurt_anim_timer - delta)
	# taunt logic (hp < 50% and off cooldown)
	var max_hp := (stats.max_health if stats else max_health_override)
	if health <= max_hp * 0.5 and taunt_cd_timer <= 0.0 and current_behavior != "attack":
		var p = get_nearest_player()
		if p and global_position.distance_to(p.global_position) <= taunt_radius:
			_start_taunt_shove()
			return
	if current_behavior == "idle" or current_behavior == "chase":
		if movement_locked:
			# Keep horizontal speed clamped to zero while locked
			velocity.x = move_toward(velocity.x, 0.0, 2000 * delta)
			# If we are in a pending turn dwell, progress the dwell and flip when time elapses
			if pending_turn:
				var p2_locked = get_nearest_player()
				if p2_locked:
					var dx_locked = p2_locked.global_position.x - global_position.x
					var dy_locked = abs(p2_locked.global_position.y - global_position.y)
					var desired_dir_locked: int = (sign(dx_locked) if dx_locked != 0 else facing_dir)
					# Cancel turn if player returns to front or vertical misalignment is too high
					if desired_dir_locked == facing_dir or dy_locked > vertical_tolerance:
						pending_turn = false
						movement_locked = false
					else:
						turn_dwell_timer -= delta
						if block_anim_timer <= 0.0 and hurt_anim_timer <= 0.0:
							_play_anim_safe("idle")
						if turn_dwell_timer <= 0.0:
							facing_dir = pending_turn_target_dir
							_update_facing()
							pending_turn = false
							movement_locked = false
							turn_cd_timer = turn_cooldown
							if hurt_anim_timer <= 0.0:
								_play_anim_safe("turn")
			else:
				if block_anim_timer <= 0.0 and hurt_anim_timer <= 0.0:
					_play_anim_safe("idle")
			return
		var p2 = get_nearest_player()
		if p2:
			var dx = p2.global_position.x - global_position.x
			var dy = abs(p2.global_position.y - global_position.y)
			var desired_dir: int = (sign(dx) if dx != 0 else facing_dir)
			# Handle delayed turning: pause before flipping to give backstab window
			if not pending_turn and turn_cd_timer <= 0.0 and desired_dir != facing_dir and abs(dx) > turn_min_dx and dy <= vertical_tolerance:
				pending_turn = true
				pending_turn_target_dir = desired_dir
				turn_dwell_timer = turn_dwell_duration
				movement_locked = true
				velocity.x = 0
				if block_anim_timer <= 0.0 and hurt_anim_timer <= 0.0:
					_play_anim_safe("idle")
				# Defer rest of logic until dwell completes
				return
			elif pending_turn:
				# If player returns to front, cancel pending turn
				if desired_dir == facing_dir:
					pending_turn = false
					movement_locked = false
				else:
					turn_dwell_timer -= delta
					if turn_dwell_timer <= 0.0:
						facing_dir = pending_turn_target_dir
						_update_facing()
						pending_turn = false
						movement_locked = false
						turn_cd_timer = turn_cooldown
						if hurt_anim_timer <= 0.0:
							_play_anim_safe("turn")
						# allow rest of logic to run after flip
			# Normal facing update when no pending turn
			if not pending_turn:
				facing_dir = desired_dir
				_update_facing()
			var within_stop: bool = abs(dx) <= engage_stop_range and dy <= vertical_tolerance
			var target_speed = 0.0 if within_stop else ((clamp(dx, -1, 1) * chase_speed) if dy <= vertical_tolerance else 0.0)
			var accel := 2000.0 if within_stop else 600.0
			velocity.x = move_toward(velocity.x, target_speed, accel * delta)
			move_and_slide()
			# locomotion anim
			if not within_stop and abs(velocity.x) > 1.0 and dy <= vertical_tolerance:
				if block_anim_timer <= 0.0 and hurt_anim_timer <= 0.0:
					_play_anim_safe("walk")
			else:
				if block_anim_timer <= 0.0 and hurt_anim_timer <= 0.0:
					_play_anim_safe("idle")
			# Try to trigger parry if player in range and cooldown ready
			if not in_parry_window and parry_cd_timer <= 0.0 and abs(dx) <= parry_trigger_range and dy <= vertical_tolerance:
				_start_parry_window()
			# Try to call guards if below cap and cooldown ready
			_clean_summoned_guards()
			if call_cd_timer <= 0.0 and abs(dx) <= taunt_radius and dy <= vertical_tolerance:
				_clean_summoned_guards()
				if summoned_guards.size() < max_guards_active:
					_start_call_guards()
			if abs(dx) < 220 and dy <= vertical_tolerance and cleave_cd_timer <= 0.0:
				_start_cleave()
			elif abs(dx) >= 220 and abs(dx) < 360 and dy <= vertical_tolerance and bash_cd_timer <= 0.0:
				_start_bash()
	elif current_behavior == "attack":
		# attack animation handled by timers/animation_player in full version
		pass

func _start_cleave() -> void:
	change_behavior("attack")
	_play_anim_safe("cleave")
	# Lock movement for cleave duration (telegraph+active+recover managed by timers)
	movement_locked = true
	velocity.x = 0
	# quick telegraph then damage in front cone
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(_do_cleave)

func _do_cleave() -> void:
	# Enable enemy hitbox briefly for active frames (swing)
	_activate_hitbox(cleave_damage, shove_force, "cleave", 0.28, 56.0, 34.0, -4.0)
	# short recover
	var rec := get_tree().create_timer(0.4)
	rec.timeout.connect(func():
		change_behavior("chase")
		_play_anim_safe("idle")
		movement_locked = false
	)
	cleave_cd_timer = cleave_cooldown

func _start_bash() -> void:
	change_behavior("attack")
	_play_anim_safe("bash")
	var tele := get_tree().create_timer(0.5)
	tele.timeout.connect(_do_bash)

func _do_bash() -> void:
	var dash_time := 0.2
	var elapsed := 0.0
	var dir := Vector2(sign(facing_dir), 0)
	var speed := 900.0
	while elapsed < dash_time and is_instance_valid(self):
		velocity = dir * speed
		move_and_slide()
		elapsed += get_physics_process_delta_time()
		await get_tree().physics_frame
	velocity = Vector2.ZERO
	# Activate enemy hitbox briefly at the end of dash for impact
	_activate_hitbox(bash_damage, 800.0, "dash", 0.14, 40.0, 26.0, -2.0)
	var rec2 := get_tree().create_timer(0.35)
	rec2.timeout.connect(func():
		change_behavior("chase")
		_play_anim_safe("idle")
	)
	bash_cd_timer = bash_cooldown

func _start_taunt_shove() -> void:
	change_behavior("attack")
	# brief taunt telegraph
	_play_anim_safe("taunt")
	# Lock movement during taunt and shove
	movement_locked = true
	velocity.x = 0
	var tele := get_tree().create_timer(0.7)
	tele.timeout.connect(_do_shove)
	taunt_cd_timer = taunt_cooldown

func _do_shove() -> void:
	# Push player(s) away without damage
	var players = get_tree().get_nodes_in_group("player")
	for n in players:
		if not is_instance_valid(n):
			continue
		var pl = n as Node2D
		var d = global_position.distance_to(pl.global_position)
		var dy = abs(pl.global_position.y - global_position.y)
		if d <= shove_radius and dy <= vertical_tolerance:
			var dir = (pl.global_position - global_position).normalized()
			if "velocity" in pl:
				pl.velocity += dir * shove_force
	var rec := get_tree().create_timer(0.4)
	rec.timeout.connect(func():
		change_behavior("chase")
		_play_anim_safe("idle")
		movement_locked = false
	)

func _start_call_guards() -> void:
	if calling_guards:
		return
	change_behavior("attack")
	_play_anim_safe("call")
	movement_locked = true
	velocity.x = 0
	calling_guards = true
	var tele := get_tree().create_timer(call_telegraph_time)
	tele.timeout.connect(_do_call_guards)
	call_cd_timer = call_guards_cooldown

func _do_call_guards() -> void:
	# Determine how many we can still summon
	_clean_summoned_guards()
	var available_slots: int = max(0, max_guards_active - summoned_guards.size())
	var can_summon: int = min(guards_per_call, available_slots)
	if can_summon <= 0:
		movement_locked = false
		change_behavior("chase")
		_play_anim_safe("idle")
		return
	var scenes: Array[PackedScene] = []
	var heavy: PackedScene = load("res://enemy/heavy/heavy_enemy.tscn")
	var flying: PackedScene = load("res://enemy/flying/flying_enemy.tscn")
	if heavy:
		scenes.append(heavy)
	if flying:
		scenes.append(flying)
	var spawned: int = 0
	var base_pos := global_position
	var angle_start: float = -0.6
	var angle_step: float = 1.2 / float(max(1, can_summon))
	while spawned < can_summon and summoned_guards.size() < max_guards_active:
		var ang := angle_start + angle_step * float(spawned)
		var offset := Vector2(call_radius * cos(ang), call_radius * sin(ang))
		var target := base_pos + offset
		var floor_pos := _find_floor_position(target)
		var scene: PackedScene = scenes[randi() % max(1, scenes.size())]
		if scene:
			var guard = scene.instantiate()
			get_parent().add_child(guard)
			guard.global_position = floor_pos
			if "z_index" in guard:
				guard.z_index = 1
			if guard.has_method("move_and_slide"):
				guard.move_and_slide()
			if guard.has_signal("enemy_defeated"):
				guard.connect("enemy_defeated", Callable(self, "_on_guard_defeated").bind(guard))
			# Clean up tracking even if the guard is removed without emitting defeat
			guard.tree_exited.connect(Callable(self, "_on_guard_defeated").bind(guard))
			summoned_guards.append(guard)
			spawned += 1

	# Hard cap enforcement in case something slipped through
	if summoned_guards.size() > max_guards_active:
		for i in range(summoned_guards.size() - 1, max_guards_active - 1, -1):
			var g = summoned_guards[i]
			if is_instance_valid(g):
				g.queue_free()
			summoned_guards.remove_at(i)
	# Recovery
	var rec := get_tree().create_timer(0.4)
	rec.timeout.connect(func():
		movement_locked = false
		change_behavior("chase")
		_play_anim_safe("idle")
		calling_guards = false
	)

func _find_floor_position(from_pos: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from_pos, from_pos + Vector2.DOWN * 600.0)
	query.collision_mask = CollisionLayers.WORLD
	var result = space_state.intersect_ray(query)
	if result and result.has("position"):
		return result.position - Vector2(0, 32)
	return from_pos

func _clean_summoned_guards() -> void:
	for i in range(summoned_guards.size() - 1, -1, -1):
		var g = summoned_guards[i]
		if not is_instance_valid(g) or not g.is_inside_tree():
			summoned_guards.remove_at(i)

func _on_guard_defeated(guard: Node) -> void:
	if summoned_guards.has(guard):
		summoned_guards.erase(guard)

func _on_self_defeated() -> void:
	# Enter dead state: stop movement, disable collisions, play death, cleanup
	change_behavior("dead")
	velocity = Vector2.ZERO
	movement_locked = true
	if is_instance_valid(enemy_hitbox):
		enemy_hitbox.disable()
	if is_instance_valid(hurtbox):
		hurtbox.monitoring = false
	_play_anim_restart("death")
	# On death animation end, freeze on its last frame and keep corpse
	if is_instance_valid(animated_sprite):
		animated_sprite.animation_finished.connect(func():
			if current_behavior == "dead" and animated_sprite.animation == "death" and is_instance_valid(animated_sprite):
				var frames: SpriteFrames = animated_sprite.sprite_frames
				if frames and frames.has_animation("death"):
					var c := frames.get_frame_count("death")
					if c > 0:
						animated_sprite.frame = c - 1
				animated_sprite.pause()
		)

func _is_in_front_cone(point: Vector2) -> bool:
	var dir_vec = Vector2(facing_dir, 0)
	var to_target = (point - global_position).normalized()
	var ang = rad_to_deg(acos(clamp(dir_vec.dot(to_target), -1.0, 1.0)))
	return ang <= front_block_angle_deg * 0.5

func _get_incoming_hit_position() -> Vector2:
	# Prefer the last hitbox position from our hurtbox for accurate direction checks
	if is_instance_valid(hurtbox):
		var hb = hurtbox.get("last_hitbox") if hurtbox.has_method("get") else null
		if hb and is_instance_valid(hb):
			return hb.global_position
	# Fallback to nearest player position
	var p = get_nearest_player()
	return p.global_position if p else global_position

func take_damage(amount: float, knockback_force: float = 200.0, knockback_up_force: float = -1.0) -> void:
	# Ignore further hits if already dead
	if current_behavior == "dead":
		return
	print("[ShieldCaptain] take_damage called dmg=", amount, " guard=", guard_value, " in_guard_break=", in_guard_break)
	var hit_pos := _get_incoming_hit_position()
	var player := get_nearest_player()
	var dy_ok := true
	if player:
		dy_ok = abs(player.global_position.y - global_position.y) <= vertical_tolerance
	var is_horizontal_front := ((hit_pos.x - global_position.x) * float(facing_dir)) > 0.0
	var is_player_falling := false
	if player and ("velocity" in player):
		is_player_falling = player.velocity.y > 120.0
	# Treat top-down fall attacks landing from the front horizontally as frontal blocks too
	var is_front := (_is_in_front_cone(hit_pos) and dy_ok) or (is_horizontal_front and is_player_falling)

	# If parry window active and hit is from front, negate damage and counter
	if in_parry_window and is_front:
		print("[ShieldCaptain] PARRY SUCCESS - negate damage and counter stun")
		if player:
			_invoke_parry_counter(player)
		return

	# During guard break do normal damage
	if in_guard_break:
		print("[ShieldCaptain] GUARD BREAK, passing to BaseEnemy dmg=", amount)
		super(amount, knockback_force, knockback_up_force)
		return

	# Directional block: any front hit consumes guard instead of health
	if is_front and guard_value > 0.0:
		guard_value -= amount * 10.0 / 15.0 # scale incoming to guard damage
		print("[ShieldCaptain] BLOCK front hit, guard->", guard_value)
		# Show block animation and prevent it from being immediately overridden
		block_anim_timer = 0.35
		_play_anim_restart("block_hit")
		block_cooldown = BLOCK_COOLDOWN
		if guard_value <= 0.0:
			_guard_break()
		return

	# Back or unblocked: apply damage (with backstab bonus if clearly behind)
	var dmg: float = amount
	if not is_front:
		dmg *= back_damage_multiplier
		print("[ShieldCaptain] BACKSTAB, final_dmg=", dmg)
	# Ensure knockback pushes away from hit and is clamped to avoid runaway movement
	var knock: float = float(min(knockback_force, 160.0))
	# Set base direction so BaseEnemy applies knockback away from attacker
	direction = sign(global_position.x - hit_pos.x)
	# Play hurt and protect it from immediate override for the full anim duration
	_play_anim_safe("hurt")
	hurt_anim_timer = 0.06 * anim_time_scale * 4.0
	super(dmg, knock, knockback_up_force)

func _guard_break() -> void:
	in_guard_break = true
	movement_locked = true
	velocity = Vector2.ZERO
	_play_anim_safe("stun")
	var stun := get_tree().create_timer(1.5)
	await stun.timeout
	if current_behavior != "dead":
		in_guard_break = false
		movement_locked = false
		_play_anim_safe("idle")
	# recover some guard slowly starts via regen

func _start_parry_window() -> void:
	in_parry_window = true
	parry_cd_timer = parry_cooldown
	# brief telegraph could be added here
	_play_anim_safe("parry")
	var t := get_tree().create_timer(parry_window_duration)
	t.timeout.connect(func():
		if current_behavior == "dead":
			return
		in_parry_window = false
		# short recovery where he won't instantly re-attack
		var rec := get_tree().create_timer(parry_recovery_duration)
		rec.timeout.connect(func():
			if current_behavior != "dead":
				_play_anim_safe("idle")
		)
	)

func _invoke_parry_counter(player: Node2D) -> void:
	# Light stun on player and small pushback, then counter poke
	if not is_instance_valid(player):
		return
	# Lock briefly during counter
	movement_locked = true
	velocity.x = 0
	if "velocity" in player:
		var dir = (player.global_position - global_position).normalized()
		player.velocity += dir * 600.0
	# Optional: trigger a player signal if exists
	if player.has_signal("perfect_parry"):
		player.emit_signal("perfect_parry")
	# Execute quick counter poke shortly after parry frames
	var t := get_tree().create_timer(0.08)
	t.timeout.connect(func():
		if current_behavior != "dead":
			_do_counter_poke(player)
	)

func _do_counter_poke(player: Node2D) -> void:
	if not is_instance_valid(player):
		return
	# Use front-cone check and vertical alignment to gate hit
	if _is_in_front_cone(player.global_position) and abs(player.global_position.y - global_position.y) <= vertical_tolerance:
		_activate_hitbox(counter_poke_damage, counter_poke_knockback, "poke", 0.10, 28.0, 18.0, -2.0)
	# Recovery to neutral
	var rec := get_tree().create_timer(0.2)
	rec.timeout.connect(func():
		if current_behavior != "dead":
			change_behavior("chase")
			_play_anim_safe("idle")
			movement_locked = false
	)

func _draw() -> void:
	# simple guard bar above head
	var w: float = 64.0
	var h: float = 6.0
	var y_off: float = -70.0
	# bg
	draw_rect(Rect2(Vector2(-w * 0.5, y_off), Vector2(w, h)), Color(0.1, 0.1, 0.1, 0.8), true)
	# fill
	var ratio := 0.0 if guard_max <= 0.0 else (guard_value / guard_max)
	ratio = clamp(ratio, 0.0, 1.0)
	draw_rect(Rect2(Vector2(-w * 0.5, y_off), Vector2(w * ratio, h)), Color(0.2, 0.7, 1.0, 0.9), true)

func _setup_sprite_frames() -> void:
	# Build SpriteFrames by slicing horizontal strips using provided frame counts and phase timings.
	var frames := SpriteFrames.new()
	var base := "res://enemy/miniboss/shield_captain/sprites/"

	# Helper lambdas
	var add_anim := func(anim_name: String, file_name: String, frame_count: int, loop: bool, per_frame_durations: Array = []):
		var tex: Texture2D = load(base + file_name)
		if tex == null:
			return
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, loop)
		var subframes: Array = _slice_strip(tex, frame_count)
		if per_frame_durations.is_empty():
			for sf in subframes:
				frames.add_frame(anim_name, sf, 0.08 * anim_time_scale)
		else:
			for i in range(subframes.size()):
				var dur: float = float(per_frame_durations[min(i, per_frame_durations.size() - 1)]) * anim_time_scale
				frames.add_frame(anim_name, subframes[i], dur)

	# Idle (12), loop - slower pacing
	add_anim.call("idle", "shield_captain_idle_border.png", 12, true,
		[0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12, 0.12])
	# Walk/Run (8), loop - slower pacing
	add_anim.call("walk", "shield_captain_walk_border.png", 8, true,
		[0.11, 0.11, 0.11, 0.11, 0.11, 0.11, 0.11, 0.11])
	# Turn (3), one-shot
	add_anim.call("turn", "shield_captain_turn_border.png", 3, false, [0.06, 0.06, 0.06])
	# Block idle (2), loop
	add_anim.call("block", "shield_captain_block_border.png", 2, true, [0.18, 0.18])
	# Block hit (5), one-shot
	add_anim.call("block_hit", "shield_captain_block_hit_border.png", 5, false, [0.06, 0.06, 0.06, 0.06, 0.06])

	# Cleave (9): 1-5 windup 0.35s, 6-7 swing 0.16s, 8-9 recover 0.20s
	add_anim.call("cleave", "shield_captain_cleave_border.png", 9, false,
		[0.07, 0.07, 0.07, 0.07, 0.07, 0.08, 0.08, 0.10, 0.10])

	# Bash (9): 1-4 tele 0.5s, 5-7 dash 0.2s, 8-9 impact/recover 0.35s
	add_anim.call("bash", "shield_captain_bash_border.png", 9, false,
		[0.125, 0.125, 0.125, 0.125, 0.0667, 0.0667, 0.0667, 0.175, 0.175])

	# Taunt+Shove (14): 1-10 taunt 0.7s, 11-14 shove 0.4s
	add_anim.call("taunt", "shield_captain_taunt_border.png", 14, false,
		[0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.10, 0.10, 0.10, 0.10])

	# Call animation: reuse only the taunt portion (first 10 frames) of the taunt strip
	var taunt_tex: Texture2D = load(base + "shield_captain_taunt_border.png")
	if taunt_tex != null:
		frames.add_animation("call")
		frames.set_animation_loop("call", false)
		var taunt_subframes: Array = _slice_strip(taunt_tex, 14)
		for i in range(10):
			if i < taunt_subframes.size():
				frames.add_frame("call", taunt_subframes[i], 0.07 * anim_time_scale)

	# Hurt light (4): one-shot, slightly longer per-frame to be more readable
	add_anim.call("hurt", "shield_captain_hurt_light_border.png", 4, false, [0.08, 0.08, 0.08, 0.08])

	# Stun (loop): guard break visual
	var stun_tex: Texture2D = load(base + "shield_captain_stun_border.png")
	if stun_tex != null:
		frames.add_animation("stun")
		frames.set_animation_loop("stun", true)
		var stun_frames: Array = _slice_strip(stun_tex, stun_frame_count)
		for i in range(stun_frames.size()):
			frames.add_frame("stun", stun_frames[i], stun_frame_duration * anim_time_scale)

	# Death (13): one-shot
	add_anim.call("death", "shield_captain_death_border.png", 13, false)

	# Parry (11): 1-6 tele ~0.2s, 7-8 active 0.25s, 9-11 success recoil 0.3s
	add_anim.call("parry", "shield_captain_parry_border.png", 11, false,
		[0.033, 0.033, 0.033, 0.033, 0.033, 0.033, 0.125, 0.125, 0.10, 0.10, 0.10])

	# Assign to sprite
	if is_instance_valid(animated_sprite):
		animated_sprite.sprite_frames = frames
		_play_anim_safe("idle")
		_update_sprite_offset()

func _slice_strip(tex: Texture2D, frame_count: int) -> Array:
	var size: Vector2i = tex.get_size()
	if frame_count <= 0 or size.x <= 0:
		return []
	var frame_w: int = int(floor(float(size.x) / float(frame_count)))
	var h: int = size.y
	var result: Array = []
	for i in range(frame_count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2i(i * frame_w, 0, frame_w, h)
		result.append(at)
	return result

func _update_sprite_offset() -> void:
	if not is_instance_valid(animated_sprite):
		return
	var frame_tex: Texture2D = null
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		frame_tex = animated_sprite.sprite_frames.get_frame_texture("idle", 0)
	if frame_tex == null:
		return
	var frame_h: float = 0.0
	# AtlasTexture returns region size
	if frame_tex is AtlasTexture:
		frame_h = (frame_tex as AtlasTexture).region.size.y
	else:
		frame_h = frame_tex.get_size().y
	var total_body_h: float = 0.0
	if is_instance_valid(body_collision) and body_collision.shape is CapsuleShape2D:
		var cap := body_collision.shape as CapsuleShape2D
		# Capsule total height = height + 2*radius
		total_body_h = cap.height + cap.radius * 2.0
	else:
		# Sensible fallback
		total_body_h = 86.0
	# Compute offset so sprite bottom aligns roughly with feet
	var desired_bottom_from_center: float = total_body_h * 0.5
	var current_bottom_from_center: float = frame_h * 0.5
	var offset_y: float = -(current_bottom_from_center - desired_bottom_from_center - sprite_foot_margin_px)
	animated_sprite.offset.y = offset_y

func _play_anim_safe(name: String) -> void:
	if not is_instance_valid(animated_sprite):
		return
	if current_behavior == "dead" and name != "death":
		return
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(name):
		if animated_sprite.animation != name:
			animated_sprite.play(name)

func _play_anim_restart(name: String) -> void:
	if not is_instance_valid(animated_sprite):
		return
	if current_behavior == "dead" and name != "death":
		return
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(name):
		animated_sprite.stop()
		animated_sprite.play(name)

func _update_facing() -> void:
	if is_instance_valid(animated_sprite):
		animated_sprite.flip_h = facing_dir < 0

func _activate_hitbox(dmg: float, kb: float, atk_type: String, active_time: float, forward_offset: float, radius: float, y_offset: float = 0.0, up_kb: float = 0.0) -> void:
	if not is_instance_valid(enemy_hitbox):
		return
	enemy_hitbox.damage = dmg
	enemy_hitbox.knockback_force = kb
	enemy_hitbox.knockback_up_force = up_kb
	enemy_hitbox.setup_attack(atk_type, true, 0.0)
	enemy_hitbox.position = Vector2(facing_dir * forward_offset, y_offset)
	if is_instance_valid(enemy_hitbox_shape) and enemy_hitbox_shape.shape is CircleShape2D:
		var circle := enemy_hitbox_shape.shape as CircleShape2D
		circle.radius = radius
	enemy_hitbox.enable()
	var t := get_tree().create_timer(active_time)
	t.timeout.connect(func():
		if is_instance_valid(enemy_hitbox):
			enemy_hitbox.disable()
	)
