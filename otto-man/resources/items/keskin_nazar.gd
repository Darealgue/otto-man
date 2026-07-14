# COMMON - %15 kritik vuruş şansı, kritikler %75 fazla hasar verir
extends ItemEffect

const CRIT_CHANCE := 0.15
const CRIT_MULTIPLIER := 1.75

var _player: CharacterBody2D = null

func _init():
	item_id = "keskin_nazar"
	item_name = "Keskin Nazar"
	description = "%15 kritik şansı, kritikler %75 fazla hasar verir"
	flavor_text = "Gözü keskin olanın kılıcı da keskindir"
	rarity = ItemRarity.COMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["crit_chance"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	var am = get_node_or_null("/root/AttackManager")
	if am:
		am.enable_critical_strike(player, CRIT_CHANCE, CRIT_MULTIPLIER)
		print("[Keskin Nazar] ✅ %%%d kritik şansı aktif" % int(CRIT_CHANCE * 100))

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# disable_critical_strike tüm kayıtları siler; başka kritik kaynağı yoksa sorun değil,
	# varsa (gelecekte) kayıt-bazlı silme eklenmeli. Şu an tek kritik-şansı kaynağı bu item.
	var am = get_node_or_null("/root/AttackManager")
	if am and is_instance_valid(player):
		am.disable_critical_strike(player)
	_player = null
	print("[Keskin Nazar] ❌ Kaldırıldı")
