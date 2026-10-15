extends Resource
class_name Concubine

# <<< YENİ: Appearance Resource >>>
const VillagerAppearance = preload("res://village/scripts/VillagerAppearance.gd")

# Cariye durumları
enum Status { BOŞTA, GÖREVDE, YARALI, DİNLENİYOR, ESIR }

## Doğuştan özellikler: tamamen şansa bağlı, 0-3 tane, her biri özgün (birbirinin tersi yok).
## Kimlikten türetilir, kayıt alanı yoktur; sabittir ve değişmez. Bir cariye hiç iyi özellik
## alamayabilir, ya da hepsi kötü olabilir; beğenmezsen köyden yollanabilir.
## Tür: "good" artı, "mixed" çift taraflı, "bad" eksi (arayüz renklendirmesi için).
const TRAIT_KINDS := {
	"fast": "good",           # Fırtına Ayaklı: yolculuk süresi -%20
	"cunning": "good",        # Kurnaz: esir düşerse %40 kendi kaçar
	"beloved": "good",        # Sevilen Komutan: asker kaybı -%40
	"frugal": "good",         # Tutumlu: hediyenin dörtte biri geri döner
	"lucky": "good",          # Şanslı Yıldız: büyük başarı şansı artar
	"learner": "good",        # Çabuk Öğrenir: XP bonusu
	"silver_tongue": "good",  # Tatlı Dilli: köy ilişkisi kazancı +1
	"greedy": "mixed",        # Açgözlü: altın ödülü +%25, hediye %20 pahalı
	"reckless": "mixed",      # Atılgan: başarı +%8, felaket (esirlik) ihtimali x1.5
	"fragile": "bad",         # Kırılgan: yaraları x1.5 gün
	"nervous": "bad",           # Ürkek: başarısızlıkta morali daha çok düşer
	"stubborn": "bad",        # Dikbaşlı: morali düşükse göreve çıkmaz
	"grumbler": "bad",        # Dert Küpü: başarısızlıkta köy morali düşer
}
const TRAIT_IDS: Array[String] = [
	"fast", "cunning", "beloved", "frugal", "lucky", "learner", "silver_tongue",
	"greedy", "reckless", "fragile", "nervous", "stubborn", "grumbler",
]

# Cariye rolleri
## REMOVED_5: eskiden "Alım" rolüydü, kaldırıldı. Sıra numaraları kayıt/WorldManager sabitleriyle
## uyumlu kalsın diye yuva duruyor; yüklemede bu değer NONE'a çevrilir. Yeni rol ekleme: sona ekle.
enum Role { NONE, KOMUTAN, AJAN, DİPLOMAT, TÜCCAR, REMOVED_5, TIBBIYECI }

# Temel cariye bilgileri
@export var id: int
@export var name: String
@export var level: int = 1
@export var experience: int = 0
@export var max_experience: int = 100

## Gelişim: statlar kalktı. Her seviye atlayışta 1 puan kazanılır, oyuncu istediği role verir
## (rol başına en çok ROLE_POINT_CAP). Yalnız AKTİF rolün puanı sayılır; puan geri alınamaz.
const ROLE_POINT_CAP := 5
## Puan verilebilen roller (REMOVED_5 hariç).
const SPENDABLE_ROLES: Array[int] = [Role.KOMUTAN, Role.AJAN, Role.DİPLOMAT, Role.TÜCCAR, Role.TIBBIYECI]
## Her puanın görev başarı şansına katkısı (5 puanda +%20).
const SUCCESS_BONUS_PER_POINT := 0.04
## rol (int) -> verilmiş puan (0..ROLE_POINT_CAP)
var role_points: Dictionary = {}
## Seviye atlayarak kazanılmış, henüz verilmemiş puan
var unspent_points: int = 0

# Durum bilgileri
var status: Status = Status.BOŞTA
var current_mission_id: String = ""
## Dinçlik (0..STAMINA_MAX): her görev düşürür, köyde yemek yiyerek dolar (MissionManager).
## Eski sağlık ve moral tek değere indirildi; yaralanma ayrı (`injured_days_left`).
const STAMINA_MAX := 100
## Bunun altındaki cariye göreve çıkamaz.
const STAMINA_MIN_FOR_MISSION := 30
const STAMINA_COST_SUCCESS := 10
const STAMINA_COST_FAIL := 25
var stamina: int = STAMINA_MAX

