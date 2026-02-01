extends Resource
class_name Concubine

# <<< YENİ: Appearance Resource >>>
const VillagerAppearance = preload("res://village/scripts/VillagerAppearance.gd")

# Cariye durumları
enum Status { BOŞTA, GÖREVDE, YARALI, DİNLENİYOR }

# Cariye yetenekleri
enum Skill { SAVAŞ, DİPLOMASİ, TİCARET, BÜROKRASİ, KEŞİF }

# Cariye rolleri
enum Role { NONE, KOMUTAN, AJAN, DİPLOMAT, TÜCCAR }

# Temel cariye bilgileri
@export var id: int
@export var name: String
@export var level: int = 1
@export var experience: int = 0
@export var max_experience: int = 100

# Yetenekler (0-100 arası)
@export var skills: Dictionary = {
	Skill.SAVAŞ: 50,
	Skill.DİPLOMASİ: 50,
	Skill.TİCARET: 50,
	Skill.BÜROKRASİ: 50,
	Skill.KEŞİF: 50
}

# Durum bilgileri
var status: Status = Status.BOŞTA
var current_mission_id: String = ""
var health: int = 100
var max_health: int = 100
var moral: int = 100
var max_moral: int = 100

# Rol bilgisi
var role: Role = Role.NONE

# Görev geçmişi
var completed_missions: Array[String] = []
var failed_missions: Array[String] = []
var total_experience_gained: int = 0

# Özel başarılar
var special_achievements: Array[String] = []

# Başarı takibi için geçici değişkenler
var consecutive_successes: int = 0  # Üst üste başarılı görev sayısı
var last_mission_successful: bool = false  # Son görevin başarılı olup olmadığı

# <<< YENİ: Görünüm Bilgisi >>>
@export var appearance: VillagerAppearance = null
# <<< YENİ SONU >>>

func _init():
	# Varsayılan değerler
	id = randi()
	name = "İsimsiz Cariye"
	level = 1
	experience = 0
	max_experience = 100

# Deneyim ekle
func add_experience(amount: int) -> bool:
	experience += amount
	total_experience_gained += amount
	
	# Seviye atlama kontrolü
	var leveled_up = false
	while experience >= max_experience:
		experience -= max_experience
		level += 1
		max_experience = int(max_experience * 1.2)  # Her seviyede %20 artış
		leveled_up = true
		
		# Seviye atlama bonusları
		_apply_level_up_bonuses()
	
	return leveled_up

# Seviye atlama bonusları
func _apply_level_up_bonuses():
	# Her seviyede tüm yetenekler +1
	for skill in skills:
		skills[skill] = min(100, skills[skill] + 1)
	
	# Sağlık ve moral artışı
	max_health += 10
	max_moral += 10
	health = max_health
	moral = max_moral
	
	# Seviye başarılarını kontrol et
	check_level_achievements()

# Görev başlat
func start_mission(mission_id: String) -> bool:
	if status != Status.BOŞTA:
		return false
	
	status = Status.GÖREVDE
	current_mission_id = mission_id
	return true

# Görev tamamla
func complete_mission(successful: bool, mission_id: String) -> Dictionary:
	status = Status.BOŞTA
	current_mission_id = ""
	
	# Görev geçmişine ekle
	if successful:
		completed_missions.append(mission_id)
		# Başarılı görev deneyim bonusu
		var leveled_up = add_experience(50)
		moral = min(max_moral, moral + 10)
		
		# Üst üste başarı takibi
		if last_mission_successful:
			consecutive_successes += 1
		else:
			consecutive_successes = 1
		last_mission_successful = true
	else:
		failed_missions.append(mission_id)
		# Başarısız görev moral cezası
		moral = max(0, moral - 20)
		consecutive_successes = 0
		last_mission_successful = false
	
	# Başarı kontrolü yap
	check_achievements()
	
	var results = {
		"cariye_id": id,
		"cariye_name": name,
		"mission_id": mission_id,
		"successful": successful,
		"level": level,
		"experience": experience,
		"health": health,
		"moral": moral
	}
	
	return results

