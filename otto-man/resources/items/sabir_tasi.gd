# sabir_tasi.gd
# RARE - Zehirli düşman ne kadar uzun süre zehirli kalırsa zehir hasarı o kadar artar
# (saniyede +%15, en fazla 5 kat). Ona vurduğun anda sayaç sıfırlanır.
# Zehir zindanının kimliği olan "sabır"ı mekanikleştirir: vur, çekil, izle, dokunma.
# Görünmezlik Pelerini ile birebir çalışır. poison_mastery setinin zirvesi.

extends ItemEffect

const GROWTH_PER_SECOND := 0.15
const MAX_MULTIPLIER := 5.0

# instance_id -> {"time": float, "base": float}
var _tracked: Dictionary = {}

func _init():
	item_id = "sabir_tasi"
	item_name = tr("item.sabir_tasi.name")
	description = tr("item.sabir_tasi.description")
	flavor_text = "Sabreden derviş, muradına ermiş"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["poison_growth"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_tracked.clear()
	print("[Sabır Taşı] ✅ Dokunmadığın zehir güçlenir (max 5x)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_tracked.clear()
	print("[Sabır Taşı] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	var tree = player.get_tree()
	if not tree:
		return
	var alive: Dictionary = {}
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		var stacks = node.get("poison_stacks")
		if stacks == null or int(stacks) <= 0:
			continue
		var eid := node.get_instance_id()
		alive[eid] = true
		if not _tracked.has(eid):
			# İlk kez zehirli görüldü: mevcut hasarı taban al
			_tracked[eid] = {"time": 0.0, "base": float(node.get("poison_damage_per_stack"))}
		var entry: Dictionary = _tracked[eid]
		entry["time"] = float(entry["time"]) + delta
		var mult: float = clampf(1.0 + GROWTH_PER_SECOND * float(entry["time"]), 1.0, MAX_MULTIPLIER)
		node.set("poison_damage_per_stack", float(entry["base"]) * mult)
	# Zehri biten / ölen düşmanları takipten çıkar
	for eid in _tracked.keys():
		if not alive.has(eid):
			_tracked.erase(eid)

func _on_player_attack_landed(_attack_type: String, _damage: float, targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	# Dokundun: sabır bozuldu, o düşmanın sayacı sıfırlanır
	for target in targets:
		if not is_instance_valid(target):
			continue
		var node: Node = target
		if node.get("poison_stacks") == null and node.get_parent():
			node = node.get_parent()
		if not is_instance_valid(node) or node.get("poison_stacks") == null:
			continue
		var eid := node.get_instance_id()
		if _tracked.has(eid):
			_tracked[eid] = {"time": 0.0, "base": float(_tracked[eid]["base"])}
			node.set("poison_damage_per_stack", float(_tracked[eid]["base"]))
