class_name BuildingInfo
extends RefCounted
## İnşa ekranında binaların ne işe yaradığını anlatan bilgi tablosu (tek kaynak).
## Tarifler binaların betiğindeki `required_resources` ile aynıdır; açıklamalar strings.csv `build.info.<id>`.

const INFO: Dictionary = {
	"res://village/buildings/WoodcutterCamp.tscn": {"id": "woodcutter", "out": "wood", "in": {}},
	"res://village/buildings/StoneMine.tscn": {"id": "stone_mine", "out": "stone", "in": {}},
	"res://village/buildings/HunterGathererHut.tscn": {"id": "hunter_hut", "out": "food", "in": {}},
	"res://village/buildings/House.tscn": {"id": "house", "out": "", "in": {}},
	"res://village/buildings/Sawmill.tscn": {"id": "sawmill", "out": "lumber", "in": {"wood": 1}},
	"res://village/buildings/Brickworks.tscn": {"id": "brickworks", "out": "brick", "in": {"stone": 1}},
	"res://village/buildings/Bakery.tscn": {"id": "bakery", "out": "bread", "in": {"food": 1}},
	"res://village/buildings/Blacksmith.tscn": {"id": "blacksmith", "out": "metal", "in": {"stone": 1, "wood": 1}},
	"res://village/buildings/Weaver.tscn": {"id": "weaver", "out": "cloth", "in": {"wood": 1, "food": 1}},
	"res://village/buildings/Herbalist.tscn": {"id": "herbalist", "out": "medicine", "in": {"stone": 1, "food": 1}},
	"res://village/buildings/Gunsmith.tscn": {"id": "gunsmith", "out": "weapon_t1", "in": {"wood": 1, "stone": 1}},
	"res://village/buildings/Tailor.tscn": {"id": "tailor", "out": "garment", "in": {"bread": 1, "cloth": 1}},
	"res://village/buildings/TeaHouse.tscn": {"id": "teahouse", "out": "tea", "in": {"brick": 1, "medicine": 1}},
	"res://village/buildings/SoapMaker.tscn": {"id": "soapmaker", "out": "soap", "in": {"lumber": 1, "metal": 1}},
	"res://village/buildings/InventorWorkshop.tscn": {"id": "inventor", "out": "", "in": {}},
	"res://village/buildings/StorageBuilding.tscn": {"id": "storage", "out": "", "in": {}},
	"res://village/buildings/Barracks.tscn": {"id": "barracks", "out": "", "in": {}},
}

## Kaynak -> onu üreten bina (zincir satırı için)
const RESOURCE_PRODUCER: Dictionary = {
	"wood": "res://village/buildings/WoodcutterCamp.tscn",
	"stone": "res://village/buildings/StoneMine.tscn",
	"food": "res://village/buildings/HunterGathererHut.tscn",
	"lumber": "res://village/buildings/Sawmill.tscn",
	"brick": "res://village/buildings/Brickworks.tscn",
	"bread": "res://village/buildings/Bakery.tscn",
	"metal": "res://village/buildings/Blacksmith.tscn",
	"cloth": "res://village/buildings/Weaver.tscn",
	"medicine": "res://village/buildings/Herbalist.tscn",
	"garment": "res://village/buildings/Tailor.tscn",
	"tea": "res://village/buildings/TeaHouse.tscn",
	"soap": "res://village/buildings/SoapMaker.tscn",
}

## Önerilen kurulum sırası: ilk kurulmamış bina "sıradaki öneri" olarak işaretlenir.
const RECOMMENDED_ORDER: Array[String] = [
	"res://village/buildings/WoodcutterCamp.tscn",
	"res://village/buildings/StoneMine.tscn",
	"res://village/buildings/HunterGathererHut.tscn",
	"res://village/buildings/Sawmill.tscn",
	"res://village/buildings/Brickworks.tscn",
	"res://village/buildings/Bakery.tscn",
	"res://village/buildings/Barracks.tscn",
	"res://village/buildings/Gunsmith.tscn",
	"res://village/buildings/Herbalist.tscn",
	"res://village/buildings/Blacksmith.tscn",
	"res://village/buildings/Weaver.tscn",
	"res://village/buildings/TeaHouse.tscn",
	"res://village/buildings/Tailor.tscn",
	"res://village/buildings/SoapMaker.tscn",
	"res://village/buildings/InventorWorkshop.tscn",
]