# Rol bilgisi
var role: Role = Role.NONE
## Zindan kurtarma minigame leverage (hikâye zinciri kilidi)
var rescue_leverage: int = 0
## Yaralıyken kaç gün sonra iyileşir (0: eski sağlık tabanlı iyileşme)
var injured_days_left: int = 0
## Esirken tutulduğu hex ("q,r"); esir değilse boş
var captured_hex: String = ""

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

var _traits_cache: Array[String] = []
var _traits_cache_id: int = -2147483648


## Bu cariyenin özellikleri (0-3). Kimlikten deterministik türetilir: 0 tane %12, 1 tane %38,
## 2 tane %38, 3 tane %12; havuzdan tekrarsız çekilir. Hiçbir denge zorunluluğu yoktur.
func get_traits() -> Array[String]:
	if _traits_cache_id == id:
		return _traits_cache
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("traits_%d" % id)
	var roll: float = rng.randf()
	var count: int = 0
	if roll >= 0.12:
		count = 1
	if roll >= 0.50:
		count = 2
	if roll >= 0.88:
		count = 3
	var pool: Array[String] = TRAIT_IDS.duplicate()
	var picked: Array[String] = []
	for i in range(count):
		var idx: int = rng.randi_range(0, pool.size() - 1)
		picked.append(pool[idx])
		pool.remove_at(idx)
	_traits_cache = picked
	_traits_cache_id = id
	return _traits_cache


func has_trait(trait_id: String) -> bool:
	return get_traits().has(trait_id)


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
	# Her seviyede 1 gelişim puanı
	unspent_points += 1

	# Seviye atlayınca dinçlik tamamen dolar
	stamina = STAMINA_MAX

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
		stamina = max(0, stamina - STAMINA_COST_SUCCESS)
		
		# Üst üste başarı takibi
		if last_mission_successful:
			consecutive_successes += 1
		else:
			consecutive_successes = 1
		last_mission_successful = true
	else:
		failed_missions.append(mission_id)
		# Başarısız görev moral cezası
		stamina = max(0, stamina - STAMINA_COST_FAIL)
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
		"stamina": stamina
	}
	
	return results

# Yaralanma
func take_damage(amount: int) -> bool:
	stamina = max(0, stamina - amount)

	if stamina <= 0:
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
	
	stamina = min(STAMINA_MAX, stamina + amount)

	if stamina >= STAMINA_MAX * 0.8:
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
	
	stamina = min(STAMINA_MAX, stamina + 5)

	if stamina >= STAMINA_MAX:
		status = Status.BOŞTA
		return true
	
	return false

## Bir role verilmiş puan (0..ROLE_POINT_CAP).
func get_role_points(for_role: int) -> int:
	return int(role_points.get(for_role, 0))


## Aktif rolün puanı (rolsüzse 0).
func get_active_role_points() -> int:
	return get_role_points(int(role))


## Pasif etkilerin (WorldManager, kışla) kullandığı 0..100 ölçeği: rol 20, her puan +16.
## Puan vermek pasif etkiyi de büyütür; puansız rol yine de küçük bir etki verir.
func get_role_power(for_role: int) -> int:
	return 20 + 16 * get_role_points(for_role)


func can_spend_point(for_role: int) -> bool:
	return unspent_points > 0 and SPENDABLE_ROLES.has(for_role) and get_role_points(for_role) < ROLE_POINT_CAP


## Puan ver (geri alınamaz). true: verildi.
func spend_point(for_role: int) -> bool:
	if not can_spend_point(for_role):
		return false
	role_points[for_role] = get_role_points(for_role) + 1
	unspent_points -= 1
	return true

# Durum adı
func get_status_name() -> String:
	match status:
		Status.BOŞTA: return tr("concubine.status.idle")
		Status.GÖREVDE: return tr("concubine.status.on_mission")
		Status.YARALI: return tr("concubine.status.injured")
		Status.DİNLENİYOR: return tr("concubine.status.resting")
		Status.ESIR: return tr("concubine.status.captive")
		_: return tr("common.unknown")

# Rol adı
func get_role_name() -> String:
	match role:
		Role.NONE: return tr("concubine.role.none")
		Role.KOMUTAN: return tr("concubine.role.commander")
		Role.AJAN: return tr("concubine.role.agent")
		Role.DİPLOMAT: return tr("concubine.role.diplomat")
		Role.TÜCCAR: return tr("concubine.role.trader")
		Role.TIBBIYECI: return tr("concubine.role.medic")
		_: return tr("common.unknown")

