extends Area2D

@export var minigame_kind: String = "villager" # or "vip"
var _fired: bool = false
var _player_overlapping: bool = false

func _ready():
	monitoring = true
	set_deferred("monitorable", true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Debug info

func _on_body_entered(body: Node):
	var groups := []
	if body.has_method("get_groups"):
		groups = body.get_groups()
	if body is CollisionObject2D:
		pass
	if _fired:
		return
	if body.has_method("is_in_group") and body.is_in_group("player"):
		_player_overlapping = true
	else:
		pass

func _on_body_exited(body: Node) -> void:
	if body.has_method("is_in_group") and body.is_in_group("player"):
		_player_overlapping = false

func _process(_delta: float) -> void:
	if _fired or not _player_overlapping:
		return
	if InputManager.is_interact_just_pressed() or InputManager.is_ui_up_just_pressed():
		_fired = true
		MinigameRouter.start_minigame(minigame_kind, {"source": name})
