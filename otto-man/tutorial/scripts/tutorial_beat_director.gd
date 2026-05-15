extends Node
## Sıralı tutorial diyalogları: numaralı TutorialPoint’e NPC taşınır, alt balon, yürüyüş mesafesiyle kapanır.
## Görsel/duman tamamen senin npc_scene prefabında; Director sadece konum + görünürlük akışını yönetir.

signal all_beats_completed

@export var tutorial_steps: Array[TutorialBeatStep] = []
@export var npc_scene: PackedScene = preload("res://tutorial/scenes/TutorialNpcGuide.tscn")
@export var auto_start: bool = true

var _root: Node2D
var _player: CharacterBody2D
var _speech: Node
var _npc: Node
var _resolved_steps: Array[TutorialBeatStep] = []

var _state: int = 0 # 0 OFF, 1 WAIT_TRIGGER, 2 SPEAKING
const _OFF := 0
const _WAIT := 1
const _SPEAK := 2

var _active: TutorialBeatStep
var _travel: float = 0.0
var _last_p: Vector2
## Balon tutma: null ise mesafe ile kapanır; doluysa overlaps_body ile beklenir.
var _speech_hold_area: Area2D = null
var _awaiting_area: Area2D
var _resume_trigger: bool = false

# --- Sıralı dövüş görevleri (use_combat_objectives) ---
var _co_phase: int = 0
var _co_light: int = 0
var _co_heavy: int = 0
var _co_fall: int = 0


func _ready() -> void:
	if auto_start:
		call_deferred("_boot")


func _boot() -> void:
	_root = get_parent() as Node2D
	if _root == null:
		push_error("[TutorialBeatDirector] Üst düğüm Node2D olmalı (TutorialDungeon kökü).")
		return
	_player = _root.get_node_or_null(^"%Player") as CharacterBody2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		push_error("[TutorialBeatDirector] Oyuncu bulunamadı.")
		return
	_speech = get_tree().get_first_node_in_group("tutorial_speech_bar")
	if _speech == null:
		_speech = _root.get_node_or_null("TutorialSpeechBar")
	if npc_scene == null:
		push_error("[TutorialBeatDirector] npc_scene atanmalı.")
		return
	var inst: Node = npc_scene.instantiate()
	if not inst.has_method("play_entrance") or not inst.has_method("depart_with_smoke_bomb"):
		push_error("[TutorialBeatDirector] npc_scene kökünde play_entrance ve depart_with_smoke_bomb olmalı.")
		return
	_npc = inst
	_root.add_child(_npc)
	_resolved_steps = tutorial_steps.duplicate() if not tutorial_steps.is_empty() else _default_steps()
	_run_sequence.call_deferred()


func _find_point(idx: int) -> Node2D:
	var hits: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group(TutorialPoint.GROUP_NAME):
		if n is TutorialPoint and (n as TutorialPoint).point_index == idx:
			hits.append(n as Node2D)
	if hits.is_empty():
		return null
	return hits[0]


func _resolve_speech_hold_area(step: TutorialBeatStep) -> Area2D:
	if not step.hold_until_exit_area.is_empty():
		var a := _root.get_node_or_null(step.hold_until_exit_area) as Area2D
		if a != null:
			return a
	if not step.trigger_area.is_empty():
		return _root.get_node_or_null(step.trigger_area) as Area2D
	return null


