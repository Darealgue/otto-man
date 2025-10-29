extends Resource
class_name Concubine

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
		add_experience(50)
		moral = min(max_moral, moral + 10)
	else:
		failed_missions.append(mission_id)
		# Başarısız görev moral cezası
		moral = max(0, moral - 20)
	
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
		return true  # Ciddi yaralanma
	
	return false  # Hafif yaralanma

# İyileşme
func heal(amount: int) -> bool:
	if status != Status.YARALI:
		return false
	
	health = min(max_health, health + amount)
	
	if health >= max_health * 0.8:  # %80 sağlığa ulaştığında iyileş
		status = Status.BOŞTA
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
