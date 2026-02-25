# ziplama_zehiri.gd
# UNCOMMON - Zıplarken (havadayken) zehir trail bırakırsın

extends ItemEffect

const PoisonCloudScript = preload("res://effects/poison_cloud.gd")
const SPAWN_INTERVAL := 0.12

var _player: CharacterBody2D = null
var _trail_timer := 0.0

func _init():
	item_id = "ziplama_zehiri"
	item_name = "Zıplama Zehiri"
	description = "Zıplarken havada zehir izi bırakırsın"
	flavor_text = "Zehirli sıçrama"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.JUMP
	affected_stats = ["jump_poison"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_trail_timer = 0.0
	print("[Zıplama Zehiri] Zıplarken zehir izi bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	var sm = player.get_node_or_null("StateMachine")
	if not sm or not sm.current_state:
		_trail_timer = 0.0
		return
	var state_name = sm.current_state.name
	# Jump veya Fall (havada) iken zehir bırak
	if state_name != "Jump" and state_name != "Fall":
		_trail_timer = 0.0
		return
	_trail_timer += delta
	if _trail_timer >= SPAWN_INTERVAL:
		_trail_timer = 0.0
		_spawn_poison_at(player.get_foot_position())

func _spawn_poison_at(pos: Vector2):
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var cloud = Node2D.new()
	cloud.set_script(PoisonCloudScript)
	tree.current_scene.add_child(cloud)
	cloud.global_position = pos
