# ikinci_nefes.gd
# RARE - İlk ölümde 1 canla dirilirsin (tek kullanım)

extends ItemEffect

var _used := false

func _init():
	item_id = "ikinci_nefes"
	item_name = "İkinci Nefes"
	description = "İlk ölümde 1 canla dirilirsin (tek kullanım)"
	flavor_text = "İkinci şans"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["revive_once"]

# ItemManager.try_revive_player() bu metodu çağırır; true dönerse oyuncu 1 canla kurtarılır
func try_revive_player() -> bool:
	if _used:
		return false
	_used = true
	print("[İkinci Nefes] 💚 Dirildin! (1 can)")
	return true
