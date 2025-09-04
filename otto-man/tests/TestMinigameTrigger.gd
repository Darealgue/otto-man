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
	print("[MiniTrigger] Ready. kind=", minigame_kind, " layer=", collision_layer, " mask=", collision_mask)

func _on_body_entered(body: Node):
	var groups := []
	if body.has_method("get_groups"):
		groups = body.get_groups()
	print("[MiniTrigger] body_entered:", body, " groups=", groups)
	if body is CollisionObject2D:
		print("[MiniTrigger] body layer=", (body as CollisionObject2D).collision_layer)
	if _fired:
		print("[MiniTrigger] already fired, ignoring")
		return
	if body.has_method("is_in_group") and body.is_in_group("player"):
		_player_overlapping = true
		print("[MiniTrigger] player overlapping: waiting for interact key")
	else:
		print("[MiniTrigger] non-player body, ignoring")

func _on_body_exited(body: Node) -> void:
	if body.has_method("is_in_group") and body.is_in_group("player"):
		_player_overlapping = false
		print("[MiniTrigger] player left area")

func _process(_delta: float) -> void:
	if _fired or not _player_overlapping:
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_up"):
		_fired = true
		print("[MiniTrigger] interact pressed → starting minigame kind=", minigame_kind)
		MinigameRouter.start_minigame(minigame_kind, {"source": name})