# Yaralanma
func take_damage(amount: int) -> bool:
	health = max(0, health - amount)
	
	if health <= 0:
		status = Status.YARALI
		# İlk yaralanma başarısı
		if not has_achievement("Hayatta Kalan"):
			add_achievement("🛡️ Hayatta Kalan", "İlk kez yaralandı ve hayatta kaldı")
		return true  # Ciddi yaralanma
	
	return false  # Hafif yaralanma

# İyileşme
func heal(amount: int) -> bool:
	if status != Status.YARALI:
		return false
	
	health = min(max_health, health + amount)
	
	if health >= max_health * 0.8:  # %80 sağlığa ulaştığında iyileş
		status = Status.BOŞTA
		# İyileşme başarısı
		if not has_achievement("İyileşen"):
			add_achievement("💚 İyileşen", "Yaralandıktan sonra tamamen iyileşti")
		return true
	
	return false

# Dinlenme
func rest() -> bool:
	if status != Status.DİNLENİYOR:
		return false
	
	# Dinlenme sırasında moral ve sağlık artışı
	moral = min(max_moral, moral + 5)
	health = min(max_health, health + 2)
	
	# Tam dinlenme
	if moral >= max_moral and health >= max_health:
		status = Status.BOŞTA
		return true
	
	return false

# Yetenek seviyesi al
func get_skill_level(skill: Skill) -> int:
	return skills.get(skill, 0)

# Yetenek adı
func get_skill_name(skill: Skill) -> String:
	match skill:
		Skill.SAVAŞ: return "Savaş"
		Skill.DİPLOMASİ: return "Diplomasi"
		Skill.TİCARET: return "Ticaret"
		Skill.BÜROKRASİ: return "Bürokrasi"
		Skill.KEŞİF: return "Keşif"
		_: return "Bilinmeyen"

# Durum adı
func get_status_name() -> String:
	match status:
		Status.BOŞTA: return "Boşta"
		Status.GÖREVDE: return "Görevde"
		Status.YARALI: return "Yaralı"
		Status.DİNLENİYOR: return "Dinleniyor"
		_: return "Bilinmeyen"

# Rol adı
func get_role_name() -> String:
	match role:
		Role.NONE: return "Rol Yok"
		Role.KOMUTAN: return "Komutan"
		Role.AJAN: return "Ajan"
		Role.DİPLOMAT: return "Diplomat"
		Role.TÜCCAR: return "Tüccar"
		_: return "Bilinmeyen"

# En yüksek yetenek
func get_best_skill() -> Skill:
	var best_skill = Skill.SAVAŞ
	var best_value = 0
	
	for skill in skills:
		if skills[skill] > best_value:
			best_value = skills[skill]
			best_skill = skill
	
	return best_skill

# Görev uygunluğu kontrolü
func can_handle_mission(mission: Mission) -> bool:
	# Seviye kontrolü
	if level < mission.required_cariye_level:
		return false
	
	# Durum kontrolü
	if status != Status.BOŞTA:
		return false
	
	# Sağlık kontrolü
	if health < max_health * 0.5:  # %50'den az sağlık
		return false
	
	# Moral kontrolü
	if moral < max_moral * 0.3:  # %30'dan az moral
		return false
	
	return true

