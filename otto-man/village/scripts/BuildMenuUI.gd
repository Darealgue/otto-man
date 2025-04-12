extends Control

# Sinyaller
signal build_requested(building_scene_path)
signal close_requested

# UI Elemanları
@onready var build_woodcutter_button: Button = %BuildWoodcutterButton
@onready var build_stone_mine_button: Button = %BuildStoneMineButton
@onready var build_hunter_hut_button: Button = %BuildHunterHutButton
@onready var build_well_button: Button = %BuildWellButton
@onready var build_bakery_button: Button = %BuildBakeryButton
@onready var build_house_button: Button = %BuildHouseButton
@onready var close_button: Button = %CloseButton

# Bina Sahne Yolları (WorkerAssignmentUI ile aynı olmalı)
const WOODCUTTER_SCENE = "res://village/buildings/WoodcutterCamp.tscn"
const STONE_MINE_SCENE = "res://village/buildings/StoneMine.tscn"
const HUNTER_HUT_SCENE = "res://village/buildings/HunterGathererHut.tscn"
const WELL_SCENE = "res://village/buildings/Well.tscn"
const BAKERY_SCENE = "res://village/buildings/Bakery.tscn"
const HOUSE_SCENE = "res://village/buildings/House.tscn"

func _ready() -> void:
	# Başlangıçta gizle
	visible = false
	
	# Buton sinyallerini bağla (Null Kontrolleri ile)
	if build_woodcutter_button:
		build_woodcutter_button.pressed.connect(_on_build_button_pressed.bind(WOODCUTTER_SCENE))
	else:
		printerr("BuildMenuUI Error: Node not found - BuildWoodButton")
	
	if build_stone_mine_button:
		build_stone_mine_button.pressed.connect(_on_build_button_pressed.bind(STONE_MINE_SCENE))
	else:
		printerr("BuildMenuUI Error: Node not found - BuildStoneButton")
	
	if build_hunter_hut_button:
		build_hunter_hut_button.pressed.connect(_on_build_button_pressed.bind(HUNTER_HUT_SCENE))
	else:
		printerr("BuildMenuUI Error: Node not found - BuildFoodButton")
		
	if build_well_button:
		build_well_button.pressed.connect(_on_build_button_pressed.bind(WELL_SCENE))
	else:
		printerr("BuildMenuUI Error: Node not found - BuildWaterButton")
	
	if build_bakery_button:
		build_bakery_button.pressed.connect(_on_build_button_pressed.bind(BAKERY_SCENE))
	else:
		printerr("BuildMenuUI Error: Node not found - BuildBakeryButton")
	
	if build_house_button:
		build_house_button.pressed.connect(_on_build_button_pressed.bind(HOUSE_SCENE))
	else:
		printerr("BuildMenuUI Error: Node not found - BuildHouseButton")
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	else:
		printerr("BuildMenuUI Error: Node not found - CloseButton")

	# VillageManager değişikliklerini dinle (opsiyonel, buton durumlarını güncellemek için)
	# VillageManager.village_data_changed.connect(_update_button_states)

# --- YENİ: Ortalanmış Gösterme Fonksiyonu ---
func show_centered() -> void:
	# Önce görünür yap ki boyutu hesaplanabilsin
	visible = true 
	# Viewport ve panel boyutlarını al
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = size
	# Ortalanmış pozisyonu hesapla
	var centered_pos = (viewport_size - panel_size) / 2
	# Pozisyonu ayarla
	position = centered_pos
	# Buton durumlarını da güncelle (gösterilirken en güncel hali görünsün)
	_update_button_states()

# Buton durumlarını güncelle (gereksinimlere göre aktif/pasif yap)
func _update_button_states() -> void:
	# Eğer UI görünür değilse güncelleme yapma (Gereksiz güncelleme sorununu çözebilir)
	if not visible: 
		return
	
	print("DEBUG BuildMenuUI: _update_button_states çağrıldı.")
	# Her bina türü için kontrol et
	_update_single_button_state(build_woodcutter_button, WOODCUTTER_SCENE)
	_update_single_button_state(build_stone_mine_button, STONE_MINE_SCENE)
	_update_single_button_state(build_hunter_hut_button, HUNTER_HUT_SCENE)
	_update_single_button_state(build_well_button, WELL_SCENE)
	_update_single_button_state(build_bakery_button, BAKERY_SCENE)
	_update_single_button_state(build_house_button, HOUSE_SCENE)

# Tek bir butonun durumunu güncelleyen yardımcı fonksiyon
func _update_single_button_state(button: Button, scene_path: String):
	# --- YENİ: Buton null ise hiçbir şey yapma ---
	if not button:
		# printerr("DEBUG BuildMenuUI: _update_single_button_state called with null button for scene: %s" % scene_path) # Opsiyonel debug
		return
	# -----------------------------------------
	
	# 1. Bu türden bina zaten var mı?
	var already_exists = VillageManager.does_building_exist(scene_path)
	# 2. Gereksinimler karşılanıyor mu?
	var can_afford = VillageManager.can_meet_requirements(scene_path)
	
	# Butonu sadece gereksinimler karşılanıyorsa VE bu türden bina yoksa aktif et
	button.disabled = already_exists or not can_afford
	print("DEBUG BuildMenuUI: %s butonu durumu (disabled): %s" % [button.name, button.disabled])
	
	# Tooltip ekle (opsiyonel ama faydalı)
	if already_exists:
		button.tooltip_text = "Bu binadan zaten var."
	elif not can_afford:
		var reqs = VillageManager.get_building_requirements(scene_path)
		button.tooltip_text = "Gereksinimler: %s" % _format_requirements_tooltip(reqs)
	else:
		var reqs = VillageManager.get_building_requirements(scene_path)
		button.tooltip_text = "İnşa Et (%s)" % _format_requirements_tooltip(reqs) # Maliyeti göster

# İnşa butonuna basıldığında
func _on_build_button_pressed(building_scene_path: String) -> void:
	print("DEBUG BuildMenuUI: _on_build_button_pressed tetiklendi. Sahne: ", building_scene_path)
	# VillageManager'a inşa isteği gönder
	emit_signal("build_requested", building_scene_path)
	# İnşa isteği sonrası menüyü kapatabiliriz veya açık bırakabiliriz
	# visible = false 
	# emit_signal("close_requested") 

# Kapat butonuna basıldığında
func _on_close_button_pressed() -> void:
	visible = false
	emit_signal("close_requested")

# Gereksinimleri tooltip için formatlayan yardımcı fonksiyon
func _format_requirements_tooltip(requirements: Dictionary) -> String:
	var parts = []
	var cost = requirements.get("cost", {})
	var levels = requirements.get("requires_level", {})
	
	if cost.has("gold") and cost["gold"] > 0:
		parts.append("Altın: %d" % cost["gold"])
		
	for resource_type in levels:
		parts.append("%s Sv: %d" % [resource_type.capitalize(), levels[resource_type]])
		
	if parts.is_empty():
		return "Maliyet Yok"
	else:
		return ", ".join(parts)
