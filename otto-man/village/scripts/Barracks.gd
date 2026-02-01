extends Node2D
class_name Barracks

# === KIŞLA BİNASI ===
# Köylü atama sistemi ile asker yönetimi

signal worker_assigned(worker_id: int)
signal worker_removed(worker_id: int)
signal barracks_ui_opened
signal barracks_ui_closed
signal upgrade_started
signal upgrade_finished

# Kışla kapasitesi
var max_workers: int = 5  # Başlangıç kapasitesi
var assigned_workers: int = 0
var assigned_worker_ids: Array[int] = []

# Asker ekipmanları: her asker için weapon ve armor durumu
# { worker_id: {"weapon": true/false, "armor": true/false} }
var soldier_equipment: Dictionary = {}

# Bina durumu
var is_ui_open: bool = false

# --- Yükseltme Sistemi (İnşaat menüsüyle uyumlu) ---
var level: int = 1
var max_level: int = 5
var is_upgrading: bool = false
var upgrade_time_seconds: float = 5.0
var upgrade_timer: Timer
const UPGRADE_COSTS := {
	2: {"gold": 100},
	3: {"gold": 180},
	4: {"gold": 260},
	5: {"gold": 350}
}

func _ready() -> void:
	# UI kullanılmıyor - kontrolcü sistemi ile atama yapılıyor
	# Yükseltme zamanlayıcısı
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true
	add_child(upgrade_timer)
	upgrade_timer.timeout.connect(_on_upgrade_finished)

# UI fonksiyonları kaldırıldı - kontrolcü sistemi kullanılıyor

func add_worker() -> bool:
	"""Kışlaya köylü ata"""
	if assigned_workers >= max_workers:
		_show_message("Kışla kapasitesi dolu!")
		return false
	
	var vm = get_node_or_null("/root/VillageManager")
	if not vm or not vm.has_method("register_generic_worker"):
		_show_message("VillageManager bulunamadı veya register_generic_worker yok!")
		return false
	
	# VillageManager API'sine göre parametresiz bir şekilde işçi örneği döner
	var worker_instance: Node = vm.register_generic_worker()
	if worker_instance == null or not is_instance_valid(worker_instance):
		_show_message("Boşta köylü yok!")
		return false
	
	# Köylüyü asker olarak işaretle
	worker_instance.assigned_job_type = "soldier"
	worker_instance.assigned_building_node = self
	# Askerler için state kontrolü gerekmez (askerler köyde geziniyorlar, mesai kontrolü yok)
	
	# Worker ID'yi bul ve listede tut
	var worker_id := _get_worker_id(vm, worker_instance)
	if worker_id != -1:
		assigned_worker_ids.append(worker_id)
		# Yeni asker için ekipman kaydı oluştur (başlangıçta ekipman yok)
		soldier_equipment[worker_id] = {"weapon": false, "armor": false}
		worker_assigned.emit(worker_id)
	
	assigned_workers += 1
	_update_ui()
	_show_message("Köylü asker yapıldı!")
	return true

func remove_worker() -> bool:
	"""Kışladan köylü çıkar"""
	if assigned_workers <= 0:
		_show_message("Atanmış köylü yok!")
		return false
	
	# Son atanan köylüyü çıkar
	var worker_id = assigned_worker_ids.pop_back()
	assigned_workers -= 1
	
	# VillageManager'ı al
	var vm = get_node_or_null("/root/VillageManager")
	
	# Ekipmanı geri al (eğer varsa)
	if soldier_equipment.has(worker_id):
		var equip = soldier_equipment[worker_id]
		if vm:
			# Ekipmanları geri al
			if equip.get("weapon", false):
				vm.resource_levels["weapon"] = vm.resource_levels.get("weapon", 0) + 1
			if equip.get("armor", false):
				vm.resource_levels["armor"] = vm.resource_levels.get("armor", 0) + 1
		soldier_equipment.erase(worker_id)
	
	# Köylüyü normal işçi yap
	if vm:
		_return_worker_to_idle(vm, worker_id)
	
	worker_removed.emit(worker_id)
	_update_ui()
	_show_message("Asker köylü yapıldı!")
	return true