func _default_steps() -> Array[TutorialBeatStep]:
	var s0 := TutorialBeatStep.new()
	s0.begin_immediately = true
	s0.npc_point_index = 1
	s0.speech_bbcode = "Kendine geldin. Çabuk ol — fazla zaman yok."
	s0.close_after_travel_pixels = 260.0
	var s1 := TutorialBeatStep.new()
	s1.begin_immediately = false
	s1.trigger_area = NodePath("Markers/Beat1Trigger")
	s1.npc_point_index = 2
	s1.speech_bbcode = "Zıpla: [color=#c8c8c8]{jump}[/color]."
	s1.close_after_travel_pixels = 200.0
	var s2 := TutorialBeatStep.new()
	s2.begin_immediately = false
	s2.trigger_area = NodePath("Markers/Beat2Trigger")
	s2.npc_point_index = 3
	s2.speech_bbcode = (
		"Bu duvarı [b]çift zıpla[/b]: havadayken tekrar [color=#c8c8c8]{jump}[/color]."
	)
	s2.close_after_travel_pixels = 220.0
	var s3 := TutorialBeatStep.new()
	s3.begin_immediately = false
	s3.trigger_area = NodePath("Markers/Beat3Trigger")
	s3.npc_point_index = 4
	s3.speech_bbcode = "Dar geçit: [color=#c8c8c8]{crouch}[/color] ile eğil."
	s3.close_after_travel_pixels = 200.0
	var s4 := TutorialBeatStep.new()
	s4.begin_immediately = false
	s4.trigger_area = NodePath("Markers/Beat4Trigger")
	s4.npc_point_index = 5
	s4.speech_bbcode = (
		"Tek yönlü platform: [color=#c8c8c8]{down}[/color] basılı tut, "
		+ "[color=#c8c8c8]{jump}[/color] ile aşağı in."
	)
	s4.close_after_travel_pixels = 200.0
	var s5 := TutorialBeatStep.new()
	s5.begin_immediately = false
	s5.trigger_area = NodePath("Markers/Beat5Trigger")
	s5.npc_point_index = 6
	s5.speech_bbcode = (
		"Köşeye zıpla. Tutunmak için [color=#c8c8c8]{block}[/color] basılı tut; "
		+ "tutunurken [color=#c8c8c8]{up}[/color] ile tırman."
	)
	s5.close_after_travel_pixels = 220.0
	var s6 := TutorialBeatStep.new()
	s6.begin_immediately = false
	s6.trigger_area = NodePath("Markers/Beat6Trigger")
	s6.npc_point_index = 7
	s6.use_combat_objectives = true
	s6.speech_bbcode = ""
	s6.close_after_travel_pixels = 99999.0
	var arr: Array[TutorialBeatStep] = []
	arr.append(s0)
	arr.append(s1)
	arr.append(s2)
	arr.append(s3)
	arr.append(s4)
	arr.append(s5)
	arr.append(s6)
	return arr


func _run_sequence() -> void:
	for step in _resolved_steps:
		if step.begin_immediately:
			await _play_beat(step)
		else:
			await _wait_trigger_then_play(step)
	all_beats_completed.emit()


func _wait_trigger_then_play(step: TutorialBeatStep) -> void:
	var area := _root.get_node_or_null(step.trigger_area) as Area2D
	if area == null:
		push_error("[TutorialBeatDirector] trigger_area bulunamadı: %s" % str(step.trigger_area))
		return
	_state = _WAIT
	_awaiting_area = area
	_resume_trigger = false
	if area.overlaps_body(_player):
		await _play_beat(step)
		_state = _OFF
		_awaiting_area = null
		return
	if not area.body_entered.is_connected(_on_trigger_body_entered):
		area.body_entered.connect(_on_trigger_body_entered)
	while not _resume_trigger:
		if not is_inside_tree():
			break
		var st_wait: SceneTree = get_tree()
		if st_wait == null:
			break
		await st_wait.physics_frame
	if area.body_entered.is_connected(_on_trigger_body_entered):
		area.body_entered.disconnect(_on_trigger_body_entered)
	_resume_trigger = false
	_awaiting_area = null
	_state = _OFF
	await _play_beat(step)


func _on_trigger_body_entered(body: Node2D) -> void:
	if _awaiting_area == null or body != _player:
		return
	_resume_trigger = true


func _play_beat(step: TutorialBeatStep) -> void:
	var pt := _find_point(step.npc_point_index)
	var spot: Vector2 = _player.global_position + Vector2(112, -40)
	if pt != null:
		spot = pt.global_position
	elif step.npc_point_index > 0:
		push_warning(
			"[TutorialBeatDirector] TutorialPoint point_index=%d bulunamadı; mentor oyuncuya göre yerleştirildi."
			% step.npc_point_index
		)
	await _npc.play_entrance(spot)
	_active = step
	_state = _SPEAK
	if step.use_combat_objectives:
		_speech_hold_area = null
		await _run_combat_objectives()
	else:
		var bb: String = _expand_tokens(step.speech_bbcode)
		if is_instance_valid(_speech) and _speech.has_method("set_speech_bbcode"):
			_speech.call("set_speech_bbcode", bb)
		_speech_hold_area = _resolve_speech_hold_area(step)
		if _speech_hold_area != null:
			# Oyuncu alanın dışındayken tek while hemen biter, balon hiç görünmez; önce giriş sonra çıkış bekle.
			while _state == _SPEAK and is_instance_valid(_speech_hold_area) and not _speech_hold_area.overlaps_body(_player):
				if not is_inside_tree():
					break
				var st0: SceneTree = get_tree()
				if st0 == null:
					break
				await st0.physics_frame
			while _state == _SPEAK and is_instance_valid(_speech_hold_area) and _speech_hold_area.overlaps_body(_player):
				if not is_inside_tree():
					break
				var st1: SceneTree = get_tree()
				if st1 == null:
					break
				await st1.physics_frame
			_state = _OFF
		else:
			_travel = 0.0
			_last_p = _player.global_position
			while _state == _SPEAK:
				if not is_inside_tree():
					break
				var st2: SceneTree = get_tree()
				if st2 == null:
					break
				await st2.physics_frame
	_speech_hold_area = null
	_active = null
	if is_instance_valid(_speech) and _speech.has_method("clear_speech"):
		_speech.call("clear_speech")
	await _npc.depart_with_smoke_bomb()
	_state = _OFF


