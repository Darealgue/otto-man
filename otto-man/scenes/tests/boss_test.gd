extends Node2D

@onready var player: Node = $Player
@onready var boss_container: Node = self
@export var boss_scene: PackedScene = preload("res://enemy/miniboss/shield_captain/shield_captain.tscn")
@export var boss_spawn_position: Vector2 = Vector2(220, -100)

var current_boss: Node = null

func _ready() -> void:
	# Ensure floor sits at y=0
	$Floor.position = Vector2(0, 0)
	_spawn_boss()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_respawn_boss()

func _respawn_boss() -> void:
	if is_instance_valid(current_boss):
		current_boss.queue_free()
	current_boss = null
	_spawn_boss()

func _spawn_boss() -> void:
	if boss_scene == null:
		push_error("[BossTest] boss_scene is null")
		return
	var boss := boss_scene.instantiate()
	if boss == null:
		push_error("[BossTest] Failed to instantiate boss scene")
		return
	boss.name = "ShieldCaptain"
	boss.position = boss_spawn_position
	boss_container.add_child(boss)
	current_boss = boss
	_connect_boss_bar(boss)

func _connect_boss_bar(boss: Node) -> void:
	var ui_root: CanvasLayer = null
	if player and player.has_node("UI") and player.get_node("UI") is CanvasLayer:
		ui_root = player.get_node("UI")
	else:
		ui_root = CanvasLayer.new()
		ui_root.name = "TemporaryBossUI"
		add_child(ui_root)

	# Replace any existing boss bar
	var existing_bar = ui_root.get_node_or_null("BossHealthBar")
	if existing_bar:
		existing_bar.queue_free()

	var boss_bar_scene: PackedScene = load("res://ui/boss_health_bar.tscn")
	if boss_bar_scene == null:
		push_error("[BossTest] Failed to load boss_health_bar.tscn")
		return
	var boss_bar = boss_bar_scene.instantiate()
	boss_bar.name = "BossHealthBar"
	ui_root.add_child(boss_bar)

	# Hook signals if present
	if boss.has_signal("health_changed"):
		boss.connect("health_changed", Callable(boss_bar, "update_health"))
	if boss.has_signal("enemy_defeated"):
		boss.connect("enemy_defeated", Callable(boss_bar, "hide_bar"))

	# Show immediately in test scene
	if boss_bar.has_method("reveal"):
		boss_bar.reveal()