func _find_idle_worker(vm: Node) -> int:
	"""Boşta köylü bul"""
	if not vm.has_method("get") or not vm.get("all_workers"):
		return -1
	
	var all_workers = vm.get("all_workers")
	for worker_id in all_workers.keys():
		var worker_data = all_workers[worker_id]
		var worker_instance = worker_data.get("instance")
		
		if is_instance_valid(worker_instance):
			# Boşta ve başka binaya atanmamış köylü
			if worker_instance.assigned_job_type == "" and worker_instance.assigned_building_node == null:
				return worker_id
	
	return -1

func _assign_worker_as_soldier(vm: Node, worker_id: int) -> bool:
	"""Deprecated: Eski API. Artık kullanılmıyor."""
	return false

func _get_worker_id(vm: Node, worker_instance: Node) -> int:
	"""Worker instance'dan worker_id'yi bul"""
	if not vm or not vm.has_method("get") or not vm.get("all_workers"):
		return -1
	var all_workers = vm.get("all_workers")
	for wid in all_workers.keys():
		var data = all_workers[wid]
		if data.get("instance") == worker_instance:
			return wid
	return -1

func _return_worker_to_idle(vm: Node, worker_id: int) -> void:
	"""Köylüyü normal işçi yap"""
	var all_workers = vm.get("all_workers")
	if not all_workers.has(worker_id):
		print("[Barracks] Worker %d all_workers'da bulunamadı!" % worker_id)
		return
	
	var worker_data = all_workers[worker_id]
	var worker_instance = worker_data.get("instance")
	
	if not is_instance_valid(worker_instance):
		print("[Barracks] Worker %d instance geçersiz!" % worker_id)
		return
	
	# Worker'ın sahne ağacında olduğundan emin ol
	if not worker_instance.is_inside_tree():
		print("[Barracks] ⚠️ Worker %d sahne ağacında değil! Parent: %s" % [worker_id, worker_instance.get_parent()])
		# WorkersContainer'a ekle
		var workers_container = vm.get("workers_container")
		if workers_container and is_instance_valid(workers_container):
			workers_container.add_child(worker_instance)
			print("[Barracks] ✅ Worker %d WorkersContainer'a eklendi!" % worker_id)
		else:
			print("[Barracks] ❌ WorkersContainer bulunamadı!")
	
	# Asker durumunu sıfırla
	worker_instance.is_deployed = false
	
	# Köylüyü normal işçi yap
	worker_instance.assigned_job_type = ""
	worker_instance.assigned_building_node = null
	
	# Worker'ı ZORUNLU olarak görünür yap ve IDLE state'e al
	worker_instance.visible = true
	worker_instance.current_state = worker_instance.State.AWAKE_IDLE
	
	# Hedefini sıfırla (ekran dışında kalmasın)
	if worker_instance.global_position.x > 1920.0:
		# Eğer ekran dışındaysa, köye geri getir
		var building_pos_x = global_position.x if is_instance_valid(self) else 960.0
		worker_instance.global_position.x = max(100.0, building_pos_x - 200.0)
		worker_instance.move_target_x = worker_instance.global_position.x
	else:
		# Mevcut konumda kal
		worker_instance.move_target_x = worker_instance.global_position.x
	
	print("[Barracks] ✅ Worker %d idle yapıldı - Visible: %s, State: %s, Pos: %s" % [
		worker_id,
		worker_instance.visible,
		worker_instance.State.keys()[worker_instance.current_state] if worker_instance.current_state >= 0 else "INVALID",
		worker_instance.global_position
	])
	
	# VillageManager'da güncelle (bu worker'ı idle listesine ekler)
	if vm.has_method("unregister_generic_worker"):
		vm.unregister_generic_worker(worker_id)

func _update_ui() -> void:
	"""UI'ı güncelle (kontrolcü sistemi için gerekli değil ama debug için)"""
	# UI kullanılmıyor - sadece debug mesajı
	print("[Barracks] Askerler: %d/%d" % [assigned_workers, max_workers])

# --- Yükseltme API (MissionCenter CONSTRUCTION sayfası ile uyumlu) ---
func get_next_upgrade_cost() -> Dictionary:
	var next_level := level + 1
	return UPGRADE_COSTS.get(next_level, {})

