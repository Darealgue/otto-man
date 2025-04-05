extends Node2D

class_name ResourceBuilding

@export var resource_type: String = "wood" # wood, stone, water, food, metal
@export var building_name: String = "Resource Building"
@export var worker_capacity: int = 1
@export var resource_production_rate: float = 1.0 # resources per hour

var assigned_workers = 0
var worker_ids = []
var slot_index: int = -1 # Bina slotunun indeksi
var building_type: String = "" # Bina türü

func _ready():
	print("ResourceBuilding başlatıldı: ", building_name, " - Tip: ", resource_type)
	
	# Gruba eklendiğinden emin ol
	if not is_in_group("resource_buildings"):
		add_to_group("resource_buildings")
		print("'resource_buildings' grubuna eklendi")
	
	# Label'ları güncelle
	update_labels()

func update_labels():
	var worker_label = get_node_or_null("WorkerLabel")
	if worker_label:
		if assigned_workers > 0:
			worker_label.text = "İşçi: " + str(assigned_workers) + "/" + str(worker_capacity)
		else:
			worker_label.text = "İşçi: Yok"

func assign_worker(worker_id):
	if assigned_workers < worker_capacity:
		assigned_workers += 1
		worker_ids.append(worker_id)
		update_labels()
		print("İşçi ", worker_id, " binaya atandı: ", building_name)
		return true
	return false

func remove_worker(worker_id):
	if worker_id in worker_ids:
		worker_ids.erase(worker_id)
		assigned_workers -= 1
		update_labels()
		print("İşçi ", worker_id, " binadan çıkarıldı: ", building_name)
		return true
	return false

func get_resource_type():
	return resource_type

func set_resource_type(type):
	resource_type = type
	print("Kaynak tipi ayarlandı: ", type)
	
func get_slot_index():
	return slot_index
	
func set_position_index(index: int):
	slot_index = index
	print("Slot indeksi ayarlandı: ", index) 