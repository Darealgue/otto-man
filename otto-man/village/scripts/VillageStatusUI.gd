extends MarginContainer # .tscn dosyasındaki kök node türü

# Bu script, UI elemanlarını kod ile oluşturur ve günceller.

# Label referansları (@onready ile sahneden alınacak)
# ÖNEMLİ: Bu node isimlerinin (%GoldLabel%) .tscn dosyasındaki
# Label'ların "Unique Name in Owner" özelliği işaretlenerek verildiğini varsayar.
# Eğer işaretlenmediyse, get_node("StatusVBox/GoldLabel") gibi yolları kullan.
@onready var gold_label: Label = %GoldLabel
@onready var worker_label: Label = %WorkerLabel
@onready var asker_label: Label = %AskerLabel
@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var food_label: Label = %FoodLabel
@onready var water_label: Label = %WaterLabel
@onready var metal_label: Label = %MetalLabel
@onready var bread_label: Label = %BreadLabel
@onready var summary_container: HBoxContainer = %SummaryHBox
@onready var resource_list_container: VBoxContainer = %ResourceList
# Events & Morale
@onready var events_label: Label = %EventsLabel
@onready var morale_label: Label = %MoraleLabel
@onready var economy_stats_label: Label = %EconomyStatsLabel
# İleride eklenecek diğer label'lar için @onready değişkenler...

# Üretici script yolu eşlemeleri (sadece bu üreticiler yerleştirildiyse kaynak göster)
const PRODUCER_SCRIPTS := {
	"wood": "res://village/scripts/WoodcutterCamp.gd",
	"stone": "res://village/scripts/StoneMine.gd",
	"food": "res://village/scripts/HunterGathererHut.gd",
	"water": "res://village/scripts/Well.gd",
	"lumber": "res://village/scripts/Sawmill.gd",
	"brick": "res://village/scripts/Brickworks.gd",
	"metal": "res://village/scripts/Blacksmith.gd",
	"bread": "res://village/scripts/Bakery.gd",
	"cloth": "res://village/scripts/Weaver.gd",
	# Gelişmiş kaynaklar
	"weapon": "res://village/scripts/Gunsmith.gd",
	"armor": "res://village/scripts/Armorer.gd",
	"garment": "res://village/scripts/Tailor.gd",
	"tea": "res://village/scripts/TeaHouse.gd",
	"soap": "res://village/scripts/SoapMaker.gd",
	"medicine": "res://village/scripts/Herbalist.gd"
}

var _extra_resource_labels: Dictionary = {}

# Icon sizing for resource rows
const RESOURCE_ICON_SIZE := Vector2(25, 25)

# --- Periyodik Güncelleme ---
var update_interval: float = 0.5 # Saniyede 2 kez güncelle
var time_since_last_update: float = 0.0
# ---------------------------

func _ready() -> void:
	# Node referanslarının alınıp alınmadığını kontrol et (güvenlik için)
	if not gold_label or not worker_label or not asker_label or not wood_label or \
	   not stone_label or not food_label or not water_label or not metal_label or \
	   not bread_label:
		printerr("VillageStatusUI Error: Label node'larından biri veya birkaçı bulunamadı! .tscn dosyasındaki isimleri (%NodeName%) veya 'Unique Name in Owner' ayarlarını kontrol edin.")
		return
	if not summary_container or not resource_list_container:
		printerr("VillageStatusUI Warning: SummaryHBox veya ResourceList bulunamadı! Düzen yerleşimini kontrol edin.")

	# Wrap static labels with icons if icons exist
	_wrap_label_with_icon(wood_label, "wood")
	_wrap_label_with_icon(stone_label, "stone")
	_wrap_label_with_icon(food_label, "food")
	_wrap_label_with_icon(water_label, "water")
	_wrap_label_with_icon(metal_label, "metal")
	_wrap_label_with_icon(bread_label, "bread")

	# Ek etiketler sahnede yoksa dinamik oluştur
	_ensure_extra_labels()

	# Sinyale Bağlanmayı Kaldır/Yorumla
#	if VillageManager.has_signal("village_data_changed"):
#		VillageManager.village_data_changed.connect(_update_labels)
#	else:
#		printerr("VillageStatusUI: VillageManager'da 'village_data_changed' sinyali bulunamadı!")

	# GlobalPlayerData için doğrudan sinyal yok, village_data_changed tetiklendiğinde
	# veya _process içinde periyodik olarak güncellenebilir. Şimdilik _update_labels içinde.

	# İlk Güncellemeyi Yap
	_update_labels()
	print("VillageStatusUI Ready.")

