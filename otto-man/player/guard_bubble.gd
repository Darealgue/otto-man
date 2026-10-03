extends Node2D
## Kalkan Küresi: hareket halindeyken (koşu, zıplama, duvar kayma, ledge grab...) savunma.
## Block tuşuna basınca oyuncunun etrafında yarı saydam bir balon açılır (Smash Bros kalkanı gibi).
## Block state'i / sprite'ı kullanılmaz; tüm savunma mantığı burada.
##  - Balon açıkken gelen her saldırı tamamen durdurulur (1 stamina).
##  - Açılış penceresi içinde gelen saldırı = parry (yerdeyken parry animasyonu, havada balon patlaması).
## Hasar akışı: PlayerHurtbox -> player.try_bubble_guard(hitbox) -> handle_hit(hitbox).

const RADIUS := 30.0
const CENTER := Vector2(0, -22)
const OPEN_TIME := 0.10
const CLOSE_TIME := 0.08
## Aynı saldırı dizisinin (çoklu hitbox) stamina'yı üst üste yememesi için
const POST_HIT_GRACE := 0.18
const PARRY_IFRAME := 1.0
## Balonun açılamadığı state'ler (kendi i-frame / hareket mantığı olanlar)
const BLOCKED_STATES := ["Dodge", "Dash", "Hurt", "FallAttack", "Block"]
const COLOR_GUARD := Color(0.45, 0.78, 1.0)
const COLOR_PARRY := Color(1.0, 0.85, 0.25)
const COLOR_BLOCK_HIT := Color(0.85, 0.95, 1.0)

var player: CharacterBody2D = null
var is_open := false
var parry_timer := 0.0
var _grace := 0.0

# --- görsel durum ---
var _scale_t := 0.0                # 0 = kapalı, 1 = tam açık
var _ripples: Array = []   # {t, dur, color, grow}
var _shards: Array = []    # {pos, vel, t, dur, color}
var _flicker := 0.0


func _ready() -> void:
	z_index = 5
	position = CENTER
	visible = false


func setup(p: CharacterBody2D) -> void:
	player = p


func _block_state():
	if not is_instance_valid(player):
		return null
	return player.get_node_or_null("StateMachine/Block")


func _state_name() -> String:
	var sm = player.get_node_or_null("StateMachine") if is_instance_valid(player) else null
	if sm and sm.get("current_state"):
		return String(sm.current_state.name)
	return ""


func _parry_window() -> float:
	var bs = _block_state()
	if bs:
		return float(bs.PARRY_WINDOW)
	return 0.2


func _parry_allowed() -> bool:
	var drs := get_node_or_null("/root/DungeonRunState")
	if drs and drs.has_method("has_segment_modifier") and drs.has_segment_modifier("no_parry"):
		return false
	return true


func _stamina_bar():
	return get_tree().get_first_node_in_group("stamina_bar")


func _has_stamina() -> bool:
	var bar = _stamina_bar()
	return bar != null and bar.has_charges()


func _can_guard() -> bool:
	if not is_instance_valid(player):
		return false
	if player.is_dead or player.get("_ui_locked"):
		return false
	return not (_state_name() in BLOCKED_STATES)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var d: float = delta * player.time_slow_player_multiplier
	if _grace > 0.0:
		_grace -= d
	if parry_timer > 0.0:
		parry_timer -= d

	var pressed := Input.is_action_pressed("block")
	if is_open:
		if not pressed or not _can_guard():
			_close()
		elif not _has_stamina():
			# Stamina bitti: balon patlar
			_pop_break()
			_close()
		elif Input.is_action_just_pressed("block") and _parry_allowed():
			# Tekrar basış parry penceresini yeniden kurar (Block state ile aynı)
			parry_timer = _parry_window()
	else:
		if pressed and player.block_input_blocked_timer <= 0.0 and _can_guard() and _has_stamina():
			_open()