func start_upgrade() -> bool:
	if is_upgrading:
		return false
	if level >= max_level:
		return false
	var cost := get_next_upgrade_cost()
	# Şimdilik sadece altın maliyeti
	var gold_cost := int(cost.get("gold", 0))
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gold_cost > 0:
		if not gpd or gpd.gold < gold_cost:
			return false
		gpd.add_gold(-gold_cost)

	is_upgrading = true
	upgrade_started.emit()
	if upgrade_timer:
		upgrade_timer.wait_time = upgrade_time_seconds
		upgrade_timer.start()
	return true

func _on_upgrade_finished() -> void:
	is_upgrading = false
	level = min(max_level, level + 1)
	# Kapasite artışı: seviye başına +2
	max_workers += 2
	upgrade_finished.emit()
	_update_ui()

func _show_message(message: String) -> void:
	"""Mesaj göster (geçici)"""
	print("[Barracks] " + message)
	# TODO: Gerçek UI mesaj sistemi ekle

func get_military_force() -> Dictionary:
	"""Köyün askeri gücünü döndür (ekipman bonusları ile)"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return {"units": {"soldiers": 0}, "equipment": {"weapon": 0, "armor": 0}, "attack_bonus": 0.0, "defense_bonus": 0.0}
	
	# Ekipman durumunu hesapla
	var equipped_weapons = 0
	var equipped_armors = 0
	for worker_id in assigned_worker_ids:
		if soldier_equipment.has(worker_id):
			var equip = soldier_equipment[worker_id]
			if equip.get("weapon", false):
				equipped_weapons += 1
			if equip.get("armor", false):
				equipped_armors += 1
	
	# Kullanılabilir ekipman sayısı (VillageManager'dan)
	var available_weapons = vm.resource_levels.get("weapon", 0)
	var available_armors = vm.resource_levels.get("armor", 0)
	
	# Saldırı ve savunma bonusları (ekipmanlı askerler)
	# Her ekipmanlı asker +%20 saldırı/savunma bonusu verir
	var attack_bonus = float(equipped_weapons) * 0.2
	var defense_bonus = float(equipped_armors) * 0.2
	
	# Köy morali bonusu (VillageManager'dan)
	var morale_value = vm.get("village_morale") if "village_morale" in vm else 80.0
	var morale_multiplier = (morale_value / 100.0) * 0.5 + 0.5  # 0-100 morale -> 0.5-1.0 multiplier
	
	var force = {
		"units": {"soldiers": assigned_workers},
		"equipment": {
			"weapon": available_weapons,
			"armor": available_armors,
			"equipped_weapon": equipped_weapons,
			"equipped_armor": equipped_armors
		},
		"attack_bonus": attack_bonus,  # Toplam saldırı bonusu (ekipmanlı askerler)
		"defense_bonus": defense_bonus,  # Toplam savunma bonusu (ekipmanlı askerler)
		"morale_multiplier": morale_multiplier,
		"supplies": {"bread": vm.resource_levels.get("bread", 0), "water": vm.resource_levels.get("water", 0)},
		"gold": 0
	}
	
	# Altın (GlobalPlayerData'dan al)
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gpd:
		force["gold"] = gpd.gold
	
	return force

func deploy_soldiers() -> void:
	"""Askerleri savaşa deploy et (ekran dışına yürüt)"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		print("[Barracks] VillageManager bulunamadı!")
		return
	
	var all_workers = vm.get("all_workers")
	if not all_workers:
		print("[Barracks] all_workers bulunamadı!")
		return
	
	var deployed_count = 0
	for worker_id in assigned_worker_ids:
		if all_workers.has(worker_id):
			var worker_data = all_workers[worker_id]
			var worker_instance = worker_data.get("instance")
			
			if is_instance_valid(worker_instance) and worker_instance.assigned_job_type == "soldier":
				worker_instance.is_deployed = true
				# Askeri ekran dışına yürüt - state kontrolü yapmadan direkt deploy et
				worker_instance.current_state = worker_instance.State.WORKING_OFFSCREEN
				# Önce görünür yap ki hareket edebilsin
				worker_instance.visible = true
				# Ekran dışına git (sağ tarafa) - mevcut konumdan sağa doğru, çok uzakta
				if worker_instance.global_position.x <= 1920.0:
					worker_instance.move_target_x = worker_instance.global_position.x + 1500.0
				else:
					worker_instance.move_target_x = 3500.0  # Zaten sağdaysa daha da sağa
				worker_instance._target_global_y = worker_instance.global_position.y
				deployed_count += 1
				print("[Barracks] Asker %d deploy edildi - Mevcut konum: (%.1f, %.1f), Hedef: (%.1f, %.1f)" % [
					worker_id, 
					worker_instance.global_position.x, 
					worker_instance.global_position.y,
					worker_instance.move_target_x,
					worker_instance._target_global_y
				])
	
	print("[Barracks] %d/%d asker deploy edildi" % [deployed_count, assigned_workers])