func _process(delta: float) -> void:
	# Zamanı artır
	time_since_last_update += delta

	# Eğer interval dolduysa UI'ı güncelle
	if time_since_last_update >= update_interval:
		# print("VillageStatusUI: Updating UI via _process timer") # Opsiyonel Debug
		_update_labels()
		time_since_last_update = 0.0 # Sayacı sıfırla

# Tüm etiketleri güncelleyen fonksiyon
func _update_labels() -> void:
	# Node referanslarının hala geçerli olup olmadığını kontrol etmek iyi bir pratiktir
	if not is_instance_valid(gold_label):
		printerr("VillageStatusUI Error: Label node referansları geçersiz!")
		# Belki sinyal bağlantısını kesmek gerekir:
		# if VillageManager.is_connected("village_data_changed", Callable(self, "_update_labels")):
		#     VillageManager.disconnect("village_data_changed", Callable(self, "_update_labels"))
		return

	# Global Veriler
	gold_label.text = "Altın: %d" % GlobalPlayerData.gold
	# Asker sayısını Barracks'tan al
	var soldier_count = _get_soldier_count()
	asker_label.text = "Asker: %d" % soldier_count
	# Morale (optional label)
	if is_instance_valid(morale_label):
		var m := VillageManager.get_morale()
		morale_label.text = "Moral: %.0f" % m
		if m >= 75.0:
			morale_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		elif m < 50.0:
			morale_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
		else:
			if morale_label.has_theme_color_override("font_color"):
				morale_label.remove_theme_color_override("font_color")
	# Diğer gelişmiş kaynaklar...

	# VillageManager Verileri
	worker_label.text = "İşçiler: %d / %d" % [VillageManager.idle_workers, VillageManager.total_workers]

	# Asker ikmal durumu
	var status_text: String = "Tam"
	var used_shortage: bool = false
	var shortages: Dictionary = {}
	var v = VillageManager.get("_last_day_shortages")
	if v != null and v is Dictionary:
		shortages = v
		if shortages.has("soldier_food") or shortages.has("soldier_water"):
			var s_food: int = int(shortages.get("soldier_food", 0))
			var s_water: int = int(shortages.get("soldier_water", 0))
			status_text = ("Tam" if (s_food == 0 and s_water == 0) else "Eksik")
			used_shortage = true
	
	# Gün daha tiklenmediyse stok bazlı öngörü: mevcut stok bu günü karşılıyor mu?
	if not used_shortage:
		var sc: int = soldier_count
		var req_w: int = int(ceil(float(sc) * 0.5))
		var req_f: int = int(ceil(float(sc) * 0.5))
		var have_w: int = int(VillageManager.resource_levels.get("water", 0))
		var have_f: int = int(VillageManager.resource_levels.get("food", 0))
		if have_w < req_w or have_f < req_f:
			status_text = "Eksik"
	
	asker_label.text += "  | İkmal: " + status_text

	# Temel Kaynaklar (Kullanılabilir / Toplam) - her zaman görünür
	_set_resource_visible_and_update(wood_label, "Odun", "wood", true)
	_set_resource_visible_and_update(stone_label, "Taş", "stone", true)
	_set_resource_visible_and_update(food_label, "Yiyecek", "food", true)
	_set_resource_visible_and_update(water_label, "Su", "water", true)
	# Diğerleri sadece envanterde varsa görünür
	_set_resource_visible_and_update(metal_label, "Metal", "metal", false, true)
	_set_resource_visible_and_update(bread_label, "Ekmek", "bread", false, true)

	# Gelişmiş Kaynaklar (dinamik label oluştur)
	_update_dynamic_resource_label("lumber", "Kereste")
	_update_dynamic_resource_label("brick", "Tuğla")
	_update_dynamic_resource_label("weapon", "Silah")
	_update_dynamic_resource_label("armor", "Zırh")
	_update_dynamic_resource_label("garment", "Giyim")
	_update_dynamic_resource_label("cloth", "Kumaş")
	_update_dynamic_resource_label("tea", "Kahve")
	_update_dynamic_resource_label("soap", "Parfüm")
	_update_dynamic_resource_label("medicine", "İlaç")

	# Aktif olaylar
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	var summaries = VillageManager.get_active_events_summary(day)
	if is_instance_valid(events_label):
		if summaries.is_empty():
			events_label.text = "Olay: Yok"
		else:
			var lines: Array[String] = []
			for s in summaries:
				lines.append("%s (%.0f%%, %dgün)" % [String(s["type"]).capitalize(), float(s["severity"]) * 100.0, int(s["days_left"])])
			events_label.text = ", ".join(lines)

	# Günlük ekonomi istatistikleri
	if is_instance_valid(economy_stats_label):
		var stats = VillageManager.get_economy_last_day_stats()
		if stats.is_empty():
			economy_stats_label.text = "Üretim/Gider/Net: -"
		else:
			var p := float(stats.get("total_production", 0.0))
			var c := float(stats.get("total_consumption", 0.0))
			var n := float(stats.get("net", 0.0))
			economy_stats_label.text = "Üretim/Gider/Net: %.1f / %.1f / %.1f" % [p, c, n]
			# Renk kodu
			if n > 0.01:
				economy_stats_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
			elif n < -0.01:
				economy_stats_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
			else:
				if economy_stats_label.has_theme_color_override("font_color"):
					economy_stats_label.remove_theme_color_override("font_color")

