class_name BaseInteractable
extends Area2D

@export var minigame_kind: String = ""
@export var base_context: Dictionary = {}
@export var auto_disable_on_success: bool = true
@export var auto_disable_on_failure: bool = false
@export var player_group: StringName = &"player"
@export var require_interact_press: bool = true

var _player_overlapping: bool = false
var _awaiting_result: bool = false
var _disabled: bool = false
var _tracked_players: Array[Node] = []

func _ready() -> void:
	input_event.connect(_on_input_event)
	if has_signal("body_entered"):
		body_entered.connect(_on_body_entered)
	if has_signal("body_exited"):
		body_exited.connect(_on_body_exited)
	set_process(true)
	# Ensure monitoring is enabled for Area2D
	monitoring = true
	monitorable = true

func _process(_delta: float) -> void:
	if _disabled or _awaiting_result:
		return
	if !_player_overlapping:
		return
	if require_interact_press:
		# Sadece "interact" ve "ui_up" fiziksel aksiyonlarını kontrol et (ui_accept ve ui_forward değil)
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_up"):
			_trigger_interaction()
	else:
		_trigger_interaction()

func _on_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if _disabled or _awaiting_result:
		return
	if !_player_overlapping:
		return
	# Sadece "interact" ve "ui_up" fiziksel aksiyonlarını kontrol et (ui_accept ve ui_forward değil)
	if (event.is_action("interact") or event.is_action("ui_up")) and event.is_pressed():
		_trigger_interaction()

func _on_body_entered(body: Node) -> void:
	if _disabled:
		return
	if not _is_valid_player(body):
		return
	if _tracked_players.has(body):
		return
	_tracked_players.append(body)
	_player_overlapping = true
	_on_player_enter(body)
	if not require_interact_press:
		_trigger_interaction()

func _on_body_exited(body: Node) -> void:
	if not _tracked_players.has(body):
		return
	_tracked_players.erase(body)
	_on_player_exit(body)
	_player_overlapping = not _tracked_players.is_empty()

func _trigger_interaction() -> void:
	print("[BaseInteractable] _trigger_interaction() called for: ", name, " class=", get_class())
	print("[BaseInteractable] Current state: _disabled=", _disabled, " _awaiting_result=", _awaiting_result, " monitoring=", monitoring, " monitorable=", monitorable)
	if _disabled:
		print("[BaseInteractable] BLOCKED: _disabled is true")
		return
	if _awaiting_result:
		print("[BaseInteractable] BLOCKED: _awaiting_result is true (minigame already active)")
		return
	var kind := get_minigame_kind()
	if kind.is_empty():
		_on_interacted_without_minigame()
		return
	if !MinigameRouter.has_minigame(kind):
		push_warning("[BaseInteractable] Unknown minigame kind: %s" % kind)
		return
	print("[BaseInteractable] Starting minigame: ", kind)
	var callback := Callable(self, "_on_router_minigame_finished")
	if MinigameRouter.is_connected("minigame_finished", callback):
		# Should not happen, but disconnect to be safe
		print("[BaseInteractable] WARNING: Already connected to minigame_finished, disconnecting")
		MinigameRouter.disconnect("minigame_finished", callback)
	MinigameRouter.connect("minigame_finished", callback, CONNECT_ONE_SHOT)
	var started := MinigameRouter.start_minigame(kind, _build_minigame_context())
	if started:
		print("[BaseInteractable] Minigame started successfully, setting _awaiting_result=true")
		_awaiting_result = true
		_on_minigame_started()
	else:
		print("[BaseInteractable] Minigame failed to start")
		if MinigameRouter.is_connected("minigame_finished", callback):
			MinigameRouter.disconnect("minigame_finished", callback)
		_on_minigame_failed_to_start()

func _on_router_minigame_finished(result: Dictionary) -> void:
	_awaiting_result = false
	var success: bool = bool(result.get("success", false))
	var payload: Dictionary = result.get("payload", {})
	var cancelled: bool = bool(payload.get("distance_cancelled", false))
	if success:
		_on_minigame_success(payload)
		if auto_disable_on_success:
			set_interactable_enabled(false)
	else:
		_on_minigame_failure(payload)
		# Uzaklaşma durumunda (cancelled) auto_disable_on_failure'ı atla
		if auto_disable_on_failure and not cancelled:
			set_interactable_enabled(false)
	_on_minigame_completed(result)

func set_interactable_enabled(enabled: bool) -> void:
	print("[BaseInteractable] set_interactable_enabled(", enabled, ") called for: ", name, " class=", get_class())
	print("[BaseInteractable] BEFORE: _disabled=", _disabled, " monitoring=", monitoring, " monitorable=", monitorable, " process=", is_processing())
	_disabled = not enabled
	monitoring = enabled
	monitorable = enabled
	set_process(enabled)
	if not enabled:
		_player_overlapping = false
		_tracked_players.clear()
	print("[BaseInteractable] AFTER: _disabled=", _disabled, " monitoring=", monitoring, " monitorable=", monitorable, " process=", is_processing())

func is_interactable_enabled() -> bool:
	return not _disabled

func get_minigame_kind() -> String:
	return minigame_kind

func _build_minigame_context() -> Dictionary:
	return base_context.duplicate(true)

func _on_player_enter(_player: Node) -> void:
	pass

func _on_player_exit(_player: Node) -> void:
	pass

func _on_interacted_without_minigame() -> void:
	pass

func _on_minigame_started() -> void:
	pass

func _on_minigame_failed_to_start() -> void:
	pass

func _on_minigame_success(_payload: Dictionary) -> void:
	pass

func _on_minigame_failure(_payload: Dictionary) -> void:
	pass

func _on_minigame_completed(_result: Dictionary) -> void:
	pass

func _is_valid_player(body: Node) -> bool:
	return body and body.has_method("is_in_group") and body.is_in_group(player_group)
