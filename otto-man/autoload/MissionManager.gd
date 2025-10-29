extends Node

# Görev yöneticisi - autoload singleton

# Görevler ve cariyeler
var missions: Dictionary = {}
var concubines: Dictionary = {}
var active_missions: Dictionary = {}

# Görev zincirleri
var mission_chains: Dictionary = {}  # chain_id -> chain_info
var completed_missions: Array[String] = []  # Tamamlanan görev ID'leri

# Görev ID sayaçları
var next_mission_id: int = 1
var next_concubine_id: int = 1

# Görev üretimi
var mission_rotation_timer: float = 0.0
var mission_rotation_interval: float = 30.0  # 30 saniyede bir görev rotasyonu

# Dinamik görev üretimi
var dynamic_mission_templates: Dictionary = {}
var world_events: Array[Dictionary] = []
var player_reputation: int = 50  # 0-100 arası
var world_stability: int = 70  # 0-100 arası

# Dünya haberleri ve oran modifikasyonları
var trade_agreements: Array[Dictionary] = []  # [{partner, daily_gold, modifiers:{res:delta}, remaining_days, infinite, applied_ids: Array[int]}]
var active_rate_modifiers: Array[Dictionary] = []  # [{resource, delta, expires_day, source}]
var _last_tick_day: int = 0
var available_trade_offers: Array[Dictionary] = []  # [{partner, daily_gold, mods:{res:delta}, days, infinite}]
var settlements: Array[Dictionary] = []  # [{id, name, type, relation, wealth, stability, military, biases:{wood:int,stone:int,food:int}}]
var mission_history: Array[Dictionary] = []  # En son gerçekleşen görev sonuçları (LIFO)
var settlement_trade_modifiers: Array[Dictionary] = [] # [{partner:String, trade_multiplier:float, blocked:bool, expires_day:int, reason:String}]

# Haber kuyrukları
var news_queue_village: Array[Dictionary] = []
var news_queue_world: Array[Dictionary] = []
var _next_news_id: int = 1

# Sinyaller
signal mission_completed(cariye_id: int, mission_id: String, successful: bool, results: Dictionary)
signal mission_started(cariye_id: int, mission_id: String)
signal mission_cancelled(cariye_id: int, mission_id: String)
signal concubine_leveled_up(cariye_id: int, new_level: int)
signal mission_chain_completed(chain_id: String, rewards: Dictionary)
signal mission_chain_progressed(chain_id: String, progress: Dictionary)
signal news_posted(news: Dictionary)
signal mission_unlocked(mission_id: String)
signal trade_offers_updated()
signal battle_completed(battle_result: Dictionary)
signal unit_losses_reported(unit_type: String, losses: int)

func _ready():
	#print("🚀 ===== MISSIONMANAGER _READY BAŞLADI =====")
	_initialize()
	#print("🚀 ===== MISSIONMANAGER _READY BİTTİ =====")

func _initialize():
	#print("🚀 ===== MISSIONMANAGER _INITIALIZE BAŞLADI =====")
	
	# Haber kuyruklarını başlat
	news_queue_village = []
	news_queue_world = []
	#print("📰 Haber kuyrukları başlatıldı: village=", news_queue_village.size(), " world=", news_queue_world.size())
	
	# Başlangıç görevleri ve cariyeler oluştur
	create_initial_missions()
	create_initial_concubines()
	
	# Görev zincirlerini oluştur
	create_mission_chains()
	
	# Başlangıçta sadece 2-3 görev olsun
	limit_initial_missions()

	# Günlük tick başlangıcı
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("get_day"):
		_last_tick_day = tm.get_day()

	# Yerleşimleri kur ve ilk teklifleri bunlara göre üret
	create_settlements()
	refresh_trade_offers("init")

	# Başlangıç ticaret teklifleri
	refresh_trade_offers("init")
	
	# Combat system integration
	_setup_combat_system()
	
	#print("🚀 ===== MISSIONMANAGER _INITIALIZE BİTTİ =====")

func _process(delta):
	# Aktif görevleri kontrol et
	check_active_missions()
	
	# Görev rotasyonu timer'ı
	mission_rotation_timer += delta
	if mission_rotation_timer >= mission_rotation_interval:
		mission_rotation_timer = 0.0
		# %30 şansla görevleri yenile
		if randf() < 0.3:
			refresh_missions()
	
	# Dünya olaylarını güncelle
	update_world_events(delta)

	# Günlük tick kontrolü
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("get_day"):
		var d = tm.get_day()
		if d != _last_tick_day and d > 0:
			_last_tick_day = d
			_on_new_day(d)

# Başlangıç görevleri oluştur
func create_initial_missions():
	
	# Savaş görevleri
	var savas_gorevi = Mission.new()
	savas_gorevi.id = "savas_1"
	savas_gorevi.name = "Kuzey Köyüne Saldırı"
	savas_gorevi.description = "Kuzeydeki düşman köyüne saldırı düzenle. Ganimet topla ve düşmanı zayıflat."
	savas_gorevi.mission_type = Mission.MissionType.SAVAŞ
	savas_gorevi.difficulty = Mission.Difficulty.ORTA
	savas_gorevi.duration = 15.0
	savas_gorevi.success_chance = 0.6
	savas_gorevi.required_cariye_level = 2
	savas_gorevi.required_army_size = 5
	savas_gorevi.required_resources = {"gold": 100}
	savas_gorevi.rewards = {"gold": 500, "wood": 100}
	savas_gorevi.penalties = {"gold": -50, "cariye_injured": true}
	savas_gorevi.target_location = "Kuzey Köyü"
	savas_gorevi.distance = 2.0
	savas_gorevi.risk_level = "Orta"
	missions[savas_gorevi.id] = savas_gorevi
	
	# Keşif görevleri
	var kesif_gorevi = Mission.new()
	kesif_gorevi.id = "kesif_1"
	kesif_gorevi.name = "Batı Ormanlarını Keşfet"
	kesif_gorevi.description = "Batıdaki bilinmeyen ormanları keşfet. Yeni kaynaklar ve ticaret yolları bul."
	kesif_gorevi.mission_type = Mission.MissionType.KEŞİF
	kesif_gorevi.difficulty = Mission.Difficulty.KOLAY
	kesif_gorevi.duration = 10.0
	kesif_gorevi.success_chance = 0.8
	kesif_gorevi.required_cariye_level = 1
	kesif_gorevi.required_army_size = 0
	kesif_gorevi.required_resources = {"gold": 50}
	kesif_gorevi.rewards = {"gold": 200, "wood": 50}
	kesif_gorevi.penalties = {"gold": -25}
	kesif_gorevi.target_location = "Batı Ormanları"
	kesif_gorevi.distance = 1.0
	kesif_gorevi.risk_level = "Düşük"
	missions[kesif_gorevi.id] = kesif_gorevi
	
	# Diplomasi görevleri
	var diplomasi_gorevi = Mission.new()
	diplomasi_gorevi.id = "diplomasi_1"
	diplomasi_gorevi.name = "Güney Köyü ile İttifak"
	diplomasi_gorevi.description = "Güneydeki köy ile dostluk anlaşması yap. Ticaret yolları aç ve güvenlik sağla."
	diplomasi_gorevi.mission_type = Mission.MissionType.DİPLOMASİ
	diplomasi_gorevi.difficulty = Mission.Difficulty.ORTA
	diplomasi_gorevi.duration = 12.0
	diplomasi_gorevi.success_chance = 0.7
	diplomasi_gorevi.required_cariye_level = 2
	diplomasi_gorevi.required_army_size = 0
	diplomasi_gorevi.required_resources = {"gold": 75}
	diplomasi_gorevi.rewards = {"gold": 300, "trade_bonus": 0.1}
	diplomasi_gorevi.penalties = {"gold": -40, "reputation": -10}
	diplomasi_gorevi.target_location = "Güney Köyü"
	diplomasi_gorevi.distance = 1.5
	diplomasi_gorevi.risk_level = "Düşük"
	missions[diplomasi_gorevi.id] = diplomasi_gorevi
	

# Başlangıç cariyeler oluştur
func create_initial_concubines():
	
	# Cariye 1 - Savaş uzmanı
	var cariye1 = Concubine.new()
	cariye1.id = next_concubine_id
	next_concubine_id += 1
	cariye1.name = "Ayla"
	cariye1.level = 2
	cariye1.experience = 50
	cariye1.skills[Concubine.Skill.SAVAŞ] = 80
	cariye1.skills[Concubine.Skill.DİPLOMASİ] = 40
	cariye1.skills[Concubine.Skill.TİCARET] = 30
	cariye1.skills[Concubine.Skill.BÜROKRASİ] = 20
	cariye1.skills[Concubine.Skill.KEŞİF] = 60
	concubines[cariye1.id] = cariye1
	
	# Cariye 2 - Diplomasi uzmanı
	var cariye2 = Concubine.new()
	cariye2.id = next_concubine_id
	next_concubine_id += 1
	cariye2.name = "Zeynep"
	cariye2.level = 1
	cariye2.experience = 25
	cariye2.skills[Concubine.Skill.SAVAŞ] = 30
	cariye2.skills[Concubine.Skill.DİPLOMASİ] = 85
	cariye2.skills[Concubine.Skill.TİCARET] = 70
	cariye2.skills[Concubine.Skill.BÜROKRASİ] = 60
	cariye2.skills[Concubine.Skill.KEŞİF] = 40
	concubines[cariye2.id] = cariye2
	
	# Cariye 3 - Keşif uzmanı
	var cariye3 = Concubine.new()
	cariye3.id = next_concubine_id
	next_concubine_id += 1
	cariye3.name = "Fatma"
	cariye3.level = 1
	cariye3.experience = 10
	cariye3.skills[Concubine.Skill.SAVAŞ] = 40
	cariye3.skills[Concubine.Skill.DİPLOMASİ] = 50
	cariye3.skills[Concubine.Skill.TİCARET] = 45
	cariye3.skills[Concubine.Skill.BÜROKRASİ] = 35
	cariye3.skills[Concubine.Skill.KEŞİF] = 90
	concubines[cariye3.id] = cariye3
	

# Rastgele görev üret

# Görev ata
func assign_mission_to_concubine(cariye_id: int, mission_id: String, soldier_count: int = 0) -> bool:
	print("=== MISSIONMANAGER ATAMA DEBUG ===")
	print("🔄 Görev atanıyor: Cariye %d -> Görev %s (Asker: %d)" % [cariye_id, mission_id, soldier_count])
	
	if not concubines.has(cariye_id):
		print("❌ Cariye bulunamadı: %d" % cariye_id)
		return false
	
	if not missions.has(mission_id):
		print("❌ Görev bulunamadı: %s" % mission_id)
		return false
	
	var cariye = concubines[cariye_id]
	var mission = missions[mission_id]
	
	print("✅ Cariye bulundu: %s (ID: %d)" % [cariye.name, cariye_id])
	print("✅ Görev bulundu: %s (ID: %s)" % [mission.name, mission_id])
	
	# Dictionary görevleri için özel işlem (defense görevleri otomatik değil)
	if mission is Dictionary:
		var mission_type = mission.get("type", "")
		if mission_type == "defense":
			print("❌ Savunma görevleri otomatik gerçekleşir, cariye atanamaz!")
			return false
		
		# Raid görevleri için asker sayısı kaydet
		if mission_type == "raid" and soldier_count > 0:
			mission["assigned_soldiers"] = soldier_count
	
	# Cariye görev alabilir mi? (Dictionary görevleri için kontrol yapma)
	if not (mission is Dictionary):
		if not cariye.can_handle_mission(mission):
			print("❌ Cariye görev alamaz: %s" % cariye.name)
			print("   - Seviye: %d (Gerekli: %d)" % [cariye.level, mission.required_cariye_level])
			print("   - Durum: %s (Gerekli: BOŞTA)" % Concubine.Status.keys()[cariye.status])
			print("   - Sağlık: %d/%d (Min: %d)" % [cariye.health, cariye.max_health, cariye.max_health * 0.5])
			print("   - Moral: %d/%d (Min: %d)" % [cariye.moral, cariye.max_moral, cariye.max_moral * 0.3])
			return false
	
	print("✅ Cariye görev alabilir: %s" % cariye.name)
	
	# Görev başlat (Mission objesi için)
	if not (mission is Dictionary):
		if mission.start_mission(cariye_id):
			cariye.start_mission(mission_id)
			active_missions[cariye_id] = mission_id
			
			print("✅ Görev başlatıldı: %s -> %s" % [cariye.name, mission.name])
			print("📋 Aktif görev sayısı: %d" % active_missions.size())
			
			mission_started.emit(cariye_id, mission_id)
			return true
	else:
		# Dictionary görevleri için basit atama
		cariye.start_mission(mission_id)
		active_missions[cariye_id] = mission_id
		
		# Raid görevleri için asker sayısını kaydet
		if mission.get("type", "") == "raid":
			mission["assigned_soldiers"] = soldier_count
			print("⚔️ Raid görevi: %d asker atandı" % soldier_count)
		
		print("✅ Dictionary görev başlatıldı: %s -> %s" % [cariye.name, mission.get("name", mission_id)])
		mission_started.emit(cariye_id, mission_id)
		return true
	
	print("❌ Görev başlatılamadı!")
	return false
	
	print("==================================")

