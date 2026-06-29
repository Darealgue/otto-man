class_name VillageDefenseBattleRunner
extends CanvasLayer
## Köy savunması — BattleScene overlay; sonuç WorldManager'a iletilir.

signal battle_finished(outcome: Dictionary)

const BATTLE_SCENE: PackedScene = preload("res://village_battlesim/BattleScene.tscn")

var _battle: Node = null
var _context: Dictionary = {}
var _awaiting_ack: bool = false
var _ack_panel: PanelContainer = null


func start_from_context(context: Dictionary) -> void:
	_context = context.duplicate(true)
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	var roster: Dictionary = VillageDefenseBattleConfig.build_rosters(
		int(_context.get("soldier_count", 0)),
		int(_context.get("attacker_strength", 8)),
		bool(_context.get("alliance_defender", false)),
		int(_context.get("defender_count", 0))
	)
	_battle = BATTLE_SCENE.instantiate()
	VillageDefenseBattleConfig.apply_to_battle_scene(_battle, roster)
	add_child(_battle)


func _process(_delta: float) -> void:
	if _battle == null or _awaiting_ack:
		return
	if not bool(_battle.get("battle_over")):
		return
	_awaiting_ack = true
	_show_ack_panel()


func _show_ack_panel() -> void:
	var summary: Dictionary = {}
	if _battle.has_method("get_outcome_summary"):
		summary = _battle.call("get_outcome_summary")
	var player_won: bool = bool(summary.get("player_won", false))
	_ack_panel = PanelContainer.new()
	_ack_panel.set_anchors_preset(Control.PRESET_CENTER)
	_ack_panel.offset_left = -220.0
	_ack_panel.offset_top = -70.0
	_ack_panel.offset_right = 220.0
	_ack_panel.offset_bottom = 70.0
	add_child(_ack_panel)
	var vbox := VBoxContainer.new()
	_ack_panel.add_child(vbox)
	var lbl := Label.new()
	lbl.text = tr("defense.battle.victory") if player_won else tr("defense.battle.defeat")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	var btn := Button.new()
	btn.text = tr("defense.battle.continue")
	vbox.add_child(btn)
	btn.pressed.connect(_on_ack_pressed.bind(summary))


func _on_ack_pressed(summary: Dictionary) -> void:
	var outcome: Dictionary = _context.duplicate(true)
	outcome.merge(summary, true)
	outcome["player_won"] = bool(summary.get("player_won", false))
	outcome["defender_losses"] = int(summary.get("defender_losses", 0))
	outcome["attacker_losses"] = int(summary.get("attacker_losses", 0))
	battle_finished.emit(outcome)
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_battle):
		_battle.queue_free()
		_battle = null
