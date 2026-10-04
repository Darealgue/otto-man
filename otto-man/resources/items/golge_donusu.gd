# golge_donusu.gd
# UNCOMMON - Dodge/dash bittikten sonra 1 sn içinde Blok tuşuna basarsan, hareketin başladığı
# yere geri ışınlanırsın; gittiğin yerde kısa süren bir gölge kalır. (Eğilme tuşu slide'a ait
# olduğu için kasıtlı olarak Blok tuşu kullanılır.)

extends ItemEffect

const DecoyScene = preload("res://effects/player_decoy.tscn")
const RETURN_WINDOW := 1.0
const COOLDOWN := 2.0
const MIN_DISTANCE := 48.0
const DECOY_LIFETIME := 1.5

var _player: CharacterBody2D = null
var _return_pos: Vector2 = Vector2.ZERO
var _window_left: float = 0.0
var _cooldown_left: float = 0.0

func _init():
	item_id = "golge_donusu"
	item_name = tr("item.golge_donusu.name")
	description = tr("item.golge_donusu.description")
	flavor_text = "Gölge her zaman geri çağırır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["dodge_return"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_window_left = 0.0
	_cooldown_left = 0.0
	print("[Gölge Dönüşü] ✅ Dodge sonrası Blok = başlangıç noktasına ışınlan")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	_window_left = 0.0
	print("[Gölge Dönüşü] ❌ Kaldırıldı")

# ItemManager player_dodged'a otomatik bağlar (dodge ve dash bitişinde ateşlenir)
func _on_player_dodged(_direction: int, start_pos: Vector2, end_pos: Vector2) -> void:
	if _cooldown_left > 0.0:
		return
	if start_pos.distance_to(end_pos) < MIN_DISTANCE:
		return
	_return_pos = start_pos
	_window_left = RETURN_WINDOW

func process(player: CharacterBody2D, delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if _window_left <= 0.0:
		return
	_window_left -= delta
	if not is_instance_valid(player):
		return
	if Input.is_action_just_pressed("block"):
		_return_now(player)

func _return_now(player: CharacterBody2D) -> void:
	_window_left = 0.0
	_cooldown_left = COOLDOWN
	var from_pos: Vector2 = player.global_position
	_spawn_decoy(from_pos, player)
	player.global_position = _return_pos
	var im := get_node_or_null("/root/ItemManager")
	if im:
		im.notify_item_event("_on_shadow_return", [from_pos, _return_pos])
	player.velocity = Vector2.ZERO
	print("[Gölge Dönüşü] ⚡ Başlangıç noktasına dönüldü")

func _spawn_decoy(pos: Vector2, player: CharacterBody2D) -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var decoy = DecoyScene.instantiate()
	decoy.lifetime_override = DECOY_LIFETIME
	tree.current_scene.add_child(decoy)
	var flip: bool = player.sprite.flip_h if player.get("sprite") else false
	decoy.setup(pos, flip, player)
