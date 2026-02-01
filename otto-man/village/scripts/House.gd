extends Node2D

class_name House # Bu, diğer scriptlerden type hint için faydalı olabilir

# Evin kaç işçiyi barındırabileceği
@export var max_occupants: int = 5

# Şu anda bu evde kalan işçilerin listesi (CampFire gibi)
var _occupants: Array = []

# Başlangıçta ev boş
func _ready() -> void:
	_occupants = []
	# Evin "Housing" grubunda olduğundan emin olalım (Inspector'dan yapıldı ama kodda da kontrol edebiliriz)
	if not is_in_group("Housing"):
		add_to_group("Housing")
		print("House %s added to Housing group via code." % name) # Debug

# Mevcut işçi sayısını döndürür (gerçekten SLEEPING state'indeki worker'ları sayar)
func get_occupant_count() -> int:
	# _occupants listesindeki geçerli worker'ları say
	var count = 0
	var to_remove: Array = []
	
	for occupant in _occupants:
		if is_instance_valid(occupant):
			# Worker hala SLEEPING state'indeyse say
			var current_state = occupant.current_state
			if current_state == 0:  # State.SLEEPING = 0
				count += 1
			else:
				# Artık uyumuyor (başka bir state'de), listeden çıkarılacak
				to_remove.append(occupant)
		else:
			# Geçersiz referans, listeden çıkarılacak
			to_remove.append(occupant)
	
	# Geçersiz olanları listeden çıkar
	for occupant in to_remove:
		var index = _occupants.find(occupant)
		if index >= 0:
			_occupants.remove_at(index)
	
	return count

# Maksimum kapasiteyi döndürür
func get_max_capacity() -> int:
	return max_occupants

# Bu ev bir işçi daha alabilir mi?
func can_add_occupant() -> bool:
	return get_occupant_count() < get_max_capacity()

# Bu eve yeni bir işçi ekler
func add_occupant(worker: Node) -> bool:
	if not can_add_occupant():
		print("[House DEBUG] Kapasite dolu! Mevcut: %d/%d" % [get_occupant_count(), get_max_capacity()])
		return false
	
	# Worker zaten listede mi kontrol et
	if worker in _occupants:
		print("[House DEBUG] Worker zaten listede. Mevcut: %d/%d" % [get_occupant_count(), get_max_capacity()])
		return true
	
	# İşçiyi listeye ekle
	_occupants.append(worker)
	print("[House DEBUG] Worker listeye eklendi. Yeni sayı: %d/%d" % [get_occupant_count(), get_max_capacity()])
	
	# İşçiyi ekle - eğer zaten bir parent'ı varsa (örn. WorkersContainer) child olarak ekleme
	# Sadece referans tut (housing_node zaten set edilmiş)
	if worker.get_parent() == null:
		add_child(worker)
		print("[House DEBUG] Worker child olarak eklendi. Mevcut: %d/%d" % [get_occupant_count(), get_max_capacity()])
	else:
		# Worker zaten WorkersContainer'da, sadece referans tut
		print("[House DEBUG] Worker zaten parent'a sahip (%s). Sadece referans tutuluyor. Mevcut: %d/%d" % [worker.get_parent().name, get_occupant_count(), get_max_capacity()])
	return true


# Evden bir işçi çıkarır (başarılıysa true döner)
# Not: Worker parametresi opsiyonel (CampFire ile uyumluluk için)
func remove_occupant(worker: Node = null) -> bool:
	# Debug: Only log errors, not normal operations
	# print("[House DEBUG] remove_occupant çağrıldı - worker: %s, mevcut: %d/%d" % [worker.name if worker else "null", get_occupant_count(), get_max_capacity()])
	
	# Eğer worker parametresi verilmişse, o worker'ı listeden çıkar
	if worker != null:
		if worker in _occupants:
			_occupants.erase(worker)
			# Debug: Only log on success if needed
			# print("[House DEBUG] Worker listeden çıkarıldı. Yeni sayı: %d/%d" % [get_occupant_count(), get_max_capacity()])
			return true
		else:
			# Worker listede yok - bu normal olabilir (worker zaten başka yerde)
			# Debug: Only log if this is unexpected
			# print("[House DEBUG] Worker listede yok! Mevcut: %d/%d" % [get_occupant_count(), get_max_capacity()])
			return true  # Başarılı say (worker zaten başka yerde olabilir)
	else:
		# Worker parametresi yoksa, ilk bulunan worker'ı çıkar (eski davranış)
		if _occupants.size() > 0:
			var first_occupant = _occupants[0]
			_occupants.remove_at(0)
			# Debug: Only log on success if needed
			# print("[House DEBUG] İlk worker çıkarıldı. Yeni sayı: %d/%d" % [get_occupant_count(), get_max_capacity()])
			return true
		else:
			# Ev zaten boş - bu normal olabilir
			# Debug: Only log if this is unexpected
			# print("[House DEBUG] UYARI: Ev zaten boş! Mevcut: %d/%d" % [get_occupant_count(), get_max_capacity()])
			return true  # Başarılı say (ev zaten boş olabilir)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
