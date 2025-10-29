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
	"metal": "res://village/scripts/StoneMine.gd",
	"bread": "res://village/scripts/Bakery.gd",
	# Gelişmiş kaynaklar
	"weapon": "res://village/scripts/Blacksmith.gd",
	"armor": "res://village/scripts/Armorer.gd",
	"garment": "res://village/scripts/Tailor.gd",
	"tea": "res://village/scripts/TeaHouse.gd",
	"soap": "res://village/scripts/SoapMaker.gd"
}

# Dinamik oluşturulan ek kaynak etiketleri
var _extra_resource_labels: Dictionary = {}

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
	bread_label.text = "Ekmek: %d" % VillageManager.resource_levels.get("bread", 0)
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

	# Temel Kaynaklar (Kullanılabilir / Toplam) - sadece üretici bina varsa göster
	_set_resource_visible_and_update(wood_label, "Odun", "wood")
	_set_resource_visible_and_update(stone_label, "Taş", "stone")
	_set_resource_visible_and_update(food_label, "Yiyecek", "food")
	_set_resource_visible_and_update(water_label, "Su", "water")
	_set_resource_visible_and_update(metal_label, "Metal", "metal")

	# Gelişmiş Kaynaklar (dinamik label oluştur)
	_update_dynamic_resource_label("weapon", "Silah")
	_update_dynamic_resource_label("armor", "Zırh")
	_update_dynamic_resource_label("garment", "Giyim")
	_update_dynamic_resource_label("tea", "Çay")
	_update_dynamic_resource_label("soap", "Sabun")
	_update_dynamic_resource_label("metal", "Metal")

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
	var container: Node = bread_label.get_parent() if bread_label and bread_label.get_parent() else self
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
	# Bu kontrol _update_labels içinde yapıldığı için burada tekrar gerekmeyebilir
	# if not is_instance_valid(label_node): return

	var current: int = VillageManager.get_resource_level(resource_key)
	var cap: int = VillageManager.get_storage_capacity_for(resource_key)
	if cap > 0:
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
		label_node.text = "%s: %d" % [resource_display_name, current]

# Helper: dinamik kaynak etiketi güncelle/oluştur
func _update_dynamic_resource_label(resource_key: String, display_name: String) -> void:
	var label := _get_or_create_resource_label(resource_key, display_name)
	var has_prod := _producer_exists(resource_key)
	label.visible = has_prod
	if has_prod:
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
func _set_resource_visible_and_update(label_node: Label, display_name: String, key: String) -> void:
	var has_prod := _producer_exists(key)
	label_node.visible = has_prod
	if has_prod:
		_update_resource_label(label_node, display_name, key)

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
	var container: Node = bread_label.get_parent() if bread_label and bread_label.get_parent() else self
	var lbl := Label.new()
	lbl.name = String(display_name) + "LabelDynamic"
	container.add_child(lbl)
	_extra_resource_labels[resource_key] = lbl
	return lbl