func recall_soldiers() -> void:
	"""Askerleri geri çağır (ekrana geri getir)"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return
	
	var all_workers = vm.get("all_workers")
	if not all_workers:
		return
	
	for worker_id in assigned_worker_ids:
		if all_workers.has(worker_id):
			var worker_data = all_workers[worker_id]
			var worker_instance = worker_data.get("instance")
			
			if is_instance_valid(worker_instance) and worker_instance.assigned_job_type == "soldier":
				worker_instance.is_deployed = false
				# Askeri geri getir
				if worker_instance.current_state == worker_instance.State.WORKING_OFFSCREEN or worker_instance.current_state == worker_instance.State.WAITING_OFFSCREEN:
					worker_instance.current_state = worker_instance.State.RETURNING_FROM_WORK
					worker_instance.visible = true
					# Köye geri dön
					if is_instance_valid(worker_instance.assigned_building_node):
						worker_instance.move_target_x = worker_instance.assigned_building_node.global_position.x
					else:
						# Eğer bina yoksa köy merkezine git
						worker_instance.move_target_x = worker_instance.global_position.x + 500.0
	
	print("[Barracks] Askerler geri çağrıldı")

func remove_soldiers(count: int) -> void:
	"""Belirli sayıda askeri kaldır (savaşta ölenler için)"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		print("[Barracks] VillageManager bulunamadı!")
		return
	
	var removed = 0
	var workers_to_remove: Array[int] = []  # Önce ID'leri topla
	
	# Önce hangi worker'ları kaldıracağımızı belirle (ama listeden çıkarma, sadece ID'leri topla)
	var current_count = assigned_worker_ids.size()
	for i in range(min(count, current_count)):
		if i < assigned_worker_ids.size():
			workers_to_remove.append(assigned_worker_ids[current_count - 1 - i])
	
	# Şimdi VillageManager'dan askerleri tamamen sil
	# remove_worker_from_village Barracks listesinden de çıkaracak
	for worker_id in workers_to_remove:
		# Ölen askerin ekipmanlarını geri al
		if soldier_equipment.has(worker_id):
			var equip = soldier_equipment[worker_id]
			if equip.get("weapon", false):
				vm.resource_levels["weapon"] = vm.resource_levels.get("weapon", 0) + 1
			if equip.get("armor", false):
				vm.resource_levels["armor"] = vm.resource_levels.get("armor", 0) + 1
			soldier_equipment.erase(worker_id)
		
		if vm.has_method("remove_worker_from_village"):
			vm.remove_worker_from_village(worker_id)
			removed += 1
		else:
			printerr("[Barracks] VillageManager.remove_worker_from_village metodu bulunamadı!")
			break
	
	print("[Barracks] %d asker kaldırıldı (savaş kaybı)" % removed)

# --- Ekipman Atama Fonksiyonları ---
func equip_soldier(worker_id: int, equipment_type: String) -> bool:
	"""Askeri ekipmanla donat (weapon veya armor)"""
	if not assigned_worker_ids.has(worker_id):
		_show_message("Asker bulunamadı!")
		return false
	
	if equipment_type != "weapon" and equipment_type != "armor":
		_show_message("Geçersiz ekipman tipi!")
		return false
	
	# Ekipman kaydı var mı kontrol et
	if not soldier_equipment.has(worker_id):
		soldier_equipment[worker_id] = {"weapon": false, "armor": false}
	
	# Zaten ekipmanlı mı?
	if soldier_equipment[worker_id].get(equipment_type, false):
		_show_message("Asker zaten %s donatılmış!" % equipment_type)
		return false
	
	# Ekipman stokta var mı?
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		_show_message("VillageManager bulunamadı!")
		return false
	
	var available = vm.resource_levels.get(equipment_type, 0)
	if available <= 0:
		_show_message("Stokta %s yok!" % equipment_type)
		return false
	
	# Ekipmanı ata
	vm.resource_levels[equipment_type] = available - 1
	soldier_equipment[worker_id][equipment_type] = true
	vm.emit_signal("village_data_changed")
	_show_message("Asker %d'ye %s verildi!" % [worker_id, equipment_type])
	_update_ui()
	return true

