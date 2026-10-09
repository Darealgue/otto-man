# tasiyici.gd
# RARE - Kayarken zehirli bir düşmanın içinden geçersen zehir katmanlarını kaparsın; dokunduğun
# sonraki zehirsiz düşmana hepsini bırakırsın. Zehri bulaştırma aracı (Hareket hattı, Kayma).

extends ItemEffect

const CONTACT_RADIUS := 55.0
const POLL_INTERVAL := 0.05
## Zehir kapılan/bırakılan düşman bu süre boyunca tekrar dokunulamaz: aksi halde aynı kayışta
## bıraktığın düşmandan zehri hemen geri çalardın (kare kare ping pong).
const HANDOFF_IMMUNE_MSEC := 1500

var _player: CharacterBody2D = null
var _carried: int = 0
var _poll_left: float = 0.0
var _immune_until: Dictionary = {}   # düşman instance id -> msec

func _init():
	item_id = "tasiyici"
	item_name = tr("item.tasiyici.name")
	description = tr("item.tasiyici.description")
	flavor_text = "Zehri sen taşırsın"
	rarity = ItemRarity.RARE
	category = ItemCategory.SLIDE
	affected_stats = ["slide_poison_carry"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_carried = 0

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	_carried = 0
	_immune_until.clear()

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = POLL_INTERVAL
	if not _is_sliding(player):
		return
	var im := get_node_or_null("/root/ItemManager")
	var tree := get_tree()
	if im == null or tree == null:
		return
	var now := Time.get_ticks_msec()
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead" or node.get("poison_stacks") == null:
			continue
		if player.global_position.distance_to(node.global_position) > CONTACT_RADIUS:
			continue
		var eid: int = node.get_instance_id()
		if _immune_until.get(eid, 0) > now:
			continue
		if _carried == 0 and int(node.poison_stacks) > 0:
			_carried = int(node.poison_stacks)
			node.poison_stacks = 0
			_immune_until[eid] = now + HANDOFF_IMMUNE_MSEC
			im.spawn_element_hit_flash(node, "poison")
		elif _carried > 0 and int(node.poison_stacks) == 0:
			im.add_poison_stacks(node, _carried)
			_carried = 0
			_immune_until[eid] = now + HANDOFF_IMMUNE_MSEC

func _is_sliding(player: CharacterBody2D) -> bool:
	var sm = player.get("state_machine")
	if sm == null or sm.get("current_state") == null:
		return false
	return sm.current_state.name == "Slide"
