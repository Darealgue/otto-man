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

# Asker ekipmanları: her asker için silah seviyesi (0 = silahsız, 1-3 = seviye)
# { worker_id: {"weapon_tier": 0} }
var soldier_equipment: Dictionary = {}

## Silah seviyesi → savaş bonusları (SSOT). Zırh sistemi kaldırıldı, sadece silah seviyesi var.
## Seviye 1: +5 hasar hissi. Seviye 2: +10 hasar + %20 hayatta kalma. Seviye 3: +20 hasar + %40 hayatta kalma.
const TIER_ATTACK_BONUS: Dictionary = {1: 0.05, 2: 0.10, 3: 0.20}
const TIER_SURVIVAL_CHANCE: Dictionary = {1: 0.0, 2: 0.20, 3: 0.40}
## Savaşa giren bir silahın o savaşta kırılma (kaybolma, stoğa dönmeme) ihtimali — düşük
## seviyeli silahlar daha kırılgan. Bkz. apply_weapon_wear_after_battle().
const TIER_BREAK_CHANCE: Dictionary = {1: 0.50, 2: 0.25, 3: 0.10}
const MAX_WEAPON_TIER: int = 3

# Bina durumu
var is_ui_open: bool = false

# --- Yükseltme Sistemi (İnşaat menüsüyle uyumlu) ---
var level: int = 1
var max_level: int = 5
var is_upgrading: bool = false
var upgrade_time_seconds: float = 5.0
var upgrade_timer: Timer

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
	if worker_id == -1:
		worker_instance.assigned_job_type = ""
		worker_instance.assigned_building_node = null
		if vm.has_method("cancel_worker_registration"):
			vm.cancel_worker_registration()
		_show_message("Köylü kimliği bulunamadı!")
		return false
	assigned_worker_ids.append(worker_id)
	soldier_equipment[worker_id] = {"weapon_tier": 0}
	worker_assigned.emit(worker_id)
	assigned_workers = assigned_worker_ids.size()
	if vm.has_method("notify_building_state_changed"):
		vm.notify_building_state_changed(self)
	elif vm.has_signal("village_data_changed"):
		vm.emit_signal("village_data_changed")
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
	
	# VillageManager'ı al
	var vm = get_node_or_null("/root/VillageManager")
	
	# Ekipmanı geri al (eğer varsa)
	if soldier_equipment.has(worker_id):
		var equip = soldier_equipment[worker_id]
		var tier := int(equip.get("weapon_tier", 0))
		if tier > 0 and vm:
			var res_key := "weapon_t%d" % tier
			vm.resource_levels[res_key] = vm.resource_levels.get(res_key, 0) + 1
		soldier_equipment.erase(worker_id)
	
	# Köylüyü normal işçi yap (kışla bağlantısı varken unregister → idle++)
	if vm:
		_return_worker_to_idle(vm, worker_id)
	
	assigned_workers = assigned_worker_ids.size()
	worker_removed.emit(worker_id)
	if vm:
		if vm.has_method("notify_building_state_changed"):
			vm.notify_building_state_changed(self)
		elif vm.has_signal("village_data_changed"):
			vm.emit_signal("village_data_changed")
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
	"""Köylüyü normal işçi yap — barınak kaydı korunur; kışla sadece iş atamasıdır."""
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
		var workers_container = vm.get("workers_container")
		if workers_container and is_instance_valid(workers_container):
			workers_container.add_child(worker_instance)
	
	# Kışla bağlantısı hâlâ geçerliyken unregister (idle_workers++); barınağa dokunma.
	if vm.has_method("unregister_generic_worker"):
		vm.unregister_generic_worker(worker_id)
	
	worker_instance.is_deployed = false
	worker_instance.assigned_job_type = ""
	
	worker_instance.visible = true
	worker_instance.current_state = worker_instance.State.AWAKE_IDLE
	
	if worker_instance.global_position.x > 1920.0:
		var building_pos_x = global_position.x if is_instance_valid(self) else 960.0
		worker_instance.global_position.x = max(100.0, building_pos_x - 200.0)
		worker_instance.move_target_x = worker_instance.global_position.x
	else:
		worker_instance.move_target_x = worker_instance.global_position.x
	
	print("[Barracks] ✅ Worker %d idle yapıldı - Visible: %s, Pos: %s" % [
		worker_id, worker_instance.visible, worker_instance.global_position
	])