# Görev başarı şansı hesapla
func calculate_mission_success_chance(mission: Mission) -> float:
	var base_chance = mission.success_chance
	
	# Yetenek bonusu
	var relevant_skill = Skill.SAVAŞ  # Varsayılan
	match mission.mission_type:
		Mission.MissionType.SAVAŞ: relevant_skill = Skill.SAVAŞ
		Mission.MissionType.DİPLOMASİ: relevant_skill = Skill.DİPLOMASİ
		Mission.MissionType.TİCARET: relevant_skill = Skill.TİCARET
		Mission.MissionType.BÜROKRASİ: relevant_skill = Skill.BÜROKRASİ
		Mission.MissionType.KEŞİF: relevant_skill = Skill.KEŞİF
	
	var skill_bonus = (get_skill_level(relevant_skill) - 50) * 0.002  # %0.2 per skill point
	
	# Seviye bonusu
	var level_bonus = (level - 1) * 0.05  # %5 per level
	
	# Moral bonusu
	var moral_bonus = (moral - 50) * 0.001  # %0.1 per moral point
	
	# Sağlık bonusu
	var health_bonus = (health - 50) * 0.001  # %0.1 per health point
	
	var final_chance = base_chance + skill_bonus + level_bonus + moral_bonus + health_bonus
	return clamp(final_chance, 0.1, 0.95)  # Min %10, max %95

# Başarı kontrolü - tüm başarıları kontrol eder
func check_achievements():
	check_mission_achievements()
	check_skill_achievements()
	check_statistics_achievements()

# Görev başarılarını kontrol et
func check_mission_achievements():
	var completed_count = completed_missions.size()
	
	# İlk görev
	if completed_count >= 1 and not has_achievement("İlk Görev"):
		add_achievement("🎯 İlk Görev", "İlk görevini başarıyla tamamladı")
	
	# Görev sayısı başarıları
	if completed_count >= 5 and not has_achievement("Görev Ustası"):
		add_achievement("⚔️ Görev Ustası", "5 görev başarıyla tamamlandı")
	if completed_count >= 10 and not has_achievement("Görev Efendisi"):
		add_achievement("👑 Görev Efendisi", "10 görev başarıyla tamamlandı")
	if completed_count >= 25 and not has_achievement("Görev Efsanesi"):
		add_achievement("🌟 Görev Efsanesi", "25 görev başarıyla tamamlandı")
	if completed_count >= 50 and not has_achievement("Görev Ustası Efsanesi"):
		add_achievement("💎 Görev Ustası Efsanesi", "50 görev başarıyla tamamlandı")
	
	# Üst üste başarı serileri
	if consecutive_successes >= 3 and not has_achievement("Üst Üste Başarı"):
		add_achievement("🔥 Üst Üste Başarı", "3 görev üst üste başarıyla tamamlandı")
	if consecutive_successes >= 5 and not has_achievement("Mükemmel Seri"):
		add_achievement("✨ Mükemmel Seri", "5 görev üst üste başarıyla tamamlandı")
	if consecutive_successes >= 10 and not has_achievement("Efsanevi Seri"):
		add_achievement("🏆 Efsanevi Seri", "10 görev üst üste başarıyla tamamlandı")
	
	# Başarı oranı başarıları
	var total_missions = completed_count + failed_missions.size()
	if total_missions >= 5:
		var success_rate = (float(completed_count) / float(total_missions)) * 100.0
		if success_rate >= 100.0 and not has_achievement("Mükemmel Oran"):
			add_achievement("💯 Mükemmel Oran", "En az 5 görevde %100 başarı oranı")

# Seviye başarılarını kontrol et
func check_level_achievements():
	if level >= 5 and not has_achievement("Seviye Atlama"):
		add_achievement("📈 Seviye Atlama", "5. seviyeye ulaşıldı")
	if level >= 10 and not has_achievement("Usta"):
		add_achievement("🎖️ Usta", "10. seviyeye ulaşıldı")
	if level >= 15 and not has_achievement("Efsane"):
		add_achievement("👑 Efsane", "15. seviyeye ulaşıldı")
	if level >= 20 and not has_achievement("Efsanevi Usta"):
		add_achievement("💫 Efsanevi Usta", "20. seviyeye ulaşıldı")
	
	# Seviye atlama ile yetenekler de artıyor, bu yüzden yetenek başarılarını da kontrol et
	check_skill_achievements()

