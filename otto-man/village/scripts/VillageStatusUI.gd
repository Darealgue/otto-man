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
# İleride eklenecek diğer label'lar için @onready değişkenler...

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
	asker_label.text = "Asker: %d" % GlobalPlayerData.asker_sayisi
	bread_label.text = "Ekmek: %d" % VillageManager.resource_levels.get("bread", 0)
	# Diğer gelişmiş kaynaklar...

	# VillageManager Verileri
	worker_label.text = "İşçiler: %d / %d" % [VillageManager.idle_workers, VillageManager.total_workers]

	# Temel Kaynaklar (Kullanılabilir / Toplam)
	_update_resource_label(wood_label, "Odun", "wood")
	_update_resource_label(stone_label, "Taş", "stone")
	_update_resource_label(food_label, "Yiyecek", "food")
	_update_resource_label(water_label, "Su", "water")
	_update_resource_label(metal_label, "Metal", "metal")

# Tek bir kaynak etiketini güncelleyen helper fonksiyonu
func _update_resource_label(label_node: Label, resource_display_name: String, resource_key: String) -> void:
	# Bu kontrol _update_labels içinde yapıldığı için burada tekrar gerekmeyebilir
	# if not is_instance_valid(label_node): return

	var total = VillageManager.resource_levels.get(resource_key, 0)
	var available = VillageManager.get_available_resource_level(resource_key)
	label_node.text = "%s: %d (%d)" % [resource_display_name, available, total]