func _update_ui() -> void:
	"""UI'ı güncelle (kontrolcü sistemi için gerekli değil ama debug için)"""
	# UI kullanılmıyor - sadece debug mesajı
	print("[Barracks] Askerler: %d/%d" % [assigned_workers, max_workers])

# --- Yükseltme API (MissionCenter CONSTRUCTION sayfası ile uyumlu) ---
func get_next_upgrade_cost() -> Dictionary:
	return BuildingUpgradeMixin.get_next_cost(self)

func start_upgrade() -> bool:
	return BuildingUpgradeMixin.start(self)

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

## Komutan cariye köyde (boşta) ise orduyu canlı olarak güçlendirir — sabit/süreli bir "buff"
## değil, her savaş gücü hesabında yeniden okunur. Savaş yeteneği ne kadar yüksekse bonus o
## kadar büyük olur. Birden fazla boştaki Komutan varsa en yüksek yetenekli olan liderlik eder.
func _get_commander_force_bonus() -> Dictionary:
	var mm := get_node_or_null("/root/MissionManager")
	if mm == null or not mm.has_method("get_concubines_by_role"):
		return {"attack_bonus": 0.0, "defense_bonus": 0.0}
	var komutanlar: Array = mm.get_concubines_by_role(Concubine.Role.KOMUTAN)
	var best_skill: int = -1
	for cariye in komutanlar:
		if cariye == null or not ("status" in cariye) or cariye.status != Concubine.Status.BOŞTA:
			continue
		var skill: int = cariye.get_skill_level(Concubine.Skill.SAVAŞ)
		if skill > best_skill:
			best_skill = skill
	if best_skill < 0:
		return {"attack_bonus": 0.0, "defense_bonus": 0.0}
	var skill_norm: float = clampf(float(best_skill) / 100.0, 0.0, 1.0)
	return {
		"attack_bonus": 0.10 + 0.30 * skill_norm,
		"defense_bonus": 0.08 + 0.22 * skill_norm,
	}


