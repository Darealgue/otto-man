extends Building
class_name House

@export var max_inhabitants: int = 2 # Evde yaşayabilecek maksimum işçi

# Ev özellikleri
var current_inhabitants: int = 0
var inhabitant_ids: Array = []

func _ready() -> void:
	building_type = "house"
	building_name = "Ev"
	max_level = 3
	
	# Temel Building sınıfının ready fonksiyonunu çağır
	super._ready()
	
	# Evi otomatik olarak köydeki evler listesine ekle
	_register_house()

func _register_house() -> void:
	# VillageManager'da ev olarak kaydet
	VillageManager.register_house(self)

func upgrade() -> bool:
	if super.upgrade():
		# Başarılı yükseltme sonrası, ev kapasitesini artır
		max_inhabitants += current_level
		
		# Görsel güncelleme, temel sınıfta yapıldı
		return true
	
	return false

func can_add_inhabitant() -> bool:
	return current_inhabitants < max_inhabitants

func add_inhabitant(worker_id: int) -> bool:
	if can_add_inhabitant() and !inhabitant_ids.has(worker_id):
		inhabitant_ids.append(worker_id)
		current_inhabitants += 1
		return true
	
	return false

func remove_inhabitant(worker_id: int) -> bool:
	if inhabitant_ids.has(worker_id):
		inhabitant_ids.erase(worker_id)
		current_inhabitants -= 1
		return true
	
	return false

# Etkileşim menüsünü göster - bina bilgileri vs.
func _show_building_ui() -> void:
	# Önce üst sınıfın fonksiyonunu çağır
	super._show_building_ui()
	
	# Ev bilgilerini göstermek için ilave kod
	print("Ev Bilgileri:")
	print("Kapasite: " + str(current_inhabitants) + "/" + str(max_inhabitants))
	print("Seviye: " + str(current_level) + "/" + str(max_level))
	
	# Daha sonra özel bir UI eklenebilir 