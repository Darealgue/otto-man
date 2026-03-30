extends Area2D
## Kamp çeşmesi: etkileşimle oyuncu canı doldurur.
## Placeholder görsel; sprite sonra eklenebilir.

const PLAYER_GROUP: StringName = &"player"

@export var heal_amount: float = 30.0
@export var heal_fraction_of_max: float = 0.0
@export var one_use_per_camp: bool = true

var _player_in_range: bool = false
var _used: bool = false

@onready var _prompt_label: Label = $PromptLabel if has_node("PromptLabel") else null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _prompt_label:
		_prompt_label.visible = false


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if one_use_per_camp and _used:
		if _prompt_label:
			_prompt_label.visible = false
		return
	if InputManager.is_interact_just_pressed() or InputManager.is_portal_enter_just_pressed():
		_try_heal()


func _is_player(body: Node2D) -> bool:
	return body.is_in_group(PLAYER_GROUP) or (body.get_parent() and body.get_parent().is_in_group(PLAYER_GROUP))


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_in_range = true
		if _prompt_label and not (one_use_per_camp and _used):
			_prompt_label.text = "E veya Yukarı - Su iç (can)"
			_prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_in_range = false
		if _prompt_label:
			_prompt_label.visible = false


func _try_heal() -> void:
	if one_use_per_camp and _used:
		return
	var ps = get_node_or_null("/root/PlayerStats")
	if not ps or not ps.has_method("get_current_health") or not ps.has_method("set_current_health"):
		return
	var current: float = ps.get_current_health()
	var max_h: float = ps.get_max_health() if ps.has_method("get_max_health") else 100.0
	if current >= max_h:
		return
	var add: float = heal_amount
	if heal_fraction_of_max > 0.0:
		add = max_h * heal_fraction_of_max
	var new_health: float = minf(current + add, max_h)
	ps.set_current_health(new_health, false)
	_used = true
	if _prompt_label:
		_prompt_label.text = "Kullanıldı"
		_prompt_label.visible = true
	print("[CampFountain] Healed player to %.1f" % new_health)