func get_military_force() -> Dictionary:
	"""Köyün askeri gücünü döndür (silah seviyesi bonusları ile — zırh sistemi kaldırıldı)"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return {"units": {"soldiers": 0}, "equipment": {"weapon": 0}, "attack_bonus": 0.0, "defense_bonus": 0.0, "survival_bonus": 0.0}
	
	# Ekipman durumunu tier'a göre hesapla
	var tier_counts: Dictionary = {1: 0, 2: 0, 3: 0}
	for worker_id in assigned_worker_ids:
		if soldier_equipment.has(worker_id):
			var tier := int(soldier_equipment[worker_id].get("weapon_tier", 0))
			if tier_counts.has(tier):
				tier_counts[tier] += 1
	var equipped_total: int = tier_counts[1] + tier_counts[2] + tier_counts[3]
	
	# Saldırı bonusu: her tier kendi ağırlığıyla katkı yapar (bkz. TIER_ATTACK_BONUS)
	var attack_bonus := 0.0
	var survival_weighted := 0.0
	for tier in tier_counts.keys():
		var count: int = tier_counts[tier]
		attack_bonus += float(count) * float(TIER_ATTACK_BONUS.get(tier, 0.0))
		survival_weighted += float(count) * float(TIER_SURVIVAL_CHANCE.get(tier, 0.0))
	# Savunma bonusu, saldırı bonusunun yarısı kadar taşar (iyi silah bir ölçüde savunmaya da yarar)
	var defense_bonus: float = attack_bonus * 0.5

	# Komutan cariye köyde (boşta) ise orduyu canlı olarak güçlendirir (bkz. _get_commander_force_bonus)
	var commander_bonus: Dictionary = _get_commander_force_bonus()
	attack_bonus += float(commander_bonus.get("attack_bonus", 0.0))
	defense_bonus += float(commander_bonus.get("defense_bonus", 0.0))
	# Hayatta kalma ihtimali: donanımlı askerler arasında ağırlıklı ortalama
	var survival_bonus: float = (survival_weighted / float(equipped_total)) if equipped_total > 0 else 0.0
	
	# Kullanılabilir stok (VillageManager'dan)
	var available_t1 = vm.resource_levels.get("weapon_t1", 0)
	var available_t2 = vm.resource_levels.get("weapon_t2", 0)
	var available_t3 = vm.resource_levels.get("weapon_t3", 0)
	
	# Köy morali bonusu (VillageManager'dan)
	var morale_value = vm.get("village_morale") if "village_morale" in vm else 80.0
	var morale_multiplier = (morale_value / 100.0) * 0.5 + 0.5  # 0-100 morale -> 0.5-1.0 multiplier
	
	var force = {
		"units": {"soldiers": assigned_workers},
		"equipment": {
			# "weapon": eski sistemle uyumluluk için toplam stok (CombatResolver bunu okuyor)
			"weapon": available_t1 + available_t2 + available_t3,
			"weapon_t1": available_t1,
			"weapon_t2": available_t2,
			"weapon_t3": available_t3,
			"equipped_weapon": equipped_total,
			"equipped_tiers": tier_counts,
		},
		"attack_bonus": attack_bonus,
		"defense_bonus": defense_bonus,
		"survival_bonus": survival_bonus,  # kayıp anında hayatta kalma ihtimali (bkz. remove_soldiers)
		"morale_multiplier": morale_multiplier,
		"supplies": {"bread": vm.resource_levels.get("bread", 0), "food": vm.resource_levels.get("food", 0)},
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
	"""Belirli sayıda askeri kaldır (savaşta ölenler için).
	Donanımlı askerler silah seviyelerine göre hayatta kalma şansı yakalar
	(bkz. TIER_SURVIVAL_CHANCE) — bu yüzden gerçekte kaldırılan sayı count'tan az olabilir."""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		print("[Barracks] VillageManager bulunamadı!")
		return
	
	var removed = 0
	var survived = 0
	var candidates: Array[int] = []  # Önce ID'leri topla
	
	# Önce hangi worker'ları kaldıracağımızı belirle (ama listeden çıkarma, sadece ID'leri topla)
	var current_count = assigned_worker_ids.size()
	for i in range(min(count, current_count)):
		if i < assigned_worker_ids.size():
			candidates.append(assigned_worker_ids[current_count - 1 - i])
	
	for worker_id in candidates:
		var tier := 0
		if soldier_equipment.has(worker_id):
			tier = int(soldier_equipment[worker_id].get("weapon_tier", 0))
		var survive_chance: float = TIER_SURVIVAL_CHANCE.get(tier, 0.0)
		if survive_chance > 0.0 and randf() < survive_chance:
			survived += 1
			continue  # Asker silahı sayesinde hayatta kaldı, kışlada kalır
		
		# Ölen askerin silahını geri al
		if soldier_equipment.has(worker_id):
			var equip = soldier_equipment[worker_id]
			var equip_tier := int(equip.get("weapon_tier", 0))
			if equip_tier > 0:
				var res_key := "weapon_t%d" % equip_tier
				vm.resource_levels[res_key] = vm.resource_levels.get(res_key, 0) + 1
			soldier_equipment.erase(worker_id)
		
		if vm.has_method("remove_worker_from_village"):
			vm.remove_worker_from_village(worker_id)
			removed += 1
		else:
			printerr("[Barracks] VillageManager.remove_worker_from_village metodu bulunamadı!")
			break
	
	if survived > 0:
		print("[Barracks] %d asker silahı sayesinde hayatta kaldı!" % survived)
	print("[Barracks] %d asker kaldırıldı (savaş kaybı)" % removed)


## Savaşa katılan (hayatta kalıp kışlada kalan) donanımlı askerlerin silahları, seviyeye göre
## bir ihtimalle kırılır (bkz. TIER_BREAK_CHANCE). Ölen askerlerin silahı zaten remove_soldiers()
## içinde stoğa dönüyor; burası sadece savaşı atlatan askerlerin ekipmanını etkiler.
## Kırılan silah, stokta AYNI seviyede yedek varsa otomatik olarak yenisiyle değiştirilir — asker
## elindeki silahı kaybetmez, oyuncunun her savaş sonrası tek tek yeniden silahlandırma yapmasına
## gerek kalmaz. Stokta yedek yoksa asker o an silahsız kalır (geri dönüş değeri bunu sayar).
func apply_weapon_wear_after_battle() -> int:
	var broken := 0
	var disarmed := 0
	var vm = get_node_or_null("/root/VillageManager")
	for worker_id in assigned_worker_ids:
		if not soldier_equipment.has(worker_id):
			continue
		var tier := int(soldier_equipment[worker_id].get("weapon_tier", 0))
		if tier <= 0:
			continue
		var break_chance: float = TIER_BREAK_CHANCE.get(tier, 0.0)
		if break_chance > 0.0 and randf() < break_chance:
			broken += 1
			var res_key := "weapon_t%d" % tier
			var available: int = int(vm.resource_levels.get(res_key, 0)) if vm else 0
			if vm and available > 0:
				# Stoktan otomatik yedek silah verilir; asker aynı seviyede silahlı kalır.
				vm.resource_levels[res_key] = available - 1
			else:
				soldier_equipment[worker_id]["weapon_tier"] = 0
				disarmed += 1
	if broken > 0:
		print("[Barracks] %d silah savaşta kırıldı (%d asker stok yetersizliğinden silahsız kaldı)" % [broken, disarmed])
		if vm and vm.has_signal("village_data_changed"):
			vm.emit_signal("village_data_changed")
		_update_ui()
	return disarmed


