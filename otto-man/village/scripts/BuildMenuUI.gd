extends Control
const DEBUG_BUILD_MENU := true
const BUILD_MENU_DEBUG_VERSION := "popup-debug-v2"

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
@onready var build_menu_panel: Control = %BuildMenuPanel
@onready var build_list: GridContainer = %BuildList
@onready var title_label: Label = get_node_or_null("BuildMenuPanel/MarginContainer/VBoxContainer/TitleLabel")

# Bina Sahne Yolları (WorkerAssignmentUI ile aynı olmalı)
const WOODCUTTER_SCENE = "res://village/buildings/WoodcutterCamp.tscn"
const STONE_MINE_SCENE = "res://village/buildings/StoneMine.tscn"
const HUNTER_HUT_SCENE = "res://village/buildings/HunterGathererHut.tscn"
const WELL_SCENE = "res://village/buildings/Well.tscn"
const BAKERY_SCENE = "res://village/buildings/Bakery.tscn"
const HOUSE_SCENE = "res://village/buildings/House.tscn"
const SAWMILL_SCENE = "res://village/buildings/Sawmill.tscn"
const BRICKWORKS_SCENE = "res://village/buildings/Brickworks.tscn"
const BLACKSMITH_SCENE = "res://village/buildings/Blacksmith.tscn"
const WEAVER_SCENE = "res://village/buildings/Weaver.tscn"
const TAILOR_SCENE = "res://village/buildings/Tailor.tscn"
const HERBALIST_SCENE = "res://village/buildings/Herbalist.tscn"
const TEAHOUSE_SCENE = "res://village/buildings/TeaHouse.tscn"
const SOAPMAKER_SCENE = "res://village/buildings/SoapMaker.tscn"
const GUNSMITH_SCENE = "res://village/buildings/Gunsmith.tscn"
const ARMORER_SCENE = "res://village/buildings/Armorer.tscn"

const BUILDING_BUTTON_LABELS := {
	WOODCUTTER_SCENE: "Odun Kampı",
	STONE_MINE_SCENE: "Taş Ocağı",
	HUNTER_HUT_SCENE: "Avcı/Toplayıcı",
	WELL_SCENE: "Kuyu",
	BAKERY_SCENE: "Fırın",
	SAWMILL_SCENE: "Kereste Atölyesi",
	BRICKWORKS_SCENE: "Tuğla Atölyesi",
	BLACKSMITH_SCENE: "Demirci",
	WEAVER_SCENE: "Dokumacı",
	TAILOR_SCENE: "Terzi",
	HERBALIST_SCENE: "Şifacı",
	TEAHOUSE_SCENE: "Çay Evi",
	SOAPMAKER_SCENE: "Sabun Atölyesi",
	GUNSMITH_SCENE: "Silahçı",
	ARMORER_SCENE: "Zırhçı",
	HOUSE_SCENE: "Ev"
}

const BUILD_MENU_ORDER := [
	WOODCUTTER_SCENE,
	STONE_MINE_SCENE,
	WELL_SCENE,
	HUNTER_HUT_SCENE,
	BAKERY_SCENE,
	SAWMILL_SCENE,
	BRICKWORKS_SCENE,
	BLACKSMITH_SCENE,
	WEAVER_SCENE,
	TAILOR_SCENE,
	HERBALIST_SCENE,
	TEAHOUSE_SCENE,
	SOAPMAKER_SCENE,
	GUNSMITH_SCENE,
	ARMORER_SCENE,
	HOUSE_SCENE
]

var scene_buttons: Dictionary = {}
var scene_cost_labels: Dictionary = {}
var button_to_scene: Dictionary = {}
var cost_popup: PopupPanel = null
var cost_popup_label: Label = null
var popup_scene_path: String = ""

