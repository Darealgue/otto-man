# tasan_kaynak.gd
# RARE - Kamp çeşmesinin doldurduğu can miktarını %50 artırır. Max_health'i
# aşan fazlalık boşa gitmez: geçici bir "taşan can" tamponu olarak üste
# eklenir (player.overheal, take_damage()'ta gerçek candan önce tüketilir).
# Zaten tam canlıyken çeşmeye dokunmak normalde hiçbir şey yapmaz — bu item
# aktifken o durumda bile tam bonus miktarı taşan can olarak kazanılır.
# Gerçek mantık scenes/CampFountain.gd:_try_heal()'da — bu item pasif bir
# işarettir.

extends ItemEffect

func _init():
	item_id = "tasan_kaynak"
	item_name = tr("item.tasan_kaynak.name")
	description = tr("item.tasan_kaynak.description")
	flavor_text = "Kaynak taştığında da boşa akmaz"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["fountain_overheal"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Taşan Kaynak] ✅ Çeşme fazla can iyileştiriyor, fazlası taşan can olarak kalıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Taşan Kaynak] ❌ Kaldırıldı")
