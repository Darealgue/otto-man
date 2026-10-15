# aci_parry.gd
# UNCOMMON - Perfect parry saldırganı ve çevredeki düşmanları zehirler. Savunma hattının zehir köprüsü.

extends ItemEffect

const RADIUS := 100.0
const STACKS := 3

var _player: CharacterBody2D = null

func _init():
	item_id = "aci_parry"
	item_name = tr("item.aci_parry.name")
	description = tr("item.aci_parry.description")
	flavor_text = "Savuşturmak da acıtır"
	category = ItemCategory.PARRY
	affected_stats = ["parry_poison"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

func _on_perfect_parry() -> void:
	if not is_instance_valid(_player):
		return
	var im := get_node_or_null("/root/ItemManager")
	var tree := get_tree()
	if im == null or tree == null:
		return
	var victims: Array = []
	var block_state := _player.get_node_or_null("StateMachine/Block")
	if block_state and block_state.get("_last_parried_attacker") != null:
		var attacker = block_state.get("_last_parried_attacker")
		if is_instance_valid(attacker) and attacker.has_method("add_poison_stack"):
			victims.append(attacker)
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or victims.has(node) or node.get("current_behavior") == "dead":
			continue
		if _player.global_position.distance_to(node.global_position) <= RADIUS and node.has_method("add_poison_stack"):
			victims.append(node)
	for enemy in victims:
		im.add_poison_stacks(enemy, STACKS)