# Görev iptal et
func cancel_mission(cariye_id: int, mission_id: String) -> bool:
	if not active_missions.has(cariye_id):
		return false
	
	if not missions.has(mission_id):
		return false
	
	var cariye = concubines[cariye_id]
	var mission = missions[mission_id]
	
	# Görev iptal et
	mission.cancel_mission()
	cariye.complete_mission(false, mission_id)  # İptal edildi, başarısız
	
	# Aktif görevlerden çıkar
	active_missions.erase(cariye_id)
	
	# Signal gönder
	mission_cancelled.emit(cariye_id, mission_id)
	
	return true

# Aktif görevleri kontrol et
func check_active_missions():
	var completed_missions = []
	
	for cariye_id in active_missions:
		var mission_id = active_missions[cariye_id]
		var mission = missions[mission_id]
		
		# Görev tamamlandı mı?
		if mission.get_remaining_time() <= 0.0:
			# Başarı şansını hesapla
			var cariye = concubines[cariye_id]
			var success_chance = cariye.calculate_mission_success_chance(mission)
			var successful = randf() < success_chance
			
			# Görev tamamla
			var results = mission.complete_mission(successful)
			cariye.complete_mission(successful, mission_id)
			
			# Sonuçları işle
			process_mission_results(cariye_id, mission_id, successful, results)
			
			# Geçmişe ekle (zenginleştirilmiş kayıt)
			var history_entry: Dictionary = results.duplicate(true)
			history_entry["cariye_name"] = cariye.name
			history_entry["mission_type"] = mission.get_mission_type_name()
			history_entry["difficulty"] = mission.get_difficulty_name()
			history_entry["risk_level"] = mission.risk_level
			history_entry["target_location"] = mission.target_location
			history_entry["distance"] = mission.distance
			# Derin kopya (varsa)
			if results.has("rewards") and results["rewards"] is Dictionary:
				history_entry["rewards"] = results["rewards"].duplicate()
			if results.has("penalties") and results["penalties"] is Dictionary:
				history_entry["penalties"] = results["penalties"].duplicate()
			mission_history.push_front(history_entry)
			# Kayıtları sınırla (performans için)
			if mission_history.size() > 100:
				mission_history = mission_history.slice(0, 100)
			
			# Zincir/bağımlılık ilerletme
			on_mission_completed(mission_id)
			
			# Aktif görevlerden çıkar
			completed_missions.append(cariye_id)
			
			# Sinyal gönder
			mission_completed.emit(cariye_id, mission_id, successful, results)
	
	# Tamamlanan görevleri temizle
	for cariye_id in completed_missions:
		active_missions.erase(cariye_id)

# --- GÖREV GEÇMİŞİ API'ları ---

func get_mission_history() -> Array[Dictionary]:
	return mission_history.duplicate(true)

