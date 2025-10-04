extends Node

signal minigame_finished(result: Dictionary)

var _active_minigame: Node = null

func start_minigame(kind: String, context := {}):
	if _active_minigame:
		return
	var ps: PackedScene = null
	match kind:
		"villager":
			var villager_path := "res://ui/minigames/VillagerLockpick.tscn"
			if FileAccess.file_exists(villager_path):
				ps = load(villager_path)
			else:
				push_warning("[MinigameRouter] Villager minigame not found at " + villager_path)
				return
		"vip":
			var vip_path := "res://ui/minigames/DealDuel.tscn"
			if FileAccess.file_exists(vip_path):
				ps = load(vip_path)
			else:
				push_warning("[MinigameRouter] VIP minigame not found at " + vip_path)
				return
		_:
			return
	if ps == null:
		push_warning("[Router] PackedScene is null; aborting")
		return
	#print("[Router] Instantiating minigame…")
	_active_minigame = ps.instantiate()
	_active_minigame.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Safely set optional 'context' property if it exists on the minigame
	var plist := _active_minigame.get_property_list()
	for p in plist:
		if typeof(p) == TYPE_DICTIONARY and p.has("name") and String(p.name) == "context":
			_active_minigame.set("context", context)
			break
	if _active_minigame.has_signal("completed"):
		_active_minigame.connect("completed", Callable(self, "_on_minigame_completed"))
	get_tree().root.add_child(_active_minigame)
	#print("[Router] Minigame added to tree; pausing game now")
	get_tree().paused = true

func _on_minigame_completed(success: bool, payload := {}):
	if is_instance_valid(_active_minigame):
		_active_minigame.queue_free()
	_active_minigame = null
	get_tree().paused = false
	emit_signal("minigame_finished", {"success": success, "payload": payload})