func _ensure_extra_labels() -> void:
	# Sahnede yoksa MoraleLabel ve EventsLabel oluşturur
	var container: Node = summary_container if is_instance_valid(summary_container) else (bread_label.get_parent() if bread_label and bread_label.get_parent() else self)
	if not is_instance_valid(morale_label):
		morale_label = Label.new()
		morale_label.name = "MoraleLabel"
		container.add_child(morale_label)
	if not is_instance_valid(events_label):
		events_label = Label.new()
		events_label.name = "EventsLabel"
		container.add_child(events_label)
	if not is_instance_valid(economy_stats_label):
		economy_stats_label = Label.new()
		economy_stats_label.name = "EconomyStatsLabel"
		container.add_child(economy_stats_label)

# Tek bir kaynak etiketini güncelleyen helper fonksiyonu
func _update_resource_label(label_node: Label, resource_display_name: String, resource_key: String) -> void:
	if not is_instance_valid(label_node):
		return

	var current: int = VillageManager.get_resource_level(resource_key)
	var cap: int = VillageManager.get_storage_capacity_for(resource_key)
	var icon_only := label_node.has_meta("icon_only") and bool(label_node.get_meta("icon_only"))
	
	if cap > 0:
		if icon_only:
			label_node.text = "%d/%d" % [current, cap]
		else:
			label_node.text = "%s: %d/%d" % [resource_display_name, current, cap]
			
		# Highlight when full
		var ratio := (float(current) / float(cap)) if cap > 0 else 0.0
		if current >= cap:
			label_node.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		elif ratio >= 0.8:
			label_node.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		else:
			if label_node.has_theme_color_override("font_color"):
				label_node.remove_theme_color_override("font_color")
	else:
		if icon_only:
			label_node.text = "%d" % current
		else:
			label_node.text = "%s: %d" % [resource_display_name, current]

# Helper: dinamik kaynak etiketi güncelle/oluştur
func _update_dynamic_resource_label(resource_key: String, display_name: String) -> void:
	var label := _get_or_create_resource_label(resource_key, display_name)
	if not is_instance_valid(label):
		return
	var current: int = VillageManager.get_resource_level(resource_key)
	var should_show = current > 0
	
	# Gizle/göster işlemini parent container'a uygula
	_set_container_visibility(label, should_show)
	
	if should_show:
		_update_resource_label(label, display_name, resource_key)

# Helper: üretici bina var mı kontrol et
func _producer_exists(resource_key: String) -> bool:
	var script_path: String = String(PRODUCER_SCRIPTS.get(resource_key, ""))
	if script_path == "":
		return false
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		return false
	var placed = scene.get_node_or_null("PlacedBuildings")
	if not placed:
		return false
	for b in placed.get_children():
		if b.has_method("get_script") and b.get_script() != null:
			var sp = b.get_script().resource_path
			if sp == script_path:
				return true
	return false

