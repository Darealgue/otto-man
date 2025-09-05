extends Node

# Görev yöneticisi - autoload singleton

# Görevler ve cariyeler
var missions: Dictionary = {}
var concubines: Dictionary = {}
var active_missions: Dictionary = {}

# Görev ID sayaçları
var next_mission_id: int = 1
var next_concubine_id: int = 1

# Görev üretimi

# Sinyaller
signal mission_completed(cariye_id: int, mission_id: String, successful: bool, results: Dictionary)
signal mission_started(cariye_id: int, mission_id: String)
signal mission_cancelled(cariye_id: int, mission_id: String)
signal concubine_leveled_up(cariye_id: int, new_level: int)

func _ready():
	# Başlangıç görevleri ve cariyeler oluştur
	create_initial_missions()
	create_initial_concubines()

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
func assign_mission_to_concubine(cariye_id: int, mission_id: String) -> bool:
	if not concubines.has(cariye_id):
		return false
	
	if not missions.has(mission_id):
		return false
	
	var cariye = concubines[cariye_id]
	var mission = missions[mission_id]
	
	# Cariye görev alabilir mi?
	if not cariye.can_handle_mission(mission):
		return false
	
	# Görev başlat
	if mission.start_mission(cariye_id):
		cariye.start_mission(mission_id)
		active_missions[cariye_id] = mission_id
		
		mission_started.emit(cariye_id, mission_id)
		return true
	
	return false

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
			
			# Aktif görevlerden çıkar
			completed_missions.append(cariye_id)
			
			# Sinyal gönder
			mission_completed.emit(cariye_id, mission_id, successful, results)
	
	# Tamamlanan görevleri temizle
	for cariye_id in completed_missions:
		active_missions.erase(cariye_id)

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
func _apply_reward(reward_type: String, amount: int):
	match reward_type:
		"gold":
			var global_data = get_node_or_null("/root/GlobalPlayerData")
			if global_data:
				global_data.gold += amount
				print("💰 +%d altın kazandın!" % amount)
		"wood", "stone", "food":
			# Şimdilik diğer kaynak ödülleri devre dışı
			print("📦 %s ödülü şimdilik devre dışı: +%d" % [reward_type, amount])

# Ceza uygula
func _apply_penalty(penalty_type: String, amount: int):
	match penalty_type:
		"gold":
			var global_data = get_node_or_null("/root/GlobalPlayerData")
			if global_data:
				global_data.gold = max(0, global_data.gold + amount)  # amount negatif olacak
				print("💸 %d altın kaybettin!" % abs(amount))
		"wood", "stone", "food":
			# Şimdilik diğer kaynak cezaları devre dışı
			print("📦 %s cezası şimdilik devre dışı: %d" % [penalty_type, amount])

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

# Görevleri yenile (eski görevleri yeni görevlerle değiştir)
func refresh_missions():
	# Mevcut görevleri temizle
	var old_missions = []
	for mission_id in missions:
		var mission = missions[mission_id]
		if mission.status == Mission.Status.MEVCUT:
			old_missions.append(mission_id)
	
	# Eski görevleri sil
	for mission_id in old_missions:
		missions.erase(mission_id)
	
	# Yeni görevler oluştur
	var new_mission_count = 3 + randi() % 3  # 3-5 yeni görev
	for i in range(new_mission_count):
		generate_new_mission()
	
	print("🔄 %d yeni görev oluşturuldu!" % new_mission_count)

# Görev rotasyonu değişkenleri
var mission_rotation_timer: float = 0.0
var mission_rotation_interval: float = 30.0  # 30 saniyede bir kontrol et


# Mevcut görevleri al
func get_available_missions() -> Array:
	var available = []
	for mission_id in missions:
		var mission = missions[mission_id]
		if mission.status == Mission.Status.MEVCUT:
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
