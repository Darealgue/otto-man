# golge_hasadi.gd
# UNCOMMON - Öldürdüğün düşmanın yerinde 4 sn duran bir gölge belirir ve yakınındaki düşmanlara
# senin vuruşunu taklit ederek saldırır. Aynı anda en fazla 2 gölge.

extends ItemEffect

const DecoyScene = preload("res://effects/player_decoy.tscn")
const SHADOW_LIFETIME := 4.0
const ATTACK_INTERVAL := 0.9
const MAX_SHADOWS := 2

var _player: CharacterBody2D = null
var _shadows: Array = []   # [{node, timer}]

func _init():
	item_id = "golge_hasadi"
	item_name = tr("item.golge_hasadi.name")
	description = tr("item.golge_hasadi.description")
	flavor_text = "Her ölü, geride bir gölge bırakır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["kill_shadow"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_shadows.clear()
	print("[Gölge Hasadı] ✅ Öldürülen düşmanın yerinde saldıran gölge")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	for s in _shadows:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	_shadows.clear()
	_player = null
	print("[Gölge Hasadı] ❌ Kaldırıldı")

func on_enemy_killed(enemy: Node2D) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(enemy):
		return
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	_prune()
	if _shadows.size() >= MAX_SHADOWS:
		# En eski gölgenin yerine yenisi geçer
		var oldest = _shadows.pop_front()
		if is_instance_valid(oldest["node"]):
			oldest["node"].queue_free()
	var decoy = DecoyScene.instantiate()
	decoy.lifetime_override = SHADOW_LIFETIME
	tree.current_scene.add_child(decoy)
	var flip: bool = _player.sprite.flip_h if _player.get("sprite") else false
	decoy.setup(enemy.global_position, flip, _player)
	_shadows.append({"node": decoy, "timer": 0.3})

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if _shadows.is_empty():
		return
	_prune()
	for s in _shadows:
		s["timer"] -= delta
		if s["timer"] > 0.0:
			continue
		s["timer"] = ATTACK_INTERVAL
		var node = s["node"]
		if is_instance_valid(node) and node.has_method("attack_physical"):
			var dmg: float = 10.0
			var hb = _player.get_node_or_null("Hitbox") if is_instance_valid(_player) else null
			if hb and hb.get("damage") != null:
				dmg = float(hb.damage)
			node.attack_physical(dmg)

func _prune() -> void:
	var alive: Array = []
	for s in _shadows:
		if is_instance_valid(s["node"]):
			alive.append(s)
	_shadows = alive
