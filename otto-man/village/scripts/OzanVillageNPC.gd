# OzanVillageNPC.gd
# Gezgin ozan. Yürüme/oturma/uyuma ve etkileşim iskeleti falcıyla aynı (FalciVillageNPC).
# Farklı olan: menü YOK. Etkileşim okunun üstünde "3 yiyecek ver" yazar; etkileşime basınca
# yemek köy deposundan düşer ve türkü ozanın konuşma balonunda çıkar. Ziyaret başına tek türkü.
#
# GEÇİCİ SANAT: sprite'lar şimdilik tüccarınkiler, sıcak turuncu tonla ayrışıyor. Ozanın kendi
# sheet'leri gelince OzanVillageNPC.tscn içindeki dört texture yolunu değiştirip
# _apply_placeholder_tint() çağrısını silmek yeterli.
extends "res://village/scripts/FalciVillageNPC.gd"

const OZAN_TINT := Color(1.0, 0.78, 0.5)
const PRICE_TAG_SIZE := Vector2(170.0, 30.0)
## Etkileşim okunun (-112.5) hemen üstü
const PRICE_TAG_CENTER_Y := -142.0
const SONG_BUBBLE_WIDTH := 280.0
const SONG_BUBBLE_FONT := 15
const SONG_BUBBLE_SECONDS := 14.0
const PRICE_COLOR_OK := Color(1.0, 0.9, 0.55)
const PRICE_COLOR_LACKING := Color(1.0, 0.55, 0.5)

var _price_tag: PanelContainer = null
var _price_label: Label = null


func _ready() -> void:
	super._ready()
	_build_price_tag()


func _apply_placeholder_tint() -> void:
	for spr in [idle_sprite, walk_sprite, sit_sprite, sleep_sprite]:
		if is_instance_valid(spr):
			spr.modulate = OZAN_TINT


func _title_key() -> String:
	return "ozan.title"


func _build_price_tag() -> void:
	_price_tag = PanelContainer.new()
	_price_tag.name = "OzanPriceTag"
	_price_tag.custom_minimum_size = PRICE_TAG_SIZE
	_price_tag.size = PRICE_TAG_SIZE
	_price_label = Label.new()
	_price_label.text = tr("ozan.price") % OzanSongs.FOOD_COST
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price_tag.add_child(_price_label)
	add_child(_price_tag)
	NpcOverheadUi.apply_frameless_nameplate(_price_tag)
	NpcOverheadUi.apply_nameplate_text_style(_price_label)
	_price_tag.visible = false
	OverheadUiTracker.attach(_price_tag, self, Vector2(INTERACT_HINT_X_SHIFT, PRICE_TAG_CENTER_Y))


## Ziyaret başına bir türkü: söylendiyse ok, isim ve fiyat etiketi kalkar.
func can_interact() -> bool:
	if not super.can_interact():
		return false
	return not _already_sung_this_visit()


func _already_sung_this_visit() -> bool:
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return false
	return int(im.get("ozan_sung_visit_day")) == int(im.get("ozan_arrives_day"))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(_price_tag):
		return
	_price_tag.visible = _hint_shown
	if _hint_shown and is_instance_valid(_price_label):
		_price_label.modulate = PRICE_COLOR_OK if _food_stock() >= OzanSongs.FOOD_COST else PRICE_COLOR_LACKING


func _village_manager() -> Node:
	return get_node_or_null("/root/VillageManager")


func _food_stock() -> int:
	var vm := _village_manager()
	return int(vm.call("get_resource_level", "food")) if vm and vm.has_method("get_resource_level") else 0


## Menü açmak yerine yemek verir ve türküyü konuşma balonunda söyler.
func interact() -> void:
	if not can_interact():
		return
	var vm := _village_manager()
	if vm == null or not vm.has_method("spend_resources"):
		return
	if _food_stock() < OzanSongs.FOOD_COST:
		_say(tr("ozan.info.no_food"), 5.0)
		return
	var clue: Dictionary = OzanSongs.pick_clue()
	if clue.is_empty():
		# Anlatılacak zindan kalmadı: yemek harcanmaz
		_say(tr("ozan.none"), 6.0)
		return
	if not bool(vm.call("spend_resources", {"food": OzanSongs.FOOD_COST})):
		_say(tr("ozan.info.no_food"), 5.0)
		return
	OzanSongs.mark_sung(clue)
	var im := get_node_or_null("/root/ItemManager")
	if im:
		im.set("ozan_sung_visit_day", int(im.get("ozan_arrives_day")))
	_say(OzanSongs.song_text(clue), SONG_BUBBLE_SECONDS)


func _say(text: String, seconds: float) -> void:
	NpcAmbientBubble.show_on_npc(self, text, seconds, SONG_BUBBLE_WIDTH, SONG_BUBBLE_FONT)