func _physics_process(_dt: float) -> void:
	if _state != _SPEAK or _player == null or _active == null:
		return
	if _active.use_combat_objectives:
		return
	if _speech_hold_area != null:
		return
	_travel += _player.global_position.distance_to(_last_p)
	_last_p = _player.global_position
	if _travel >= _active.close_after_travel_pixels:
		_state = _OFF


func _run_combat_objectives() -> void:
	_co_phase = 0
	_co_light = 0
	_co_heavy = 0
	_co_fall = 0
	_connect_combat_signals()
	_refresh_combat_speech()
	while _co_phase < 7 and _state == _SPEAK and is_instance_valid(_player):
		if not is_inside_tree():
			break
		var st_co: SceneTree = get_tree()
		if st_co == null:
			break
		await st_co.process_frame
	_disconnect_combat_signals()
	if _state == _SPEAK:
		_state = _OFF


func _connect_combat_signals() -> void:
	if _player == null:
		return
	if _player.has_signal("player_attack_landed"):
		if not _player.is_connected("player_attack_landed", _co_on_attack_landed):
			_player.player_attack_landed.connect(_co_on_attack_landed)
	if _player.has_signal("player_dodged"):
		if not _player.is_connected("player_dodged", _co_on_player_dodged):
			_player.player_dodged.connect(_co_on_player_dodged)
	if _player.has_signal("player_blocked"):
		if not _player.is_connected("player_blocked", _co_on_player_blocked):
			_player.player_blocked.connect(_co_on_player_blocked)
	if _player.has_signal("perfect_parry"):
		if not _player.is_connected("perfect_parry", _co_on_perfect_parry):
			_player.perfect_parry.connect(_co_on_perfect_parry)
	if _player.has_signal("player_attack_performed"):
		if not _player.is_connected("player_attack_performed", _co_on_attack_performed):
			_player.player_attack_performed.connect(_co_on_attack_performed)


func _disconnect_combat_signals() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.is_connected("player_attack_landed", _co_on_attack_landed):
		_player.player_attack_landed.disconnect(_co_on_attack_landed)
	if _player.is_connected("player_dodged", _co_on_player_dodged):
		_player.player_dodged.disconnect(_co_on_player_dodged)
	if _player.is_connected("player_blocked", _co_on_player_blocked):
		_player.player_blocked.disconnect(_co_on_player_blocked)
	if _player.is_connected("perfect_parry", _co_on_perfect_parry):
		_player.perfect_parry.disconnect(_co_on_perfect_parry)
	if _player.is_connected("player_attack_performed", _co_on_attack_performed):
		_player.player_attack_performed.disconnect(_co_on_attack_performed)


func _refresh_combat_speech() -> void:
	var raw := _combat_objective_bbcode()
	if is_instance_valid(_speech) and _speech.has_method("set_speech_bbcode"):
		_speech.call("set_speech_bbcode", _expand_tokens(raw))


func _combat_objective_bbcode() -> String:
	match _co_phase:
		0:
			return (
				"[b]Dövüş pratiği[/b] (1/7)\n"
				+ "Düşmana [color=#c8c8c8]{attack}[/color] ile [b]5[/b] hafif vuruş (ilerleme: %d/5).\n"
				% _co_light
				+ "Yer veya havadayken hafif saldırı tuşuna bas; düşmana isabet etsin."
			)
		1:
			return (
				"[b]Dövüş pratiği[/b] (2/7)\n"
				+ "Düşmana [color=#c8c8c8]{attack_heavy}[/color] ile [b]2[/b] ağır vuruş (ilerleme: %d/2).\n" % _co_heavy
				+ "Ağır saldırı tuşunu basılı tut veya combo ile ağır vuruş çıkar; ikisinde de düşmana çarpmalı."
			)
		2:
			return (
				"[b]Dövüş pratiği[/b] (3/7)\n"
				+ "Havadayken [color=#c8c8c8]{down}[/color] + [color=#c8c8c8]{jump}[/color] ile [b]2[/b] düşüş saldırısı (ilerleme: %d/2).\n" % _co_fall
				+ "Düşüş saldırısı düşmana değince sayılır."
			)
		3:
			return (
				"[b]Dövüş pratiği[/b] (4/7)\n"
				+ "[color=#c8c8c8]{dodge}[/color] ile bir kez kaçın.\n"
				+ "Yön tuşlarıyla yüzünü çevir, kaçış tuşu ile yuvarlan."
			)
		4:
			return (
				"[b]Dövüş pratiği[/b] (5/7)\n"
				+ "Bir saldırıyı [color=#c8c8c8]{block}[/color] ile tut: kalkanı aç, vuruşu hasarsız kes.\n"
				+ "Parry değil — sadece blok (hasarı kıran normal blok)."
			)
		5:
			return (
				"[b]Dövüş pratiği[/b] (6/7)\n"
				+ "Bir saldırıyı [b]parry[/b] yap: [color=#c8c8c8]{block}[/color] ile vuruşun geldiği anı yakala (timing).\n"
				+ "Kısa pencerede bloğa bas; hasar gelmez, parry sayılır."
			)
		6:
			return (
				"[b]Dövüş pratiği[/b] (7/7)\n"
				+ "Parry sonrası kontra: pencere açıkken [color=#c8c8c8]{attack}[/color] veya [color=#c8c8c8]{attack_heavy}[/color] ile vur.\n"
				+ "Kontra vuruş animasyonu tetiklenince görev biter."
			)
		_:
			return "[b]Tamam![/b]\nArtık hazırsın."


