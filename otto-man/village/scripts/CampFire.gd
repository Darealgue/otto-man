extends Node2D # veya StaticBody2D, ne tür bir node ise

# Eklediğimiz PopupMenu node'una referans
@onready var interaction_menu: PopupMenu = $InteractionMenu

# Açılacak UI panellerinin sahne yolları (GEREKİRSE GÜNCELLE)
const BUILD_MENU_SCENE = "res://village/scenes/BuildMenuUI.tscn" # Yorumu kaldır ve yolu kontrol et
const WORKER_ASSIGN_SCENE = "res://village/scenes/WorkerAssignmentUI.tscn" # Bu yol doğru olmalı
const CARIYE_MENU_SCENE = "res://village/scenes/CariyeManagementUI.tscn" # Bu yol doğru olmalı

# Menü öğeleri için ID'ler
enum MenuOption {
	BUILD,
	ASSIGN_WORKER,
	MANAGE_CARIYE
}

# --- YENİ: Açık panelleri takip etmek için dictionary ---
var open_panels = {}
# -----------------------------------------------------

func _ready() -> void:
	# PopupMenu'nun id_pressed sinyalini bağla
	if interaction_menu:
		# Önce mevcut bağlantıyı kes (varsa)
		if interaction_menu.is_connected("id_pressed", _on_interaction_menu_id_pressed):
			interaction_menu.disconnect("id_pressed", _on_interaction_menu_id_pressed)
		# Yeniden bağla
		interaction_menu.id_pressed.connect(_on_interaction_menu_id_pressed)
	else:
		printerr("Campfire: InteractionMenu bulunamadı!")


# Oyuncu etkileşime geçtiğinde çağrılır
func interact():
	print("Campfire.interact() çağrıldı.")
	if not interaction_menu:
		printerr("Campfire: InteractionMenu node'u bulunamıyor!")
		return

	# Menüyü temizle (önceki açılıştan kalmış olabilecekleri sil)
	interaction_menu.clear()

	# Menü öğelerini ekle
	interaction_menu.add_item("İnşa Et", MenuOption.BUILD)
	interaction_menu.add_item("İşçi Ata", MenuOption.ASSIGN_WORKER)
	interaction_menu.add_item("Cariyeleri Yönet", MenuOption.MANAGE_CARIYE)
	# Gerekirse başka seçenekler eklenebilir

	# Menüyü oyuncunun veya kamp ateşinin biraz üzerinde göster
	# Global fare pozisyonunu kullanmak daha dinamik olabilir
	# ESKİ KOD: interaction_menu.popup(Rect2(get_global_mouse_position(), Vector2.ZERO))
	# Veya kamp ateşinin pozisyonuna göre:
	# ESKİ KOD: interaction_menu.popup(Rect2(global_position + Vector2(0, -50), Vector2.ZERO))

	# YENİ KOD: Menüyü ekranın ortasında aç
	interaction_menu.popup_centered()


# PopupMenu'den bir öğe seçildiğinde çalışır
func _on_interaction_menu_id_pressed(id: int) -> void:
	match id:
		MenuOption.BUILD:
			print("İnşa Et seçildi.")
			_open_or_show_ui_panel(BUILD_MENU_SCENE) # <-- Yeni fonksiyonu çağır
		MenuOption.ASSIGN_WORKER:
			print("İşçi Ata seçildi.")
			_open_or_show_ui_panel(WORKER_ASSIGN_SCENE) # <-- Yeni fonksiyonu çağır
		MenuOption.MANAGE_CARIYE:
			print("Cariyeleri Yönet seçildi.")
			_open_or_show_ui_panel(CARIYE_MENU_SCENE) # <-- Yeni fonksiyonu çağır
		_:
			print("Bilinmeyen menü seçeneği: %d" % id)


# Belirtilen UI panelini açar veya zaten açıksa gösterir
func _open_or_show_ui_panel(scene_path: String) -> void:
	# 1. Panel zaten açık mı (instance var mı)?
	if open_panels.has(scene_path) and is_instance_valid(open_panels[scene_path]):
		var existing_instance = open_panels[scene_path]
		print("Campfire: Re-showing existing panel for: ", scene_path)
		# Asıl paneli bul (CanvasLayer içindeyse)
		var target_panel = existing_instance
		if existing_instance is CanvasLayer:
			for child in existing_instance.get_children():
				if child is PanelContainer or child is Control: # Daha genel olabilir
					target_panel = child
					break
		# Sadece görünür yap ve ortala
		if target_panel.has_method("show_centered"):
			target_panel.show_centered()
		else:
			existing_instance.visible = true # Fallback
		return # İşlem tamam

	# 2. Panel açık değilse, yenisini oluştur
	print("Campfire: Creating new panel instance for: ", scene_path)
	var panel_scene = load(scene_path)
	if panel_scene:
		var instance = panel_scene.instantiate()
		get_tree().root.add_child(instance)
		open_panels[scene_path] = instance # Referansı sakla

		# Asıl paneli bul (CanvasLayer içindeyse)
		var target_panel = instance 
		if instance is CanvasLayer:
			for child in instance.get_children():
				if child is PanelContainer or child is Control:
					target_panel = child
					break
			if target_panel == instance:
				printerr("Campfire: CanvasLayer for %s has no Panel/Control child!" % scene_path)

		# Sinyalleri Bağla (target_panel'e)
		if target_panel.has_signal("build_requested"):
			target_panel.build_requested.connect(_on_panel_build_requested)
		if target_panel.has_signal("close_requested"):
			target_panel.close_requested.connect(_on_panel_close_requested.bind(scene_path)) # scene_path'i bind et

		# Ortala ve Göster (target_panel üzerinde)
		if target_panel.has_method("show_centered"):
			target_panel.show_centered()
		else:
			instance.visible = true # Fallback
	else:
		printerr("Campfire: UI panel scene could not be loaded: %s" % scene_path)

# BuildMenuUI'dan gelen build_requested sinyalini işler
func _on_panel_build_requested(building_scene_path: String) -> void:
	print("Campfire: Received build request for: ", building_scene_path)
	var success = VillageManager.request_build_building(building_scene_path)
	# if success: # Başarılı inşa sonrası menüyü gizle
	# 	_on_panel_close_requested(BUILD_MENU_SCENE) # BUILD_MENU_SCENE kullan

# Herhangi bir panelden gelen close_requested sinyalini işler
func _on_panel_close_requested(scene_path_to_close: String) -> void: # Parametre değişti
	print("Campfire: Received close request for scene: ", scene_path_to_close)
	if open_panels.has(scene_path_to_close) and is_instance_valid(open_panels[scene_path_to_close]):
		var instance_to_hide = open_panels[scene_path_to_close]
		# Asıl paneli (PanelContainer/Control) bul ve gizle
		var target_panel = instance_to_hide
		if instance_to_hide is CanvasLayer:
			for child in instance_to_hide.get_children():
				if child is PanelContainer or child is Control:
					target_panel = child
					break
		target_panel.visible = false # queue_free() yerine gizle
		print("Campfire: Panel hidden: ", scene_path_to_close)
	else:
		print("Campfire: Panel to hide not found or invalid: ", scene_path_to_close)

# Oyun kapatılırken veya sahne değişirken panelleri temizle (opsiyonel)
func _exit_tree() -> void:
	for scene_path in open_panels:
		if is_instance_valid(open_panels[scene_path]):
			open_panels[scene_path].queue_free()
	open_panels.clear()
