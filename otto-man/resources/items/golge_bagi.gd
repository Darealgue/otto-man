# golge_bagi.gd
# RARE - Bir gölgenin vurduğu düşman 4 sn işaretlenir; ona yaptığın sonraki vuruş %60 fazla hasar
# verir (işaret tüketilir). Gölge üreten her item (Ortaoyunu, Gölge Hasadı, Kukla Oyunu, Gölge
# Dönüşü, Gölge Sahnesi) bu işareti besler. Gölge vuruşları player_attack_landed'ı "physical_only"
# / "elemental_only" filtresiyle yayınladığı için yalnızca GERÇEK vuruşlar ("all") bonusu tüketir.

extends ItemEffect

const _AoeBurstRingScript = preload("res://effects/aoe_burst_ring.gd")
const MARK_DURATION_MSEC := 4000
const BONUS_FRACTION := 0.6
const MARK_META := "golge_bagi_until"
const RING_COLOR := Color(0.55, 0.3, 0.9, 0.8)

var _player: CharacterBody2D = null

func _init():
	item_id = "golge_bagi"
	item_name = tr("item.golge_bagi.name")
	description = tr("item.golge_bagi.description")
	flavor_text = "Gölge tutar, sen vurursun"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["shadow_mark"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Gölge Bağı] ✅ Gölgenin vurduğu düşman işaretlenir")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Gölge Bağı] ❌ Kaldırıldı")

# player_decoy.gd -> ItemManager.notify_item_event
func _on_decoy_hit_enemy(enemy: Node, _decoy_pos: Vector2) -> void:
	if is_instance_valid(enemy):
		enemy.set_meta(MARK_META, Time.get_ticks_msec() + MARK_DURATION_MSEC)

# ItemManager player_attack_landed'a otomatik bağlar
func _on_player_attack_landed(_attack_type: String, damage: float, targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter != "all":
		return
	var now := Time.get_ticks_msec()
	for t in targets:
		if not is_instance_valid(t) or not t.has_meta(MARK_META):
			continue
		var until: int = int(t.get_meta(MARK_META))
		t.remove_meta(MARK_META)
		if until < now or not t.has_method("take_damage"):
			continue
		t.take_damage(damage * BONUS_FRACTION, 0.0, 0.0, true)
		_spawn_ring(t.global_position)

func _spawn_ring(pos: Vector2) -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var ring := Node2D.new()
	ring.set_script(_AoeBurstRingScript)
	tree.current_scene.add_child(ring)
	ring.setup(pos, 40.0, RING_COLOR)