func _open() -> void:
	is_open = true
	parry_timer = _parry_window() if _parry_allowed() else 0.0
	player.enter_combat_state()
	var bar = _stamina_bar()
	if bar:
		bar.show_bar()


func _close() -> void:
	is_open = false
	parry_timer = 0.0
	var bar = _stamina_bar()
	if bar and not bar.is_recharging():
		bar.hide_bar()


## PlayerHurtbox çağırır. true dönerse hasar bu balon tarafından halledilmiştir
## (hurtbox.last_damage bu fonksiyonda ayarlanır).
func handle_hit(hitbox: Area2D) -> bool:
	if not is_open or not _can_guard():
		return false
	var hurtbox = player.hurtbox
	var attacker: Node2D = hitbox.get_parent() if hitbox else null
	var hit_pos: Vector2 = hitbox.global_position if hitbox else player.global_position

	# Son vuruştan hemen sonraki ek hitbox'lar / parry i-frame'i: bedava yutulur
	if _grace > 0.0 or (hurtbox.has_method("is_invincible") and hurtbox.is_invincible()):
		hurtbox.last_damage = 0.0
		return true

	var bar = _stamina_bar()
	var is_parry := parry_timer > 0.0 and _parry_allowed()
	var blocked_damage: float = hitbox.get_damage() if hitbox.has_method("get_damage") else 0.0

	if is_parry:
		return _do_parry(hitbox, attacker, hit_pos, bar)

	# Normal blok: tüm hasar durur, 1 stamina (Kalkan Ustası şansı Block state'ten okunur)
	var saved := false
	var bs = _block_state()
	if bs and bs.has_meta("stamina_save_chance"):
		saved = randf() < float(bs.get_meta("stamina_save_chance"))
	if not saved and not (bar and bar.use_charge()):
		return false
	hurtbox.last_damage = 0.0
	_grace = POST_HIT_GRACE
	_add_ripple(COLOR_BLOCK_HIT, 0.28, 0.35)
	_flicker = 0.12
	_play_sfx(hit_pos, false)
	if blocked_damage > 0.0 and player.has_signal("player_blocked"):
		player.emit_signal("player_blocked", blocked_damage, attacker)
	return true


## Parry. Yerdeyse ve Idle/Run'dayken gerçek parry animasyonu + karşı saldırı akışı için
## Block state'ine "balon parry" modunda girilir (stamina'yı Block state kendisi harcar).
## Havada / hareket halinde: sadece balon efekti, stamina burada harcanır.
func _do_parry(hitbox: Area2D, attacker: Node2D, hit_pos: Vector2, bar: Node) -> bool:
	var hurtbox = player.hurtbox
	var bs = _block_state()
	var sm = player.get_node_or_null("StateMachine")

	var used_block_state := false
	if bs and sm and player.is_on_floor() and _state_name() in ["Idle", "Run"]:
		bs.bubble_parry_mode = true
		sm.transition_to("Block")
		if sm.current_state == bs:
			bs._last_parried_attacker = attacker
			bs._on_hurtbox_hurt(hitbox)
			used_block_state = bs.is_parrying
		if not used_block_state:
			bs.bubble_parry_mode = false
			if sm.current_state == bs:
				sm.transition_to("Idle")

	if not used_block_state and not (bar and bar.use_charge()):
		return false

	hurtbox.last_damage = 0.0
	_grace = POST_HIT_GRACE
	parry_timer = 0.0
	_play_sfx(hit_pos, true)

	if used_block_state:
		# Parry i-frame / efekt / sinyal Block state tarafından zaten halledildi
		_close()
		_burst(COLOR_PARRY, true)
		return true

	if hurtbox.has_method("set_invincible"):
		hurtbox.set_invincible(PARRY_IFRAME)
	var fx = preload("res://effects/parry_effect.tscn").instantiate()
	player.add_child(fx)
	fx.global_position = hit_pos
	# Havada parry: Block state'in parry sonrası akışı (karşı saldırı penceresi, sinyal) elle
	player._on_successful_parry()
	_burst(COLOR_PARRY, false)
	return true