# Helper: görünürlük + güncelleme
func _set_resource_visible_and_update(label_node: Label, display_name: String, key: String, force_visible: bool, show_when_nonzero: bool = false) -> void:
	if not is_instance_valid(label_node):
		return
	var current: int = VillageManager.get_resource_level(key)
	var visible_by_stock := show_when_nonzero and current > 0
	var should_show = force_visible or visible_by_stock
	
	# Gizle/göster işlemini parent container'a uygula
	if is_instance_valid(label_node):
		_set_container_visibility(label_node, should_show)
	
	if should_show:
		_update_resource_label(label_node, display_name, key)

# Helper: Parent container'ı (Row) gizle/göster
func _set_container_visibility(label_node: Label, visible: bool) -> void:
	if not is_instance_valid(label_node):
		return
	label_node.visible = visible
	var parent = label_node.get_parent()
	if is_instance_valid(parent) and (parent is HBoxContainer) and (parent.name.ends_with("Row") or parent.name.ends_with("RowDynamic")):
		parent.visible = visible

# Helper: Barracks'tan asker sayısını al
func _get_soldier_count() -> int:
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		return 0
	var placed = scene.get_node_or_null("PlacedBuildings")
	if not placed:
		return 0
	for building in placed.get_children():
		if building.has_method("get_military_force"):  # Barracks-specific method
			# assigned_workers property'sine direkt erişmeyi dene
			if building.get("assigned_workers") != null:
				return building.assigned_workers
			return 0
	return 0

# Helper: ihtiyaç halinde label oluştur
func _get_or_create_resource_label(resource_key: String, display_name: String) -> Label:
	if _extra_resource_labels.has(resource_key):
		return _extra_resource_labels[resource_key]
	var container: Node = resource_list_container if is_instance_valid(resource_list_container) else (bread_label.get_parent() if bread_label and bread_label.get_parent() else self)
	var lbl := _create_resource_row_with_icon(resource_key, display_name, container)
	_extra_resource_labels[resource_key] = lbl
	return lbl

func _create_resource_row_with_icon(resource_key: String, display_name: String, container: Node) -> Label:
	var row := HBoxContainer.new()
	row.name = resource_key.capitalize() + "RowDynamic"
	row.layout_mode = 2
	row.add_theme_constant_override("separation", 6)

	var icon_path := _get_icon_path_for_resource(resource_key)
	if icon_path != "":
		var icon := TextureRect.new()
		icon.name = resource_key.capitalize() + "Icon"
		icon.layout_mode = 2
		icon.custom_minimum_size = RESOURCE_ICON_SIZE
		icon.texture = load(icon_path)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	var lbl := Label.new()
	lbl.name = String(display_name) + "LabelDynamic"
	lbl.layout_mode = 2
	lbl.set_meta("icon_only", true)
	lbl.text = "-"
	row.add_child(lbl)

	container.add_child(row)
	return lbl

func _get_icon_path_for_resource(resource_key: String) -> String:
	var candidates: Array[String] = []
	if resource_key == "tea":
		candidates = [
			"res://assets/Icons/coffee_icon.png",
			"res://assets/Icons/coffe_icon.png",
			"res://assets/Icons/tea_icon.png"
		]
	elif resource_key == "soap":
		candidates = [
			"res://assets/Icons/perfume_icon.png",
			"res://assets/Icons/soap_icon.png"
		]
	else:
		candidates = ["res://assets/Icons/%s_icon.png" % resource_key]
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return ""

func _wrap_label_with_icon(label_node: Label, resource_key: String) -> void:
	if not is_instance_valid(label_node):
		return
	# Force icon_only meta to ensure text is formatted correctly (just number)
	label_node.set_meta("icon_only", true)
	
	var parent := label_node.get_parent()
	if not is_instance_valid(parent):
		return
	# Already wrapped with an icon?
	if parent is HBoxContainer:
		for child in parent.get_children():
			if child is TextureRect:
				return
	var icon_path := _get_icon_path_for_resource(resource_key)
	if icon_path == "":
		return
	var index: int = parent.get_children().find(label_node)
	if index < 0:
		return
	parent.remove_child(label_node)
	var row := HBoxContainer.new()
	row.name = resource_key.capitalize() + "Row"
	row.layout_mode = 2
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.name = resource_key.capitalize() + "Icon"
	icon.layout_mode = 2
	icon.custom_minimum_size = RESOURCE_ICON_SIZE
	icon.texture = load(icon_path)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.add_child(label_node)
	parent.add_child(row)
	parent.move_child(row, index)