func _ready() -> void:
	if DEBUG_BUILD_MENU:
		print("[BuildMenuUI] READY version=", BUILD_MENU_DEBUG_VERSION, " path=", get_path())
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
	
	scene_buttons = {
		WOODCUTTER_SCENE: build_woodcutter_button,
		STONE_MINE_SCENE: build_stone_mine_button,
		WELL_SCENE: build_well_button,
		HUNTER_HUT_SCENE: build_hunter_hut_button,
		BAKERY_SCENE: build_bakery_button,
		HOUSE_SCENE: build_house_button
	}
	_ensure_cost_popup()
	_ensure_processing_buttons()
	_refresh_button_texts()
	var viewport := get_viewport()
	if viewport and not viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.connect(_on_gui_focus_changed)
	if is_instance_valid(title_label):
		title_label.text = "İnşaat [%s]" % BUILD_MENU_DEBUG_VERSION
	if DEBUG_BUILD_MENU:
		print("[BuildMenuUI] Buttons initialized: ", scene_buttons.keys())
	
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
	if build_menu_panel:
		var panel_size = build_menu_panel.size
		var centered_pos = (viewport_size - panel_size) / 2
		build_menu_panel.position = centered_pos
	
	# Buton durumlarını da güncelle (gösterilirken en güncel hali görünsün)
	_update_button_states()
	_hide_cost_popup()
	if DEBUG_BUILD_MENU:
		print("[BuildMenuUI] show_centered called. visible=", visible, " panel_pos=", build_menu_panel.position if build_menu_panel else Vector2.ZERO)
	
	# İlk butona odaklan (Klavye/Gamepad navigasyonu için)
	for scene_path in BUILD_MENU_ORDER:
		var button: Button = scene_buttons.get(scene_path, null)
		if button and not button.disabled and button.visible:
			button.grab_focus()
			if DEBUG_BUILD_MENU:
				print("[BuildMenuUI] First focus button=", button.text, " scene=", scene_path)
			break

# Buton durumlarını güncelle (gereksinimlere göre aktif/pasif yap)
func _update_button_states() -> void:
	# Eğer UI görünür değilse güncelleme yapma (Gereksiz güncelleme sorununu çözebilir)
	if not visible: 
		return
	
	# Her bina türü için kontrol et
	for scene_path in BUILD_MENU_ORDER:
		_update_single_button_state(scene_buttons.get(scene_path, null), scene_path)

func _refresh_button_texts() -> void:
	for scene_path in BUILD_MENU_ORDER:
		var button: Button = scene_buttons.get(scene_path, null)
		if not button:
			continue
		var reqs = VillageManager.get_building_requirements(scene_path)
		button.text = String(BUILDING_BUTTON_LABELS.get(scene_path, scene_path.get_file().trim_suffix(".tscn")))
		var cost_label: Label = scene_cost_labels.get(scene_path, null)
		if cost_label:
			cost_label.text = ""

func _ensure_processing_buttons() -> void:
	if not build_list:
		return
	for child in build_list.get_children():
		child.queue_free()
	scene_buttons.clear()
	scene_cost_labels.clear()
	button_to_scene.clear()
	for scene_path in BUILD_MENU_ORDER:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 2)

		var button := Button.new()
		button.text = String(BUILDING_BUTTON_LABELS.get(scene_path, scene_path.get_file().trim_suffix(".tscn")))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 32.0
		button.pressed.connect(_on_build_button_pressed.bind(scene_path))
		button.mouse_entered.connect(_on_build_button_hovered.bind(scene_path, button))
		button.focus_entered.connect(_on_build_button_hovered.bind(scene_path, button))
		button.mouse_exited.connect(_on_build_button_unhovered.bind(scene_path))
		button.focus_exited.connect(_on_build_button_unhovered.bind(scene_path))
		card.add_child(button)

		var cost_label := Label.new()
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_label.text = ""
		cost_label.visible = false
		card.add_child(cost_label)

		build_list.add_child(card)
		scene_buttons[scene_path] = button
		scene_cost_labels[scene_path] = cost_label
		button_to_scene[button] = scene_path

# Tek bir butonun durumunu güncelleyen yardımcı fonksiyon
func _update_single_button_state(button: Button, scene_path: String):
	# --- YENİ: Buton null ise hiçbir şey yapma ---
	if not button:
		# printerr("DEBUG BuildMenuUI: _update_single_button_state called with null button for scene: %s" % scene_path) # Opsiyonel debug
		return
	# -----------------------------------------
	
	# 1. Bu türden bina zaten var mı?
	# House artık kat ekleme ile tekrar tekrar inşa edilebiliyor.
	var already_exists = false if scene_path == HOUSE_SCENE else VillageManager.does_building_exist(scene_path)
	# 2. Gereksinimler karşılanıyor mu?
	var can_afford = VillageManager.can_meet_requirements(scene_path)
	var reqs = VillageManager.get_building_requirements(scene_path)
	var cost_label: Label = scene_cost_labels.get(scene_path, null)
	if cost_label:
		cost_label.text = ""
	
	# Butonu sadece gereksinimler karşılanıyorsa VE bu türden bina yoksa aktif et
	button.disabled = already_exists or not can_afford
	# <<< YORUMA AL >>>
	# print("DEBUG BuildMenuUI: %s butonu durumu (disabled): %s" % [button.name, button.disabled])
	
	# Tooltip ekle (opsiyonel ama faydalı)
	if already_exists:
		button.tooltip_text = "Bu binadan zaten var."
	elif not can_afford:
		button.tooltip_text = _format_cannot_build_reason(reqs)
	else:
		button.tooltip_text = "İnşa Et (%s)" % _format_requirements_tooltip(reqs) # Maliyeti göster
	if popup_scene_path == scene_path:
		_show_cost_popup(scene_path, button)

