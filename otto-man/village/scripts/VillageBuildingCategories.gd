class_name VillageBuildingCategories
extends RefCounted
## Köy inşa menüsü kategorileri (parsel popup SSOT).

enum Category {
	RESOURCE,
	UTILITY,
	MILITARY,
	DECORATION,
}

const CATEGORY_ORDER: Array[Category] = [
	Category.RESOURCE,
	Category.UTILITY,
	Category.MILITARY,
	Category.DECORATION,
]

const CATEGORY_LABELS: Dictionary = {
	Category.RESOURCE: "Kaynak & Üretim",
	Category.UTILITY: "Yardımcı",
	Category.MILITARY: "Askeri",
	Category.DECORATION: "Dekorasyon",
}

const SCENE_PATHS: Dictionary = {
	Category.RESOURCE: [
		"res://village/buildings/WoodcutterCamp.tscn",
		"res://village/buildings/StoneMine.tscn",
		"res://village/buildings/HunterGathererHut.tscn",
		"res://village/buildings/Sawmill.tscn",
		"res://village/buildings/Brickworks.tscn",
		"res://village/buildings/Bakery.tscn",
		"res://village/buildings/Weaver.tscn",
		"res://village/buildings/Tailor.tscn",
		"res://village/buildings/Blacksmith.tscn",
		"res://village/buildings/Gunsmith.tscn",
		"res://village/buildings/Herbalist.tscn",
		"res://village/buildings/TeaHouse.tscn",
		"res://village/buildings/SoapMaker.tscn",
	],
	Category.UTILITY: [
		"res://village/buildings/House.tscn",
		"res://village/buildings/StorageBuilding.tscn",
		"res://village/buildings/InventorWorkshop.tscn",
	],
	Category.MILITARY: [
		"res://village/buildings/Barracks.tscn",
	],
	Category.DECORATION: [],
}


static func get_category_label(cat: Category) -> String:
	return String(CATEGORY_LABELS.get(cat, "Bina"))


static func get_scenes_for_category(cat: Category) -> Array[String]:
	var raw: Variant = SCENE_PATHS.get(cat, [])
	var out: Array[String] = []
	if raw is Array:
		for item in raw:
			out.append(String(item))
	return out