# ---------------------------------------------------------------------------
# Görsel
# ---------------------------------------------------------------------------

func _add_ripple(color: Color, dur: float, grow: float) -> void:
	_ripples.append({"t": 0.0, "dur": dur, "color": color, "grow": grow})


## Parry: altın halka dışa doğru yayılır + (havada) balon açılıp patlar
func _burst(color: Color, grounded: bool) -> void:
	_add_ripple(color, 0.32, 0.9)
	_add_ripple(Color(1, 1, 1), 0.2, 0.5)
	if not grounded:
		_spawn_shards(color, 10)


## Stamina bitişi: balon küçük parçalar halinde dağılır
func _pop_break() -> void:
	_spawn_shards(COLOR_GUARD, 8)
	_add_ripple(COLOR_GUARD, 0.22, 0.4)


func _spawn_shards(color: Color, count: int) -> void:
	for i in count:
		var ang := TAU * float(i) / float(count) + randf_range(-0.2, 0.2)
		_shards.append({
			"pos": Vector2.from_angle(ang) * RADIUS,
			"vel": Vector2.from_angle(ang) * randf_range(70.0, 130.0),
			"t": 0.0,
			"dur": randf_range(0.25, 0.4),
			"color": color,
		})


func _play_sfx(at_position: Vector2, parry: bool) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.play_sfx("parry" if parry else "block", at_position)


func _process(delta: float) -> void:
	var target := 1.0 if is_open else 0.0
	var speed := (1.0 / OPEN_TIME) if is_open else (1.0 / CLOSE_TIME)
	_scale_t = move_toward(_scale_t, target, speed * delta)
	if _flicker > 0.0:
		_flicker -= delta
	for r in _ripples:
		r["t"] += delta
	_ripples = _ripples.filter(func(r): return r["t"] < r["dur"])
	for s in _shards:
		s["t"] += delta
		s["pos"] += s["vel"] * delta
	_shards = _shards.filter(func(s): return s["t"] < s["dur"])
	visible = _scale_t > 0.001 or not _ripples.is_empty() or not _shards.is_empty()
	if visible:
		queue_redraw()


func _draw() -> void:
	if _scale_t > 0.001:
		var ease_t := 1.0 - pow(1.0 - _scale_t, 3.0)  # ease-out: hızlı açılır, yumuşak oturur
		var r := RADIUS * (0.25 + 0.75 * ease_t)
		# Parry penceresi açıkken balon altın tonda; süre bitince mavi
		var in_window := is_open and parry_timer > 0.0
		var base := COLOR_PARRY if in_window else COLOR_GUARD
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
		var fill_a := (0.14 + 0.05 * pulse) * ease_t
		var edge_a := (0.55 + 0.15 * pulse) * ease_t
		if _flicker > 0.0:
			base = base.lerp(COLOR_BLOCK_HIT, 0.7)
			fill_a += 0.18
			edge_a = 0.95
		draw_circle(Vector2.ZERO, r, Color(base.r, base.g, base.b, fill_a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(base.r, base.g, base.b, edge_a), 1.8, true)
		# Üst-sol parlama yayı (cam hissi)
		draw_arc(Vector2.ZERO, r * 0.78, deg_to_rad(200), deg_to_rad(260), 12, Color(1, 1, 1, 0.45 * ease_t), 1.5, true)
	for rp in _ripples:
		var k: float = rp["t"] / rp["dur"]
		var rr: float = RADIUS * (1.0 + rp["grow"] * k)
		var c: Color = rp["color"]
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(c.r, c.g, c.b, (1.0 - k) * 0.9), 2.2, true)
	for sh in _shards:
		var k2: float = sh["t"] / sh["dur"]
		var c2: Color = sh["color"]
		var dir: Vector2 = (sh["vel"] as Vector2).normalized()
		draw_line(sh["pos"], sh["pos"] + dir * 5.0, Color(c2.r, c2.g, c2.b, 1.0 - k2), 1.6)
