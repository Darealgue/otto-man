# ziplatan_yumruk.gd
# RARE - Normal heavy attack (heavy_neutral) da up_heavy'nin fırlatma kuvvetini
# kullanır — Havaya Fırlatma boru hattının ana açıcısı (bkz.
# docs/ITEM_PIPELINE_DESIGN.md §2.4). Davranış components/player_hitbox.gd
# içinde (force_heavy_launch bayrağı) kontrol edilir, bu item pasif bir işarettir.

extends ItemEffect

var _hitbox: Node = null

func _init():
	item_id = "ziplatan_yumruk"
	item_name = tr("item.ziplatan_yumruk.name")
	description = tr("item.ziplatan_yumruk.description")
	flavor_text = "Her yumruk gökyüzüne açılır"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_launch"]

func activate(player: CharacterBody2D):
	super.activate(player)
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox:
		_hitbox = hitbox
		_hitbox.force_heavy_launch = true
		print("[Zıplatan Yumruk] ✅ Normal heavy attack de fırlatıcı oldu")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.force_heavy_launch = false
	_hitbox = null
	print("[Zıplatan Yumruk] ❌ Kaldırıldı")
