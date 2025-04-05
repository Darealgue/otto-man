extends Control
class_name ResourceDisplay

@onready var wood_label: Label = $ResourcePanel/HBoxContainer/WoodContainer/WoodCount
@onready var water_label: Label = $ResourcePanel/HBoxContainer/WaterContainer/WaterCount
@onready var food_label: Label = $ResourcePanel/HBoxContainer/FoodContainer/FoodCount
@onready var stone_label: Label = $ResourcePanel/HBoxContainer/StoneContainer/StoneCount
@onready var metal_label: Label = $ResourcePanel/HBoxContainer/MetalContainer/MetalCount
@onready var worker_label: Label = $ResourcePanel/HBoxContainer/WorkerContainer/WorkerCount
@onready var housing_label: Label = $ResourcePanel/HBoxContainer/HousingContainer/HousingCount

func _ready() -> void:
	# Hata kontrolü
	if !wood_label or !water_label or !food_label or !stone_label or !metal_label:
		push_error("Kaynak etiketleri bulunamadı! Node yollarını kontrol edin.")
		return
	
	# Sinyalleri bağla
	VillageManager.worker_assigned.connect(_on_worker_assignment_changed)
	VillageManager.worker_unassigned.connect(_on_worker_assignment_changed)
	VillageManager.house_registered.connect(_update_housing_info)
	
	# Tüm bilgileri güncelle
	_update_all_resources()
	_update_worker_info()
	_update_housing_info()

func _update_all_resources() -> void:
	# Tüm kaynak sayılarını güncelle (işçi sayısına göre)
	if wood_label:
		wood_label.text = str(VillageManager.get_resource_worker_count("wood"))
	
	if water_label:
		water_label.text = str(VillageManager.get_resource_worker_count("water"))
	
	if food_label:
		food_label.text = str(VillageManager.get_resource_worker_count("food"))
	
	if stone_label:
		stone_label.text = str(VillageManager.get_resource_worker_count("stone"))
	
	if metal_label:
		metal_label.text = str(VillageManager.get_resource_worker_count("metal"))

func _update_worker_info(_worker_id: int = -1, _assignment: String = "") -> void:
	# İşçi bilgisini güncelle - Sadece boşta olan işçileri göster
	if worker_label:
		var available_workers = VillageManager.get_unassigned_worker_count()
		worker_label.text = str(available_workers)

func _update_housing_info(_house_id: int = -1) -> void:
	# Barınma bilgisini güncelle - Sadece toplam kapasiteyi göster
	if housing_label:
		var total = VillageManager.get_total_housing_capacity()
		housing_label.text = str(total)

func _on_worker_assignment_changed(_worker_id: int = -1, _assignment: String = "") -> void:
	# İşçi ataması değişince tüm kaynakları güncelle
	_update_all_resources()
	_update_worker_info() 