# Yetenek başarılarını kontrol et
func check_skill_achievements():
	# Her yetenek için kontrol et
	for skill in skills:
		var skill_level = skills[skill]
		var skill_name = get_skill_name(skill)
		
		# 80+ yetenek başarıları
		if skill_level >= 80:
			var achievement_name = skill_name + " Ustası"
			if not has_achievement(achievement_name):
				var emoji = get_skill_emoji(skill)
				add_achievement(emoji + " " + achievement_name, skill_name + " yeteneği 80'e ulaştı")
		
		# 100 yetenek başarıları
		if skill_level >= 100:
			var achievement_name = skill_name + " Efsanesi"
			if not has_achievement(achievement_name):
				var emoji = get_skill_emoji(skill)
				add_achievement(emoji + " " + achievement_name, skill_name + " yeteneği mükemmelliğe ulaştı")

# Yetenek emoji'si
func get_skill_emoji(skill: Skill) -> String:
	match skill:
		Skill.SAVAŞ: return "⚔️"
		Skill.DİPLOMASİ: return "🤝"
		Skill.TİCARET: return "💰"
		Skill.BÜROKRASİ: return "📋"
		Skill.KEŞİF: return "🔍"
		_: return "⭐"

# İstatistik başarılarını kontrol et
func check_statistics_achievements():
	# Deneyim başarıları
	if total_experience_gained >= 1000 and not has_achievement("Deneyim Toplayıcı"):
		add_achievement("📚 Deneyim Toplayıcı", "1000 deneyim puanı toplandı")
	if total_experience_gained >= 5000 and not has_achievement("Deneyim Efendisi"):
		add_achievement("📖 Deneyim Efendisi", "5000 deneyim puanı toplandı")
	if total_experience_gained >= 10000 and not has_achievement("Deneyim Efsanesi"):
		add_achievement("📜 Deneyim Efsanesi", "10000 deneyim puanı toplandı")

# Başarı ekle (tekrar eklenmesini önler)
func add_achievement(achievement_name: String, achievement_description: String = ""):
	# Başarı zaten varsa ekleme
	if has_achievement(achievement_name):
		return
	
	# Sadece ismi ekle (açıklama opsiyonel)
	var full_achievement = achievement_name
	if achievement_description != "":
		full_achievement = achievement_name + " - " + achievement_description
	
	special_achievements.append(full_achievement)
	print("🏆 Başarı Kazanıldı: %s (%s)" % [achievement_name, name])

# Başarı kontrolü (isimle)
func has_achievement(achievement_name: String) -> bool:
	for achievement in special_achievements:
		# Başarı ismini kontrol et (açıklama olabilir)
		if achievement.begins_with(achievement_name) or achievement.contains(achievement_name):
			return true
	return false

# Save/Load için Dictionary'ye dönüştür
func to_dict() -> Dictionary:
	var dict: Dictionary = {}
	dict["id"] = id
	dict["name"] = name
	dict["level"] = level
	dict["experience"] = experience
	dict["max_experience"] = max_experience
	dict["skills"] = {}
	for skill in skills.keys():
		dict["skills"][int(skill)] = skills[skill]
	dict["status"] = int(status)
	dict["current_mission_id"] = current_mission_id
	dict["health"] = health
	dict["max_health"] = max_health
	dict["moral"] = moral
	dict["max_moral"] = max_moral
	dict["role"] = int(role)
	dict["completed_missions"] = completed_missions.duplicate()
	dict["failed_missions"] = failed_missions.duplicate()
	dict["total_experience_gained"] = total_experience_gained
	dict["special_achievements"] = special_achievements.duplicate()
	dict["consecutive_successes"] = consecutive_successes
	dict["last_mission_successful"] = last_mission_successful
	# Appearance'ı da kaydet (eğer varsa)
	if appearance != null:
		if appearance.has_method("to_dict"):
			var appearance_dict = appearance.to_dict()
			if appearance_dict != null and appearance_dict.size() > 0:
				dict["appearance"] = appearance_dict
				print("[Concubine.to_dict] ✅ Cariye %d görünümü kaydedildi (dict size: %d)" % [id, appearance_dict.size()])
			else:
				printerr("[Concubine.to_dict] ⚠️ Cariye %d görünümü to_dict() boş dict döndü!" % id)
				dict["appearance"] = null
		else:
			printerr("[Concubine.to_dict] ⚠️ Cariye %d görünümü to_dict() metodu yok!" % id)
			dict["appearance"] = null
	else:
		printerr("[Concubine.to_dict] ⚠️ Cariye %d görünümü null, kaydedilemiyor!" % id)
		dict["appearance"] = null
	return dict

