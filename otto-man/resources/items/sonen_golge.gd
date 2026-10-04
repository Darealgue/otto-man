# sonen_golge.gd
# RARE - Bir gölge süresi dolup kaybolurken (en az 1 sn yaşamışsa) patlar: 110 px içindeki
# düşmanlara senin vuruşunun %80'i kadar hasar verir ve sahip olduğun TÜM elementleri uygular
# (Zehirli Tırnak, Ateşli Yumruk, Buzlu Kılıç, Şimşek Parmak vb.). Gölge Hasadı'nın kısa ömürlü
# gölgeleri ve Gölge Sahnesi/Ortaoyunu gölgeleri en iyi yakıtlardır.

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const RADIUS := 110.0
const DAMAGE_FRACTION := 0.8
const FALLBACK_DAMAGE := 8.0
const ELEMENT_COLORS := {
	"poison": Color(0.4, 0.9, 0.3, 0.8),
	"fire": Color(1.0, 0.5, 0.1, 0.8),
	"ice": Color(0.5, 0.85, 1.0, 0.8),
	"lightning": Color(1.0, 0.95, 0.4, 0.8),
}
const DEFAULT_COLOR := Color(0.55, 0.3, 0.9, 0.8)

var _player: CharacterBody2D = null

func _init():
	item_id = "sonen_golge"
	item_name = tr("item.sonen_golge.name")
	description = tr("item.sonen_golge.description")
	flavor_text = "Işık sönerken en parlak gölge düşer"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["shadow_burst"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Sönen Gölge] ✅ Gölgeler sönerken element taşıyan patlama")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Sönen Gölge] ❌ Kaldırıldı")

# player_decoy.gd -> ItemManager.notify_item_event
func _on_decoy_expired(pos: Vector2, _lifetime: float) -> void:
	var tree := get_tree()
	if not tree or not is_instance_valid(_player):
		return
	var im := get_node_or_null("/root/ItemManager")
	var elements: Array = im.get_active_elements() if im else []
	var dmg: float = FALLBACK_DAMAGE
	var hb = _player.get_node_or_null("Hitbox")
	if hb and hb.get("damage") != null:
		dmg = float(hb.damage)
	dmg *= DAMAGE_FRACTION
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if pos.distance_to(node.global_position) > RADIUS or not node.has_method("take_damage"):
			continue
		node.take_damage(dmg, 120.0, 60.0, true)
		if im and is_instance_valid(node):
			for el in elements:
				im.apply_element_to_enemy(node, el)
	if tree.current_scene:
		var ring := Node2D.new()
		ring.set_script(_AoeBurstRingScript)
		tree.current_scene.add_child(ring)
		var color: Color = ELEMENT_COLORS.get(elements[0], DEFAULT_COLOR) if not elements.is_empty() else DEFAULT_COLOR
		ring.setup(pos, RADIUS, color)
