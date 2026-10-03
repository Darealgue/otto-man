# hasar_donusumu.gd
# RARE - Bloklanan hasarın %30'u birikir ve sıradaki HEAVY attack'a düz bonus olarak eklenir.
# (Emici Kalkan'ın heavy'ye özel kuzeni; birikim PlayerHitbox.pending_heavy_damage_bonus'ta.)

extends ItemEffect

const CONVERT_RATIO := 0.3
const MAX_BANK := 80.0

var _hitbox: Node = null

func _init():
	item_id = "hasar_donusumu"
	item_name = tr("item.hasar_donusumu.name")
	description = tr("item.hasar_donusumu.description")
	flavor_text = "Yediğin darbe, vereceğin darbe"
	rarity = ItemRarity.RARE
	category = ItemCategory.BLOCK
	affected_stats = ["heavy_damage_bank"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_hitbox = player.get_node_or_null("Hitbox")
	print("[Hasar Dönüşümü] ✅ Bloklanan hasar heavy attack'a dönüşür")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.pending_heavy_damage_bonus = 0.0
	_hitbox = null
	print("[Hasar Dönüşümü] ❌ Kaldırıldı")

func _on_player_blocked(blocked_damage: float, _attacker: Node2D) -> void:
	if blocked_damage <= 0.0 or not _hitbox or not is_instance_valid(_hitbox):
		return
	_hitbox.pending_heavy_damage_bonus = minf(_hitbox.pending_heavy_damage_bonus + blocked_damage * CONVERT_RATIO, MAX_BANK)
