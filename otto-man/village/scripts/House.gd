extends Node2D

class_name House # Bu, diğer scriptlerden type hint için faydalı olabilir

# Evin kaç işçiyi barındırabileceği
@export var max_occupants: int = 2

# Şu anda bu evde kalan işçilerin sayısını tutan bir dizi
# Veya sadece sayısını tutabiliriz, şimdilik sayı daha kolay:
var current_occupants: int = 0

# Başlangıçta ev boş
func _ready() -> void:
	current_occupants = 0
	# Evin "Housing" grubunda olduğundan emin olalım (Inspector'dan yapıldı ama kodda da kontrol edebiliriz)
	if not is_in_group("Housing"):
		add_to_group("Housing")
		print("House %s added to Housing group via code." % name) # Debug


# Bu evin bir işçi daha alıp alamayacağını kontrol eder
func can_house_worker() -> bool:
	return current_occupants < max_occupants


# Eve yeni bir işçi ekler (başarılıysa true döner)
func add_occupant() -> bool:
	if can_house_worker():
		current_occupants += 1
		print("House %s: Occupant added. Current: %d/%d" % [name, current_occupants, max_occupants]) # Debug
		return true
	else:
		printerr("House %s: Cannot add occupant, house is full! (%d/%d)" % [name, current_occupants, max_occupants])
		return false


# Evden bir işçi çıkarır (başarılıysa true döner)
# Not: Şimdilik hangi işçinin çıktığını takip etmiyoruz, sadece sayıyı azaltıyoruz.
func remove_occupant() -> bool:
	if current_occupants > 0:
		current_occupants -= 1
		print("House %s: Occupant removed. Current: %d/%d" % [name, current_occupants, max_occupants]) # Debug
		return true
	else:
		# Bu durumun olmaması lazım ama güvenlik kontrolü
		printerr("House %s: Cannot remove occupant, house is already empty!" % name)
		return false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
