# korku_yangini.gd
# RARE - Yanma katmanları dolan düşman panikler: 1.5 sn hedef kaybeder (saldırmaz) ve senden uzağa
# kaçar. Düşman başına 6 sn bekleme. Boss ve miniboss etkilenmez. Hedef kaybı base_enemy.gd
# (start_fear / is_afraid / get_nearest_player), kaçış hareketi burada.

extends ItemEffect

const FEAR_DURATION := 1.5
const FEAR_COOLDOWN := 6.0
const FLEE_SPEED := 170.0
const FULL_BURN_TICKS := 9
const COOLDOWN_META := "korku_yangini_ready_at"

var _player: CharacterBody2D = null

func _init():
	item_id = "korku_yangini"
	item_name = tr("item.korku_yangini.name")
	description = tr("item.korku_yangini.description")
	flavor_text = "Ateşten herkes kaçar"
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["burn_fear"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	var im := get_node_or_null("/root/ItemManager")
	var tree := get_tree()
	if im == null or tree == null:
		return
	var now := Time.get_ticks_msec()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_live_enemy(node):
			continue
		if not node.has_method("is_afraid"):
			continue
		if node.is_afraid():
			_flee(node, player, delta)
		elif node.get("burn_remaining_ticks") != null and int(node.burn_remaining_ticks) >= FULL_BURN_TICKS and _can_panic(node, now):
			node.start_fear(FEAR_DURATION)
			node.set_meta(COOLDOWN_META, now + int((FEAR_DURATION + FEAR_COOLDOWN) * 1000.0))
			im.spawn_element_hit_flash(node, "fire")

func _can_panic(node: Node, now: int) -> bool:
	if node.has_meta(COOLDOWN_META) and int(node.get_meta(COOLDOWN_META)) > now:
		return false
	var path := ""
	if node.get_script() != null:
		path = String(node.get_script().resource_path)
	return not (path.contains("boss") or path.contains("miniboss"))

func _flee(node: Node, player: Node2D, delta: float) -> void:
	if not node.has_method("move_and_collide"):
		return
	var away: float = 1.0 if node.global_position.x >= player.global_position.x else -1.0
	node.move_and_collide(Vector2(away * FLEE_SPEED * delta, 0.0))
