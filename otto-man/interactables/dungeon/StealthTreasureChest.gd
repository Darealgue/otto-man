class_name StealthTreasureChest
extends Area2D
## Yan yol sandığı: zemin anchor'ında spawn; ↑ ile açılır, altın saçar.

const CollisionLayers = preload("res://resources/CollisionLayers.gd")

const GROUP_NAME: StringName = &"stealth_treasure_chest"
const CHEST_TEXTURE_PATHS: Array[String] = [
	"res://assets/decorations/chest_1.png",
	"res://assets/decorations/barrel_1.png",
	"res://assets/decorations/small_pot_1.png",
]
const CHEST_OPEN_PATH: String = "res://assets/decorations/chest_open.png"

var gold_total: int = 18
var _opened: bool = false
var _locked: bool = false
var _player_in_range: bool = false
var _sprite: Sprite2D
var _placeholder: Polygon2D
var _hint: Label

const CHEST_Z_INDEX: int = 3


func setup(total_gold: int) -> void:
	gold_total = maxi(8, total_gold)


func _ready() -> void:
	add_to_group(GROUP_NAME)
	collision_layer = CollisionLayers.ITEM
	collision_mask = CollisionLayers.PLAYER
	monitoring = true
	monitorable = true
	z_index = CHEST_Z_INDEX

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(72.0, 56.0)
	shape.shape = rect
	add_child(shape)

	_placeholder = Polygon2D.new()
	_placeholder.name = "Placeholder"
	_placeholder.color = Color(0.52, 0.36, 0.2, 1.0)
	_placeholder.polygon = PackedVector2Array([
		Vector2(-28.0, 8.0),
		Vector2(28.0, 8.0),
		Vector2(32.0, -6.0),
		Vector2(24.0, -28.0),
		Vector2(-24.0, -28.0),
		Vector2(-32.0, -6.0),
	])
	add_child(_placeholder)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = _resolve_closed_texture()
	_sprite.centered = true
	_sprite.position = Vector2(0.0, -10.0)
	if _sprite.texture:
		_placeholder.visible = false
	add_child(_sprite)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = "Sandık"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-52.0, -58.0)
	_hint.size = Vector2(104.0, 20.0)
	_hint.add_theme_font_size_override("normal_font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.12))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.visible = false
	add_child(_hint)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var sm: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(sm) and sm.has_signal("alarm_raised"):
		if not sm.alarm_raised.is_connected(lock_on_alarm):
			sm.alarm_raised.connect(lock_on_alarm)
		if sm.get("segment_alarm") == true:
			lock_on_alarm("")


func _process(_delta: float) -> void:
	if _opened or _locked or not _player_in_range:
		return
	if InputManager.is_ui_up_just_pressed():
		_open_chest()


func lock_on_alarm(_reason: String = "") -> void:
	if _opened:
		return
	_locked = true
	if _sprite:
		_sprite.modulate = Color(0.45, 0.45, 0.5, 0.85)
	if _placeholder:
		_placeholder.modulate = Color(0.45, 0.45, 0.5, 0.85)
	if _hint.visible:
		_hint.text = "Kilitli"
		_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))


func _open_chest() -> void:
	if _opened or _locked:
		return
	_opened = true
	if _sprite:
		var open_tex: Texture2D = _load_texture(CHEST_OPEN_PATH)
		if open_tex:
			_sprite.texture = open_tex
			_placeholder.visible = false
		else:
			_sprite.modulate = Color(0.9, 0.95, 1.0)
	if _placeholder:
		_placeholder.color = Color(0.35, 0.28, 0.18)
	_hint.visible = false
	_spawn_gold_burst()
	print("[StealthChest] Açıldı — %d altın saçıldı" % gold_total)


func _spawn_gold_burst() -> void:
	var spawner: DecorationSpawner = _find_loot_spawner()
	if spawner == null:
		push_warning("[StealthChest] Loot spawner bulunamadı")
		return
	spawner.call_deferred("spawn_enemy_gold_burst", global_position + Vector2(0.0, -16.0), gold_total, false)


func _find_loot_spawner() -> DecorationSpawner:
	for n in get_tree().get_nodes_in_group("decoration_spawner"):
		if n is DecorationSpawner:
			return n as DecorationSpawner
	var lg: Node = get_tree().get_first_node_in_group("level_generator")
	if lg:
		var sp := DecorationSpawner.new()
		sp.name = "StealthChestLootSpawner"
		lg.add_child(sp)
		return sp
	return null


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = true
		if not _opened and not _locked:
			_hint.visible = true
			_hint.text = "[↑] Sandık"


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		if not _opened and not _locked:
			_hint.visible = false
			_hint.text = "Sandık"


func _resolve_closed_texture() -> Texture2D:
	for path in CHEST_TEXTURE_PATHS:
		var tex: Texture2D = _load_texture(path)
		if tex:
			return tex
	return null


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