# --- Ekipman Atama Fonksiyonları (sadece silah — zırh sistemi kaldırıldı) ---
func equip_soldier(worker_id: int, tier: int) -> bool:
	"""Askere belirli seviyede silah ver (1-3). Asker zaten silahlıysa eski silahı geri alır."""
	if not assigned_worker_ids.has(worker_id):
		_show_message("Asker bulunamadı!")
		return false
	
	if tier < 1 or tier > MAX_WEAPON_TIER:
		_show_message("Geçersiz silah seviyesi!")
		return false
	
	if not soldier_equipment.has(worker_id):
		soldier_equipment[worker_id] = {"weapon_tier": 0}
	
	var current_tier := int(soldier_equipment[worker_id].get("weapon_tier", 0))
	if current_tier == tier:
		_show_message("Asker zaten bu seviyede silahlı!")
		return false
	
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		_show_message("VillageManager bulunamadı!")
		return false
	
	var res_key := "weapon_t%d" % tier
	var available = vm.resource_levels.get(res_key, 0)
	if available <= 0:
		_show_message("Stokta %d. seviye silah yok!" % tier)
		return false
	
	# Varsa eski silahı geri al
	if current_tier > 0:
		var old_key := "weapon_t%d" % current_tier
		vm.resource_levels[old_key] = vm.resource_levels.get(old_key, 0) + 1
	
	# Yeni silahı ata
	vm.resource_levels[res_key] = available - 1
	soldier_equipment[worker_id]["weapon_tier"] = tier
	vm.emit_signal("village_data_changed")
	_show_message("Asker %d'ye %d. seviye silah verildi!" % [worker_id, tier])
	_update_ui()
	return true

func unequip_soldier(worker_id: int) -> bool:
	"""Askerin silahını geri al (stoka döner)"""
	if not assigned_worker_ids.has(worker_id):
		_show_message("Asker bulunamadı!")
		return false
	
	if not soldier_equipment.has(worker_id):
		_show_message("Askerin ekipman kaydı yok!")
		return false
	
	var tier := int(soldier_equipment[worker_id].get("weapon_tier", 0))
	if tier <= 0:
		_show_message("Asker zaten silahsız!")
		return false
	
	var vm = get_node_or_null("/root/VillageManager")
	if vm:
		var res_key := "weapon_t%d" % tier
		vm.resource_levels[res_key] = vm.resource_levels.get(res_key, 0) + 1
		soldier_equipment[worker_id]["weapon_tier"] = 0
		vm.emit_signal("village_data_changed")
		_show_message("Asker %d'den silah alındı!" % worker_id)
		_update_ui()
		return true
	
	return false

func equip_all_soldiers_with_available() -> void:
	"""Silahsız askerlere elde en yüksek seviyeden başlayarak mevcut silahları otomatik dağıt"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm:
		return
	
	for worker_id in assigned_worker_ids:
		if not soldier_equipment.has(worker_id):
			soldier_equipment[worker_id] = {"weapon_tier": 0}
		
		var equip = soldier_equipment[worker_id]
		if int(equip.get("weapon_tier", 0)) > 0:
			continue  # Zaten silahlı
		
		for tier in [3, 2, 1]:
			var res_key := "weapon_t%d" % tier
			if vm.resource_levels.get(res_key, 0) > 0:
				equip_soldier(worker_id, tier)
				break

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
