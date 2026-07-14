# UNCOMMON - Menzilli vuruşların menzil sınırı kalkar; 300px+ mesafeden çarpan mermiler kritik sayılır
extends ItemEffect

const CRIT_RANGE := 300.0
const CRIT_MULT := 1.75

func _init():
	item_id = "kartal_bakisi"
	item_name = "Kartal Bakışı"
	description = "Mermilerin menzili sınırsızdır; 300px+ mesafeden isabet kritik sayılır"
	flavor_text = "Uzağı gören, doğru vurur"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["projectile_range"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Kartal Bakışı] ✅ Menzil sınırsız, uzak vuruş kritik")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Kartal Bakışı] ❌ Kaldırıldı")
