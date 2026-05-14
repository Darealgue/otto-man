extends Node
## Hareket segmenti: önce [b]GoalRight[/b] (sadece “şimdi sola dön” aşamasına geçer, köy yok),
## sonra [b]GoalLeft[/b] (köye geçiş — SceneManager.change_to_village). Alanları haritada istediğin yere koyabilirsin;
## isimler sırayı belirler, yönü değil. Köy çıkışı tek tünel ve sağdaysa: önce bir yerde GoalRight tetiklenmeli,
## tüneldeki alan [b]GoalLeft[/b] olmalı. Metinler InputManager ipuçlarını kullanır.

## TutorialBeatDirector alt balonu kullanıyorsa true bırak: çift metin olmasın.
@export var suppress_movement_speech: bool = true
## Beat6 dövüş listesi bittiğinde (TutorialBeatDirector.all_beats_completed) gösterilir; BBCode.
@export_multiline var post_combat_exit_hint_bbcode: String = (
	"[b]Acele et — çıkış bu tarafta[/b]\n"
	+ "[color=#c8c8c8]Sağa koş[/color]; tünelden geçince köye dönersin."
)

enum _Step { RUN_RIGHT, RUN_LEFT, DONE }

var _step: _Step = _Step.RUN_RIGHT
var _last_prompt_text: String = ""

var _player: CharacterBody2D

@onready var _speech: CanvasLayer = %TutorialSpeechBar
@onready var _goal_right: Area2D = %GoalRight
@onready var _goal_left: Area2D = %GoalLeft


func _ready() -> void:
	call_deferred("_setup_player_and_goals")
	call_deferred("_connect_beat_director_hooks")


func _connect_beat_director_hooks() -> void:
	var root := get_parent()
	if root == null:
		return
	var director := root.get_node_or_null("TutorialBeatDirector")
	if director == null or not director.has_signal("all_beats_completed"):
		return
	if director.all_beats_completed.is_connected(_on_all_tutorial_beats_done):
		return
	director.all_beats_completed.connect(_on_all_tutorial_beats_done)


func _on_all_tutorial_beats_done() -> void:
	var root := get_parent()
	if root != null:
		var spawner := root.get_node_or_null("TutorialSequentialEnemySpawner")
		if spawner != null and spawner.has_method("stop_spawning"):
			spawner.call("stop_spawning")
	if is_instance_valid(_speech) and _speech.has_method("set_speech_bbcode"):
		_speech.call("set_speech_bbcode", post_combat_exit_hint_bbcode)


func _setup_player_and_goals() -> void:
	_player = get_node_or_null(^"%Player") as CharacterBody2D
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		push_error("[TutorialDungeonController] Oyuncu bulunamadı (%Player veya 'player' grubu).")
		return
	if is_instance_valid(_goal_right):
		_goal_right.body_entered.connect(_on_goal_right)
	if is_instance_valid(_goal_left):
		_goal_left.body_entered.connect(_on_goal_left)
	_refresh_prompt()


func _process(_delta: float) -> void:
	if _step == _Step.DONE:
		return
	_refresh_prompt()


func _refresh_prompt() -> void:
	if suppress_movement_speech:
		return
	if not is_instance_valid(_speech):
		return
	var next_text: String = ""
	var im: Node = get_node_or_null("/root/InputManager")
	var move_hint := "A ve D"
	var jump_hint := "Space"
	if im != null:
		if im.has_method("get_tutorial_horizontal_move_hint"):
			move_hint = str(im.call("get_tutorial_horizontal_move_hint"))
		if im.has_method("get_tutorial_jump_hint"):
			jump_hint = str(im.call("get_tutorial_jump_hint"))
	match _step:
		_Step.RUN_RIGHT:
			next_text = "[b]Sağa git[/b]\n[color=#c8c8c8]%s[/color] ile sağa koş ve [b]yeşil işaretli alana[/b] gir." % move_hint
		_Step.RUN_LEFT:
			next_text = (
				"[b]Sola dön[/b]\n[color=#c8c8c8]%s[/color] ile sola koş ve diğer işaretli alana gir.\nİleride zıplamak için: [color=#c8c8c8]%s[/color]"
				% [move_hint, jump_hint]
			)
		_:
			return
	if next_text == _last_prompt_text:
		return
	_last_prompt_text = next_text
	_speech.set_speech_bbcode(next_text)


func _on_goal_right(body: Node2D) -> void:
	if _step != _Step.RUN_RIGHT:
		return
	if body != _player:
		return
	_step = _Step.RUN_LEFT
	_refresh_prompt()


func _on_goal_left(body: Node2D) -> void:
	if _step != _Step.RUN_LEFT:
		return
	if body != _player:
		return
	_finish_segment()


func _finish_segment() -> void:
	_step = _Step.DONE
	_last_prompt_text = ""
	if is_instance_valid(_speech):
		_speech.set_speech_bbcode("[b]Güzel![/b]\nKöye geçiliyor…")
	var tm: Node = get_node_or_null("/root/TutorialManager")
	if tm != null and tm.has_method("mark_dungeon_movement_complete"):
		tm.call("mark_dungeon_movement_complete")
	await get_tree().create_timer(1.1).timeout
	if is_instance_valid(SceneManager):
		SceneManager.change_to_village({"source": "new_game_tutorial_dungeon"}, true)