# Görev uygunluğu kontrolü
func can_handle_mission(mission: Mission) -> bool:
	# Seviye kontrolü
	if level < mission.required_cariye_level:
		return false
	
	# Durum kontrolü
	if status != Status.BOŞTA:
		return false
	
	# Dinçlik kontrolü
	if stamina < STAMINA_MIN_FOR_MISSION:
		return false
	
	return true

# Görev başarı şansı hesapla
func calculate_mission_success_chance(mission: Mission) -> float:
	var base_chance = mission.success_chance
	
	# Gelişim bonusu: aktif rolün puanı (en çok 5 x %4 = %20). Seviyenin kendisi bonus vermez.
	var role_bonus = float(get_active_role_points()) * SUCCESS_BONUS_PER_POINT

	# Dinçlik bonusu: tok ve dinç +%5, bitkin -%5
	var stamina_bonus = (stamina - 50) * 0.001

	var final_chance = base_chance + role_bonus + stamina_bonus
	if has_trait("reckless"):
		final_chance += 0.08
	var vce := _get_village_card_effects()
	if vce:
		final_chance += vce.get_mission_success_bonus(int(mission.mission_type))
	return clamp(final_chance, 0.1, 0.98)  # Min %10, max %98

# Concubine bir Resource olduğu için get_node_or_null yok; Mission.gd'deki
# Engine.get_main_loop() paterniyle autoload'a erişilir.
func _get_village_card_effects() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("VillageCardEffects")
	return null

# Başarı kontrolü - tüm başarıları kontrol eder
func check_achievements():
	check_mission_achievements()
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
	var rp: Dictionary = {}
	for rk in role_points.keys():
		rp[str(int(rk))] = int(role_points[rk])
	dict["role_points"] = rp
	dict["unspent_points"] = unspent_points
	dict["status"] = int(status)
	dict["current_mission_id"] = current_mission_id
	dict["stamina"] = stamina
	dict["role"] = int(role)
	dict["rescue_leverage"] = rescue_leverage
	dict["injured_days_left"] = injured_days_left
	dict["captured_hex"] = captured_hex
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
	# Gelişim puanları. Eski kayıtlarda "skills" vardı: statlar silinir, her seviye
	# (seviye - 1) 1 boş puan olarak verilir.
	if dict.has("role_points") and dict["role_points"] is Dictionary:
		role_points = {}
		for rk in (dict["role_points"] as Dictionary).keys():
			var rid: int = int(rk)
			if SPENDABLE_ROLES.has(rid):
				role_points[rid] = clampi(int(dict["role_points"][rk]), 0, ROLE_POINT_CAP)
		unspent_points = maxi(0, int(dict.get("unspent_points", 0)))
	elif dict.has("skills"):
		role_points = {}
		unspent_points = maxi(0, int(dict.get("level", 1)) - 1)
	if dict.has("status"):
		status = dict["status"] as Status
	if dict.has("current_mission_id"):
		current_mission_id = dict["current_mission_id"]
	if dict.has("stamina"):
		stamina = clampi(int(dict["stamina"]), 0, STAMINA_MAX)
	elif dict.has("moral") or dict.has("health"):
		# Eski kayıt: sağlık ve moralin düşüğü, 100 üzerinden dinçlik olur.
		var mr: float = float(dict.get("moral", 100)) / maxf(1.0, float(dict.get("max_moral", 100)))
		var hr: float = float(dict.get("health", 100)) / maxf(1.0, float(dict.get("max_health", 100)))
		stamina = clampi(int(round(100.0 * minf(mr, hr))), 0, STAMINA_MAX)
	if dict.has("role"):
		role = dict["role"] as Role
		if int(role) == int(Role.REMOVED_5):
			role = Role.NONE  # kaldırılan Alım rolü
	if dict.has("rescue_leverage"):
		rescue_leverage = int(dict["rescue_leverage"])
	if dict.has("injured_days_left"):
		injured_days_left = int(dict["injured_days_left"])
	if dict.has("captured_hex"):
		captured_hex = String(dict["captured_hex"])
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
			else:
				printerr("[Concubine.from_dict] ⚠️ Cariye %d görünümü from_dict metodu yok!" % id)
				appearance = null
		else:
			printerr("[Concubine.from_dict] ⚠️ Cariye %d görünümü null veya Dictionary değil! Value: %s" % [id, str(dict["appearance"])])
			appearance = null
	else:
		printerr("[Concubine.from_dict] ⚠️ Cariye %d görünümü dict'te yok!" % id)
		appearance = null