# İnşa butonuna basıldığında
func _on_build_button_pressed(building_scene_path: String) -> void:
	print("[BuildMenuUI] 🏗️ İnşa butonu basıldı: %s" % building_scene_path.get_file())
	emit_signal("build_requested", building_scene_path)

# Kapat butonuna basıldığında
func _on_close_button_pressed() -> void:
	visible = false
	_hide_cost_popup()
	emit_signal("close_requested")

func _ensure_cost_popup() -> void:
	if is_instance_valid(cost_popup):
		return
	cost_popup = PopupPanel.new()
	cost_popup.name = "BuildCostPopup"
	cost_popup.visible = false
	add_child(cost_popup)
	cost_popup_label = Label.new()
	cost_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost_popup_label.custom_minimum_size = Vector2(220, 0)
	cost_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cost_popup.add_child(cost_popup_label)

func _on_build_button_hovered(scene_path: String, button: Button) -> void:
	if DEBUG_BUILD_MENU:
		print("[BuildMenuUI] hover scene=", scene_path, " button=", button.text, " rect=", button.get_global_rect())
	_show_cost_popup(scene_path, button)

func _on_build_button_unhovered(scene_path: String) -> void:
	if DEBUG_BUILD_MENU:
		print("[BuildMenuUI] unhover scene=", scene_path)
	if popup_scene_path == scene_path:
		_hide_cost_popup()

func _show_cost_popup(scene_path: String, button: Button) -> void:
	if not is_instance_valid(cost_popup) or not is_instance_valid(cost_popup_label):
		return
	var reqs = VillageManager.get_building_requirements(scene_path)
	var building_name := String(BUILDING_BUTTON_LABELS.get(scene_path, scene_path.get_file().trim_suffix(".tscn")))
	var can_afford := VillageManager.can_meet_requirements(scene_path)
	var info_lines := []
	info_lines.append(building_name)
	info_lines.append("Maliyet: %s" % _format_cost_line_long(reqs.get("cost", {})))
	if not can_afford:
		info_lines.append(_format_cannot_build_reason(reqs))
	cost_popup_label.text = "\n".join(info_lines)
	cost_popup.reset_size()
	var rect := button.get_global_rect()
	var popup_size := cost_popup.size
	var viewport_rect := get_viewport().get_visible_rect()
	var pos := Vector2(rect.end.x + 10.0, rect.position.y)
	if pos.x + popup_size.x > viewport_rect.end.x:
		pos.x = rect.position.x - popup_size.x - 10.0
	if pos.y + popup_size.y > viewport_rect.end.y:
		pos.y = max(0.0, viewport_rect.end.y - popup_size.y - 8.0)
	pos.x = max(0.0, pos.x)
	pos.y = max(0.0, pos.y)
	cost_popup.position = pos
	cost_popup.popup()
	popup_scene_path = scene_path
	if DEBUG_BUILD_MENU:
		print("[BuildMenuUI] popup shown scene=", scene_path, " pos=", pos, " size=", popup_size, " text=", cost_popup_label.text)

func _hide_cost_popup() -> void:
	popup_scene_path = ""
	if is_instance_valid(cost_popup):
		cost_popup.hide()
	if DEBUG_BUILD_MENU:
		print("[BuildMenuUI] popup hidden")

func _on_gui_focus_changed(focused: Control) -> void:
	if not visible:
		return
	if focused and button_to_scene.has(focused):
		var scene_path: String = String(button_to_scene[focused])
		if DEBUG_BUILD_MENU:
			print("[BuildMenuUI] focus_changed scene=", scene_path, " button=", focused.name)
		_show_cost_popup(scene_path, focused as Button)
	else:
		_hide_cost_popup()

