# koruk.gd
# UNCOMMON - Combo sayacı 5'i geçince vücut tutuşur: 4 sn boyunca yakındaki düşmanlar yanar.
# Eksi: tutuşukken alınan hasar +%20. Saldırganlığı ödüllendirir, riski artırır.

extends ItemEffect

const COMBO_THRESHOLD := 5
const COMBO_WINDOW := 3.0      # vuruşlar arası bu süre geçerse sayaç sıfırlanır
const IGNITE_DURATION := 4.0
const IGNITE_TICK_INTERVAL := 1.0
const IGNITE_RADIUS := 140.0
const DAMAGE_TAKEN_PENALTY := 1.20
const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const IGNITE_COLOR := Color(1.0, 0.5, 0.15, 0.55)

var _player: CharacterBody2D = null
var _combo := 0
var _combo_timer := 0.0
var _ignite_timer := 0.0
var _tick_timer := 0.0
var _penalty_applied := false

func _init():
	item_id = "koruk"
	item_name = tr("item.koruk.name")
	description = tr("item.koruk.description")
	flavor_text = "Körüklenen ateş, sahibini de yalar"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.STAMINA
	tags = ["elemental_fire"]
	affected_stats = ["combo_ignite", "incoming_damage"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_combo = 0
	_combo_timer = 0.0
	_ignite_timer = 0.0
	_tick_timer = 0.0
	_penalty_applied = false
	print("[Körük] ✅ 5 combo → 4 sn tutuşma (alınan hasar +%20)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_clear_penalty()
	_player = null
	print("[Körük] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, _damage: float, _targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "elemental_only":
		return
	if not is_instance_valid(_player) or (attack_type != "normal" and attack_type != "ranged"):
		return
	_combo += 1
	_combo_timer = COMBO_WINDOW
	if _combo >= COMBO_THRESHOLD and _ignite_timer <= 0.0:
		_start_ignite()

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	_player = player

	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo = 0

	if _ignite_timer <= 0.0:
		return

	_ignite_timer -= delta
	if _ignite_timer <= 0.0:
		_clear_penalty()
		_combo = 0
		return

	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer = IGNITE_TICK_INTERVAL
	var tree = player.get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if not node.has_method("add_burn_stack"):
			continue
		if player.global_position.distance_to(node.global_position) <= IGNITE_RADIUS:
			node.add_burn_stack()
	if tree.current_scene:
		var burst = Node2D.new()
		burst.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(burst)
		burst.setup(player.global_position, IGNITE_RADIUS, IGNITE_COLOR)

func _start_ignite() -> void:
	_ignite_timer = IGNITE_DURATION
	_tick_timer = 0.0
	if not _penalty_applied and is_instance_valid(_player):
		_player.incoming_damage_multiplier *= DAMAGE_TAKEN_PENALTY
		_penalty_applied = true
	print("[Körük] 🔥 Tutuştu — 4 sn çevre yanıyor, alınan hasar +%20")

func _clear_penalty() -> void:
	if _penalty_applied and is_instance_valid(_player):
		_player.incoming_damage_multiplier /= DAMAGE_TAKEN_PENALTY
	_penalty_applied = false
	_ignite_timer = 0.0