func unequip_soldier(worker_id: int, equipment_type: String) -> bool:
	"""Askerden ekipmanı kaldır"""
	if not assigned_worker_ids.has(worker_id):
		_show_message("Asker bulunamadı!")
		return false
	
	if equipment_type != "weapon" and equipment_type != "armor":
		_show_message("Geçersiz ekipman tipi!")
		return false
	
	# Ekipman kaydı var mı ve ekipmanlı mı?
	if not soldier_equipment.has(worker_id):
		_show_message("Askerin ekipman kaydı yok!")
		return false
	
	if not soldier_equipment[worker_id].get(equipment_type, false):
		_show_message("Asker zaten %s donatılmamış!" % equipment_type)
		return false
	
	# Ekipmanı geri al
	var vm = get_node_or_null("/root/VillageManager")
	if vm:
		vm.resource_levels[equipment_type] = vm.resource_levels.get(equipment_type, 0) + 1
		soldier_equipment[worker_id][equipment_type] = false
		vm.emit_signal("village_data_changed")
		_show_message("Asker %d'den %s alındı!" % [worker_id, equipment_type])
		_update_ui()
		return true
	
	return false

func equip_all_soldiers_with_available() -> void:
	"""Tüm askerlere mevcut ekipmanları otomatik ata"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return
	
	var available_weapons = vm.resource_levels.get("weapon", 0)
	var available_armors = vm.resource_levels.get("armor", 0)
	
	for worker_id in assigned_worker_ids:
		if not soldier_equipment.has(worker_id):
			soldier_equipment[worker_id] = {"weapon": false, "armor": false}
		
		var equip = soldier_equipment[worker_id]
		
		# Silah ata (eğer yoksa ve stokta varsa)
		if not equip.get("weapon", false) and available_weapons > 0:
			equip_soldier(worker_id, "weapon")
			available_weapons -= 1
		
		# Zırh ata (eğer yoksa ve stokta varsa)
		if not equip.get("armor", false) and available_armors > 0:
			equip_soldier(worker_id, "armor")
			available_armors -= 1

func upgrade_capacity() -> bool:
	"""Kışla kapasitesini artır"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return false
	
	# Yükseltme maliyeti
	var upgrade_cost = {"gold": 100, "wood": 5, "stone": 3}
	
	# Maliyet kontrolü
	if not _can_afford_cost(upgrade_cost):
		return false
	
	# Maliyeti öde
	_pay_cost(upgrade_cost)
	
	# Kapasiteyi artır
	max_workers += 3
	
	_update_ui()
	_show_message("Kışla kapasitesi artırıldı!")
	return true

func _can_afford_cost(cost: Dictionary) -> bool:
	"""Maliyeti karşılayabilir mi kontrol et"""
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	var vm = get_node_or_null("/root/VillageManager")
	
	if not gpd or not vm:
		return false
	
	# Altın kontrolü
	var gold_cost = cost.get("gold", 0)
	if gold_cost > 0 and gpd.gold < gold_cost:
		return false
	
	# Kaynak kontrolü
	var wood_cost = cost.get("wood", 0)
	var stone_cost = cost.get("stone", 0)
	
	if wood_cost > 0 and vm.resource_levels.get("wood", 0) < wood_cost:
		return false
	
	if stone_cost > 0 and vm.resource_levels.get("stone", 0) < stone_cost:
		return false
	
	return true

func _pay_cost(cost: Dictionary) -> void:
	"""Maliyeti öde"""
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	var vm = get_node_or_null("/root/VillageManager")
	
	if not gpd or not vm:
		return
	
	# Altın öde
	var gold_cost = cost.get("gold", 0)
	if gold_cost > 0:
		gpd.add_gold(-gold_cost)
	
	# Kaynak öde
	var wood_cost = cost.get("wood", 0)
	var stone_cost = cost.get("stone", 0)
	
	if wood_cost > 0:
		vm.resource_levels["wood"] = max(0, vm.resource_levels.get("wood", 0) - wood_cost)
	
	if stone_cost > 0:
		vm.resource_levels["stone"] = max(0, vm.resource_levels.get("stone", 0) - stone_cost)
