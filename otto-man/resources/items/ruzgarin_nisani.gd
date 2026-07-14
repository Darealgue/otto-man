# UNCOMMON - Menzilli vuruşlar aktif melee elementini mermiye bulaştırır
extends ItemEffect

func _init():
	item_id = "ruzgarin_nisani"
	item_name = "Rüzgârın Nişanı"
	description = "Menzilli vuruşlar aktif elementini (zehir/ateş/buz) mermiye bulaştırır"
	flavor_text = "Rüzgar da bir element taşır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["projectile_element"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Rüzgârın Nişanı] ✅ Mermiler element taşıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Rüzgârın Nişanı] ❌ Kaldırıldı")

## uzun_menzil/ok_yagmuru gibi mermi fırlatan itemler bu fonksiyonu çağırıp
## döneni projectile.element'e atar. Öncelik: zehir > ateş > buz (tek element seçilir).
static func detect_active_element(im: Node) -> String:
	if not im:
		return ""
	if im.has_active_item("zehirli_tirnak") or im.has_active_item("zehirli_dev"):
		return "poison"
	if im.has_active_item("atesli_yumruk"):
		return "fire"
	if im.has_active_item("buzlu_kilic"):
		return "frost"
	return ""