func _co_on_attack_landed(attack_type: String, _damage: float, _targets: Array, _pos: Vector2, _filter: String) -> void:
	if _state != _SPEAK or _co_phase > 2:
		return
	match _co_phase:
		0:
			if attack_type == "normal":
				_co_light = mini(_co_light + 1, 5)
				if _co_light >= 5:
					_co_phase = 1
				_refresh_combat_speech()
		1:
			if attack_type == "heavy":
				_co_heavy = mini(_co_heavy + 1, 2)
				if _co_heavy >= 2:
					_co_phase = 2
				_refresh_combat_speech()
		2:
			if attack_type == "fall":
				_co_fall = mini(_co_fall + 1, 2)
				if _co_fall >= 2:
					_co_phase = 3
				_refresh_combat_speech()


func _co_on_player_dodged(_dir: int, _s: Vector2, _e: Vector2) -> void:
	if _state != _SPEAK or _co_phase != 3:
		return
	_co_phase = 4
	_refresh_combat_speech()


func _co_on_player_blocked(_blocked: float, _attacker: Node2D) -> void:
	if _state != _SPEAK or _co_phase != 4:
		return
	if _blocked <= 0.0:
		return
	_co_phase = 5
	_refresh_combat_speech()


func _co_on_perfect_parry() -> void:
	if _state != _SPEAK or _co_phase != 5:
		return
	_co_phase = 6
	_refresh_combat_speech()


func _co_on_attack_performed(attack_name: String, _damage: float) -> void:
	if _state != _SPEAK or _co_phase != 6:
		return
	var n := str(attack_name)
	if n.begins_with("counter_"):
		_co_phase = 7
		_refresh_combat_speech()


func _expand_tokens(bbcode: String) -> String:
	var out := bbcode
	var im: Node = get_node_or_null("/root/InputManager")
	if im != null:
		if "{jump}" in out and im.has_method("get_tutorial_jump_hint"):
			out = out.replace("{jump}", str(im.call("get_tutorial_jump_hint")))
		if "{move}" in out and im.has_method("get_tutorial_horizontal_move_hint"):
			out = out.replace("{move}", str(im.call("get_tutorial_horizontal_move_hint")))
		if "{crouch}" in out and im.has_method("get_tutorial_crouch_hint"):
			out = out.replace("{crouch}", str(im.call("get_tutorial_crouch_hint")))
		if "{down}" in out and im.has_method("get_tutorial_move_down_hint"):
			out = out.replace("{down}", str(im.call("get_tutorial_move_down_hint")))
		if "{up}" in out and im.has_method("get_tutorial_move_up_hint"):
			out = out.replace("{up}", str(im.call("get_tutorial_move_up_hint")))
		if "{block}" in out and im.has_method("get_tutorial_block_hint"):
			out = out.replace("{block}", str(im.call("get_tutorial_block_hint")))
		if "{attack}" in out and im.has_method("get_tutorial_attack_hint"):
			out = out.replace("{attack}", str(im.call("get_tutorial_attack_hint")))
		if "{attack_heavy}" in out and im.has_method("get_tutorial_attack_heavy_hint"):
			out = out.replace("{attack_heavy}", str(im.call("get_tutorial_attack_heavy_hint")))
		if "{dodge}" in out and im.has_method("get_tutorial_dodge_hint"):
			out = out.replace("{dodge}", str(im.call("get_tutorial_dodge_hint")))
	return out