# Gereksinimleri tooltip için formatlayan yardımcı fonksiyon
func _format_requirements_tooltip(requirements: Dictionary) -> String:
	var parts = []
	var cost = requirements.get("cost", {})
	var levels = requirements.get("requires_level", {})
	
	for resource_type in cost:
		var amount := int(cost[resource_type])
		if amount <= 0:
			continue
		var resource_key: String = String(resource_type)
		var display_name: String = "Altın" if resource_key == "gold" else resource_key.capitalize()
		parts.append("%s: %d" % [display_name, amount])
		
	for resource_type in levels:
		parts.append("%s Sv: %d" % [resource_type.capitalize(), levels[resource_type]])
		
	if parts.is_empty():
		return "Maliyet Yok"
	else:
		return ", ".join(parts)

func _format_button_text(scene_path: String, requirements: Dictionary) -> String:
	var title := String(BUILDING_BUTTON_LABELS.get(scene_path, scene_path.get_file().trim_suffix(".tscn")))
	var cost_text := _format_cost_line(requirements.get("cost", {}))
	if cost_text == "":
		return title
	return "%s\n%s" % [cost_text, title]

func _format_cost_line(cost: Dictionary) -> String:
	var ordered_keys := []
	if cost.has("gold"):
		ordered_keys.append("gold")
	for key in cost.keys():
		if key == "gold":
			continue
		ordered_keys.append(key)
	var parts := []
	for key in ordered_keys:
		var amount := int(cost.get(key, 0))
		if amount <= 0:
			continue
		var key_str: String = String(key)
		var short_name: String = _cost_short_key(key_str)
		parts.append("%d%s" % [amount, short_name])
	return " | ".join(parts)

func _format_cost_line_long(cost: Dictionary) -> String:
	var ordered_keys := []
	if cost.has("gold"):
		ordered_keys.append("gold")
	for key in cost.keys():
		if key == "gold":
			continue
		ordered_keys.append(key)
	var parts := []
	for key in ordered_keys:
		var amount := int(cost.get(key, 0))
		if amount <= 0:
			continue
		var key_str: String = String(key)
		var display_name := _resource_display_name(key_str)
		parts.append("%s: %d" % [display_name, amount])
	if parts.is_empty():
		return "Maliyet yok"
	return ", ".join(parts)

func _cost_short_key(resource_key: String) -> String:
	match resource_key:
		"gold": return "G"
		"wood": return "O"
		"stone": return "T"
		"food": return "Y"
		"water": return "S"
		"lumber": return "K"
		"brick": return "Tu"
		"metal": return "M"
		"cloth": return "Ku"
		"garment": return "Gi"
		"bread": return "E"
		"tea": return "C"
		"soap": return "Sa"
		"medicine": return "I"
		"weapon": return "Si"
		"armor": return "Zi"
		_: return resource_key.left(2).capitalize()

func _resource_display_name(resource_key: String) -> String:
	match resource_key:
		"gold": return "Altın"
		"wood": return "Odun"
		"stone": return "Taş"
		"food": return "Yiyecek"
		"water": return "Su"
		"lumber": return "Kereste"
		"brick": return "Tuğla"
		"metal": return "Metal"
		"cloth": return "Kumaş"
		"garment": return "Giysi"
		"bread": return "Ekmek"
		"tea": return "Çay"
		"soap": return "Sabun"
		"medicine": return "İlaç"
		"weapon": return "Silah"
		"armor": return "Zırh"
		_: return resource_key.capitalize()

func _format_cannot_build_reason(requirements: Dictionary) -> String:
	var reasons := []
	var cost: Dictionary = requirements.get("cost", {})
	var missing_costs := []
	for key in cost.keys():
		var key_str: String = String(key)
		var required := int(cost.get(key, 0))
		if required <= 0:
			continue
		var current := 0
		if key_str == "gold":
			current = int(GlobalPlayerData.gold)
		else:
			current = int(VillageManager.get_resource_level(key_str))
		if current < required:
			var display_name: String = "Altın" if key_str == "gold" else key_str.capitalize()
			missing_costs.append("%s %d/%d" % [display_name, current, required])
	if not missing_costs.is_empty():
		reasons.append("Eksik maliyet: %s" % ", ".join(missing_costs))

	var levels: Dictionary = requirements.get("requires_level", {})
	var missing_levels := []
	for key in levels.keys():
		var key_str: String = String(key)
		var required_level := int(levels.get(key, 0))
		var current_level := int(VillageManager.get_available_resource_level(key_str))
		if current_level < required_level:
			missing_levels.append("%s %d/%d" % [key_str.capitalize(), current_level, required_level])
	if not missing_levels.is_empty():
		reasons.append("Eksik seviye: %s" % ", ".join(missing_levels))

	if reasons.is_empty():
		return "Gereksinimler: %s" % _format_requirements_tooltip(requirements)
	return "\n".join(reasons)
