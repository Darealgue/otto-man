# RARE - Element vuruşları geçici bir hasar-emme kalkanı biriktirir (vuruş başına %2 max can, max %30);
# 3sn hasarsız kalırsan kalkan sıfırlanır. Elemental Odak'ın fizik zayıflığını telafi eder.
extends ItemEffect

const SHIELD_PER_HIT_RATIO := 0.02
const SHIELD_CAP_RATIO := 0.30
const DECAY_GRACE := 3.0
const ELEMENT_ITEM_IDS := [
	"zehirli_tirnak", "atesli_yumruk", "buzlu_kilic", "simsek_parmagi",
	"zehirli_dev", "gok_gurultusu", "lav_cekici", "donma_cekici",
]

var _player: CharacterBody2D = null
var _no_hit_timer := 0.0

func _init():
	item_id = "cuppe_degil_zirh"
	item_name = "Cüppe Değil Zırh"
	description = "Element hasarı verdikçe kalkan biriktirirsin (max %30 max can, 3sn hasarsızlıkta sıfırlanır)"
	flavor_text = "Büyücü de zırh giyer"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["element_shield"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_no_hit_timer = 0.0
	print("[Cüppe Değil Zırh] ✅ Element vuruşları kalkan biriktiriyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if is_instance_valid(_player):
		_player.element_shield = 0.0
	_player = null
	print("[Cüppe Değil Zırh] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	_no_hit_timer += delta
	if _no_hit_timer >= DECAY_GRACE and player.element_shield > 0.0:
		player.element_shield = 0.0

func _on_player_attack_landed(_attack_type: String, _damage: float, _targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only" or not is_instance_valid(_player):
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	var has_element := false
	for eid in ELEMENT_ITEM_IDS:
		if im.has_active_item(eid):
			has_element = true
			break
	if not has_element:
		return
	var stats = get_node_or_null("/root/PlayerStats")
	if not stats:
		return
	var max_hp: float = stats.get_max_health()
	_player.element_shield = min(_player.element_shield + max_hp * SHIELD_PER_HIT_RATIO, max_hp * SHIELD_CAP_RATIO)
	_no_hit_timer = 0.0