# Dictionary'den yükle
func from_dict(dict: Dictionary) -> void:
	if dict.has("id"):
		# JSON'dan float (1.0) gelebilir; MissionManager int anahtar kullanıyor
		var raw_id = dict["id"]
		id = int(raw_id) if raw_id != null else 0
	if dict.has("name"):
		name = dict["name"]
	if dict.has("level"):
		level = dict["level"]
	if dict.has("experience"):
		experience = dict["experience"]
	if dict.has("max_experience"):
		max_experience = dict["max_experience"]
	if dict.has("skills"):
		skills = {}
		for skill_key in dict["skills"].keys():
			# Skill enum değerini al
			var skill_enum_value = int(skill_key)
			# Dictionary'de enum key olarak kullan
			skills[skill_enum_value] = dict["skills"][skill_key]
	if dict.has("status"):
		status = dict["status"] as Status
	if dict.has("current_mission_id"):
		current_mission_id = dict["current_mission_id"]
	if dict.has("health"):
		health = dict["health"]
	if dict.has("max_health"):
		max_health = dict["max_health"]
	if dict.has("moral"):
		moral = dict["moral"]
	if dict.has("max_moral"):
		max_moral = dict["max_moral"]
	if dict.has("role"):
		role = dict["role"] as Role
	if dict.has("completed_missions"):
		var loaded_completed = dict["completed_missions"]
		if loaded_completed is Array:
			completed_missions = []
			for item in loaded_completed:
				if item is String:
					completed_missions.append(item)
	if dict.has("failed_missions"):
		var loaded_failed = dict["failed_missions"]
		if loaded_failed is Array:
			failed_missions = []
			for item in loaded_failed:
				if item is String:
					failed_missions.append(item)
	if dict.has("total_experience_gained"):
		total_experience_gained = dict["total_experience_gained"]
	if dict.has("special_achievements"):
		var loaded_achievements = dict["special_achievements"]
		if loaded_achievements is Array:
			special_achievements = []
			for item in loaded_achievements:
				if item is String:
					special_achievements.append(item)
	if dict.has("consecutive_successes"):
		consecutive_successes = dict["consecutive_successes"]
	if dict.has("last_mission_successful"):
		last_mission_successful = dict["last_mission_successful"]
	# Appearance'ı yükle
	if dict.has("appearance"):
		if dict["appearance"] != null and dict["appearance"] is Dictionary:
			appearance = VillagerAppearance.new()
			if appearance.has_method("from_dict"):
				appearance.from_dict(dict["appearance"])
				print("[Concubine.from_dict] ✅ Cariye %d görünümü yüklendi" % id)
			else:
				printerr("[Concubine.from_dict] ⚠️ Cariye %d görünümü from_dict metodu yok!" % id)
				appearance = null
		else:
			printerr("[Concubine.from_dict] ⚠️ Cariye %d görünümü null veya Dictionary değil! Value: %s" % [id, str(dict["appearance"])])
			appearance = null
	else:
		printerr("[Concubine.from_dict] ⚠️ Cariye %d görünümü dict'te yok!" % id)
		appearance = null