func get_mission_history_for_cariye(cariye_id: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for h in mission_history:
		if int(h.get("cariye_id", -1)) == cariye_id:
			filtered.append(h)
	return filtered

func get_mission_stats() -> Dictionary:
	var total := mission_history.size()
	var success := 0
	var fail := 0
	for h in mission_history:
		if h.get("successful", false):
			success += 1
		else:
			fail += 1
	var success_rate := int((float(success) / float(max(1, total))) * 100.0)
	return {"total": total, "success": success, "fail": fail, "success_rate": success_rate}

# Görev sonuçlarını işle
func process_mission_results(cariye_id: int, mission_id: String, successful: bool, results: Dictionary):
	var cariye = concubines[cariye_id]
	var mission = missions[mission_id]
	
	if successful:
		# Ödülleri ver
		for reward_type in mission.rewards:
			var amount = mission.rewards[reward_type]
			_apply_reward(reward_type, amount)
		
		# Cariye deneyim kazansın
		var leveled_up = cariye.add_experience(100)
		if leveled_up:
			concubine_leveled_up.emit(cariye_id, cariye.level)
	else:
		# Ceza uygula
		for penalty_type in mission.penalties:
			var amount = mission.penalties[penalty_type]
			if penalty_type == "cariye_injured":
				cariye.take_damage(30)
				print("⚠️ %s yaralandı!" % cariye.name)
			else:
				_apply_penalty(penalty_type, amount)

# Ödül uygula
func _apply_reward(reward_type: String, amount):
	# Amount'u int'e dönüştür
	var int_amount = 0
	if amount is int:
		int_amount = amount
	elif amount is float:
		int_amount = int(amount)
	elif amount is String:
		int_amount = int(amount)
	else:
		print("⚠️ Bilinmeyen ödül tipi: " + str(amount))
		return
	
	match reward_type:
		"gold":
			var global_data = get_node_or_null("/root/GlobalPlayerData")
			if global_data:
				global_data.gold += int_amount
				print("💰 +%d altın kazandın!" % int_amount)
		"wood_rate":
			_active_rate_add("wood", int_amount, 1, "Görev Ödülü")
		"stone_rate":
			_active_rate_add("stone", int_amount, 1, "Görev Ödülü")
		"food_rate":
			_active_rate_add("food", int_amount, 1, "Görev Ödülü")
		"wood", "stone", "food":
			# Şimdilik diğer kaynak ödülleri devre dışı
			print("📦 %s ödülü şimdilik devre dışı: +%d" % [reward_type, int_amount])
		"trade_bonus", "defense", "reputation", "stability_bonus":
			# Özel ödüller - şimdilik sadece log
			print("🎁 %s ödülü: +%s" % [reward_type, str(amount)])
		"special_item", "building", "alliance", "trade_route":
			# Özel öğeler - şimdilik sadece log
			print("🏆 Özel ödül: %s" % str(amount))

# Ceza uygula
func _apply_penalty(penalty_type: String, amount):
	# Amount'u int'e dönüştür
	var int_amount = 0
	if amount is int:
		int_amount = amount
	elif amount is float:
		int_amount = int(amount)
	elif amount is String:
		int_amount = int(amount)
	else:
		print("⚠️ Bilinmeyen ceza tipi: " + str(amount))
		return
	
	match penalty_type:
		"gold":
			var global_data = get_node_or_null("/root/GlobalPlayerData")
			if global_data:
				global_data.gold = max(0, global_data.gold + int_amount)  # amount negatif olacak
				print("💸 %d altın kaybettin!" % abs(int_amount))
		"food_rate":
			_active_rate_add("food", int_amount, 1, "Görev Cezası")
		"wood", "stone", "food":
			# Şimdilik diğer kaynak cezaları devre dışı
			print("📦 %s cezası şimdilik devre dışı: %d" % [penalty_type, int_amount])
		"reputation", "stability_penalty":
			# Özel cezalar - şimdilik sadece log
			print("⚠️ %s cezası: %s" % [penalty_type, str(amount)])

# Yeni görev üret
func generate_new_mission() -> Mission:
	var mission = Mission.new()
	
	# Rastgele ID oluştur
	mission.id = "generated_%d" % Time.get_unix_time_from_system()
	
	# Rastgele görev türü
	var mission_types = Mission.MissionType.values()
	mission.mission_type = mission_types[randi() % mission_types.size()]
	
	# Rastgele zorluk
	var difficulties = Mission.Difficulty.values()
	mission.difficulty = difficulties[randi() % difficulties.size()]
	
	# Görev detaylarını oluştur
	_generate_mission_details(mission)
	
	# Görevi kaydet
	missions[mission.id] = mission
	
	return mission

# Görev detaylarını oluştur
func _generate_mission_details(mission: Mission):
	match mission.mission_type:
		Mission.MissionType.SAVAŞ:
			_generate_combat_mission(mission)
		Mission.MissionType.KEŞİF:
			_generate_exploration_mission(mission)
		Mission.MissionType.TİCARET:
			_generate_trade_mission(mission)
		Mission.MissionType.DİPLOMASİ:
			_generate_diplomacy_mission(mission)
		Mission.MissionType.İSTİHBARAT:
			_generate_intelligence_mission(mission)

# Savaş görevi oluştur
func _generate_combat_mission(mission: Mission):
	var combat_names = [
		"Bandi Kampını Temizle",
		"Ork Saldırısını Püskürt",
		"Korsan Gemisini Ele Geçir",
		"Ejder Yuvasını Keşfet",
		"Goblin Kalesini Fethet"
	]
	
	mission.name = combat_names[randi() % combat_names.size()]
	mission.description = "Düşman güçlerle savaş ve bölgeyi güvence altına al."
	mission.duration = 15.0 + (randf() * 10.0)  # 15-25 saniye
	mission.success_chance = 0.6 + (randf() * 0.3)  # 60-90%
	mission.required_cariye_level = 1 + randi() % 3  # 1-3 seviye
	mission.required_army_size = 10 + randi() % 20  # 10-30 asker
	mission.required_resources = {"gold": 100 + randi() % 200}
	mission.rewards = {"gold": 300 + randi() % 400, "wood": 50 + randi() % 100}
	mission.penalties = {"gold": -50 - randi() % 100, "cariye_injured": 1}
	mission.target_location = "Bilinmeyen Bölge"
	mission.distance = 1.0 + randf() * 2.0
	mission.risk_level = "Yüksek"

# Keşif görevi oluştur
func _generate_exploration_mission(mission: Mission):
	var exploration_names = [
		"Batı Ormanlarını Keşfet",
		"Kayıp Şehri Bul",
		"Gizli Mağarayı Araştır",
		"Eski Tapınağı Keşfet",
		"Bilinmeyen Adayı Keşfet"
	]
	
	mission.name = exploration_names[randi() % exploration_names.size()]
	mission.description = "Bilinmeyen bölgeleri keşfet ve yeni kaynaklar bul."
	mission.duration = 10.0 + (randf() * 8.0)  # 10-18 saniye
	mission.success_chance = 0.7 + (randf() * 0.2)  # 70-90%
	mission.required_cariye_level = 1 + randi() % 2  # 1-2 seviye
	mission.required_army_size = 5 + randi() % 10  # 5-15 asker
	mission.required_resources = {"gold": 50 + randi() % 100}
	mission.rewards = {"gold": 200 + randi() % 300, "wood": 30 + randi() % 70, "stone": 20 + randi() % 50}
	mission.penalties = {"gold": -25 - randi() % 50}
	mission.target_location = "Bilinmeyen Bölge"
	mission.distance = 0.5 + randf() * 1.5
	mission.risk_level = "Orta"

# Ticaret görevi oluştur
func _generate_trade_mission(mission: Mission):
	var trade_names = [
		"Komşu Şehirle Ticaret",
		"Değerli Malları Sat",
		"Ticaret Yolu Aç",
		"Pazar Yerini Kur",
		"Ticaret Anlaşması Yap"
	]
	
	mission.name = trade_names[randi() % trade_names.size()]
	mission.description = "Ticaret yaparak altın kazan ve ekonomiyi güçlendir."
	mission.duration = 8.0 + (randf() * 6.0)  # 8-14 saniye
	mission.success_chance = 0.8 + (randf() * 0.15)  # 80-95%
	mission.required_cariye_level = 1 + randi() % 2  # 1-2 seviye
	mission.required_army_size = 0  # Ticaret için asker gerekmez
	mission.required_resources = {"gold": 200 + randi() % 300}
	mission.rewards = {"gold": 400 + randi() % 600}
	mission.penalties = {"gold": -100 - randi() % 200}
	mission.target_location = "Ticaret Merkezi"
	mission.distance = 0.3 + randf() * 0.7
	mission.risk_level = "Düşük"

# Diplomasi görevi oluştur
func _generate_diplomacy_mission(mission: Mission):
	var diplomacy_names = [
		"Barış Anlaşması Yap",
		"İttifak Kur",
		"Elçi Gönder",
		"Anlaşmazlığı Çöz",
		"Ticaret Anlaşması İmzala"
	]
	
	mission.name = diplomacy_names[randi() % diplomacy_names.size()]
	mission.description = "Diplomatik ilişkiler kurarak barışı sağla."
	mission.duration = 12.0 + (randf() * 8.0)  # 12-20 saniye
	mission.success_chance = 0.65 + (randf() * 0.25)  # 65-90%
	mission.required_cariye_level = 2 + randi() % 2  # 2-3 seviye
	mission.required_army_size = 0  # Diplomasi için asker gerekmez
	mission.required_resources = {"gold": 150 + randi() % 250}
	mission.rewards = {"gold": 300 + randi() % 400, "food": 50 + randi() % 100}
	mission.penalties = {"gold": -75 - randi() % 125}
	mission.target_location = "Diplomatik Merkez"
	mission.distance = 0.4 + randf() * 0.6
	mission.risk_level = "Düşük"

# İstihbarat görevi oluştur
func _generate_intelligence_mission(mission: Mission):
	var intelligence_names = [
		"Düşman Planlarını Öğren",
		"Casus Ağı Kur",
		"Gizli Bilgi Topla",
		"Düşman Güçlerini Keşfet",
		"İçeriden Bilgi Al"
	]
	
	mission.name = intelligence_names[randi() % intelligence_names.size()]
	mission.description = "Gizli bilgi toplayarak düşman hakkında istihbarat elde et."
	mission.duration = 6.0 + (randf() * 4.0)  # 6-10 saniye
	mission.success_chance = 0.5 + (randf() * 0.3)  # 50-80%
	mission.required_cariye_level = 2 + randi() % 2  # 2-3 seviye
	mission.required_army_size = 0  # İstihbarat için asker gerekmez
	mission.required_resources = {"gold": 100 + randi() % 150}
	mission.rewards = {"gold": 250 + randi() % 350, "wood": 20 + randi() % 40}
	mission.penalties = {"gold": -50 - randi() % 100, "cariye_injured": 1}
	mission.target_location = "Düşman Bölgesi"
	mission.distance = 0.2 + randf() * 0.3
	mission.risk_level = "Yüksek"

# Görevleri yenile (eski görevleri yeni görevlerle değiştir) - YENİ VERSİYON AŞAĞIDA

# Görev rotasyonu değişkenleri (zaten yukarıda tanımlandı)


# Mevcut görevleri al
func get_available_missions() -> Array:
	var available = []
	for mission_id in missions:
		var mission = missions[mission_id]
		
		# Mission objesi mi yoksa Dictionary mi kontrol et
		var is_available = false
		if mission is Dictionary:
			# Dictionary görevleri için status kontrolü
			var status = mission.get("status", "")
			is_available = (status == "available" or status == "urgent" or status == "MEVCUT")
		else:
			# Mission objesi için normal kontrol
			if mission.status == Mission.Status.MEVCUT:
				is_available = true
		
		if is_available:
			# Önkoşulları kontrol et (Mission objeleri için)
			if not (mission is Dictionary) and mission.has_method("are_prerequisites_met"):
				if mission.are_prerequisites_met(completed_missions):
					available.append(mission)
				else:
					var mission_name = mission.name if mission.has("name") else mission_id
					print("🔒 Görev kilitli (önkoşul eksik): " + str(mission_name))
			else:
				# Dictionary görevleri için önkoşul kontrolü yapma, direkt ekle
				available.append(mission)
	return available

# Boşta cariyeleri al
func get_idle_concubines() -> Array:
	var idle = []
	for cariye_id in concubines:
		var cariye = concubines[cariye_id]
		if cariye.status == Concubine.Status.BOŞTA:
			idle.append(cariye)
	return idle

# Aktif görevleri al
func get_active_missions() -> Dictionary:
	return active_missions.duplicate()

# Tamamlanan görevleri al
func get_completed_missions() -> Array[String]:
	# Tamamlanan görev ID'lerini döndür
	return completed_missions

# --- GÖREV ZİNCİRİ YÖNETİMİ ---

# Görev zinciri oluştur
func create_mission_chain(chain_id: String, chain_name: String, chain_type: Mission.ChainType, chain_rewards: Dictionary = {}):
	mission_chains[chain_id] = {
		"name": chain_name,
		"type": chain_type,
		"rewards": chain_rewards,
		"missions": [],
		"completed": false
	}

# Görevi zincire ekle
func add_mission_to_chain(mission_id: String, chain_id: String, chain_order: int = 0):
	if mission_id in missions and chain_id in mission_chains:
		var mission = missions[mission_id]
		mission.chain_id = chain_id
		mission.chain_type = mission_chains[chain_id]["type"]
		mission.chain_order = chain_order
		mission_chains[chain_id]["missions"].append(mission_id)

# Görev önkoşullarını kontrol et
func check_mission_prerequisites(mission_id: String) -> bool:
	if mission_id not in missions:
		return false
	
	var mission = missions[mission_id]
	return mission.are_prerequisites_met(completed_missions)

# Görev tamamlandığında zincir kontrolü
func on_mission_completed(mission_id: String):
	if mission_id not in missions:
		return
	
	var mission = missions[mission_id]
	
	# Tamamlanan görevler listesine ekle
	if mission_id not in completed_missions:
		completed_missions.append(mission_id)
	
	# Zincirdeki görevlerin önkoşullarını kontrol et
	check_chain_prerequisites(mission.chain_id)
	
	# Bu görev tamamlandığında açılacak görevleri kontrol et
	check_unlocked_missions(mission_id)
	
	# Zincir tamamlandı mı kontrol et
	check_chain_completion(mission.chain_id)
	# Zincir ilerleme sinyali gönder
	if mission.chain_id != null and mission.chain_id != "":
		var prog := get_chain_progress(mission.chain_id)
		mission_chain_progressed.emit(mission.chain_id, prog)

# Zincir önkoşullarını kontrol et
func check_chain_prerequisites(chain_id: String):
	if chain_id == "" or chain_id not in mission_chains:
		return
	
	var chain = mission_chains[chain_id]
	for mission_id in chain["missions"]:
		if mission_id in missions:
			var mission = missions[mission_id]
			if mission.status == Mission.Status.MEVCUT:
				if mission.are_prerequisites_met(completed_missions):
					# Görev artık yapılabilir
					mission_unlocked.emit(mission_id)

# Açılacak görevleri kontrol et
func check_unlocked_missions(completed_mission_id: String):
	if completed_mission_id not in missions:
		return
	
	var mission = missions[completed_mission_id]
	var unlocked_missions = mission.get_unlocked_missions()
	
	for unlocked_id in unlocked_missions:
		if unlocked_id in missions:
			var unlocked_mission = missions[unlocked_id]
			if unlocked_mission.status == Mission.Status.MEVCUT:
				mission_unlocked.emit(unlocked_id)

# Zincir tamamlandı mı kontrol et
func check_chain_completion(chain_id: String):
	if chain_id == "" or chain_id not in mission_chains:
		return
	
	var chain = mission_chains[chain_id]
	if chain["completed"]:
		return
	
	# Zincirdeki tüm görevler tamamlandı mı?
	var all_completed = true
	for mission_id in chain["missions"]:
		if mission_id in missions:
			var mission = missions[mission_id]
			if mission.status != Mission.Status.TAMAMLANDI:
				all_completed = false
				break
	
	if all_completed:
		chain["completed"] = true
		mission_chain_completed.emit(chain_id, chain["rewards"])

# Zincir bilgilerini al
func get_chain_info(chain_id: String) -> Dictionary:
	if chain_id in mission_chains:
		return mission_chains[chain_id]
	return {}

# Zincirdeki görevleri al
func get_chain_missions(chain_id: String) -> Array:
	if chain_id not in mission_chains:
		return []
	
	var chain_missions = []
	for mission_id in mission_chains[chain_id]["missions"]:
		if mission_id in missions:
			chain_missions.append(missions[mission_id])
	
	return chain_missions

# Zincir ilerlemesini al
func get_chain_progress(chain_id: String) -> Dictionary:
	if chain_id not in mission_chains:
		return {"completed": 0, "total": 0, "percentage": 0.0}
	
	var chain = mission_chains[chain_id]
	var completed = 0
	var total = chain["missions"].size()
	
	for mission_id in chain["missions"]:
		if mission_id in missions:
			var mission = missions[mission_id]
			if mission.status == Mission.Status.TAMAMLANDI:
				completed += 1
	
	var percentage = (float(completed) / float(total)) * 100.0 if total > 0 else 0.0
	
	return {
		"completed": completed,
		"total": total,
		"percentage": percentage
	}

# Örnek görev zincirleri oluştur
func create_mission_chains():
	# 1. Kuzey Seferi Zinciri (Sıralı)
	create_mission_chain("kuzey_seferi", "Kuzey Seferi", Mission.ChainType.SEQUENTIAL, {
		"gold": 1000,
		"wood": 200,
		"stone": 100
	})
	
	# Kuzey Seferi görevlerini oluştur
	var kesif_gorevi = Mission.new()
	kesif_gorevi.id = "kuzey_kesif"
	kesif_gorevi.name = "Kuzey Bölgesini Keşfet"
	kesif_gorevi.description = "Kuzey bölgesini keşfet ve düşman güçlerini tespit et."
	kesif_gorevi.mission_type = Mission.MissionType.KEŞİF
	kesif_gorevi.difficulty = Mission.Difficulty.KOLAY
	kesif_gorevi.duration = 8.0
	kesif_gorevi.success_chance = 0.8
	kesif_gorevi.required_cariye_level = 1
	kesif_gorevi.rewards = {"gold": 150, "wood": 30}
	kesif_gorevi.unlocks_missions.clear()
	kesif_gorevi.unlocks_missions.append("kuzey_saldiri")
	missions[kesif_gorevi.id] = kesif_gorevi
	add_mission_to_chain(kesif_gorevi.id, "kuzey_seferi", 1)
	
	var saldiri_gorevi = Mission.new()
	saldiri_gorevi.id = "kuzey_saldiri"
	saldiri_gorevi.name = "Kuzey Köyüne Saldırı"
	saldiri_gorevi.description = "Keşif sonuçlarına göre kuzey köyüne saldırı düzenle."
	saldiri_gorevi.mission_type = Mission.MissionType.SAVAŞ
	saldiri_gorevi.difficulty = Mission.Difficulty.ORTA
	saldiri_gorevi.duration = 12.0
	saldiri_gorevi.success_chance = 0.6
	saldiri_gorevi.required_cariye_level = 2
	saldiri_gorevi.required_army_size = 5
	saldiri_gorevi.prerequisite_missions.clear()
	saldiri_gorevi.prerequisite_missions.append("kuzey_kesif")
	saldiri_gorevi.rewards = {"gold": 400, "wood": 80}
	saldiri_gorevi.unlocks_missions.clear()
	saldiri_gorevi.unlocks_missions.append("kuzey_kontrol")
	missions[saldiri_gorevi.id] = saldiri_gorevi
	add_mission_to_chain(saldiri_gorevi.id, "kuzey_seferi", 2)

	# 2. Barış Süreci Zinciri (Diplomasi odaklı)
	create_mission_chain("baris_sureci", "Barış Süreci", Mission.ChainType.SEQUENTIAL, {"gold": 400, "reputation": 10})

	var elci_gonder = Mission.new()
	elci_gonder.id = "elci_gonder"
	elci_gonder.name = "Elçi Gönder"
	elci_gonder.description = "Komşu yerleşime barış teklifini ilet."
	elci_gonder.mission_type = Mission.MissionType.DİPLOMASİ
	elci_gonder.difficulty = Mission.Difficulty.KOLAY
	elci_gonder.duration = 6.0
	elci_gonder.success_chance = 0.85
	elci_gonder.required_cariye_level = 1
	elci_gonder.rewards = {"gold": 60}
	missions[elci_gonder.id] = elci_gonder
	add_mission_to_chain(elci_gonder.id, "baris_sureci", 1)

	var baris_anlasmasi = Mission.new()
	baris_anlasmasi.id = "baris_anlasmasi"
	baris_anlasmasi.name = "Barış Anlaşması"
	baris_anlasmasi.description = "Şartları müzakere et ve anlaşmayı imzala."
	baris_anlasmasi.mission_type = Mission.MissionType.DİPLOMASİ
	baris_anlasmasi.difficulty = Mission.Difficulty.ORTA
	baris_anlasmasi.duration = 10.0
	baris_anlasmasi.success_chance = 0.65
	baris_anlasmasi.required_cariye_level = 2
	baris_anlasmasi.rewards = {"gold": 120}
	baris_anlasmasi.prerequisite_missions.clear()
	baris_anlasmasi.prerequisite_missions.append("elci_gonder")
	missions[baris_anlasmasi.id] = baris_anlasmasi
	add_mission_to_chain(baris_anlasmasi.id, "baris_sureci", 2)
	
	var kontrol_gorevi = Mission.new()
	kontrol_gorevi.id = "kuzey_kontrol"
	kontrol_gorevi.name = "Kuzey Bölgesini Kontrol Et"
	kontrol_gorevi.description = "Kuzey bölgesini tamamen kontrol altına al ve güvenliği sağla."
	kontrol_gorevi.mission_type = Mission.MissionType.BÜROKRASİ
	kontrol_gorevi.difficulty = Mission.Difficulty.ZOR
	kontrol_gorevi.duration = 15.0
	kontrol_gorevi.success_chance = 0.5
	kontrol_gorevi.required_cariye_level = 3
	kontrol_gorevi.prerequisite_missions.clear()
	kontrol_gorevi.prerequisite_missions.append("kuzey_saldiri")
	kontrol_gorevi.rewards = {"gold": 600, "wood": 120, "stone": 60}
	missions[kontrol_gorevi.id] = kontrol_gorevi
	add_mission_to_chain(kontrol_gorevi.id, "kuzey_seferi", 3)
	
	# 2. Ticaret Ağı Zinciri (Paralel)
	create_mission_chain("ticaret_agi", "Ticaret Ağı Kurma", Mission.ChainType.PARALLEL, {
		"gold": 800,
		"trade_bonus": 0.2
	})
	
	# Ticaret Ağı görevlerini oluştur
	var dogu_ticaret = Mission.new()
	dogu_ticaret.id = "dogu_ticaret"
	dogu_ticaret.name = "Doğu Köyü ile Ticaret"
	dogu_ticaret.description = "Doğudaki köy ile ticaret anlaşması yap."
	dogu_ticaret.mission_type = Mission.MissionType.TİCARET
	dogu_ticaret.difficulty = Mission.Difficulty.ORTA
	dogu_ticaret.duration = 10.0
	dogu_ticaret.success_chance = 0.7
	dogu_ticaret.required_cariye_level = 2
	dogu_ticaret.rewards = {"gold": 300, "trade_route": "east"}
	missions[dogu_ticaret.id] = dogu_ticaret
	add_mission_to_chain(dogu_ticaret.id, "ticaret_agi", 1)
	
	var bati_ticaret = Mission.new()
	bati_ticaret.id = "bati_ticaret"
	bati_ticaret.name = "Batı Köyü ile Ticaret"
	bati_ticaret.description = "Batıdaki köy ile ticaret anlaşması yap."
	bati_ticaret.mission_type = Mission.MissionType.TİCARET
	bati_ticaret.difficulty = Mission.Difficulty.ORTA
	bati_ticaret.duration = 10.0
	bati_ticaret.success_chance = 0.7
	bati_ticaret.required_cariye_level = 2
	bati_ticaret.rewards = {"gold": 300, "trade_route": "west"}
	missions[bati_ticaret.id] = bati_ticaret
	add_mission_to_chain(bati_ticaret.id, "ticaret_agi", 2)
	
	var guney_ticaret = Mission.new()
	guney_ticaret.id = "guney_ticaret"
	guney_ticaret.name = "Güney Köyü ile Ticaret"
	guney_ticaret.description = "Güneydeki köy ile ticaret anlaşması yap."
	guney_ticaret.mission_type = Mission.MissionType.TİCARET
	guney_ticaret.difficulty = Mission.Difficulty.ORTA
	guney_ticaret.duration = 10.0
	guney_ticaret.success_chance = 0.7
	guney_ticaret.required_cariye_level = 2
	guney_ticaret.rewards = {"gold": 300, "trade_route": "south"}
	missions[guney_ticaret.id] = guney_ticaret
	add_mission_to_chain(guney_ticaret.id, "ticaret_agi", 3)
	
	# 3. Seçimli Görev Zinciri
	create_mission_chain("savunma_secimi", "Savunma Stratejisi", Mission.ChainType.CHOICE, {
		"gold": 500,
		"defense_bonus": 0.3
	})
	
	# Seçimli görevler (sadece biri yapılabilir)
	var kale_yap = Mission.new()
	kale_yap.id = "kale_yap"
	kale_yap.name = "Kale İnşa Et"
	kale_yap.description = "Güçlü bir kale inşa ederek savunmayı güçlendir."
	kale_yap.mission_type = Mission.MissionType.BÜROKRASİ
	kale_yap.difficulty = Mission.Difficulty.ZOR
	kale_yap.duration = 20.0
	kale_yap.success_chance = 0.6
	kale_yap.required_cariye_level = 3
	kale_yap.required_resources = {"gold": 800, "wood": 400, "stone": 200}
	kale_yap.rewards = {"gold": 200, "building": "castle", "defense": 50}
	missions[kale_yap.id] = kale_yap
	add_mission_to_chain(kale_yap.id, "savunma_secimi", 1)
	
	var ittifak_yap = Mission.new()
	ittifak_yap.id = "ittifak_yap"
	ittifak_yap.name = "Savunma İttifakı"
	ittifak_yap.description = "Komşu köylerle savunma ittifakı kur."
	ittifak_yap.mission_type = Mission.MissionType.DİPLOMASİ
	ittifak_yap.difficulty = Mission.Difficulty.ZOR
	ittifak_yap.duration = 15.0
	ittifak_yap.success_chance = 0.5
	ittifak_yap.required_cariye_level = 3
	ittifak_yap.rewards = {"gold": 200, "alliance": "defense", "defense": 30}
	missions[ittifak_yap.id] = ittifak_yap
	add_mission_to_chain(ittifak_yap.id, "savunma_secimi", 2)
	
	print("🔗 Görev zincirleri oluşturuldu:")
	print("  - Kuzey Seferi (Sıralı): 3 görev")
	print("  - Ticaret Ağı (Paralel): 3 görev")
	print("  - Savunma Stratejisi (Seçimli): 2 görev")
	
	# Dinamik görev şablonlarını oluştur
	create_dynamic_mission_templates()
	
	# Başlangıç dünya olaylarını oluştur
	create_initial_world_events()

# --- DİNAMİK GÖREV ÜRETİMİ ---

# Dinamik görev şablonlarını oluştur
func create_dynamic_mission_templates():
	# Savaş görev şablonları
	dynamic_mission_templates["savas"] = {
		"names": [
			"{location} Saldırısı",
			"{enemy} ile Savaş",
			"{location} Kuşatması",
			"{enemy} Ordusunu Püskürt",
			"{location} Yağması"
		],
		"descriptions": [
			"{location} bölgesindeki {enemy} güçlerine saldırı düzenle.",
			"{enemy} ile savaşarak bölgeyi güvence altına al.",
			"{location} kalesini kuşat ve ele geçir.",
			"{enemy} ordusunun saldırısını püskürt.",
			"{location} köyünü yağmala ve ganimet topla."
		],
		"locations": ["Kuzey", "Güney", "Doğu", "Batı", "Merkez"],
		"enemies": ["Düşman", "Haydut", "Rakip", "İsyancı", "Yabancı"],
		"base_rewards": {"gold": 200, "wood": 50},
		"base_penalties": {"gold": -100, "cariye_injured": true},
		"difficulty_modifiers": {
			Mission.Difficulty.KOLAY: {"success_chance": 0.8, "duration": 8.0, "reward_multiplier": 0.7},
			Mission.Difficulty.ORTA: {"success_chance": 0.6, "duration": 12.0, "reward_multiplier": 1.0},
			Mission.Difficulty.ZOR: {"success_chance": 0.4, "duration": 18.0, "reward_multiplier": 1.5},
			Mission.Difficulty.EFSANEVİ: {"success_chance": 0.2, "duration": 25.0, "reward_multiplier": 2.0}
		}
	}
	
	# Keşif görev şablonları
	dynamic_mission_templates["kesif"] = {
		"names": [
			"{location} Keşfi",
			"{area} Bölgesini Araştır",
			"{location} Gizemini Çöz",
			"{area} Kaynaklarını Bul",
			"{location} Haritasını Çıkar"
		],
		"descriptions": [
			"{location} bölgesini keşfet ve bilinmeyen alanları araştır.",
			"{area} bölgesindeki kaynakları ve tehlikeleri tespit et.",
			"{location} gizemini çöz ve sırları ortaya çıkar.",
			"{area} bölgesindeki değerli kaynakları bul.",
			"{location} için detaylı harita çıkar."
		],
		"locations": ["Orman", "Dağ", "Çöl", "Göl", "Mağara"],
		"areas": ["Bilinmeyen", "Terk Edilmiş", "Tehlikeli", "Gizemli", "Efsanevi"],
		"base_rewards": {"gold": 150, "wood": 30, "stone": 20},
		"base_penalties": {"gold": -50},
		"difficulty_modifiers": {
			Mission.Difficulty.KOLAY: {"success_chance": 0.9, "duration": 6.0, "reward_multiplier": 0.8},
			Mission.Difficulty.ORTA: {"success_chance": 0.7, "duration": 10.0, "reward_multiplier": 1.0},
			Mission.Difficulty.ZOR: {"success_chance": 0.5, "duration": 15.0, "reward_multiplier": 1.3},
			Mission.Difficulty.EFSANEVİ: {"success_chance": 0.3, "duration": 20.0, "reward_multiplier": 1.8}
		}
	}
	
	# Ticaret görev şablonları
	dynamic_mission_templates["ticaret"] = {
		"names": [
			"{location} ile Ticaret",
			"{resource} Ticareti",
			"{location} Pazarı",
			"{resource} Anlaşması",
			"{location} Ticaret Yolu"
		],
		"descriptions": [
			"{location} ile karlı ticaret anlaşması yap.",
			"{resource} ticareti için anlaşma sağla.",
			"{location} pazarında ticaret yap.",
			"{resource} için uzun vadeli anlaşma imzala.",
			"{location} ile ticaret yolu kur."
		],
		"locations": ["Köy", "Şehir", "Kasaba", "Pazar", "Liman"],
		"resources": ["Altın", "Odun", "Taş", "Gıda", "Silah"],
		"base_rewards": {"gold": 300, "trade_bonus": 0.1},
		"base_penalties": {"gold": -75, "reputation": -5},
		"difficulty_modifiers": {
			Mission.Difficulty.KOLAY: {"success_chance": 0.8, "duration": 8.0, "reward_multiplier": 0.8},
			Mission.Difficulty.ORTA: {"success_chance": 0.6, "duration": 12.0, "reward_multiplier": 1.0},
			Mission.Difficulty.ZOR: {"success_chance": 0.4, "duration": 16.0, "reward_multiplier": 1.4},
			Mission.Difficulty.EFSANEVİ: {"success_chance": 0.2, "duration": 22.0, "reward_multiplier": 2.0}
		}
	}
	
	print("🎲 Dinamik görev şablonları oluşturuldu")

# Başlangıç dünya olaylarını oluştur
func create_initial_world_events():
	world_events = [
		{
			"id": "kuraklik",
			"name": "Kuraklık",
			"description": "Bölgede kuraklık başladı. Su kaynakları azalıyor.",
			"effect": "water_shortage",
			"duration": 60.0,
			"mission_modifiers": {"kesif": {"success_chance": -0.1, "duration": 2.0}}
		},
		{
			"id": "gocmenler",
			"name": "Göçmen Dalgası",
			"description": "Savaştan kaçan göçmenler bölgeye geliyor.",
			"effect": "population_increase",
			"duration": 45.0,
			"mission_modifiers": {"diplomasi": {"success_chance": 0.1, "rewards": {"gold": 50}}}
		},
		{
			"id": "kurt_surusu",
			"name": "Kurt Sürüsü",
			"description": "Tehlikeli kurt sürüsü bölgede dolaşıyor.",
			"effect": "danger_increase",
			"duration": 30.0,
			"mission_modifiers": {"kesif": {"success_chance": -0.2, "penalties": {"cariye_injured": true}}}
		}
	]
	
	print("🌍 Dünya olayları oluşturuldu")

# Başlangıç görevlerini sınırla
func limit_initial_missions():
	print("🔧 Başlangıç görevleri sınırlanıyor...")
	
	# TÜM görevleri kaldır (zincir görevleri dahil)
	var missions_to_remove = []
	for mission_id in missions:
		var mission = missions[mission_id]
		if mission.status == Mission.Status.MEVCUT:
			missions_to_remove.append(mission_id)
	
	# Tüm görevleri sil
	for mission_id in missions_to_remove:
		missions.erase(mission_id)
		print("🗑️ Başlangıç görevi kaldırıldı: " + mission_id)
	
	print("✅ Başlangıçta hiç görev yok - yavaş yavaş eklenecek")
	
	# İlk görevi 5 saniye sonra ekle
	await get_tree().create_timer(5.0).timeout
	add_first_mission()

# İlk görevi ekle
func add_first_mission():
	print("🎯 İlk görev ekleniyor...")
	
	# Basit bir keşif görevi oluştur
	var first_mission = Mission.new()
	first_mission.id = "ilk_kesif"
	first_mission.name = "Köy Çevresini Keşfet"
	first_mission.description = "Köyün çevresindeki bölgeyi keşfet ve kaynakları tespit et."
	first_mission.mission_type = Mission.MissionType.KEŞİF
	first_mission.difficulty = Mission.Difficulty.KOLAY
	first_mission.duration = 30.0
	first_mission.required_cariye_level = 1
	first_mission.required_army_size = 0
	first_mission.required_resources = {}
	first_mission.rewards = {"gold": 50, "experience": 20}
	first_mission.penalties = {"gold": -10}
	first_mission.status = Mission.Status.MEVCUT
	
	missions[first_mission.id] = first_mission
	print("✅ İlk görev eklendi: " + first_mission.name)
	
	# İkinci görevi 30 saniye sonra ekle
	await get_tree().create_timer(30.0).timeout
	add_second_mission()

# İkinci görevi ekle
func add_second_mission():
	print("🎯 İkinci görev ekleniyor...")
	
	# Zincir görevinin ilkini ekle
	var chain_mission = Mission.new()
	chain_mission.id = "kuzey_kesif_1"
	chain_mission.name = "Kuzey Bölgesini Keşfet"
	chain_mission.description = "Kuzey bölgesindeki gizemli yapıları keşfet."
	chain_mission.mission_type = Mission.MissionType.KEŞİF
	chain_mission.difficulty = Mission.Difficulty.ORTA
	chain_mission.duration = 45.0
	chain_mission.required_cariye_level = 2
	chain_mission.required_army_size = 5
	chain_mission.required_resources = {"food": 20}
	chain_mission.rewards = {"gold": 100, "experience": 50, "special_item": "Antik Harita"}
	chain_mission.penalties = {"gold": -25, "reputation": -5}
	chain_mission.status = Mission.Status.MEVCUT
	
	# Zincir bilgileri
	chain_mission.chain_id = "kuzey_kesif_chain"
	chain_mission.chain_type = Mission.ChainType.SEQUENTIAL
	chain_mission.chain_order = 1
	chain_mission.unlocks_missions.clear()
	chain_mission.unlocks_missions.append("kuzey_kesif_2")
	
	missions[chain_mission.id] = chain_mission
	print("✅ Zincir görevi eklendi: " + chain_mission.name)

# Dinamik görev oluştur
func create_dynamic_mission(mission_type: String, difficulty: Mission.Difficulty = Mission.Difficulty.ORTA) -> Mission:
	if mission_type not in dynamic_mission_templates:
		return null
	
	var template = dynamic_mission_templates[mission_type]
	var mission = Mission.new()
	
	# Benzersiz ID oluştur
	mission.id = "dynamic_" + mission_type + "_" + str(next_mission_id)
	next_mission_id += 1
	
	# Rastgele isim ve açıklama seç
	var name_template = template["names"][randi() % template["names"].size()]
	var desc_template = template["descriptions"][randi() % template["descriptions"].size()]
	
	# Şablon değişkenlerini doldur
	mission.name = fill_template(name_template, template)
	mission.description = fill_template(desc_template, template)
	
	# Görev türü
	match mission_type:
		"savas": mission.mission_type = Mission.MissionType.SAVAŞ
		"kesif": mission.mission_type = Mission.MissionType.KEŞİF
		"ticaret": mission.mission_type = Mission.MissionType.TİCARET
	
	# Zorluk ayarları
	mission.difficulty = difficulty
	var modifiers = template["difficulty_modifiers"][difficulty]
	mission.success_chance = modifiers["success_chance"]
	mission.duration = modifiers["duration"]
	
	# Dünya olaylarından etkilenme
	apply_world_event_modifiers(mission, mission_type)
	
	# Ödüller ve cezalar
	mission.rewards = calculate_rewards(template["base_rewards"], modifiers["reward_multiplier"])
	mission.penalties = template["base_penalties"].duplicate()
	
	# Gereksinimler
	mission.required_cariye_level = calculate_required_level(difficulty)
	mission.required_army_size = calculate_required_army(mission_type, difficulty)
	mission.required_resources = calculate_required_resources(mission_type, difficulty)
	
	# Hedef konum
	mission.target_location = template.get("locations", ["Bilinmeyen"])[randi() % template.get("locations", ["Bilinmeyen"]).size()]
	mission.distance = randf_range(1.0, 5.0)
	mission.risk_level = calculate_risk_level(difficulty, mission_type)
	
	return mission

# Şablon doldurma
func fill_template(template: String, template_data: Dictionary) -> String:
	var result = template
	
	# Konum değişkenleri
	if "locations" in template_data:
		var location = template_data["locations"][randi() % template_data["locations"].size()]
		result = result.replace("{location}", location)
	
	# Düşman/alan değişkenleri
	if "enemies" in template_data:
		var enemy = template_data["enemies"][randi() % template_data["enemies"].size()]
		result = result.replace("{enemy}", enemy)
	
	if "areas" in template_data:
		var area = template_data["areas"][randi() % template_data["areas"].size()]
		result = result.replace("{area}", area)
	
	if "resources" in template_data:
		var resource = template_data["resources"][randi() % template_data["resources"].size()]
		result = result.replace("{resource}", resource)
	
	return result

# Dünya olayı etkilerini uygula
func apply_world_event_modifiers(mission: Mission, mission_type: String):
	for event in world_events:
		if "mission_modifiers" in event and mission_type in event["mission_modifiers"]:
			var modifiers = event["mission_modifiers"][mission_type]
			
			if "success_chance" in modifiers:
				mission.success_chance += modifiers["success_chance"]
				mission.success_chance = clamp(mission.success_chance, 0.1, 0.95)
			
			if "duration" in modifiers:
				mission.duration += modifiers["duration"]
				mission.duration = max(5.0, mission.duration)
			
			if "rewards" in modifiers:
				for reward_type in modifiers["rewards"]:
					if reward_type in mission.rewards:
						mission.rewards[reward_type] += modifiers["rewards"][reward_type]
					else:
						mission.rewards[reward_type] = modifiers["rewards"][reward_type]
			
			if "penalties" in modifiers:
				for penalty_type in modifiers["penalties"]:
					mission.penalties[penalty_type] = modifiers["penalties"][penalty_type]

# Ödül hesaplama
func calculate_rewards(base_rewards: Dictionary, multiplier: float) -> Dictionary:
	var rewards = {}
	for reward_type in base_rewards:
		rewards[reward_type] = int(base_rewards[reward_type] * multiplier)
	return rewards

# Gerekli seviye hesaplama
func calculate_required_level(difficulty: Mission.Difficulty) -> int:
	match difficulty:
		Mission.Difficulty.KOLAY: return 1
		Mission.Difficulty.ORTA: return 2
		Mission.Difficulty.ZOR: return 3
		Mission.Difficulty.EFSANEVİ: return 4
		_: return 1

# Gerekli ordu hesaplama
func calculate_required_army(mission_type: String, difficulty: Mission.Difficulty) -> int:
	var base_army = 0
	match mission_type:
		"savas": base_army = 3
		"kesif": base_army = 0
		"ticaret": base_army = 1
	
	var difficulty_multiplier = 1
	match difficulty:
		Mission.Difficulty.KOLAY: difficulty_multiplier = 1
		Mission.Difficulty.ORTA: difficulty_multiplier = 2
		Mission.Difficulty.ZOR: difficulty_multiplier = 3
		Mission.Difficulty.EFSANEVİ: difficulty_multiplier = 4
	
	return base_army * difficulty_multiplier

# Gerekli kaynak hesaplama
func calculate_required_resources(mission_type: String, difficulty: Mission.Difficulty) -> Dictionary:
	var resources = {}
	
	match mission_type:
		"savas":
			resources["gold"] = 100
		"kesif":
			resources["gold"] = 50
		"ticaret":
			resources["gold"] = 75
	
	# Zorluk çarpanı
	var multiplier = 1
	match difficulty:
		Mission.Difficulty.KOLAY: multiplier = 1
		Mission.Difficulty.ORTA: multiplier = 2
		Mission.Difficulty.ZOR: multiplier = 3
		Mission.Difficulty.EFSANEVİ: multiplier = 4
	
	for resource in resources:
		resources[resource] *= multiplier
	
	return resources

# Risk seviyesi hesaplama
func calculate_risk_level(difficulty: Mission.Difficulty, mission_type: String) -> String:
	var risk_score = 0
	
	# Zorluk etkisi
	match difficulty:
		Mission.Difficulty.KOLAY: risk_score += 1
		Mission.Difficulty.ORTA: risk_score += 2
		Mission.Difficulty.ZOR: risk_score += 3
		Mission.Difficulty.EFSANEVİ: risk_score += 4
	
	# Görev türü etkisi
	match mission_type:
		"savas": risk_score += 2
		"kesif": risk_score += 1
		"ticaret": risk_score += 0
	
	# Dünya istikrarı etkisi
	risk_score += int((100 - world_stability) / 25)
	
	if risk_score <= 2:
		return "Düşük"
	elif risk_score <= 4:
		return "Orta"
	else:
		return "Yüksek"

# Rastgele dinamik görev oluştur
func generate_random_dynamic_mission() -> Mission:
	var mission_types = ["savas", "kesif", "ticaret"]
	var difficulties = [Mission.Difficulty.KOLAY, Mission.Difficulty.ORTA, Mission.Difficulty.ZOR]
	
	# Oyuncu seviyesine göre zorluk seçimi
	var available_difficulties = []
	var max_cariye_level = get_max_concubine_level()
	
	for diff in difficulties:
		if calculate_required_level(diff) <= max_cariye_level:
			available_difficulties.append(diff)
	
	if available_difficulties.is_empty():
		available_difficulties = [Mission.Difficulty.KOLAY]
	
	var selected_type = mission_types[randi() % mission_types.size()]
	var selected_difficulty = available_difficulties[randi() % available_difficulties.size()]
	
	return create_dynamic_mission(selected_type, selected_difficulty)

# En yüksek cariye seviyesini al
func get_max_concubine_level() -> int:
	var max_level = 1
	for cariye_id in concubines:
		var cariye = concubines[cariye_id]
		if cariye.level > max_level:
			max_level = cariye.level
	return max_level

# Görev rotasyonu - eski görevleri kaldır, yenilerini ekle
func refresh_missions():
	print("🔄 Görev rotasyonu başlıyor...")
	
	# Mevcut görevlerden bazılarını kaldır (sadece MEVCUT olanlar)
	var missions_to_remove = []
	for mission_id in missions:
		var mission = missions[mission_id]
		if mission.status == Mission.Status.MEVCUT and not mission.is_part_of_chain():
			missions_to_remove.append(mission_id)
	
	# %50 şansla görev kaldır
	for mission_id in missions_to_remove:
		if randf() < 0.5:
			missions.erase(mission_id)
	
	# Yeni dinamik görevler ekle
	var new_mission_count = randi_range(1, 3)
	for i in range(new_mission_count):
		var new_mission = generate_random_dynamic_mission()
		if new_mission:
			missions[new_mission.id] = new_mission
			print("✨ Yeni dinamik görev: " + new_mission.name)
	
	print("🔄 Görev rotasyonu tamamlandı")

# --- DÜNYA OLAYLARI YÖNETİMİ ---

# Dünya olayları timer'ı
var world_events_timer: float = 0.0
var world_events_interval: float = 120.0  # 2 dakikada bir dünya olayı kontrolü

# Dünya olaylarını güncelle
func update_world_events(delta: float):
	world_events_timer += delta
	if world_events_timer >= world_events_interval:
		world_events_timer = 0.0
		process_world_events()

# Dünya olaylarını işle
func process_world_events():
	# Aktif olayları kontrol et
	var active_events = []
	for event in world_events:
		if "start_time" in event:
			var elapsed = Time.get_unix_time_from_system() - event["start_time"]
			if elapsed < event["duration"]:
				active_events.append(event)
			else:
				# Olay süresi doldu
				end_world_event(event)
	
	# Yeni olay başlatma şansı
	if randf() < 0.3:  # %30 şans
		start_random_world_event()
		# Olası ticaret etkisiyle birlikte yeni teklifler yenilenebilir
		refresh_trade_offers("world_event")

	# Koşullu nadir olaylar
	if world_stability < 35 and randf() < 0.25:
		_trigger_plague()
	if settlements.size() >= 2 and randf() < 0.2:
		_trigger_embargo_between_settlements()

func post_news(category: String, title: String, content: String, color: Color = Color.WHITE, subcategory: String = "info"):
	var tm = get_node_or_null("/root/TimeManager")
	var time_text = tm.get_time_string() if tm and tm.has_method("get_time_string") else "Şimdi"
	
	# Determine priority and visual emphasis based on subcategory
	var priority := 0
	var emphasis_color := color
	var emphasis_icon := ""
	
	match subcategory:
		"critical":
			priority = 3
			emphasis_color = Color(1.0, 0.3, 0.3)  # Bright red
			emphasis_icon = "🚨"
		"warning":
			priority = 2
			emphasis_color = Color(1.0, 0.7, 0.3)  # Orange
			emphasis_icon = "⚠️"
		"success":
			priority = 1
			emphasis_color = Color(0.3, 1.0, 0.3)  # Bright green
			emphasis_icon = "✅"
		"info":
			priority = 0
			emphasis_color = color
			emphasis_icon = "ℹ️"
	
	# Add icon to title if not already present
	var final_title := title
	if not title.begins_with(emphasis_icon):
		final_title = emphasis_icon + " " + title
	
	var news = {
		"id": _next_news_id,
		"category": category,
		"subcategory": subcategory,
		"title": final_title,
		"content": content,
		"time": time_text,
		"timestamp": int(Time.get_unix_time_from_system()),
		"color": emphasis_color,
		"original_color": color,
		"priority": priority,
		"read": false
	}
	_next_news_id += 1
	
	# Haberleri kuyruklara ekle
	var is_village = category in ["Başarı", "Bilgi"]
	if is_village:
		news_queue_village.push_front(news)
		# Kuyruk boyutunu sınırla (son 50 haber)
		if news_queue_village.size() > 50:
			news_queue_village = news_queue_village.slice(0, 50)
	else:
		news_queue_world.push_front(news)
		# Kuyruk boyutunu sınırla (son 50 haber)
		if news_queue_world.size() > 50:
			news_queue_world = news_queue_world.slice(0, 50)
	
	news_posted.emit(news)

# Haber kuyruklarını al (kopya döner, kaynak korunur)
func get_village_news(limit: int = 50) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count: int = min(limit, news_queue_village.size())
	for i in range(count):
		var entry: Dictionary = news_queue_village[i]
		result.append(entry.duplicate(true))
	return result

func get_world_news(limit: int = 50) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count: int = min(limit, news_queue_world.size())
	for i in range(count):
		var entry: Dictionary = news_queue_world[i]
		result.append(entry.duplicate(true))
	return result

func get_unread_counts() -> Dictionary:
	var v := 0
	var w := 0
	for n in news_queue_village:
		if not bool(n.get("read", false)):
			v += 1
	for n2 in news_queue_world:
		if not bool(n2.get("read", false)):
			w += 1
	return {"village": v, "world": w, "total": v + w}

func mark_all_news_read(scope: String = "all") -> void:
	if scope == "all" or scope == "village":
		for i in range(news_queue_village.size()):
			news_queue_village[i]["read"] = true
	if scope == "all" or scope == "world":
		for i in range(news_queue_world.size()):
			news_queue_world[i]["read"] = true

func mark_news_read(news_id: int) -> bool:
	for i in range(news_queue_village.size()):
		if int(news_queue_village[i].get("id", -1)) == news_id:
			news_queue_village[i]["read"] = true
			return true
	for j in range(news_queue_world.size()):
		if int(news_queue_world[j].get("id", -1)) == news_id:
			news_queue_world[j]["read"] = true
			return true
	return false

func _on_new_day(day: int):
	# Süresi dolan rate modifier'ları kaldır
	var remaining: Array[Dictionary] = []
	for m in active_rate_modifiers:
		if not m.has("expires_day") or m["expires_day"] >= day:
			remaining.append(m)
		else:
			post_news("Bilgi", "Etki Sona Erdi", "%s için %+d etki bitti" % [m.get("resource","?"), int(m.get("delta",0))], Color(0.8,0.8,0.8))
	active_rate_modifiers = remaining

	# Ticaret anlaşmalarını uygula (günlük peşin ödeme ve modlar)
	var kept: Array[Dictionary] = []
	for ta in trade_agreements:
		var daily_gold = int(ta.get("daily_gold", 0))
		if daily_gold > 0:
			var gpd = get_node_or_null("/root/GlobalPlayerData")
			if gpd and gpd.has_method("add_gold"):
				gpd.add_gold(-daily_gold)
		# Modifiers uygula (sonsuz için expires_day yok; süreliyse day+remaining_days)
		var mods: Dictionary = ta.get("modifiers", {})
		for res in mods.keys():
			var delta = int(mods[res])
			# Günlük etki: sadece bugünün sonunda sona ersin
			var expires_day = day
			active_rate_modifiers.append({"resource": res, "delta": delta, "expires_day": expires_day, "source": ta.get("partner","ticaret")})
		# Gün sayısını azalt
		if ta.get("infinite", false):
			kept.append(ta)
		else:
			var rem = int(ta.get("remaining_days", 0)) - 1
			if rem > 0:
				ta["remaining_days"] = rem
				kept.append(ta)
			else:
				post_news("Bilgi", "Ticaret Bitti", "%s ile anlaşma sona erdi" % ta.get("partner","?"), Color(0.8,0.8,1))
	trade_agreements = kept

	# Yerleşim ticaret modları süresi dolanları temizle
	_clean_expired_settlement_modifiers(day)

	# Her gün yeni teklifler gelebilir
	refresh_trade_offers("day_tick")

	# İlişki ve istikrar değişimleri (küçük dalgalanmalar) + haberler
	for s in settlements:
		var drel = randi_range(-2, 2)
		s["relation"] = clamp(int(s["relation"]) + drel, 0, 100)
		var dstab = randi_range(-1, 1)
		s["stability"] = clamp(int(s.get("stability",70)) + dstab, 0, 100)
		if drel != 0:
			var txt = "%s ile ilişkiler %s%d" % [s.get("name","?"), ("+" if drel>0 else ""), drel]
			post_news("Bilgi", "Diplomasi Güncellemesi", txt, Color(0.9,0.9,1))

	# Olası çatışmaları simüle et ve görevlere yansıt
	_simulate_conflicts()

	# Ekonomik/diplomatik rastgele olaylar
	if randf() < 0.25:
		_trigger_trade_caravan()
	if world_stability < 45 and randf() < 0.35:
		_trigger_bandit_activity()
	if randf() < 0.18:
		_trigger_random_festival()

func _simulate_conflicts():
	if settlements.size() < 2:
		return
	# Olasılık: dünya istikrarı ve genel gerginliğe bağlı
	var instability: float = 1.0 - float(world_stability) / 100.0
	var chance: float = clamp(0.15 + instability * 0.35, 0.10, 0.50)
	if randf() > chance:
		return
	# Saldıran aday: istikrarı düşük ya da askeri gücü yüksek olan taraf
	var attacker: Dictionary = settlements[randi() % settlements.size()]
	for i in range(3):
		var cand: Dictionary = settlements[randi() % settlements.size()]
		var cand_score: int = int(60 - int(cand.get("stability", 50))) + int(cand.get("military", 30))
		var att_score: int = int(60 - int(attacker.get("stability", 50))) + int(attacker.get("military", 30))
		if cand_score > att_score:
			attacker = cand
	# Savunmacı: saldıranla ilişkisi daha kötü olanlardan biri
	var defender: Dictionary = settlements[randi() % settlements.size()]
	for i in range(4):
		var cand2: Dictionary = settlements[randi() % settlements.size()]
		if cand2 == attacker:
			continue
		if int(cand2.get("relation", 50)) < int(defender.get("relation", 50)):
			defender = cand2
	if attacker == defender:
		return
	# Şiddet seviyesi ve sonuç
	var roll: float = randf()
	var event_type: String = "skirmish" if roll < 0.6 else ("raid" if roll < 0.9 else "siege")
	var att_pow: int = int(attacker.get("military", 30)) + randi_range(-5, 10)
	var def_pow: int = int(defender.get("military", 30)) + randi_range(-5, 10)
	# Kuşatma/yağma daha yüksek etki
	if event_type == "siege":
		att_pow += 5
	elif event_type == "raid":
		att_pow += 2
	var attacker_wins: bool = att_pow >= def_pow
	# Kayıplar
	var base_att_loss: int = randi_range(1, 4)
	var base_def_loss: int = randi_range(2, 6)
	var mult: int = 2 if event_type == "siege" else (1 if event_type == "skirmish" else 1)
	var loss_att: int = base_att_loss * mult
	var loss_def: int = base_def_loss * mult
	if attacker_wins:
		attacker["military"] = max(5, int(attacker.get("military", 30)) - loss_att)
		defender["military"] = max(5, int(defender.get("military", 30)) - loss_def)
		attacker["relation"] = clamp(int(attacker.get("relation", 50)) - 3, 0, 100)
		defender["relation"] = clamp(int(defender.get("relation", 50)) - 6, 0, 100)
		defender["stability"] = clamp(int(defender.get("stability", 60)) - (2 if event_type != "skirmish" else 1), 10, 100)
	else:
		attacker["military"] = max(5, int(attacker.get("military", 30)) - loss_def)
		defender["military"] = max(5, int(defender.get("military", 30)) - loss_att)
		attacker["relation"] = clamp(int(attacker.get("relation", 50)) - 6, 0, 100)
		defender["relation"] = clamp(int(defender.get("relation", 50)) - 3, 0, 100)
		attacker["stability"] = clamp(int(attacker.get("stability", 60)) - 1, 10, 100)
	# Haberler
	var at_name: String = attacker.get("name", "?")
	var df_name: String = defender.get("name", "?")
	var kind_text: String = ("sınır çatışması" if event_type == "skirmish" else ("baskın" if event_type == "raid" else "kuşatma"))
	post_news("Uyarı", "⚔️ %s %s %s" % [at_name, kind_text, df_name], "%s %s üzerine harekete geçti." % [at_name, df_name], Color(1,0.85,0.8))
	var outcome: String = "%s üstün geldi" % at_name if attacker_wins else "%s saldırıyı püskürttü" % df_name
	var details: String = "Kayıplar - Saldıran:%d, Savunan:%d" % [loss_att, loss_def]
	post_news("Dünya", "⚔️ Sonuç: %s" % outcome, "%s | Tür: %s" % [details, kind_text], Color(1,0.95,0.7))
	# Görev fırsatları ve ticaret etkisi
	_create_conflict_missions(attacker, defender)
	if attacker_wins and randf() < 0.4:
		_add_settlement_trade_modifier(df_name, 1.25, 2, true, "conflict")
		refresh_trade_offers("conflict")

func _create_conflict_missions(attacker: Dictionary, defender: Dictionary):
	# Savunma görevi
	var defend = Mission.new()
	defend.id = "defend_%d" % Time.get_unix_time_from_system()
	defend.name = "Savunma Yardımı: %s" % defender.get("name","?")
	defend.description = "%s'nin saldırısına karşı %s'yi savun." % [attacker.get("name","?"), defender.get("name","?")]
	defend.mission_type = Mission.MissionType.SAVAŞ
	defend.difficulty = Mission.Difficulty.ORTA
	defend.duration = 12.0
	defend.success_chance = 0.6
	defend.required_cariye_level = 2
	defend.required_army_size = 4
	defend.required_resources = {"gold": 80}
	defend.rewards = {"gold": 250, "wood": 40}
	defend.penalties = {"gold": -40}
	defend.status = Mission.Status.MEVCUT
	missions[defend.id] = defend

	# Yağma görevi (fırsat)
	var raid = Mission.new()
	raid.id = "raid_%d" % (Time.get_unix_time_from_system() + 1)
	raid.name = "Yağma Fırsatı: %s" % defender.get("name","?")
	raid.description = "%s ve %s arasındaki kaostan faydalanarak kaynak yağmala." % [attacker.get("name","?"), defender.get("name","?")]
	raid.mission_type = Mission.MissionType.SAVAŞ
	raid.difficulty = Mission.Difficulty.KOLAY
	raid.duration = 8.0
	raid.success_chance = 0.7
	raid.required_cariye_level = 1
	raid.required_army_size = 3
	raid.required_resources = {"gold": 50}
	raid.rewards = {"gold": 180, "stone": 30}
	raid.penalties = {"gold": -30, "reputation": -5}
	raid.status = Mission.Status.MEVCUT
	missions[raid.id] = raid
	post_news("Bilgi", "Görev Fırsatı", "Savunma ve yağma görevleri listene eklendi", Color(0.8,1,0.8))

func cancel_trade_agreement_by_index(idx: int):
	if idx < 0 or idx >= trade_agreements.size():
		return
	var ta = trade_agreements[idx]
	post_news("Uyarı", "Ticaret İptal", "%s ile anlaşma iptal edildi" % ta.get("partner","?"), Color(1,0.8,0.8))
	trade_agreements.remove_at(idx)

# Rastgele dünya olayı başlat
func start_random_world_event():
	var available_events = []
	
	# Aktif olmayan olayları bul
	for event in world_events:
		if "start_time" not in event:
			available_events.append(event)
	
	if available_events.is_empty():
		return
	
	var selected_event = available_events[randi() % available_events.size()]
	selected_event["start_time"] = Time.get_unix_time_from_system()
	
	print("🌍 Dünya olayı başladı: " + selected_event["name"])
	print("   " + selected_event["description"])
	post_news("Uyarı", selected_event["name"], selected_event["description"], Color(1,0.8,0.8))

# Dünya olayını sonlandır
func end_world_event(event: Dictionary):
	print("🌍 Dünya olayı sona erdi: " + event["name"])
	event.erase("start_time")
	post_news("Bilgi", event["name"] + " Sona Erdi", "Etki bitti.", Color(0.8,0.8,0.8))

# Aktif dünya olaylarını al
func get_active_world_events() -> Array:
	var active = []
	for event in world_events:
		if "start_time" in event:
			var elapsed = Time.get_unix_time_from_system() - event["start_time"]
			if elapsed < event["duration"]:
				active.append(event)
	return active

func get_external_rate_delta(resource: String) -> int:
	var tm = get_node_or_null("/root/TimeManager")
	var day = tm.get_day() if tm and tm.has_method("get_day") else 0
	var sum := 0
	for m in active_rate_modifiers:
		if m.get("resource", "") != resource:
			continue
		var exp = int(m.get("expires_day", 0))
		if exp == 0 or exp >= day:
			sum += int(m.get("delta", 0))
	return sum

func _active_rate_add(resource: String, delta: int, days: int, source: String):
	var tm = get_node_or_null("/root/TimeManager")
	var day = tm.get_day() if tm and tm.has_method("get_day") else 0
	var expires = 0
	if days > 0:
		expires = day + days - 1
	active_rate_modifiers.append({"resource": resource, "delta": delta, "expires_day": expires, "source": source})
	var sign = "+" if delta >= 0 else ""
	post_news("Bilgi", "Üretim Etkisi", "%s için %s%d (kaynak: %s)" % [resource, sign, delta, source], Color(0.8,0.8,1))

func add_trade_agreement(partner: String, daily_gold: int, modifiers: Dictionary, days: int = 0, infinite: bool = false):
	var ta = {"partner": partner, "daily_gold": daily_gold, "modifiers": modifiers, "infinite": infinite}
	if not infinite:
		ta["remaining_days"] = max(1, days)
	trade_agreements.append(ta)
	var mods_text = ""
	for r in modifiers.keys():
		var d = int(modifiers[r])
		var s = "+" if d >= 0 else ""
		mods_text += "%s%s %s  " % [s, d, r]
	var title = "Ticaret Anlaşması"
	var content = "%s ile %sAltın/gün karşılığı: %s%s" % [partner, str(daily_gold), mods_text, (" (Süresiz)" if infinite else "")] 
	post_news("Başarı", title, content, Color(0.8,1,0.8))
	# Anlaşma yapıldıktan sonra teklifler değişebilir
	refresh_trade_offers("agreement_added")

func get_trade_offers() -> Array[Dictionary]:
	return available_trade_offers.duplicate(true)

# Haber→görev dönüştürme özelliği kaldırıldı

func refresh_trade_offers(reason: String = "manual"):
	# Yerleşimlere dayalı üretici: ilişki, zenginlik ve önyargılara göre teklifler
	var resources = ["food", "wood", "stone"]
	var new_offers: Array[Dictionary] = []
	if settlements.is_empty():
		create_settlements()
	var tm = get_node_or_null("/root/TimeManager")
	var day = tm.get_day() if tm and tm.has_method("get_day") else 0
	for s in settlements:
		# İlişki ve zenginliğe göre teklif sayısı ve koşullar
		var rel:int = int(s.get("relation", 50))
		var wealth:int = int(s.get("wealth", 50))
		var bias:Dictionary = s.get("biases", {})
		var num = 1
		if rel >= 70:
			num += 1
		if wealth >= 70:
			num += 1
		# Yerleşim ticaret modifikasyonu
		var partner_name = s.get("name","?")
		var mod = _get_trade_modifier_for_partner(partner_name, day)
		if mod.get("blocked", false):
			continue
		for i in range(num):
			var res = resources[randi() % resources.size()]
			# bias etkisi
			if randf() < 0.6:
				for k in bias.keys():
					if randf() < 0.5:
						res = k
						break
			var delta = clamp(int(bias.get(res, 1)) + randi_range(0,2), 1, 4)
			var base_price = 40 + randi() % 100
			# ilişki arttıkça indirim
			var price = int(base_price * (1.0 - (rel - 50) * 0.003))
			# Yerel modifikasyon: festival/embargo etkisi
			var mult: float = float(mod.get("trade_multiplier", 1.0))
			price = int(float(price) * mult)
			var days = randi_range(2,5)
			var infinite_flag = randf() < 0.2 and rel >= 65
			var offer = {"partner": s.get("name","?"), "daily_gold": max(10, price), "mods": {res: delta}, "days": days, "infinite": infinite_flag}
			new_offers.append(offer)
	available_trade_offers = new_offers
	trade_offers_updated.emit()
	post_news("Bilgi", "Yeni Ticaret Teklifleri", "%d yeni teklif geldi (%s)" % [available_trade_offers.size(), reason], Color(0.8,0.9,1))

# Yerleşim ticaret modunu getir
func _get_trade_modifier_for_partner(partner: String, day: int) -> Dictionary:
	for m in settlement_trade_modifiers:
		var exp = int(m.get("expires_day", 0))
		if m.get("partner", "") == partner:
			if exp == 0 or exp >= day:
				return m
	return {"trade_multiplier": 1.0, "blocked": false}

# Süresi dolan yerleşim ticaret modlarını temizle
func _clean_expired_settlement_modifiers(day: int) -> void:
	var kept: Array[Dictionary] = []
	for m in settlement_trade_modifiers:
		var exp = int(m.get("expires_day", 0))
		if exp == 0 or exp >= day:
			kept.append(m)
	settlement_trade_modifiers = kept

# Yerleşime ticaret modu ekle (indirim/ambargo)
func _add_settlement_trade_modifier(partner: String, trade_multiplier: float, days: int, blocked: bool, reason: String) -> void:
	var tm = get_node_or_null("/root/TimeManager")
	var day = tm.get_day() if tm and tm.has_method("get_day") else 0
	var exp = 0
	if days > 0:
		exp = day + days
	settlement_trade_modifiers.append({
		"partner": partner,
		"trade_multiplier": trade_multiplier,
		"blocked": blocked,
		"expires_day": exp,
		"reason": reason
	})
	var effect_text = "Ambargo" if blocked else ("İndirim x" + str(trade_multiplier))
	post_news("Bilgi", "Ticaret Modu (%s)" % partner, "%s: %s gün" % [effect_text, str(days)], Color(0.9,0.95,1))
	refresh_trade_offers(reason)

func create_settlements():
	# Basit başlangıç seti
	settlements = [
		{"id": "east_village", "name": "Doğu Köyü", "type": "village", "relation": 60, "wealth": 55, "stability": 65, "military": 20, "biases": {"food": 3}},
		{"id": "west_town", "name": "Batı Kasabası", "type": "town", "relation": 50, "wealth": 70, "stability": 60, "military": 35, "biases": {"wood": 2}},
		{"id": "south_city", "name": "Güney Şehri", "type": "city", "relation": 65, "wealth": 80, "stability": 75, "military": 50, "biases": {"stone": 2, "food": 1}},
		{"id": "north_fort", "name": "Kuzey Kalesi", "type": "fort", "relation": 45, "wealth": 45, "stability": 55, "military": 80, "biases": {"stone": 3}}
	]
	post_news("Bilgi", "Komşular Tanımlandı", "%d yerleşim keşfedildi" % settlements.size(), Color(0.8,1,0.8))
	# İlk karavan/teklif canlandırması için küçük bir olasılık
	if randf() < 0.5:
		_trigger_trade_caravan()

# --- ZENGİN OLAYLAR ---

func _trigger_trade_caravan() -> void:
	if settlements.is_empty():
		return
	var s = settlements[randi() % settlements.size()]
	var partner = s.get("name","?")
	post_news("Başarı", "Kervan Geldi", "%s'den ticaret kervanı köy yakınlarında." % partner, Color(0.8,1,0.8))
	# Geçici indirim etkisi ve yeni teklifler
	_add_settlement_trade_modifier(partner, 0.85, 3, false, "caravan")
	refresh_trade_offers("caravan")
	# Eskort görevi üret
	_create_escort_mission(partner)

func _trigger_bandit_activity() -> void:
	post_news("Uyarı", "Haydut Faaliyeti", "Yollarda haydutlar arttı. Ticaret riskli.", Color(1,0.8,0.8))
	# Üretim cezaları (1-2 gün)
	_active_rate_add("wood", -1, 2, "Haydut Faaliyeti")
	_active_rate_add("stone", -1, 2, "Haydut Faaliyeti")
	# Savunma/temizlik görevleri
	_create_bandit_missions()

func _trigger_random_festival() -> void:
	if settlements.is_empty():
		return
	var s = settlements[randi() % settlements.size()]
	var partner = s.get("name","?")
	post_news("Başarı", "Festival", "%s'de bereket festivali! Pazarlar canlandı." % partner, Color(1,0.95,0.6))
	# Ticarette indirim, gıdada küçük artı (2 gün)
	_add_settlement_trade_modifier(partner, 0.9, 2, false, "festival")
	_active_rate_add("food", 1, 2, "Festival")

func _trigger_plague() -> void:
	post_news("Uyarı", "Salgın", "Bölgede salgın yayıldı. Üretim düşüyor.", Color(1,0.6,0.6))
	_active_rate_add("food", -1, 3, "Salgın")
	_active_rate_add("wood", -1, 3, "Salgın")
	# Yardım (ilaç/ikmal) görevi
	_create_aid_mission()

func _trigger_embargo_between_settlements() -> void:
	if settlements.size() < 2:
		return
	var a = settlements[randi() % settlements.size()]
	var b = settlements[randi() % settlements.size()]
	if a == b:
		return
	var pa = a.get("name","?")
	var pb = b.get("name","?")
	post_news("Uyarı", "Ticaret Ambargosu", "%s ile %s arasında ticaret askıya alındı." % [pa, pb], Color(1,0.8,0.8))
	_add_settlement_trade_modifier(pa, 1.0, 3, true, "embargo")
	_add_settlement_trade_modifier(pb, 1.0, 3, true, "embargo")
	refresh_trade_offers("embargo")

# --- Olay kaynaklı görevler ---

func _create_escort_mission(partner: String) -> void:
	var m = Mission.new()
	m.id = "escort_%d" % Time.get_unix_time_from_system()
	m.name = "Kervanı Koru: %s" % partner
	m.description = "%s'den gelen kervanı güvenli şekilde pazara ulaştır." % partner
	m.mission_type = Mission.MissionType.SAVAŞ
	m.difficulty = Mission.Difficulty.ORTA
	m.duration = 10.0
	m.success_chance = 0.65
	m.required_cariye_level = 2
	m.required_army_size = 4
	m.required_resources = {"gold": 60}
	m.rewards = {"gold": 220, "wood": 30}
	m.penalties = {"gold": -40}
	m.status = Mission.Status.MEVCUT
	missions[m.id] = m
	post_news("Bilgi", "Görev: Kervan Eskortu", "Yeni görev listene eklendi.", Color(0.8,1,0.8))

func _create_bandit_missions() -> void:
	var clear = Mission.new()
	clear.id = "bandit_clear_%d" % Time.get_unix_time_from_system()
	clear.name = "Haydut Temizliği"
	clear.description = "Yollardaki haydutları temizle ve güvenliği sağla."
	clear.mission_type = Mission.MissionType.SAVAŞ
	clear.difficulty = Mission.Difficulty.ORTA
	clear.duration = 9.0
	clear.success_chance = 0.6
	clear.required_cariye_level = 2
	clear.required_army_size = 4
	clear.required_resources = {"gold": 50}
	clear.rewards = {"gold": 200, "stone": 20}
	clear.penalties = {"gold": -30}
	clear.status = Mission.Status.MEVCUT
	missions[clear.id] = clear

func _create_aid_mission() -> void:
	var aid = Mission.new()
	aid.id = "aid_%d" % Time.get_unix_time_from_system()
	aid.name = "Yardım Görevi"
	aid.description = "Salgından etkilenen bölgelere yardım ulaştır."
	aid.mission_type = Mission.MissionType.DİPLOMASİ
	aid.difficulty = Mission.Difficulty.ORTA
	aid.duration = 12.0
	aid.success_chance = 0.6
	aid.required_cariye_level = 2
	aid.required_army_size = 2
	aid.required_resources = {"gold": 70}
	aid.rewards = {"gold": 180, "reputation": 10}
	aid.penalties = {"gold": -40}
	aid.status = Mission.Status.MEVCUT
	missions[aid.id] = aid

# Oyuncu itibarını güncelle
func update_player_reputation(change: int):
	player_reputation += change
	player_reputation = clamp(player_reputation, 0, 100)
	#print("📊 Oyuncu itibarı: " + str(player_reputation))

# Dünya istikrarını güncelle
func update_world_stability(change: int):
	world_stability += change
	world_stability = clamp(world_stability, 0, 100)
	#print("🌍 Dünya istikrarı: " + str(world_stability))
	post_news("Bilgi", "İstikrar Değişti", "Yeni istikrar: %d" % world_stability, Color(0.8,1,0.8))

# Oyuncu seviyesine göre dinamik görev üretimi
func generate_level_appropriate_missions() -> Array:
	var generated_missions = []
	var max_level = get_max_concubine_level()
	
	# Seviyeye göre görev sayısı
	var mission_count = 2 + (max_level / 2)  # Seviye arttıkça daha fazla görev
	
	for i in range(mission_count):
		var mission = generate_random_dynamic_mission()
		if mission:
			generated_missions.append(mission)
	
	return generated_missions

# Özel durum görevleri (nadir görevler)
func generate_special_missions() -> Array:
	var special_missions = []
	
	# Oyuncu itibarı yüksekse özel görevler
	if player_reputation >= 80:
		var special_mission = create_special_mission("elite_contract")
		if special_mission:
			special_missions.append(special_mission)
	
	# Dünya istikrarı düşükse acil görevler
	if world_stability <= 30:
		var emergency_mission = create_special_mission("emergency_response")
		if emergency_mission:
			special_missions.append(emergency_mission)
	
	return special_missions

# Özel görev oluştur
func create_special_mission(special_type: String) -> Mission:
	var mission = Mission.new()
	
	match special_type:
		"elite_contract":
			mission.id = "special_elite_" + str(next_mission_id)
			mission.name = "Elit Sözleşme"
			mission.description = "Yüksek itibarınız sayesinde özel bir görev teklifi aldınız."
			mission.mission_type = Mission.MissionType.SAVAŞ
			mission.difficulty = Mission.Difficulty.EFSANEVİ
			mission.duration = 30.0
			mission.success_chance = 0.3
			mission.required_cariye_level = 4
			mission.required_army_size = 8
			mission.required_resources = {"gold": 500}
			mission.rewards = {"gold": 2000, "wood": 500, "stone": 200, "special_item": "elite_weapon"}
			mission.penalties = {"gold": -300, "reputation": -20}
			mission.target_location = "Elit Kalesi"
			mission.distance = 8.0
			mission.risk_level = "Yüksek"
		
		"emergency_response":
			mission.id = "special_emergency_" + str(next_mission_id)
			mission.name = "Acil Müdahale"
			mission.description = "Dünya istikrarı tehlikede! Hemen harekete geçin."
			mission.mission_type = Mission.MissionType.DİPLOMASİ
			mission.difficulty = Mission.Difficulty.ZOR
			mission.duration = 20.0
			mission.success_chance = 0.4
			mission.required_cariye_level = 3
			mission.required_army_size = 4
			mission.required_resources = {"gold": 200}
			mission.rewards = {"gold": 800, "stability_bonus": 20, "reputation": 15}
			mission.penalties = {"gold": -150, "stability_penalty": -10}
			mission.target_location = "Kriz Merkezi"
			mission.distance = 3.0
			mission.risk_level = "Orta"
	
	next_mission_id += 1
	return mission

# === Combat System Integration ===
func _setup_combat_system() -> void:
	"""Setup combat system integration"""
	var cr = get_node_or_null("/root/CombatResolver")
	if cr:
		# Connect combat signals
		cr.connect("battle_resolved", Callable(self, "_on_battle_resolved"))
		cr.connect("unit_losses", Callable(self, "_on_unit_losses"))
		cr.connect("equipment_consumed", Callable(self, "_on_equipment_consumed"))

func create_raid_mission(target_settlement: String, day: int = 0, difficulty: String = "medium") -> Dictionary:
	"""Create a raid mission against a settlement"""
	var mission_id := "raid_" + target_settlement + "_" + str(next_mission_id)
	var mission := {
		"id": mission_id,
		"type": "raid",
		"name": "Baskın: " + target_settlement,
		"description": target_settlement + " yerleşimine baskın düzenle",
		"target": target_settlement,
		"difficulty": difficulty,
		"duration": 15.0,
		"success_chance": 0.6,
		"required_army_size": 3,
		"required_resources": {"gold": 100, "weapon": 5, "armor": 3},
		"rewards": {"gold": 300, "equipment": {"weapon": 2, "armor": 1}},
		"penalties": {"gold": -50, "army_losses": 1},
		"status": "available",
		"day": day
	}
	
	missions[mission_id] = mission
	next_mission_id += 1
	
	# Post news about raid opportunity
	post_news("Görev", "Baskın Fırsatı", target_settlement + " yerleşimine baskın düzenleme fırsatı!", Color(1, 0.8, 0.8), "warning")
	
	print("⚔️ Baskın görevi oluşturuldu: %s (Gün: %d)" % [target_settlement, day])
	
	return mission

func create_defense_mission(attacker: String, day: int = 0) -> Dictionary:
	"""Create a defense mission against an attacker"""
	var mission_id := "defense_" + attacker + "_" + str(next_mission_id)
	var mission := {
		"id": mission_id,
		"type": "defense",
		"name": "Savunma: " + attacker,
		"description": attacker + " saldırısına karşı köyü savun",
		"attacker": attacker,
		"difficulty": "hard",
		"duration": 10.0,
		"success_chance": 0.7,
		"required_army_size": 4,
		"required_resources": {"gold": 50, "weapon": 3, "armor": 2},
		"rewards": {"gold": 200, "stability_bonus": 15, "reputation": 10},
		"penalties": {"gold": -100, "stability_penalty": -20, "army_losses": 2},
		"status": "urgent",
		"day": day
	}
	
	missions[mission_id] = mission
	next_mission_id += 1
	
	# Post urgent news about defense
	post_news("Acil", "Savunma Gerekli", attacker + " saldırısına karşı köyü savun!", Color(1, 0.3, 0.3), "critical")
	
	print("🛡️ Savunma görevi oluşturuldu: %s (Gün: %d)" % [attacker, day])
	
	return mission

func execute_battle_mission(mission_id: String, cariye_id: int) -> Dictionary:
	"""Execute a battle mission using CombatResolver"""
	var mission: Dictionary = missions.get(mission_id, {})
	if mission.is_empty():
		return {"error": "Mission not found"}
	
	var cr = get_node_or_null("/root/CombatResolver")
	if not cr:
		return {"error": "CombatResolver not available"}
	
	# Get player's military force
	var player_force := _get_player_military_force()
	
	# Get target force based on mission type
	var target_force := {}
	if mission.type == "raid":
		target_force = _get_settlement_defense_force(mission.target)
	elif mission.type == "defense":
		target_force = _get_attacker_force(mission.attacker)
	
	# Execute battle
	var battle_result := {}
	if mission.type == "raid":
		battle_result = cr.simulate_raid(player_force, target_force)
	elif mission.type == "defense":
		battle_result = cr.simulate_skirmish(target_force, player_force)
	
	# Process battle results
	_process_battle_results(mission, battle_result)
	
	return battle_result

func _find_barracks() -> Node:
	"""Kışla binasını bul"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm or not vm.village_scene_instance:
		return null
	
	var placed_buildings = vm.village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return null
	
	for building in placed_buildings.get_children():
		if building.has_method("get_military_force"): # Check for Barracks-specific method
			return building
	
	return null

func _get_player_military_force() -> Dictionary:
	"""Get player's current military force from Barracks"""
	# Kışla binasını bul
	var barracks = _find_barracks()
	if barracks and barracks.has_method("get_military_force"):
		return barracks.get_military_force()
	
	# Fallback: eski sistem
	return {
		"units": {"infantry": 5, "archers": 3, "cavalry": 2},
		"equipment": {"weapon": 10, "armor": 8},
		"supplies": {"bread": 20, "water": 15},
		"gold": 500
	}

# === Köy Savunması ve Saldırı Görevleri ===
# (Duplicate functions removed - using the ones defined earlier)

func _get_settlement_defense_force(settlement_name: String) -> Dictionary:
	"""Get defense force for a settlement"""
	# Find settlement in settlements array
	var settlement := {}
	for s in settlements:
		if s.get("name", "") == settlement_name:
			settlement = s
			break
	
	if settlement.is_empty():
		# Default defense force
		return {
			"units": {"infantry": 3, "archers": 2},
			"equipment": {"weapon": 5, "armor": 4},
			"supplies": {"bread": 10, "water": 8},
			"gold": 200
		}
	
	# Calculate defense force based on settlement stats
	var military := int(settlement.get("military", 50))
	var wealth := int(settlement.get("wealth", 50))
	
	var infantry := int(military / 20)
	var archers := int(military / 30)
	var cavalry := int(military / 40)
	
	return {
		"units": {"infantry": infantry, "archers": archers, "cavalry": cavalry},
		"equipment": {"weapon": int(wealth / 10), "armor": int(wealth / 15)},
		"supplies": {"bread": int(wealth / 5), "water": int(wealth / 8)},
		"gold": wealth
	}

func _get_attacker_force(attacker_name: String) -> Dictionary:
	"""Get attacker force for defense missions"""
	# Generate attacker force based on world stability
	var stability := world_stability
	var attacker_strength := int((100 - stability) / 10) + 2
	
	return {
		"units": {"infantry": attacker_strength, "archers": int(attacker_strength / 2)},
		"equipment": {"weapon": attacker_strength * 2, "armor": attacker_strength},
		"supplies": {"bread": attacker_strength * 3, "water": attacker_strength * 2},
		"gold": attacker_strength * 50
	}

func _process_battle_results(mission: Dictionary, battle_result: Dictionary) -> void:
	"""Process the results of a battle"""
	var victor: String = battle_result.get("victor", "defender")
	var attacker_losses: int = battle_result.get("attacker_losses", 0)
	var defender_losses: int = battle_result.get("defender_losses", 0)
	var gains: Dictionary = battle_result.get("gains", {})
	
	# Determine if player won
	var player_won := false
	if mission.type == "raid" and victor == "attacker":
		player_won = true
	elif mission.type == "defense" and victor == "defender":
		player_won = true
	
	# Apply results
	if player_won:
		# Apply gains
		var gold_gain := int(gains.get("gold", 0))
		if gold_gain > 0:
			GlobalPlayerData.add_gold(gold_gain)
		
		# Apply equipment gains
		var equipment_gains: Dictionary = gains.get("equipment", {})
		for equipment_type in equipment_gains:
			var amount := int(equipment_gains[equipment_type])
			# This would need integration with equipment storage system
			pass
		
		# Post success news
		var title: String = "Savaş Zaferi"
		var content: String = mission.name + " başarıyla tamamlandı! Kazanç: " + str(gold_gain) + " altın"
		post_news("Başarı", title, content, Color(0.3, 1.0, 0.3), "success")
		
		# Update world stability
		world_stability = min(100, world_stability + 5)
		
	else:
		# Apply losses
		var gold_loss := int(mission.get("penalties", {}).get("gold", 0))
		if gold_loss > 0:
			GlobalPlayerData.add_gold(-gold_loss)
		
		# Apply stability penalty
		var stability_penalty := int(mission.get("penalties", {}).get("stability_penalty", 0))
		if stability_penalty > 0:
			world_stability = max(0, world_stability - stability_penalty)
		
		# Post failure news
		var title: String = "Savaş Yenilgisi"
		var content: String = mission.name + " başarısız oldu. Kayıp: " + str(gold_loss) + " altın"
		post_news("Uyarı", title, content, Color(1.0, 0.3, 0.3), "critical")
		
		# Update world stability
		world_stability = max(0, world_stability - 10)
	
	# Emit battle completed signal
	battle_completed.emit(battle_result)

func _on_battle_resolved(attacker: Dictionary, defender: Dictionary, result: Dictionary) -> void:
	"""Handle battle resolution signal from CombatResolver"""
	# This can be used for additional processing
	pass

func _on_unit_losses(unit_type: String, losses: int) -> void:
	"""Handle unit losses signal from CombatResolver"""
	unit_losses_reported.emit(unit_type, losses)
	
	# Post news about losses
	if losses > 0:
		post_news("Uyarı", "Asker Kaybı", str(losses) + " " + unit_type + " kaybedildi", Color(1.0, 0.7, 0.3), "warning")

func _on_equipment_consumed(equipment_type: String, amount: int) -> void:
	"""Handle equipment consumption signal from CombatResolver"""
	# This would integrate with equipment storage system
	pass

# === Debug Functions for Testing ===
func debug_create_test_raid() -> Dictionary:
	"""Create a test raid mission for debugging"""
	var tm = get_node_or_null("/root/TimeManager")
	var current_day: int = tm.get_day() if tm and tm.has_method("get_day") else 1
	var test_mission := create_raid_mission("Test Yerleşimi", current_day, "medium")
	print("🔍 Test baskın görevi oluşturuldu: ", test_mission.id)
	return test_mission

func debug_create_test_defense() -> Dictionary:
	"""Create a test defense mission for debugging"""
	var tm = get_node_or_null("/root/TimeManager")
	var current_day: int = tm.get_day() if tm and tm.has_method("get_day") else 1
	var test_mission := create_defense_mission("Test Saldırgan", current_day)
	print("🔍 Test savunma görevi oluşturuldu: ", test_mission.id)
	return test_mission

func debug_execute_test_battle(mission_id: String) -> Dictionary:
	"""Execute a test battle for debugging"""
	print("🔍 Test savaş başlatılıyor: ", mission_id)
	var result := execute_battle_mission(mission_id, 1)  # Use cariye ID 1
	print("🔍 Savaş sonucu: ", result)
	return result

func debug_create_test_forces() -> Dictionary:
	"""Create test military forces for debugging"""
	var cr = get_node_or_null("/root/CombatResolver")
	if not cr:
		print("❌ CombatResolver bulunamadı!")
		return {}
	
	# Create test attacker force
	var attacker: Dictionary = cr.create_force(
		{"infantry": 5, "archers": 3, "cavalry": 2},
		{"weapon": 10, "armor": 8},
		{"bread": 20, "water": 15},
		500
	)
	
	# Create test defender force  
	var defender: Dictionary = cr.create_force(
		{"infantry": 4, "archers": 2, "cavalry": 1},
		{"weapon": 6, "armor": 5},
		{"bread": 12, "water": 10},
		300
	)
	
	print("🔍 Test kuvvetleri oluşturuldu:")
	print("  Saldırgan: ", attacker)
	print("  Savunan: ", defender)
	
	# Test battle
	var battle_result: Dictionary = cr.simulate_raid(attacker, defender)
	print("🔍 Test savaş sonucu: ", battle_result)
	
	return battle_result

func debug_show_combat_stats() -> void:
	"""Show current combat system stats"""
	var cr = get_node_or_null("/root/CombatResolver")
	if not cr:
		print("❌ CombatResolver bulunamadı!")
		return
	
	print("🔍 Savaş Sistemi İstatistikleri:")
	print("  Savaş sistemi aktif: ", cr.war_enabled)
	print("  Mevcut birlik türleri: ", cr.get_unit_types().keys())
	print("  Dünya istikrarı: ", world_stability)
	print("  Oyuncu itibarı: ", player_reputation)
	
	# Show player force
	var player_force := _get_player_military_force()
	print("  Oyuncu kuvveti: ", player_force)

func debug_run_full_combat_test() -> void:
	"""Run a complete combat system test"""
	print("🚀 === SAVAŞ SİSTEMİ TAM TEST BAŞLIYOR ===")
	
	# 1. Show initial stats
	debug_show_combat_stats()
	
	# 2. Create test forces and battle
	print("\n🔍 Test kuvvetleri oluşturuluyor...")
	debug_create_test_forces()
	
	# 3. Create and test raid mission
	print("\n🔍 Baskın görevi test ediliyor...")
	var raid_mission := debug_create_test_raid()
	debug_execute_test_battle(raid_mission.id)
	
	# 4. Create and test defense mission
	print("\n🔍 Savunma görevi test ediliyor...")
	var defense_mission := debug_create_test_defense()
	debug_execute_test_battle(defense_mission.id)
	
	# 5. Show final stats
	print("\n🔍 Test sonrası istatistikler:")
	debug_show_combat_stats()
	
	print("🚀 === SAVAŞ SİSTEMİ TAM TEST BİTTİ ===")

# --- CARİYE ROL YÖNETİMİ ---

# Cariye rolü ata
func set_concubine_role(cariye_id: int, role: Concubine.Role) -> bool:
	if not concubines.has(cariye_id):
		print("❌ Cariye bulunamadı: ", cariye_id)
		return false
	
	var cariye = concubines[cariye_id]
	
	# Eğer aynı rol zaten atanmışsa, değişiklik yok
	if cariye.role == role:
		return true
	
	# Eski rolü temizle (eğer varsa)
	if cariye.role != Concubine.Role.NONE:
		_clear_concubine_role(cariye_id)
	
	# Yeni rolü ata
	cariye.role = role
	print("✅ Cariye rolü atandı: %s -> %s" % [cariye.name, cariye.get_role_name()])
	
	# Rol atama sinyali gönder
	emit_signal("concubine_role_changed", cariye_id, role)
	
	return true

# Cariye rolünü al
func get_concubine_role(cariye_id: int) -> Concubine.Role:
	if not concubines.has(cariye_id):
		return Concubine.Role.NONE
	
	return concubines[cariye_id].role

# Cariye rolünü temizle
func clear_concubine_role(cariye_id: int) -> bool:
	return set_concubine_role(cariye_id, Concubine.Role.NONE)

# Özel rol temizleme (internal)
func _clear_concubine_role(cariye_id: int):
	var cariye = concubines[cariye_id]
	var old_role = cariye.role
	cariye.role = Concubine.Role.NONE
	print("🧹 Cariye rolü temizlendi: %s -> %s" % [cariye.name, cariye.get_role_name()])

# Belirli roldeki cariyeleri al
func get_concubines_by_role(role: Concubine.Role) -> Array[Concubine]:
	var result: Array[Concubine] = []
	
	for cariye in concubines.values():
		if cariye.role == role:
			result.append(cariye)
	
	return result

# Komutan cariyeleri al
func get_commander_concubines() -> Array[Concubine]:
	return get_concubines_by_role(Concubine.Role.KOMUTAN)

# Rol atama sinyali
signal concubine_role_changed(cariye_id: int, new_role: Concubine.Role)
