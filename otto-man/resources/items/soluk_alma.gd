# soluk_alma.gd
# UNCOMMON - Gölge Dönüşü ile ışınlandığında stamina barının yarım segmenti geri dolar.
# Ön koşul: Gölge Dönüşü. Ayran / Ruh Akışı / Rüzgâr Toplama ile aynı stamina ekonomisi.

extends ItemEffect

const RESTORE_FRACTION := 0.5

func _init():
	item_id = "soluk_alma"
	item_name = tr("item.soluk_alma.name")
	description = tr("item.soluk_alma.description")
	flavor_text = "Gölgeye sığınan nefes alır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["return_stamina"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Soluk Alma] ✅ Gölge dönüşü stamina iade eder")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Soluk Alma] ❌ Kaldırıldı")

# golge_donusu.gd -> ItemManager.notify_item_event
func _on_shadow_return(_from_pos: Vector2, _to_pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var bar = tree.get_first_node_in_group("stamina_bar")
	if bar and bar.has_method("restore_partial_charge"):
		var im := get_node_or_null("/root/ItemManager")
		var mult: float = im.get_specialist_multiplier("kacinma") if im else 1.0
		bar.restore_partial_charge(RESTORE_FRACTION * mult)
