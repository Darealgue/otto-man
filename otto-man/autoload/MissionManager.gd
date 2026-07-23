extends Node

# Görev yöneticisi - autoload singleton

const VillagerAppearance = preload("res://village/scripts/VillagerAppearance.gd")

# Görevler ve cariyeler
var missions: Dictionary = {}
var concubines: Dictionary = {}
var active_missions: Dictionary = {}

# Görev zincirleri
var mission_chains: Dictionary = {}  # chain_id -> chain_info
var completed_missions: Array[String] = []  # Tamamlanan görev ID'leri

const RESCUE_CHAIN_ID := "rescue_onboarding"
const RESCUE_MISSION_IDS: Array[String] = [
	"rescue_chain_rest",
	"rescue_chain_intel",
	"rescue_chain_contribute",
]

var rescue_onboarding_started: bool = false
var rescue_onboarding_concubine_id: int = -1

## Rol imza görevi / kişisel hikâye zinciri durumu (save ile kalıcı)
var _role_chains_started: Dictionary = {}  # "cariye_id:role_int" -> true
var _story_chains_active: Dictionary = {}  # cariye_id -> true

# Görev ID sayaçları
var next_mission_id: int = 1
var next_concubine_id: int = 1

# Görev üretimi
var mission_rotation_timer: float = 0.0
var mission_rotation_interval: float = 30.0  # 30 saniyede bir görev rotasyonu
var _next_daily_dynamic_spawn_day: int = 2
const DAILY_DYNAMIC_SPAWN_CHANCE: float = 0.32
const DAILY_DYNAMIC_MAX_AVAILABLE: int = 2
const WORLD_NEWS_BASE_DAILY_CAP: int = 2
const WORLD_NEWS_MAX_DAILY_CAP: int = 10
const DAILY_WORLD_EVENT_SPAWN_CHANCE: float = 0.07
const DAILY_WORLD_EVENT_MIN_GAP_DAYS: int = 3

# Dinamik görev üretimi
var dynamic_mission_templates: Dictionary = {}
var world_events: Array[Dictionary] = []
var world_event_templates: Array[Dictionary] = []
var player_reputation: int = 50  # 0-100 arası
var world_stability: int = 70  # 0-100 arası

# Dünya haberleri ve oran modifikasyonları
# ESKİ SİSTEM KALDIRILDI: trade_agreements ve available_trade_offers artık kullanılmıyor
# YENİ SİSTEM: Aktif tüccarlar (köye gelen tüccarlar)
var active_traders: Array[Dictionary] = []  # [{id, name, origin_settlement, products:[{resource, price_per_unit}], arrives_day, leaves_day, relation_multiplier}]
var active_rate_modifiers: Array[Dictionary] = []  # [{resource, delta, expires_day, source}]
var _last_tick_day: int = 0
var _world_news_count_day: int = 0
var _world_news_count_day_id: int = -1
var _last_world_event_spawn_day: int = -9999
var settlements: Array[Dictionary] = []  # [{id, name, type, relation, wealth, stability, military, biases:{wood:int,stone:int,food:int}}]
var trade_routes: Array[Dictionary] = []  # [{from, to, products:[], distance, risk, active, relation}]
var mission_history: Array[Dictionary] = []  # En son gerçekleşen görev sonuçları (LIFO)

# Kaydetme/Yükleme (SaveManager profil alt klasörü)
const ROLES_FILE := "concubine_roles.json"


func _concubine_roles_base_dir() -> String:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_profile_data_directory"):
		return str(sm.get_profile_data_directory())
	return "user://otto-man-save/profile_1/"

# Faz 7 dengeleme sabitleri (kayıp etkileri)
const LOSS_RESOURCE_PCT := 0.08        # Kaynakların yüzde kaçı gider (8%)
const LOSS_GOLD_FLAT := 8              # Ek altın kaybı (köy ekonomisi ölçeği)
const LOSS_STABILITY_DELTA := 7        # Dünya istikrarı düşüşü
const LOSS_MORALE_DELTA := 10          # Köy morali düşüşü (varsa)
const LOSS_BUILDING_DAMAGE_CHANCE := 0.15  # Bir binanın hasar alma olasılığı
var settlement_trade_modifiers: Array[Dictionary] = [] # [{partner:String, trade_multiplier:float, blocked:bool, expires_day:int, reason:String}]
var bandit_activity_active: bool = false  # Bandit Activity event aktif mi?
var bandit_trade_multiplier: float = 1.0  # Ticaret çarpanı (bandit activity için)
var bandit_risk_level: int = 0  # Risk seviyesi artışı (0=LOW, 1=MEDIUM, 2=HIGH)

# Haber kuyrukları
var news_queue_village: Array[Dictionary] = []
var news_queue_world: Array[Dictionary] = []
var _next_news_id: int = 1
# Raid görevlerinde cariye+asker çıkışı: mission_id -> { mission_exit_x, assigned_soldier_worker_ids }
# Mission (Resource) set/get güvenilir olmadığı için burada tutuyoruz
var _raid_mission_extra: Dictionary = {}
var _world_map_returning_units: Dictionary = {}
const PLAYER_MAP_GOLD_REWARD_MULT: float = 0.35
const PLAYER_MAP_FAIL_HP_LOSS: float = 14.0
## Görev ekonomisi: 1 kaynak birimi ≈ 1 işçi-günü (VillageManager SECONDS_PER_RESOURCE_UNIT / gather).
## Ödüller birkaç işçi-günü değerinde; altın bina maliyetleriyle (10–100) uyumlu.
const MISSION_ECON_RESOURCE_BASE := 1

# Sinyaller
signal mission_completed(cariye_id: int, mission_id: String, successful: bool, results: Dictionary)
signal mission_started(cariye_id: int, mission_id: String)
signal mission_cancelled(cariye_id: int, mission_id: String)
signal concubine_leveled_up(cariye_id: int, new_level: int)
signal mission_chain_completed(chain_id: String, rewards: Dictionary)
signal mission_chain_progressed(chain_id: String, progress: Dictionary)
signal news_posted(news: Dictionary)
signal mission_unlocked(mission_id: String)
signal mission_list_changed()  # Yeni görev eklendiğinde (örn. Haydut Temizliği) UI yenilensin
signal active_traders_updated()  # Aktif tüccarlar değiştiğinde
signal battle_completed(battle_result: Dictionary)
signal unit_losses_reported(unit_type: String, losses: int)

func _ready():
	#print("🚀 ===== MISSIONMANAGER _READY BAŞLADI =====")
	_initialize()
	#print("🚀 ===== MISSIONMANAGER _READY BİTTİ =====")

func _initialize():
	#print("🚀 ===== MISSIONMANAGER _INITIALIZE BAŞLADI =====")
	
	# Random seed'i ayarla (her oyun başında farklı isimler için)
	randomize()
	
	# Haber kuyruklarını başlat
	news_queue_village = []
	news_queue_world = []
	#print("📰 Haber kuyrukları başlatıldı: village=", news_queue_village.size(), " world=", news_queue_world.size())
	
	# Aktif tüccarları başlat
	active_traders = []
	
	# Kullanılan isimleri sıfırla
	_used_names.clear()
	
	# Yüklenen cariyelerin isimlerini kullanılan listesine ekle (kurtarma vb.)
	for cariye in concubines.values():
		if cariye.name in CONCUBINE_NAMES and not cariye.name in _used_names:
			_used_names.append(cariye.name)
	
	# Kaydedilmiş roller varsa yükle
	_load_concubine_roles()
	
	# Dinamik görev şablonları + dünya olayları (placeholder görev yok)
	create_mission_chains()
	_purge_legacy_placeholder_missions()

	# Günlük tick başlangıcı
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		if tm.has_method("get_day"):
			_last_tick_day = tm.get_day()
		if tm.has_signal("time_advanced"):
			tm.connect("time_advanced", Callable(self, "_on_time_advanced"))

	# Yerleşimleri kur (icinde sync -> refresh; trade_routes bos ise kurulur)
	create_settlements()
	
	if not concubine_role_changed.is_connected(_on_concubine_role_assigned):
		concubine_role_changed.connect(_on_concubine_role_assigned)
	
	# Combat system integration
	_setup_combat_system()
	
	#print("🚀 ===== MISSIONMANAGER _INITIALIZE BİTTİ =====")


## Ana menüden yeni oyun: kayıt/yüklemeden kalan görevler, cariyeler, haberler vb.
func reset_for_new_game() -> void:
	news_queue_village.clear()
	news_queue_world.clear()
	_next_news_id = 1
	missions.clear()
	active_missions.clear()
	completed_missions.clear()
	concubines.clear()
	mission_chains.clear()
	dynamic_mission_templates.clear()
	next_mission_id = 1
	next_concubine_id = 1
	_used_names.clear()
	active_traders.clear()
	mission_history.clear()
	world_events.clear()
	world_event_templates.clear()
	active_rate_modifiers.clear()
	settlement_trade_modifiers.clear()
	trade_routes.clear()
	bandit_activity_active = false
	bandit_trade_multiplier = 1.0
	bandit_risk_level = 0
	player_reputation = 50
	world_stability = 70
	_world_map_returning_units.clear()
	_raid_mission_extra.clear()
	rescue_onboarding_started = false
	rescue_onboarding_concubine_id = -1
	_role_chains_started.clear()
	_story_chains_active.clear()
	_next_daily_dynamic_spawn_day = 2
	_last_tick_day = 0
	create_mission_chains()
	_purge_legacy_placeholder_missions()
	var tm := get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("get_day"):
		_last_tick_day = tm.get_day()
	create_settlements()
	mission_list_changed.emit()
	active_traders_updated.emit()


func _process(delta):
	# Oyun pause'da ise görev ilerlemesi durdur
	if get_tree().paused:
		return
	
	# Aktif görevleri kontrol et
	check_active_missions()
	
	# Eski saniyelik görev rotasyonu ekonomi enflasyonu yaratıyordu.
	# Spawn kontrolü artık sadece günlük tick'te (_on_new_day) yapılıyor.
	
	# Dünya olayları: yalnizca suresi dolanlari guncelle (yeni olay gunluk tick'te)
	_expire_world_events_only()
	
	# Günlük tick kontrolü
	var tm = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("get_day"):
		var d = tm.get_day()
		if d != _last_tick_day and d > 0:
			_last_tick_day = d
			_on_new_day(d)

const LEGACY_PLACEHOLDER_MISSION_IDS: Array[String] = [
	"savas_1", "kesif_1", "diplomasi_1",
	"ilk_kesif", "kuzey_kesif_1", "kuzey_kesif_2",
	"kuzey_kesif", "kuzey_saldiri", "kuzey_kontrol",
	"elci_gonder", "baris_anlasmasi",
	"dogu_ticaret", "bati_ticaret", "guney_ticaret",
	"kale_yap", "ittifak_yap",
]

const LEGACY_PLACEHOLDER_CHAIN_IDS: Array[String] = [
	"kuzey_seferi", "baris_sureci", "ticaret_agi", "savunma_secimi", "kuzey_kesif_chain",
]


func _purge_legacy_placeholder_missions() -> void:
	var removed: int = 0
	for mid in LEGACY_PLACEHOLDER_MISSION_IDS:
		if missions.erase(mid):
			removed += 1
	for cid in LEGACY_PLACEHOLDER_CHAIN_IDS:
		mission_chains.erase(cid)
	if removed > 0:
		mission_list_changed.emit()


# Cariye isim havuzu (Türkçe kadın isimleri)
const CONCUBINE_NAMES: Array[String] = [
	# Osmanlı dönemi cariye isimleri - Klasik ve geleneksel isimler
	"Ayşe", "Fatma", "Hatice", "Zeynep", "Emine", "Şerife", "Hanife", "Rukiye",
	"Gülsüm", "Havva", "Meryem", "Rabia", "Safiye", "Ümmügülsüm", "Zübeyde", "Şehrazat",
	"Leyla", "Mecnun", "Dilşad", "Gülşah", "Nigar", "Peri", "Şirin", "Tahire",
	"Azize", "Cemile", "Fadime", "Gülnar", "Hamide", "İclal", "Kadriye", "Latife",
	"Mihri", "Nazife", "Özlem", "Pakize", "Rahime", "Saniye", "Tevhide", "Ümran",
	"Vesile", "Yasemin", "Zehra", "Adile", "Behiye", "Cemile", "Dürdane", "Esma",
	"Feride", "Gülizar", "Hacer", "İffet", "Kamer", "Lütfiye", "Mihriban", "Naciye",
	"Özge", "Pembe", "Rana", "Safiye", "Tuba", "Ülkü", "Vildan", "Yeliz",
	"Zümrüt", "Arzu", "Banu", "Cemre", "Duygu", "Eda", "Fulya", "Gül"
]

# Kullanılan isimleri takip et (aynı ismin tekrar kullanılmasını önlemek için)
var _used_names: Array[String] = []

# Rastgele cariye oluştur
func create_random_concubine() -> Concubine:
	var cariye = Concubine.new()
	cariye.id = next_concubine_id
	next_concubine_id += 1
	
	# Rastgele isim seç (havuzdan, kullanılan isimleri atla)
	var available_names = CONCUBINE_NAMES.duplicate()
	# Kullanılan isimleri listeden çıkar
	for used_name in _used_names:
		var index = available_names.find(used_name)
		if index >= 0:
			available_names.remove_at(index)
	
	# Eğer tüm isimler kullanıldıysa, listeyi sıfırla
	if available_names.is_empty():
		available_names = CONCUBINE_NAMES.duplicate()
		_used_names.clear()
	
	# Rastgele bir isim seç
	var random_index = randi() % available_names.size()
	cariye.name = available_names[random_index]
	_used_names.append(cariye.name)
	
	# Rastgele seviye (1-3 arası)
	cariye.level = randi_range(1, 3)
	
	# Rastgele deneyim (seviyeye göre)
	if cariye.level == 1:
		cariye.experience = randi_range(0, 50)
	elif cariye.level == 2:
		cariye.experience = randi_range(0, 100)
	else:  # level 3
		cariye.experience = randi_range(0, 150)
	
	# Rastgele statlar oluştur
	# Her stat için 20-80 arası rastgele değer
	# Bir ana stat 60-90 arası olacak (uzmanlık alanı)
	var all_skills = [
		Concubine.Skill.SAVAŞ,
		Concubine.Skill.DİPLOMASİ,
		Concubine.Skill.TİCARET,
		Concubine.Skill.BÜROKRASİ,
		Concubine.Skill.KEŞİF
	]
	
	# Önce tüm statları 20-50 arası rastgele değerlerle başlat
	for skill in all_skills:
		cariye.skills[skill] = randi_range(20, 50)
	
	# Bir rastgele ana stat seç ve 60-90 arası yap (uzmanlık alanı)
	var main_skill = all_skills[randi() % all_skills.size()]
	cariye.skills[main_skill] = randi_range(60, 90)
	
	# İkinci bir statı da 50-70 arası yap (ikincil yetenek)
	var remaining_skills = all_skills.duplicate()
	remaining_skills.erase(main_skill)
	var secondary_skill = remaining_skills[randi() % remaining_skills.size()]
	cariye.skills[secondary_skill] = randi_range(50, 70)
	
	# Görünüm rastgele oluştur
	cariye.appearance = AppearanceDB.generate_random_concubine_appearance()
	
	return cariye

## Zindandan kurtarılan cariyeyi MissionManager'a ekler (köy sahnesinde spawn + save için).
## cariye_data: { isim, leverage?, appearance (VillagerAppearance veya dict) }
## Döndürür: yeni cariye id (VillageManager.add_cariye_with_id ile senkron için).
func add_concubine_from_rescue(cariye_data: Dictionary) -> int:
	var cariye = Concubine.new()
	cariye.id = next_concubine_id
	next_concubine_id += 1
	cariye.name = cariye_data.get("isim", "İsimsiz")
	cariye.level = 1
	cariye.experience = 0
	cariye.max_experience = 100
	var all_skills = [
		Concubine.Skill.SAVAŞ,
		Concubine.Skill.DİPLOMASİ,
		Concubine.Skill.TİCARET,
		Concubine.Skill.BÜROKRASİ,
		Concubine.Skill.KEŞİF
	]
	for skill in all_skills:
		cariye.skills[skill] = 50
	if cariye_data.has("appearance"):
		var app = cariye_data["appearance"]
		if app is Dictionary and app.size() > 0:
			cariye.appearance = VillagerAppearance.new()
			if cariye.appearance.has_method("from_dict"):
				cariye.appearance.from_dict(app)
		elif is_instance_of(app, VillagerAppearance):
			cariye.appearance = app
	if cariye.appearance == null:
		cariye.appearance = AppearanceDB.generate_random_concubine_appearance()
	cariye.rescue_leverage = int(cariye_data.get("leverage", 5))
	if cariye.name in CONCUBINE_NAMES and not cariye.name in _used_names:
		_used_names.append(cariye.name)
	concubines[cariye.id] = cariye
	return cariye.id


## İlk kurtarılan cariye için 3 adımlık onboarding görev zincirini açar.
func setup_rescue_onboarding_chain(cariye_id: int, cariye_name: String) -> void:
	if rescue_onboarding_started:
		return
	if not concubines.has(cariye_id):
		return
	rescue_onboarding_started = true
	rescue_onboarding_concubine_id = cariye_id
	_create_rescue_onboarding_chain(cariye_id, cariye_name.strip_edges())


func _create_rescue_onboarding_chain(cariye_id: int, cariye_name: String) -> void:
	if missions.has(RESCUE_MISSION_IDS[0]):
		return
	var display_name := cariye_name if not cariye_name.is_empty() else tr("cariye.unknown")
	create_mission_chain(
		RESCUE_CHAIN_ID,
		tr("mission.rescue_chain.chain_name"),
		Mission.ChainType.SEQUENTIAL,
		{"gold": 25, "reputation": 5, "world_stability": 5}
	)
	var m1 := _build_rescue_chain_mission(
		RESCUE_MISSION_IDS[0],
		tr("mission.rescue_chain.1.name") % display_name,
		tr("mission.rescue_chain.1.desc"),
		Mission.MissionType.BÜROKRASİ,
		60.0,
		0.92,
		cariye_id,
		[],
		{"gold": 8}
	)
	var m2 := _build_rescue_chain_mission(
		RESCUE_MISSION_IDS[1],
		tr("mission.rescue_chain.2.name") % display_name,
		tr("mission.rescue_chain.2.desc"),
		Mission.MissionType.KEŞİF,
		120.0,
		0.82,
		cariye_id,
		[RESCUE_MISSION_IDS[0]],
		{"gold": 14}
	)
	var m3 := _build_rescue_chain_mission(
		RESCUE_MISSION_IDS[2],
		tr("mission.rescue_chain.3.name") % display_name,
		tr("mission.rescue_chain.3.desc"),
		Mission.MissionType.DİPLOMASİ,
		150.0,
		0.76,
		cariye_id,
		[RESCUE_MISSION_IDS[1]],
		{"gold": 20}
	)
	missions[m1.id] = m1
	missions[m2.id] = m2
	missions[m3.id] = m3
	add_mission_to_chain(m1.id, RESCUE_CHAIN_ID, 0)
	add_mission_to_chain(m2.id, RESCUE_CHAIN_ID, 1)
	add_mission_to_chain(m3.id, RESCUE_CHAIN_ID, 2)
	m1.unlocks_missions = [RESCUE_MISSION_IDS[1]]
	m2.unlocks_missions = [RESCUE_MISSION_IDS[2]]
	post_news(
		"village",
		tr("news.rescue_chain.start.title") % display_name,
		tr("news.rescue_chain.start.body"),
		Color(1.0, 0.88, 0.95),
		"info"
	)
	mission_list_changed.emit()
	mission_unlocked.emit(m1.id)


func _build_rescue_chain_mission(
	mission_id: String,
	title: String,
	body: String,
	mtype: Mission.MissionType,
	duration: float,
	success: float,
	cariye_id: int,
	prerequisites: Array,
	rewards: Dictionary
) -> Mission:
	var m := Mission.new()
	m.id = mission_id
	m.name = title
	m.description = body
	m.mission_type = mtype
	m.difficulty = Mission.Difficulty.KOLAY if success >= 0.85 else Mission.Difficulty.ORTA
	m.duration = duration
	m.success_chance = success
	m.required_cariye_level = 1
	m.required_army_size = 0
	m.required_concubine_id = cariye_id
	m.required_resources = {}
	m.rewards = rewards
	m.penalties = {"gold": -3}
	m.target_location = tr("mission.rescue_chain.target.village")
	m.distance = 0.1
	m.risk_level = tr("mission.rescue_chain.risk.low")
	m.allow_player_map_completion = false
	m.chain_id = RESCUE_CHAIN_ID
	m.chain_type = Mission.ChainType.SEQUENTIAL
	m.prerequisite_missions = prerequisites.duplicate()
	m.status = Mission.Status.MEVCUT
	return m


func is_rescue_onboarding_mission(mission_id: String) -> bool:
	return mission_id in RESCUE_MISSION_IDS


func get_rescue_onboarding_concubine_id() -> int:
	return rescue_onboarding_concubine_id


func is_mission_listing_available(mission: Mission) -> bool:
	if mission == null:
		return false
	if mission.status != Mission.Status.MEVCUT:
		return false
	if not mission.are_prerequisites_met(completed_missions):
		return false
	if mission.required_concubine_id >= 0:
		if not concubines.has(mission.required_concubine_id):
			return false
		var bound: Concubine = concubines[mission.required_concubine_id]
		if not mission.is_unlocked_for_concubine(bound):
			return false
	elif mission.unlock_leverage_min > 0 or mission.unlock_level_min > 0:
		return false
	return true


func _on_concubine_role_assigned(cariye_id: int, role: Concubine.Role) -> void:
	if role == Concubine.Role.NONE:
		return
	setup_role_mission_chain(cariye_id, role)
	setup_story_chain_for_concubine(cariye_id)


func _role_chain_state_key(cariye_id: int, role: Concubine.Role) -> String:
	return "%d:%d" % [cariye_id, int(role)]


func _role_mission_id(cariye_id: int, role: Concubine.Role, step: int) -> String:
	return "role_%d_%d_%d" % [int(role), cariye_id, step]


func _story_mission_id(cariye_id: int, step: int) -> String:
	return "story_%d_%d" % [cariye_id, step]


func _role_chain_id(cariye_id: int) -> String:
	return "role_chain_%d" % cariye_id


func _story_chain_id(cariye_id: int) -> String:
	return "story_chain_%d" % cariye_id


func setup_role_mission_chain(cariye_id: int, role: Concubine.Role) -> void:
	if role == Concubine.Role.NONE or not concubines.has(cariye_id):
		return
	var state_key: String = _role_chain_state_key(cariye_id, role)
	var first_mid: String = _role_mission_id(cariye_id, role, 1)
	var is_new: bool = not missions.has(first_mid)
	if bool(_role_chains_started.get(state_key, false)) and not is_new:
		return
	var steps: Array[Dictionary] = RoleMissionCatalog.get_role_mission_steps(role)
	if steps.is_empty():
		return
	var cariye: Concubine = concubines[cariye_id]
	var display_name: String = cariye.name.strip_edges()
	if display_name.is_empty():
		display_name = tr("cariye.unknown")
	var chain_id: String = _role_chain_id(cariye_id)
	if not mission_chains.has(chain_id):
		create_mission_chain(
			chain_id,
			tr("mission.role.chain_name") % [display_name, cariye.get_role_name()],
			Mission.ChainType.SEQUENTIAL,
			RoleMissionCatalog.get_role_chain_rewards()
		)
	var prev_id: String = ""
	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		var mid: String = _role_mission_id(cariye_id, role, i + 1)
		if missions.has(mid):
			prev_id = mid
			continue
		var prereqs: Array = []
		if not prev_id.is_empty():
			prereqs = [prev_id]
		var m: Mission = _build_personal_chain_mission(
			mid,
			tr(String(step.get("name_key", ""))) % display_name,
			tr(String(step.get("desc_key", ""))) % display_name,
			int(step.get("type", Mission.MissionType.BÜROKRASİ)),
			float(step.get("duration", 120.0)),
			float(step.get("success", 0.8)),
			cariye_id,
			int(role),
			prereqs,
			step.get("rewards", {}) as Dictionary,
			chain_id,
			0,
			0
		)
		missions[mid] = m
		add_mission_to_chain(mid, chain_id, i)
		if i + 1 < steps.size():
			m.unlocks_missions = [_role_mission_id(cariye_id, role, i + 2)]
		prev_id = mid
	_role_chains_started[state_key] = true
	if is_new:
		post_news(
			"village",
			tr("news.role_chain.start.title") % display_name,
			tr("news.role_chain.start.body") % cariye.get_role_name(),
			Color(0.85, 0.92, 1.0),
			"info"
		)
		mission_unlocked.emit(first_mid)
	mission_list_changed.emit()


func setup_story_chain_for_concubine(cariye_id: int) -> void:
	if not concubines.has(cariye_id):
		return
	var first_mid: String = _story_mission_id(cariye_id, 1)
	var is_new: bool = not missions.has(first_mid)
	if bool(_story_chains_active.get(cariye_id, false)) and not is_new:
		return
	var cariye: Concubine = concubines[cariye_id]
	var display_name: String = cariye.name.strip_edges()
	if display_name.is_empty():
		display_name = tr("cariye.unknown")
	var chain_id: String = _story_chain_id(cariye_id)
	if not mission_chains.has(chain_id):
		create_mission_chain(
			chain_id,
			tr("mission.story.chain_name") % display_name,
			Mission.ChainType.SEQUENTIAL,
			RoleMissionCatalog.get_story_chain_rewards()
		)
	var steps: Array[Dictionary] = RoleMissionCatalog.get_story_steps()
	var prev_id: String = ""
	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		var mid: String = _story_mission_id(cariye_id, i + 1)
		if missions.has(mid):
			prev_id = mid
			continue
		var prereqs: Array = []
		if not prev_id.is_empty():
			prereqs = [prev_id]
		var m: Mission = _build_personal_chain_mission(
			mid,
			tr(String(step.get("name_key", ""))) % display_name,
			tr(String(step.get("desc_key", ""))) % display_name,
			int(step.get("type", Mission.MissionType.BÜROKRASİ)),
			float(step.get("duration", 120.0)),
			float(step.get("success", 0.85)),
			cariye_id,
			-1,
			prereqs,
			step.get("rewards", {}) as Dictionary,
			chain_id,
			int(step.get("unlock_leverage", 0)),
			int(step.get("unlock_level", 0))
		)
		missions[mid] = m
		add_mission_to_chain(mid, chain_id, i)
		if i + 1 < steps.size():
			m.unlocks_missions = [_story_mission_id(cariye_id, i + 2)]
		prev_id = mid
	_story_chains_active[cariye_id] = true
	if is_new:
		post_news(
			"village",
			tr("news.story_chain.start.title") % display_name,
			tr("news.story_chain.start.body"),
			Color(1.0, 0.9, 0.95),
			"info"
		)
		mission_unlocked.emit(first_mid)
	mission_list_changed.emit()


func restore_role_story_chains_after_load() -> void:
	for cariye_id in concubines.keys():
		var cariye: Concubine = concubines[cariye_id]
		if cariye.role != Concubine.Role.NONE:
			var sk: String = _role_chain_state_key(int(cariye_id), cariye.role)
			if bool(_role_chains_started.get(sk, false)) or missions.has(_role_mission_id(int(cariye_id), cariye.role, 1)):
				_role_chains_started[sk] = true
				setup_role_mission_chain(int(cariye_id), cariye.role)
		if bool(_story_chains_active.get(cariye_id, false)) or missions.has(_story_mission_id(int(cariye_id), 1)):
			_story_chains_active[cariye_id] = true
			setup_story_chain_for_concubine(int(cariye_id))
	mission_list_changed.emit()


func _build_personal_chain_mission(
	mission_id: String,
	title: String,
	body: String,
	mtype: int,
	duration: float,
	success: float,
	cariye_id: int,
	required_role: int,
	prerequisites: Array,
	rewards: Dictionary,
	chain_id: String,
	unlock_leverage: int,
	unlock_level: int
) -> Mission:
	var m := Mission.new()
	m.id = mission_id
	m.name = title
	m.description = body
	m.mission_type = mtype as Mission.MissionType
	m.difficulty = Mission.Difficulty.KOLAY if success >= 0.85 else Mission.Difficulty.ORTA
	m.duration = duration
	m.success_chance = success
	m.required_cariye_level = 1
	m.required_army_size = 0
	m.required_concubine_id = cariye_id
	m.required_concubine_role = required_role
	m.unlock_leverage_min = unlock_leverage
	m.unlock_level_min = unlock_level
	m.required_resources = {}
	m.rewards = rewards.duplicate(true)
	m.penalties = {"gold": -4}
	m.target_location = tr("mission.rescue_chain.target.village")
	m.distance = 0.1
	m.risk_level = tr("mission.rescue_chain.risk.low")
	m.allow_player_map_completion = false
	m.chain_id = chain_id
	m.chain_type = Mission.ChainType.SEQUENTIAL
	m.prerequisite_missions = prerequisites.duplicate()
	m.status = Mission.Status.MEVCUT
	return m

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
	
	if not (mission is Dictionary):
		if mission.required_concubine_id >= 0 and cariye_id != mission.required_concubine_id:
			print("❌ Bu görev yalnızca kurtarılan cariye için: %d" % mission.required_concubine_id)
			return false
		if mission.required_concubine_role >= 0 and int(cariye.role) != mission.required_concubine_role:
			print("❌ Bu görev için gerekli rol atanmamış.")
			return false
		if not mission.is_unlocked_for_concubine(cariye):
			print("❌ Hikâye kilidi: leverage veya seviye yetersiz.")
			return false
	
	# Dictionary görevleri için özel işlem (defense görevleri otomatik değil)
	if mission is Dictionary:
		var mission_type = mission.get("type", "")
		if mission_type == "defense":
			print("❌ Savunma görevleri otomatik gerçekleşir, cariye atanamaz!")
			return false
		
		# Raid görevleri için asker sayısı ve göreve giden askerlerin worker ID'leri
		if mission_type == "raid" and soldier_count > 0:
			mission["assigned_soldiers"] = soldier_count
			var barracks = _find_barracks()
			if barracks and "assigned_worker_ids" in barracks and barracks.assigned_worker_ids.size() > 0:
				var n = min(soldier_count, barracks.assigned_worker_ids.size())
				var worker_ids: Array = []
				for i in range(n):
					worker_ids.append(barracks.assigned_worker_ids[i])
				mission["assigned_soldier_worker_ids"] = worker_ids
	
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
			# Asker atanan her görev (escort, raid vb.): çıkış yönü ve asker worker ID'leri
			if soldier_count >= 0:
				var exit_distance := 4800.0
				var exit_x = -exit_distance if randf() < 0.5 else exit_distance
				var worker_ids: Array = []
				if soldier_count > 0:
					var barracks = _find_barracks()
					if barracks and "assigned_worker_ids" in barracks and barracks.assigned_worker_ids.size() > 0:
						var available_ids = _get_available_soldier_worker_ids_for_mission(barracks, mission_id)
						var n = min(soldier_count, available_ids.size())
						for i in range(n):
							worker_ids.append(available_ids[i])
				_raid_mission_extra[mission_id] = { "mission_exit_x": exit_x, "assigned_soldier_worker_ids": worker_ids }
				print("[RAID_DEBUG] Mission objesi (askerli): mission_id=%s exit_x=%.0f worker_ids=%s" % [mission_id, exit_x, str(worker_ids)])
			print("✅ Görev başlatıldı: %s -> %s" % [cariye.name, mission.name])
			print("📋 Aktif görev sayısı: %d" % active_missions.size())
			
			mission_started.emit(cariye_id, mission_id)
			return true
	else:
		# Dictionary görevleri için basit atama
		var tm_dict: Node = get_node_or_null("/root/TimeManager")
		if tm_dict and tm_dict.has_method("get_total_game_minutes"):
			mission["started_total_minutes"] = int(tm_dict.call("get_total_game_minutes"))
		cariye.start_mission(mission_id)
		active_missions[cariye_id] = mission_id
		
		# Asker atanan her görev (raid, escort vb.): çıkış yönü ve asker ID'leri
		if mission.get("type", "") == "raid" or soldier_count > 0:
			var exit_distance := 4800.0
			var exit_x = -exit_distance if randf() < 0.5 else exit_distance
			mission["mission_exit_x"] = exit_x
			mission["assigned_soldiers"] = soldier_count
			var worker_ids: Array = []
			if soldier_count > 0:
				var barracks = _find_barracks()
				if barracks and "assigned_worker_ids" in barracks and barracks.assigned_worker_ids.size() > 0:
					var available_ids = _get_available_soldier_worker_ids_for_mission(barracks, mission_id)
					var n = min(soldier_count, available_ids.size())
					for i in range(n):
						worker_ids.append(available_ids[i])
					mission["assigned_soldier_worker_ids"] = worker_ids
			_raid_mission_extra[mission_id] = { "mission_exit_x": exit_x, "assigned_soldier_worker_ids": worker_ids }
			print("[RAID_DEBUG] Dictionary (askerli/raid): mission_id=%s exit_x=%.0f worker_ids=%s" % [mission_id, exit_x, str(worker_ids)])
			if mission.get("type", "") == "raid":
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
			
			# Zincir/bağımlılık ilerletme (yalnızca başarılı görevler)
			if successful:
				on_mission_completed(mission_id)

			# Aktif görevlerden çıkar
			_register_world_map_returning_unit(cariye_id, mission_id, mission)
			completed_missions.append(cariye_id)
			
			# Sinyal gönder
			mission_completed.emit(cariye_id, mission_id, successful, results)
			if successful:
				_try_resolve_world_incident_for_completed_mission(mission)
				_try_grant_pending_role_for_completed_mission(mission)
	
	# Tamamlanan görevleri temizle
	for cariye_id in completed_missions:
		active_missions.erase(cariye_id)


## Rol eğitim görevi başarıyla bitince gerçek rol ataması burada yapılır (bkz. request_concubine_role).
func _try_grant_pending_role_for_completed_mission(mission: Mission) -> void:
	if mission == null or mission.grants_concubine_role < 0:
		return
	var cariye_id: int = mission.assigned_cariye_id
	if not concubines.has(cariye_id):
		return
	var role: int = mission.grants_concubine_role
	var cariye: Concubine = concubines[cariye_id]
	if not set_concubine_role(cariye_id, role):
		return
	post_news(
		"village",
		tr("news.role_granted.title") % cariye.name,
		tr("news.role_granted.body") % cariye.get_role_name(),
		Color(0.85, 0.92, 1.0),
		"success"
	)


func _try_resolve_world_incident_for_completed_mission(mission: Mission) -> void:
	if mission == null:
		return
	var wm: Node = get_node_or_null("/root/WorldManager")
	var aid_sid: String = String(mission.completes_alliance_aid_settlement_id)
	if not aid_sid.is_empty():
		if wm and wm.has_method("apply_alliance_aid_mission_success"):
			wm.call("apply_alliance_aid_mission_success", aid_sid)
		return
	var cid: String = String(mission.completes_incident_id)
	if cid.is_empty():
		return
	if wm and wm.has_method("resolve_settlement_incident_by_id"):
		wm.call("resolve_settlement_incident_by_id", cid)

## Eski doğrudan spawn — artık NarrativeSpawnPipeline üzerinden yayınlanır.
func try_spawn_incident_relief_mission(incident: Dictionary) -> void:
	var nsp: Node = get_node_or_null("/root/NarrativeSpawnPipeline")
	if nsp and nsp.has_method("request_settlement_incident_package"):
		return
	_spawn_incident_relief_mission_legacy(incident)


func mission_to_mechanical(mission: Mission) -> Dictionary:
	if mission == null:
		return {}
	return {
		"id": mission.id,
		"mission_type": int(mission.mission_type),
		"difficulty": int(mission.difficulty),
		"duration": mission.duration,
		"success_chance": mission.success_chance,
		"required_cariye_level": mission.required_cariye_level,
		"required_army_size": mission.required_army_size,
		"required_resources": mission.required_resources.duplicate(true),
		"rewards": mission.rewards.duplicate(true),
		"penalties": mission.penalties.duplicate(true),
		"target_location": mission.target_location,
		"distance": mission.distance,
		"risk_level": mission.risk_level,
		"target_settlement_id": mission.target_settlement_id,
		"settlement_id": mission.target_settlement_id,
		"settlement_name": mission.target_location,
		"world_hex_key": mission.world_hex_key,
		"completes_incident_id": mission.completes_incident_id,
		"incident_id": mission.completes_incident_id,
		"completes_alliance_aid_settlement_id": mission.completes_alliance_aid_settlement_id,
		"locale_name_key": mission.locale_name_key,
		"locale_desc_key": mission.locale_desc_key,
		"locale_vars": mission.locale_vars.duplicate(true),
		"player_map_strategies": mission.player_map_strategies.duplicate(true),
		"allow_player_map_completion": mission.allow_player_map_completion,
		"dynamic_type": mission.get_meta("dynamic_type") if mission.has_meta("dynamic_type") else "",
	}


func _narrative_pipeline() -> Node:
	return get_node_or_null("/root/NarrativeSpawnPipeline")


func try_enqueue_mission_spawn(mission: Mission, source: String, news_cfg: Dictionary = {}) -> bool:
	if mission == null or String(mission.id).is_empty():
		return false
	if missions.has(mission.id):
		return false
	var nsp: Node = _narrative_pipeline()
	if nsp == null or not nsp.has_method("enqueue"):
		return false
	var post_news: bool = bool(news_cfg.get("post_news", true))
	var news_source: String = str(news_cfg.get("news_source", source))
	var facts: Dictionary = news_cfg.get("facts", {}) if news_cfg.get("facts") is Dictionary else {}
	if facts.is_empty():
		facts = {"settlement_name": mission.target_location, "target": mission.target_location}
	var mech: Dictionary = mission_to_mechanical(mission)
	var brief_extra: Dictionary = news_cfg.get("brief_extra", {}) if news_cfg.get("brief_extra") is Dictionary else {}
	var mech_news: Dictionary = {}
	if post_news:
		if news_cfg.get("news_override") is Dictionary and not (news_cfg["news_override"] as Dictionary).is_empty():
			mech_news = news_cfg["news_override"]
		else:
			mech_news = AiNarrativeBrief.mechanical_news(news_source, facts)
	nsp.call("enqueue", {
		"request_id": "mission_%s" % mission.id,
		"source": source,
		"include_mission": true,
		"mission_id": mission.id,
		"mission_mechanical": mech,
		"brief_extra": brief_extra,
		"mechanical_mission": AiNarrativeBrief.mechanical_mission(source, {
			"title": mission.name,
			"body": mission.description,
			"settlement_name": mission.target_location,
		}),
		"mechanical_news": mech_news,
		"post_news": post_news,
		"post_publish_actions": news_cfg.get("post_publish_actions", []),
	})
	return true


func try_enqueue_news(source: String, facts: Dictionary, news_override: Dictionary = {}) -> bool:
	var nsp: Node = _narrative_pipeline()
	if nsp == null or not nsp.has_method("enqueue"):
		return false
	var mech_news: Dictionary = news_override if not news_override.is_empty() else AiNarrativeBrief.mechanical_news(source, facts)
	nsp.call("enqueue", {
		"request_id": "news_%s_%d" % [source, Time.get_unix_time_from_system()],
		"source": source,
		"include_mission": false,
		"post_news": true,
		"brief": AiNarrativeBrief.build_news_brief(source, facts),
		"news_facts": facts,
		"mechanical_news": mech_news,
	})
	return true


func try_enqueue_dict_mission_spawn(
	dict_mission: Dictionary,
	source: String,
	news_cfg: Dictionary = {}
) -> bool:
	if dict_mission.is_empty():
		return false
	var mid: String = String(dict_mission.get("id", ""))
	if mid.is_empty() or missions.has(mid):
		return false
	var nsp: Node = _narrative_pipeline()
	if nsp == null or not nsp.has_method("enqueue"):
		return false
	var post_news: bool = bool(news_cfg.get("post_news", true))
	var news_source: String = str(news_cfg.get("news_source", source))
	var facts: Dictionary = news_cfg.get("facts", {}) if news_cfg.get("facts") is Dictionary else {}
	var target: String = String(dict_mission.get("target", dict_mission.get("name", "")))
	if facts.is_empty():
		facts = {"target": target, "settlement_name": target, "attacker": dict_mission.get("attacker", "")}
	var mech_news: Dictionary = {}
	if post_news:
		if news_cfg.get("news_override") is Dictionary and not (news_cfg["news_override"] as Dictionary).is_empty():
			mech_news = news_cfg["news_override"]
		else:
			mech_news = AiNarrativeBrief.mechanical_news(news_source, facts)
	nsp.call("enqueue", {
		"request_id": "mission_%s" % mid,
		"source": source,
		"include_mission": true,
		"publish_dict_mission": true,
		"mission_id": mid,
		"dict_mechanical": dict_mission.duplicate(true),
		"mechanical_mission": AiNarrativeBrief.mechanical_mission(source, {
			"title": str(dict_mission.get("name", "")),
			"body": str(dict_mission.get("description", "")),
			"target": target,
		}),
		"mechanical_news": mech_news,
		"post_news": post_news,
	})
	return true


func run_post_publish_actions(actions: Array) -> void:
	for action in actions:
		if not (action is Dictionary):
			continue
		var kind: String = String(action.get("action", ""))
		match kind:
			"increase_relation":
				_increase_settlement_relation(String(action.get("settlement_id", "")), int(action.get("amount", 0)))


func publish_narrative_mission(
	mechanical: Dictionary,
	brief: Dictionary,
	title: String,
	body: String,
	mode: String = "mechanical"
) -> void:
	if mechanical.is_empty():
		return
	var mission_id: String = String(mechanical.get("id", ""))
	if mission_id.is_empty() or missions.has(mission_id):
		return
	var m: Mission = Mission.new()
	m.id = mission_id
	m.name = title
	m.description = body
	m.mission_type = int(mechanical.get("mission_type", Mission.MissionType.DİPLOMASİ)) as Mission.MissionType
	m.difficulty = int(mechanical.get("difficulty", Mission.Difficulty.KOLAY)) as Mission.Difficulty
	m.duration = float(mechanical.get("duration", 150.0))
	m.success_chance = float(mechanical.get("success_chance", 0.72))
	m.required_cariye_level = int(mechanical.get("required_cariye_level", 1))
	m.required_army_size = int(mechanical.get("required_army_size", 0))
	if mechanical.get("required_resources") is Dictionary:
		m.required_resources = mechanical["required_resources"].duplicate(true)
	if mechanical.get("rewards") is Dictionary:
		m.rewards = mechanical["rewards"].duplicate(true)
	if mechanical.get("penalties") is Dictionary:
		m.penalties = mechanical["penalties"].duplicate(true)
	m.target_location = String(mechanical.get("target_location", mechanical.get("settlement_name", "")))
	m.distance = float(mechanical.get("distance", 0.0))
	m.risk_level = String(mechanical.get("risk_level", "Dusuk"))
	m.target_settlement_id = String(mechanical.get("target_settlement_id", mechanical.get("settlement_id", "")))
	m.world_hex_key = String(mechanical.get("world_hex_key", ""))
	m.completes_incident_id = String(mechanical.get("completes_incident_id", mechanical.get("incident_id", "")))
	m.completes_alliance_aid_settlement_id = String(mechanical.get("completes_alliance_aid_settlement_id", ""))
	m.locale_name_key = String(mechanical.get("locale_name_key", ""))
	m.locale_desc_key = String(mechanical.get("locale_desc_key", ""))
	if mechanical.get("locale_vars") is Dictionary:
		m.locale_vars = mechanical["locale_vars"].duplicate(true)
	if mechanical.get("player_map_strategies") is Array:
		m.player_map_strategies = mechanical["player_map_strategies"].duplicate(true)
	m.allow_player_map_completion = bool(mechanical.get("allow_player_map_completion", true))
	m.status = Mission.Status.MEVCUT
	m.ai_brief = brief.duplicate(true) if brief is Dictionary else {}
	var locale: String = "tr"
	var lm: Node = get_node_or_null("/root/LocaleManager")
	if lm and lm.has_method("get_locale"):
		locale = str(lm.call("get_locale"))
	m.ai_narratives[locale] = {"title": title, "body": body}
	m.ai_narrative_mode = mode if mode in ["narrative", "mechanical"] else "mechanical"
	missions[mission_id] = m
	mission_list_changed.emit()


func publish_narrative_dict_mission(
	dict_mission: Dictionary,
	brief: Dictionary,
	title: String,
	body: String,
	mode: String = "mechanical"
) -> void:
	if dict_mission.is_empty():
		return
	var mission_id: String = String(dict_mission.get("id", ""))
	if mission_id.is_empty() or missions.has(mission_id):
		return
	var d: Dictionary = dict_mission.duplicate(true)
	d["name"] = title
	d["description"] = body
	d["ai_brief"] = brief.duplicate(true) if brief is Dictionary else {}
	d["ai_narrative_mode"] = mode
	missions[mission_id] = d
	mission_list_changed.emit()


func _spawn_incident_relief_mission_legacy(incident: Dictionary) -> void:
	if incident.is_empty():
		return
	if randf() > 0.38:
		return
	var raw_id: String = String(incident.get("id", "x"))
	var safe_id: String = raw_id.replace(",", "_").replace("|", "_").replace(" ", "_")
	var mission_id: String = "relief_" + safe_id
	if mission_id.length() > 96:
		mission_id = mission_id.substr(0, 96)
	if missions.has(mission_id):
		return
	var sn: String = String(incident.get("settlement_name", "Komsu"))
	var sid: String = String(incident.get("settlement_id", ""))
	var wm: Node = get_node_or_null("/root/WorldManager")
	var hex_key: String = ""
	if wm and wm.has_method("get_settlement_hex_key_for_mission"):
		hex_key = String(wm.call("get_settlement_hex_key_for_mission", sid))
	publish_narrative_mission({
		"id": mission_id,
		"settlement_name": sn,
		"settlement_id": sid,
		"incident_id": raw_id,
		"world_hex_key": hex_key,
		"mission_type": Mission.MissionType.DİPLOMASİ,
		"difficulty": Mission.Difficulty.KOLAY,
		"duration": 150.0,
		"success_chance": 0.72,
		"required_cariye_level": 1,
		"rewards": {"gold": 12},
		"penalties": {"gold": -4},
		"risk_level": "Dusuk",
	}, {}, "Yardim Gonder: %s" % sn, "Komsu koydeki krizi yumusatmak icin yardim orgutle.", "mechanical")
	post_news("world", tr("news.relief.title"), tr("news.relief.body") % sn, Color(0.85, 1.0, 0.85), "info")

## `force_spawn`: aid_call acilisinda true — oyuncu her zaman bir `ally_relief_*` gorevi gorebilsin.
func try_spawn_alliance_aid_relief_mission(settlement_id: String, day: int, force_spawn: bool = false) -> void:
	if String(settlement_id).is_empty():
		return
	if not force_spawn and randf() > 0.40:
		return
	var safe: String = String(settlement_id).replace(",", "_").replace("|", "_").replace(" ", "_")
	var mission_id: String = "ally_relief_" + safe
	if mission_id.length() > 96:
		mission_id = mission_id.substr(0, 96)
	if missions.has(mission_id):
		return
	var wm: Node = get_node_or_null("/root/WorldManager")
	if not wm:
		return
	var sn: String = String(settlement_id)
	if wm.has_method("_get_settlement_display_name"):
		sn = String(wm.call("_get_settlement_display_name", settlement_id))
	var m: Mission = Mission.new()
	m.id = mission_id
	m.name = "Muttefik Yardimi: %s" % sn
	m.description = "Muttefik koyun yardim cagrisina diplomatik/lojistik cevap ver."
	m.mission_type = Mission.MissionType.DİPLOMASİ
	m.difficulty = Mission.Difficulty.KOLAY
	m.duration = 140.0
	m.success_chance = 0.70
	m.required_cariye_level = 1
	m.rewards = {"gold": 12, "reputation": 2}
	m.penalties = {"gold": -4}
	m.target_location = sn
	m.risk_level = "Dusuk"
	m.target_settlement_id = String(settlement_id)
	m.completes_alliance_aid_settlement_id = String(settlement_id)
	if wm.has_method("get_settlement_hex_key_for_mission"):
		m.world_hex_key = String(wm.call("get_settlement_hex_key_for_mission", settlement_id))
	m.status = Mission.Status.MEVCUT
	if try_enqueue_mission_spawn(m, "alliance_aid", {
		"news_override": {
			"title": tr("news.ally_relief.title"),
			"body": tr("news.ally_relief.body") % sn,
			"category": "Dünya",
			"color": Color(0.9, 1.0, 0.95),
			"subcategory": "info",
		},
	}):
		return
	missions[mission_id] = m
	mission_list_changed.emit()
	post_news("world", tr("news.ally_relief.title"), tr("news.ally_relief.body") % sn, Color(0.9, 1.0, 0.95), "info")

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
	
	# Ticaret görevleri için özel işleme
	if mission.mission_type == Mission.MissionType.TİCARET and mission.has_meta("trade_route_id"):
		_process_trade_mission_completion(cariye_id, mission_id, successful, mission)
		return
	
	if successful:
		var is_raid_mission: bool = mission is Dictionary and String(mission.get("type", "")) == "raid"
		var vce := get_node_or_null("/root/VillageCardEffects")
		# Ödülleri ver
		for reward_type in mission.rewards:
			var amount = mission.rewards[reward_type]
			if is_raid_mission and String(reward_type) == "gold" and vce:
				amount = vce.modify_raid_mission_gold(int(amount))
			_apply_reward(reward_type, amount)
		if is_raid_mission and vce:
			vce.notify_raid_mission_success()
		
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

# Ticaret görevi tamamlama işlemi
func _process_trade_mission_completion(cariye_id: int, mission_id: String, successful: bool, mission: Mission):
	if not successful:
		# Başarısız ticaret görevi - cezaları uygula
		for penalty_type in mission.penalties:
			var amount = mission.penalties[penalty_type]
			if penalty_type == "cariye_injured":
				var cariye = concubines[cariye_id]
				cariye.take_damage(30)
			else:
				_apply_penalty(penalty_type, amount)
		return
	
	var cariye = concubines[cariye_id]
	var route = mission.get_meta("trade_route", {})
	if route.is_empty():
		return
	
	var products = mission.required_resources  # Götürülen mallar
	
	# Kâr hesaplama (zaten mission.rewards içinde hesaplanmış)
	var total_profit = mission.rewards.get("gold", 0)
	
	# Altın ekle
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gpd:
		gpd.gold += total_profit
	
	# İlişki artışı (yetenek bonuslu)
	var trade_skill = cariye.get_skill_level(Concubine.Skill.TİCARET)
	var base_relation_gain = 2 + randi_range(0, 3)  # 2-5 temel
	var skill_relation_bonus = 1.0
	
	if trade_skill >= 90:
		skill_relation_bonus = 1.5  # %50 bonus
	elif trade_skill >= 80:
		skill_relation_bonus = 1.25  # %25 bonus
	
	var final_relation_gain = int(base_relation_gain * skill_relation_bonus)
	_increase_settlement_relation(route.get("to", ""), final_relation_gain)
	
	# Cariye deneyim kazancı (ticaret görevleri için özel)
	var exp_gain = 30 + (trade_skill / 2)  # Yetenek arttıkça daha fazla exp
	var leveled_up = cariye.add_experience(int(exp_gain))
	if leveled_up:
		concubine_leveled_up.emit(cariye_id, cariye.level)
	
	# Haber
	var skill_text = ""
	if trade_skill >= 100:
		skill_text = tr("news.trade_skill.legendary")
	elif trade_skill >= 90:
		skill_text = tr("news.trade_skill.master")
	elif trade_skill >= 80:
		skill_text = tr("news.trade_skill.expert")
	
	var settlement_name = route.get("to_name", "?")
	post_news("village", tr("news.trade_success.title") % skill_text,
		tr("news.trade_success.body") % [cariye.name, settlement_name, total_profit, final_relation_gain],
		Color(0.8, 1, 0.8), "success")

# Ödül uygula
func _grant_village_resource(resource_type: String, delta: int) -> int:
	if delta == 0:
		return 0
	var vm: Node = get_node_or_null("/root/VillageManager")
	if not is_instance_valid(vm) or not vm.has_method("apply_resource_delta"):
		push_warning("[MissionManager] Köy kaynağı uygulanamadi: %s %+d" % [resource_type, delta])
		return 0
	return int(vm.call("apply_resource_delta", resource_type, delta))


func _apply_army_losses(count: int) -> void:
	if count <= 0:
		return
	var barracks: Node = _find_barracks()
	if barracks and barracks.has_method("remove_soldiers"):
		barracks.call("remove_soldiers", count)


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
		"wood", "stone", "food", "medicine":
			var applied: int = _grant_village_resource(reward_type, int_amount)
			if applied > 0:
				print("📦 +%d %s (köy stoğu)" % [applied, reward_type])
		"reputation":
			update_player_reputation(int_amount)
		"stability_bonus", "world_stability":
			update_world_stability(int_amount)
		"defense":
			update_world_stability(int_amount if int_amount != 0 else 3)
		"trade_bonus":
			if amount is float and absf(float(amount)) < 1.0:
				var bonus_gold: int = maxi(1, int(round(float(amount) * 100.0)))
				_apply_reward("gold", bonus_gold)
			else:
				update_player_reputation(int_amount)
		"special_item", "building", "alliance", "trade_route":
			print("🏆 Özel ödül (henüz otomatik değil): %s = %s" % [reward_type, str(amount)])

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
		"wood_rate":
			_active_rate_add("wood", int_amount, 1, "Görev Cezası")
		"stone_rate":
			_active_rate_add("stone", int_amount, 1, "Görev Cezası")
		"wood", "stone", "food", "medicine":
			var applied: int = _grant_village_resource(penalty_type, int_amount)
			if applied < 0:
				print("📦 %d %s kaybedildi (köy stoğu)" % [abs(applied), penalty_type])
		"reputation":
			update_player_reputation(int_amount)
		"stability_penalty":
			update_world_stability(int_amount)
		"army_losses":
			_apply_army_losses(maxi(0, abs(int_amount)))

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
	
	if try_enqueue_mission_spawn(mission, "procedural", {"post_news": false}):
		return mission
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

func _assign_proc_mission_locale(mission: Mission, name_keys: Array, desc_key: String, target_key: String) -> void:
	var nk := String(name_keys[randi() % name_keys.size()])
	mission.locale_name_key = nk
	mission.locale_desc_key = desc_key
	mission.locale_vars = {}
	mission.name = _tr_mission_template(nk, {})
	mission.description = _tr_mission_template(desc_key, {})
	mission.target_location = tr(target_key)


func _strategy_display_text(raw: Dictionary, index: int) -> String:
	var key := str(raw.get("text_key", ""))
	if not key.is_empty():
		return tr(key)
	return str(raw.get("text", raw.get("label", tr("wm.mission.strategy.option") % (index + 1))))


# Savaş görevi oluştur
func _generate_combat_mission(mission: Mission):
	_assign_proc_mission_locale(mission, [
		"mission.proc.combat.bandit_camp",
		"mission.proc.combat.ork_attack",
		"mission.proc.combat.pirate_ship",
		"mission.proc.combat.dragon_lair",
		"mission.proc.combat.goblin_fort",
	], "mission.proc.combat.desc", "mission.loc.unknown_region")
	mission.duration = 180.0 + (randf() * 120.0)  # 180-300 oyun dakikası (3-5 saat, test için)
	mission.success_chance = 0.6 + (randf() * 0.3)  # 60-90%
	mission.required_cariye_level = 1 + randi() % 3  # 1-3 seviye
	mission.required_army_size = 10 + randi() % 20  # 10-30 asker
	mission.required_resources = {"gold": 6 + randi() % 10}
	mission.rewards = {"gold": 8 + randi() % 10, "wood": 1 + randi() % 2}
	mission.penalties = {"gold": -4 - randi() % 5, "cariye_injured": 1}
	mission.distance = 1.0 + randf() * 2.0
	mission.risk_level = "Yüksek"

# Keşif görevi oluştur
func _generate_exploration_mission(mission: Mission):
	_assign_proc_mission_locale(mission, [
		"mission.proc.explore.west_forest",
		"mission.proc.explore.lost_city",
		"mission.proc.explore.secret_cave",
		"mission.proc.explore.ancient_temple",
		"mission.proc.explore.unknown_island",
	], "mission.proc.explore.desc", "mission.loc.unknown_region")
	mission.duration = 180.0 + (randf() * 120.0)  # 180-300 oyun dakikası (3-5 saat, test için)
	mission.success_chance = 0.7 + (randf() * 0.2)  # 70-90%
	mission.required_cariye_level = 1 + randi() % 2  # 1-2 seviye
	mission.required_army_size = 5 + randi() % 10  # 5-15 asker
	mission.required_resources = {"gold": 4 + randi() % 6}
	mission.rewards = {"gold": 6 + randi() % 8, "wood": 1 + randi() % 2, "stone": 1 + randi() % 2}
	mission.penalties = {"gold": -3 - randi() % 4}
	mission.distance = 0.5 + randf() * 1.5
	mission.risk_level = "Orta"

# Ticaret görevi oluştur
func _generate_trade_mission(mission: Mission):
	_assign_proc_mission_locale(mission, [
		"mission.proc.trade.neighbor_city",
		"mission.proc.trade.sell_goods",
		"mission.proc.trade.open_route",
		"mission.proc.trade.setup_market",
		"mission.proc.trade.trade_deal",
	], "mission.proc.trade.desc", "mission.loc.trade_hub")
	mission.duration = 180.0 + (randf() * 120.0)  # 180-300 oyun dakikası (3-5 saat, test için)
	mission.success_chance = 0.8 + (randf() * 0.15)  # 80-95%
	mission.required_cariye_level = 1 + randi() % 2  # 1-2 seviye
	mission.required_army_size = 0  # Ticaret için asker gerekmez
	mission.required_resources = {"gold": 8 + randi() % 12}
	mission.rewards = {"gold": 10 + randi() % 14}
	mission.penalties = {"gold": -5 - randi() % 7}
	mission.distance = 0.3 + randf() * 0.7
	mission.risk_level = "Düşük"

# Diplomasi görevi oluştur
func _generate_diplomacy_mission(mission: Mission):
	_assign_proc_mission_locale(mission, [
		"mission.proc.diplomacy.peace",
		"mission.proc.diplomacy.alliance",
		"mission.proc.diplomacy.envoy",
		"mission.proc.diplomacy.dispute",
		"mission.proc.diplomacy.trade_treaty",
	], "mission.proc.diplomacy.desc", "mission.loc.diplomatic_hub")
	mission.duration = 200.0 + (randf() * 100.0)  # 200-300 oyun dakikası (3.3-5 saat, test için)
	mission.success_chance = 0.65 + (randf() * 0.25)  # 65-90%
	mission.required_cariye_level = 2 + randi() % 2  # 2-3 seviye
	mission.required_army_size = 0  # Diplomasi için asker gerekmez
	mission.required_resources = {"gold": 6 + randi() % 10}
	mission.rewards = {"gold": 8 + randi() % 10, "food": 1 + randi() % 3}
	mission.penalties = {"gold": -4 - randi() % 6}
	mission.distance = 0.4 + randf() * 0.6
	mission.risk_level = "Düşük"

# İstihbarat görevi oluştur
func _generate_intelligence_mission(mission: Mission):
	_assign_proc_mission_locale(mission, [
		"mission.proc.intel.enemy_plans",
		"mission.proc.intel.spy_network",
		"mission.proc.intel.secret_info",
		"mission.proc.intel.enemy_forces",
		"mission.proc.intel.insider",
	], "mission.proc.intel.desc", "mission.loc.enemy_territory")
	mission.duration = 180.0 + (randf() * 120.0)  # 180-300 oyun dakikası (3-5 saat, test için)
	mission.success_chance = 0.5 + (randf() * 0.3)  # 50-80%
	mission.required_cariye_level = 2 + randi() % 2  # 2-3 seviye
	mission.required_army_size = 0  # İstihbarat için asker gerekmez
	mission.required_resources = {"gold": 5 + randi() % 8}
	mission.rewards = {"gold": 7 + randi() % 9, "wood": 1 + randi() % 2}
	mission.penalties = {"gold": -4 - randi() % 5, "cariye_injured": 1}
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
				if mission is Mission:
					_ensure_mission_has_world_objective_hex(mission)
				if mission.are_prerequisites_met(completed_missions):
					available.append(mission)
				else:
					var mission_name: String = String(mission_id)
					if mission is Dictionary:
						mission_name = String(mission.get("name", mission_id))
					elif mission is Mission:
						mission_name = mission.name
					print("🔒 Görev kilitli (önkoşul eksik): " + mission_name)
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

func get_world_map_active_unit_markers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wm: Node = get_node_or_null("/root/WorldManager")
	var tm: Node = get_node_or_null("/root/TimeManager")
	if not wm or not ("world_map_player_pos" in wm) or not ("world_map_settlement_positions" in wm):
		return out
	var village_pos: Dictionary = _get_world_map_player_village_pos(wm)
	var origin_q: int = int(village_pos.get("q", int(wm.world_map_player_pos.get("q", 0))))
	var origin_r: int = int(village_pos.get("r", int(wm.world_map_player_pos.get("r", 0))))
	var total_minutes_now: int = 0
	if tm and tm.has_method("get_total_game_minutes"):
		total_minutes_now = int(tm.call("get_total_game_minutes"))
	for cariye_id in active_missions.keys():
		var mission_id: String = String(active_missions[cariye_id])
		if not missions.has(mission_id):
			continue
		var mission_data = missions[mission_id]
		var target_info: Dictionary = _resolve_mission_target_on_world_map(mission_data, wm.world_map_settlement_positions, wm)
		if target_info.is_empty():
			continue
		var progress: float = _get_active_mission_progress_ratio(mission_data, total_minutes_now)
		var mission_type_tag: String = _extract_mission_type_tag(mission_data)
		var target_q: int = int(target_info.get("q", origin_q))
		var target_r: int = int(target_info.get("r", origin_r))
		var current_coords: Dictionary = _sample_world_position_on_path(
			_get_world_path_points(wm, origin_q, origin_r, target_q, target_r),
			progress,
			origin_q,
			origin_r
		)
		var current_q: int = int(current_coords.get("q", origin_q))
		var current_r: int = int(current_coords.get("r", origin_r))
		var reveal_radius_outbound: int = _get_unit_reveal_radius(wm, current_q, current_r, mission_type_tag, false)
		_reveal_world_map_for_unit(wm, current_q, current_r, "mission_team", reveal_radius_outbound)
		var cariye_name: String = "Cariye"
		if concubines.has(cariye_id):
			var c = concubines[cariye_id]
			if c and "name" in c:
				cariye_name = String(c.name)
		out.append({
			"unit_type": "mission_team",
			"cariye_id": int(cariye_id),
			"cariye_name": cariye_name,
			"mission_id": mission_id,
			"mission_name": _get_mission_name_safe(mission_data, mission_id),
			"mission_type_tag": mission_type_tag,
			"progress": progress,
			"q": current_q,
			"r": current_r,
			"origin_q": origin_q,
			"origin_r": origin_r,
			"target_q": target_q,
			"target_r": target_r,
			"target_name": String(target_info.get("name", "Bilinmeyen"))
		})
	var returning_to_remove: Array = []
	for cariye_key in _world_map_returning_units.keys():
		var ret: Dictionary = _world_map_returning_units[cariye_key]
		var start_minutes: int = int(ret.get("start_minutes", total_minutes_now))
		var arrive_minutes: int = int(ret.get("arrive_minutes", start_minutes))
		var dur: int = max(1, arrive_minutes - start_minutes)
		var p: float = clampf(float(total_minutes_now - start_minutes) / float(dur), 0.0, 1.0)
		var rq0: int = int(ret.get("start_q", origin_q))
		var rr0: int = int(ret.get("start_r", origin_r))
		var rq1: int = int(ret.get("target_q", origin_q))
		var rr1: int = int(ret.get("target_r", origin_r))
		var current_return_coords: Dictionary = _sample_world_position_on_path(
			_get_world_path_points(wm, rq0, rr0, rq1, rr1),
			p,
			rq0,
			rr0
		)
		var cq: int = int(current_return_coords.get("q", rq0))
		var cr: int = int(current_return_coords.get("r", rr0))
		var reveal_radius_returning: int = _get_unit_reveal_radius(wm, cq, cr, String(ret.get("mission_type_tag", "")), true)
		_reveal_world_map_for_unit(wm, cq, cr, "mission_team", reveal_radius_returning)
		out.append({
			"unit_type": "returning_team",
			"cariye_id": int(cariye_key),
			"cariye_name": String(ret.get("cariye_name", "Cariye")),
			"mission_id": String(ret.get("mission_id", "")),
			"mission_name": String(ret.get("mission_name", "Gorev Donusu")),
			"mission_type_tag": String(ret.get("mission_type_tag", "")),
			"progress": p,
			"q": cq,
			"r": cr,
			"origin_q": rq0,
			"origin_r": rr0,
			"target_q": rq1,
			"target_r": rr1,
			"target_name": String(ret.get("target_name", "Koy"))
		})
		if total_minutes_now >= arrive_minutes:
			returning_to_remove.append(cariye_key)
	for key in returning_to_remove:
		_world_map_returning_units.erase(key)
	return out

func _resolve_mission_target_on_world_map(mission_data, settlement_positions: Dictionary, wm: Node = null) -> Dictionary:
	var world_hex_key: String = ""
	if mission_data is Dictionary:
		world_hex_key = String(mission_data.get("world_hex_key", ""))
	else:
		if "world_hex_key" in mission_data:
			world_hex_key = String(mission_data.world_hex_key)
	if not world_hex_key.is_empty() and wm != null and "world_map_tiles" in wm:
		var loc_name: String = "Hedef"
		if mission_data is Dictionary:
			loc_name = String(mission_data.get("name", "Hedef"))
		elif mission_data != null and "name" in mission_data:
			loc_name = String(mission_data.name)
		if wm.world_map_tiles.has(world_hex_key):
			var t: Dictionary = wm.world_map_tiles[world_hex_key]
			return {"q": int(t.get("q", 0)), "r": int(t.get("r", 0)), "name": loc_name}
		var parts: PackedStringArray = world_hex_key.split(",")
		if parts.size() == 2:
			return {"q": int(parts[0]), "r": int(parts[1]), "name": "Hedef"}
	var target_settlement_id: String = ""
	var target_name: String = ""
	if mission_data is Dictionary:
		target_settlement_id = String(mission_data.get("target_settlement_id", ""))
		target_name = String(mission_data.get("target", mission_data.get("target_location", "")))
	else:
		if "target_location" in mission_data:
			target_name = String(mission_data.target_location)
	if not target_settlement_id.is_empty() and settlement_positions.has(target_settlement_id):
		return settlement_positions[target_settlement_id]
	if not target_name.is_empty():
		for sid in settlement_positions.keys():
			var info: Dictionary = settlement_positions[sid]
			if String(info.get("name", "")).to_lower() == target_name.to_lower():
				return info
	return {}

func _mission_world_hex_placement_profile(mission: Mission) -> String:
	if mission == null:
		return "any"
	match mission.mission_type:
		Mission.MissionType.SAVAŞ:
			return "near_settlement_trail"
		Mission.MissionType.TİCARET:
			return "near_settlement_trail"
		Mission.MissionType.KEŞİF:
			return "wilderness"
		_:
			return "any"

func _ensure_mission_has_world_objective_hex(mission: Mission) -> void:
	if mission == null:
		return
	if not String(mission.world_hex_key).is_empty():
		return
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("pick_random_mission_objective_hex"):
		var placement: String = _mission_world_hex_placement_profile(mission)
		var assigned: String = ""
		for _i in range(10):
			var hk: Variant = wm.call("pick_random_mission_objective_hex", 2, 14, placement)
			if not (hk is String):
				continue
			var hks: String = String(hk)
			if hks.is_empty():
				continue
			if not _is_world_hex_used_by_other_available_player_map_mission(hks, mission.id):
				assigned = hks
				break
		if not assigned.is_empty():
			mission.world_hex_key = assigned

func _is_world_hex_used_by_other_available_player_map_mission(hex_key: String, mission_id_to_ignore: String = "") -> bool:
	for mid in missions.keys():
		var m: Mission = missions[mid] as Mission
		if m == null:
			continue
		if String(mid) == String(mission_id_to_ignore):
			continue
		if m.status != Mission.Status.MEVCUT:
			continue
		if not m.allow_player_map_completion:
			continue
		# Recursive stack overflow korumasi:
		# Burada baska gorevler icin world_hex üretmeye calismayiz; sadece mevcut key'e bakariz.
		var existing_key: String = String(m.world_hex_key)
		if existing_key.is_empty():
			continue
		if existing_key == hex_key:
			return true
	return false

func _append_player_map_mission_history_and_notify(mission_id: String, m: Mission, successful: bool, results: Dictionary) -> void:
	var history_entry: Dictionary = results.duplicate(true)
	history_entry["successful"] = successful
	history_entry["cariye_name"] = "Oyuncu (harita)"
	history_entry["mission_type"] = m.get_mission_type_name()
	history_entry["difficulty"] = m.get_difficulty_name()
	history_entry["risk_level"] = m.risk_level
	history_entry["target_location"] = m.target_location
	history_entry["distance"] = m.distance
	mission_history.push_front(history_entry)
	if mission_history.size() > 100:
		mission_history = mission_history.slice(0, 100)
	if successful:
		on_mission_completed(mission_id)
	mission_completed.emit(-1, mission_id, successful, results)
	if successful:
		_try_resolve_world_incident_for_completed_mission(m)
		_try_grant_pending_role_for_completed_mission(m)
		post_news("village", get_mission_display_name(m), tr("news.map_mission.success"), Color(0.75, 1.0, 0.75), "success")
	else:
		post_news("village", get_mission_display_name(m), tr("news.map_mission.failed"), Color(1.0, 0.75, 0.75), "warning")

func _compute_expedition_village_split_for_strategy_cost(cost: Dictionary) -> Dictionary:
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var exp_part: Dictionary = {}
	var vil_part: Dictionary = {}
	for k in cost.keys():
		var key: String = str(k)
		var need: int = int(cost[k])
		if need <= 0:
			continue
		if key == "gold":
			var poc: int = 0
			if ps and ps.has_method("get_world_expedition_supplies"):
				poc = int(ps.call("get_world_expedition_supplies").get("world_gold", 0))
			var from_p: int = mini(need, poc)
			var rem_g: int = need - from_p
			if from_p > 0:
				exp_part["world_gold"] = from_p
			if rem_g > 0:
				vil_part["gold"] = int(vil_part.get("gold", 0)) + rem_g
			continue
		if ps and ps.has_method("get_world_expedition_supplies"):
			var wes: Dictionary = ps.call("get_world_expedition_supplies")
			if wes.has(key):
				var have: int = int(wes.get(key, 0))
				var from_e: int = mini(need, have)
				var rem2: int = need - from_e
				if from_e > 0:
					exp_part[key] = from_e
				if rem2 > 0:
					vil_part[key] = int(vil_part.get(key, 0)) + rem2
				continue
		vil_part[key] = int(vil_part.get(key, 0)) + need
	return {"exp": exp_part, "vil": vil_part}

func _can_afford_mixed_strategy_cost(cost: Dictionary) -> bool:
	var split: Dictionary = _compute_expedition_village_split_for_strategy_cost(cost)
	var vil: Dictionary = split.get("vil", {})
	var vm: Node = get_node_or_null("/root/VillageManager")
	if not vil.is_empty():
		if vm == null or not vm.has_method("can_afford_resources"):
			return false
		if not bool(vm.call("can_afford_resources", vil)):
			return false
	return true

func _apply_mixed_strategy_cost(split: Dictionary) -> bool:
	var exp: Dictionary = split.get("exp", {})
	var vil: Dictionary = split.get("vil", {})
	var ps: Node = get_node_or_null("/root/PlayerStats")
	var vm: Node = get_node_or_null("/root/VillageManager")
	if not vil.is_empty():
		if vm == null or not vm.has_method("spend_resources"):
			return false
		if not bool(vm.call("spend_resources", vil)):
			return false
	for k in exp.keys():
		var amt: int = int(exp[k])
		if amt <= 0:
			continue
		if str(k) == "world_gold":
			if ps and ps.has_method("apply_world_expedition_gold_delta"):
				ps.call("apply_world_expedition_gold_delta", -amt)
		else:
			if ps and ps.has_method("add_world_expedition_supplies"):
				ps.call("add_world_expedition_supplies", {str(k): -amt})
	return true

func _build_player_map_strategy_ui_rows(mission: Mission) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i in range(mission.player_map_strategies.size()):
		var raw = mission.player_map_strategies[i]
		if not raw is Dictionary:
			continue
		var cost: Dictionary = {}
		if raw.get("cost") is Dictionary:
			cost = raw["cost"].duplicate(true)
		var chance: float = float(raw.get("success_chance", mission.success_chance))
		var txt: String = _strategy_display_text(raw, i)
		var affordable: bool = _can_afford_mixed_strategy_cost(cost)
		rows.append({
			"index": i,
			"text": txt,
			"cost": cost,
			"success_chance": chance,
			"affordable": affordable
		})
	return rows

## Hedef hex'te strateji seçimi gerektiren (kaynak + metin) görevler.
func get_player_map_strategy_missions_at_hex(q: int, r: int) -> Array[Dictionary]:
	var key: String = str(q) + "," + str(r)
	var out: Array[Dictionary] = []
	for mid in missions.keys():
		var m: Mission = missions[mid] as Mission
		if m == null:
			continue
		if m.status != Mission.Status.MEVCUT:
			continue
		if not m.allow_player_map_completion:
			continue
		_ensure_mission_has_world_objective_hex(m)
		if String(m.world_hex_key) != key:
			continue
		if m.player_map_strategies.is_empty():
			continue
		out.append({
			"mission_id": String(mid),
			"mission_name": get_mission_display_name(m),
			"strategies": _build_player_map_strategy_ui_rows(m)
		})
	return out

## Oyuncu bir strateji seçtikten sonra (hex doğrulanır, kaynak düşülür, zar atılır).
func resolve_player_map_mission_with_strategy(mission_id: String, strategy_index: int, q: int, r: int) -> Dictionary:
	var key: String = str(q) + "," + str(r)
	if mission_id not in missions:
		return {"ok": false, "reason": tr("wm.mission.resolve.not_found")}
	var m: Mission = missions[mission_id] as Mission
	if m == null:
		return {"ok": false, "reason": tr("wm.mission.resolve.invalid")}
	if m.status != Mission.Status.MEVCUT:
		return {"ok": false, "reason": tr("wm.mission.resolve.not_available")}
	if not m.allow_player_map_completion:
		return {"ok": false, "reason": tr("wm.mission.resolve.not_player_map")}
	_ensure_mission_has_world_objective_hex(m)
	if String(m.world_hex_key) != key:
		return {"ok": false, "reason": tr("wm.mission.resolve.wrong_hex")}
	if strategy_index < 0 or strategy_index >= m.player_map_strategies.size():
		return {"ok": false, "reason": tr("wm.mission.resolve.bad_option")}
	var raw = m.player_map_strategies[strategy_index]
	if not raw is Dictionary:
		return {"ok": false, "reason": tr("wm.mission.resolve.bad_strategy")}
	var cost: Dictionary = {}
	if raw.get("cost") is Dictionary:
		cost = raw["cost"].duplicate(true)
	if not _can_afford_mixed_strategy_cost(cost):
		return {"ok": false, "reason": tr("wm.mission.resolve.insufficient"), "affordable": false}
	var split: Dictionary = _compute_expedition_village_split_for_strategy_cost(cost)
	if not _apply_mixed_strategy_cost(split):
		return {"ok": false, "reason": tr("wm.mission.resolve.spend_failed")}
	var chance: float = float(raw.get("success_chance", m.success_chance))
	chance = clampf(chance, 0.05, 0.98)
	var successful: bool = randf() < chance
	var results: Dictionary = m.complete_mission(successful)
	_process_player_map_mission_results(m, successful, results)
	var entry: Dictionary = _build_player_map_resolution_entry(m, successful)
	_append_player_map_mission_history_and_notify(mission_id, m, successful, results)
	mission_list_changed.emit()
	return {"ok": true, "successful": successful, "results": results, "resolution_entry": entry}

func get_world_map_mission_objective_markers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mid in missions.keys():
		var m: Mission = missions[mid] as Mission
		if m == null:
			continue
		if m.status != Mission.Status.MEVCUT:
			continue
		_ensure_mission_has_world_objective_hex(m)
		var hk: String = String(m.world_hex_key)
		if hk.is_empty():
			continue
		var parts: PackedStringArray = hk.split(",")
		if parts.size() != 2:
			continue
		out.append({
			"kind": "mission_objective",
			"mission_id": String(mid),
			"mission_name": get_mission_display_name(m),
			"q": int(parts[0]),
			"r": int(parts[1])
		})
	return out

func try_complete_player_missions_at_hex_with_report(q: int, r: int) -> Dictionary:
	var key: String = str(q) + "," + str(r)
	var done: int = 0
	var to_complete: Array[String] = []
	var entries: Array[Dictionary] = []
	for mid in missions.keys():
		var m: Mission = missions[mid] as Mission
		if m == null:
			continue
		if m.status != Mission.Status.MEVCUT:
			continue
		if not m.allow_player_map_completion:
			continue
		if m.player_map_strategies.size() > 0:
			continue
		_ensure_mission_has_world_objective_hex(m)
		if String(m.world_hex_key) != key:
			continue
		to_complete.append(String(mid))
	for mid_str in to_complete:
		var m2: Mission = missions[mid_str] as Mission
		if m2 == null:
			continue
		var successful: bool = randf() < clampf(float(m2.success_chance), 0.05, 0.98)
		var results: Dictionary = m2.complete_mission(successful)
		_process_player_map_mission_results(m2, successful, results)
		entries.append(_build_player_map_resolution_entry(m2, successful))
		_append_player_map_mission_history_and_notify(mid_str, m2, successful, results)
		done += 1
		break
	if done > 0:
		mission_list_changed.emit()
	return {"done": done, "entries": entries}

func try_complete_player_missions_at_hex(q: int, r: int) -> int:
	var rep: Dictionary = try_complete_player_missions_at_hex_with_report(q, r)
	return int(rep.get("done", 0))

func _build_player_map_resolution_entry(mission: Mission, successful: bool) -> Dictionary:
	var out: Dictionary = {
		"mission_id": String(mission.id),
		"mission_name": get_mission_display_name(mission),
		"successful": successful,
		"gold_delta": 0,
		"expedition_rewards": {},
		"hp_loss": 0.0
	}
	if successful:
		var ex_rewards: Dictionary = {}
		for reward_type in mission.rewards.keys():
			var amount: int = int(mission.rewards[reward_type])
			if String(reward_type) == "gold":
				var gold_gain: int = int(round(float(amount) * PLAYER_MAP_GOLD_REWARD_MULT))
				out["gold_delta"] = int(out.get("gold_delta", 0)) + gold_gain
			elif String(reward_type) in ["food", "medicine"]:
				ex_rewards[String(reward_type)] = int(ex_rewards.get(String(reward_type), 0)) + amount
		out["expedition_rewards"] = ex_rewards
	else:
		out["hp_loss"] = PLAYER_MAP_FAIL_HP_LOSS
		var fail_gold: int = 0
		for penalty_type in mission.penalties.keys():
			if String(penalty_type) == "gold":
				fail_gold += int(mission.penalties[penalty_type])
		out["gold_delta"] = fail_gold
	return out

func _process_player_map_mission_results(mission: Mission, successful: bool, _results: Dictionary) -> void:
	if mission == null:
		return
	if mission.mission_type == Mission.MissionType.TİCARET and mission.has_meta("trade_route_id"):
		return
	if successful:
		for reward_type in mission.rewards:
			var amount = mission.rewards[reward_type]
			if String(reward_type) == "gold":
				amount = int(round(float(int(amount)) * PLAYER_MAP_GOLD_REWARD_MULT))
				var ps_map: Node = get_node_or_null("/root/PlayerStats")
				if ps_map and ps_map.has_method("apply_world_expedition_gold_delta"):
					ps_map.call("apply_world_expedition_gold_delta", int(amount))
				else:
					_apply_reward(reward_type, amount)
			else:
				_apply_reward(reward_type, amount)
	else:
		var ps_fail: Node = get_node_or_null("/root/PlayerStats")
		if ps_fail and ps_fail.has_method("get_current_health") and ps_fail.has_method("set_current_health"):
			var old_h: float = float(ps_fail.get_current_health())
			ps_fail.set_current_health(maxf(1.0, old_h - PLAYER_MAP_FAIL_HP_LOSS), false)
		for penalty_type in mission.penalties:
			var amount = mission.penalties[penalty_type]
			if penalty_type == "cariye_injured":
				var ps: Node = get_node_or_null("/root/PlayerStats")
				if ps and "current_health" in ps:
					ps.current_health = maxf(1.0, float(ps.current_health) - 25.0)
			else:
				_apply_penalty(penalty_type, amount)

func _get_active_mission_progress_ratio(mission_data, total_minutes_now: int) -> float:
	if mission_data is Dictionary:
		var start_minutes: int = int(mission_data.get("started_total_minutes", total_minutes_now))
		var duration_minutes: int = int(round(float(mission_data.get("duration", 120.0))))
		duration_minutes = max(1, duration_minutes)
		return clampf(float(total_minutes_now - start_minutes) / float(duration_minutes), 0.0, 1.0)
	if mission_data and mission_data.has_method("get_remaining_time"):
		var remain: float = float(mission_data.get_remaining_time())
		var duration: float = float(mission_data.duration if "duration" in mission_data else 180.0)
		duration = maxf(1.0, duration)
		return clampf(1.0 - (remain / duration), 0.0, 1.0)
	return 0.0

func _get_mission_name_safe(mission_data, fallback_id: String) -> String:
	if mission_data is Mission:
		return get_mission_display_name(mission_data)
	if fallback_id in missions:
		var stored: Mission = missions[fallback_id] as Mission
		if stored != null:
			return get_mission_display_name(stored)
	if mission_data is Dictionary:
		return get_mission_display_name(mission_data)
	if mission_data and "name" in mission_data:
		return get_mission_display_name(mission_data)
	return fallback_id

func _register_world_map_returning_unit(cariye_id: int, mission_id: String, mission_data) -> void:
	var wm: Node = get_node_or_null("/root/WorldManager")
	var tm: Node = get_node_or_null("/root/TimeManager")
	if not wm or not ("world_map_settlement_positions" in wm):
		return
	var village_pos: Dictionary = _get_world_map_player_village_pos(wm)
	var target_info: Dictionary = _resolve_mission_target_on_world_map(mission_data, wm.world_map_settlement_positions, wm)
	if village_pos.is_empty() or target_info.is_empty():
		return
	var start_q: int = int(target_info.get("q", int(village_pos.get("q", 0))))
	var start_r: int = int(target_info.get("r", int(village_pos.get("r", 0))))
	var target_q: int = int(village_pos.get("q", 0))
	var target_r: int = int(village_pos.get("r", 0))
	var now_minutes: int = 0
	if tm and tm.has_method("get_total_game_minutes"):
		now_minutes = int(tm.call("get_total_game_minutes"))
	var dist: int = _hex_distance_local(start_q, start_r, target_q, target_r)
	var return_duration: int = max(20, dist * 25)
	var cariye_name: String = "Cariye"
	if concubines.has(cariye_id):
		var c = concubines[cariye_id]
		if c and "name" in c:
			cariye_name = String(c.name)
	_world_map_returning_units[cariye_id] = {
		"mission_id": mission_id,
		"mission_name": _get_mission_name_safe(mission_data, mission_id),
		"mission_type_tag": _extract_mission_type_tag(mission_data),
		"cariye_name": cariye_name,
		"start_q": start_q,
		"start_r": start_r,
		"target_q": target_q,
		"target_r": target_r,
		"target_name": "Koy",
		"start_minutes": now_minutes,
		"arrive_minutes": now_minutes + return_duration
	}

func _get_world_map_player_village_pos(wm: Node) -> Dictionary:
	if "world_map_tiles" in wm:
		for key in wm.world_map_tiles.keys():
			var t: Dictionary = wm.world_map_tiles[key]
			if String(t.get("poi_type", "")) == "player_village":
				return {"q": int(t.get("q", 0)), "r": int(t.get("r", 0))}
	if "world_map_player_pos" in wm:
		return {"q": int(wm.world_map_player_pos.get("q", 0)), "r": int(wm.world_map_player_pos.get("r", 0))}
	return {}

func _hex_distance_local(aq: int, ar: int, bq: int, br: int) -> int:
	var asv: int = -aq - ar
	var bsv: int = -bq - br
	return int((abs(aq - bq) + abs(ar - br) + abs(asv - bsv)) / 2)

func _reveal_world_map_for_unit(wm: Node, q: int, r: int, source: String, reveal_radius: int = 1) -> void:
	if wm and wm.has_method("discover_tiles"):
		wm.call("discover_tiles", {"q": q, "r": r}, max(1, reveal_radius), source)

func _extract_mission_type_tag(mission_data) -> String:
	if mission_data is Dictionary:
		return String(mission_data.get("type", "generic")).to_lower()
	if mission_data and "mission_type" in mission_data:
		var mission_type_val = int(mission_data.mission_type)
		match mission_type_val:
			0:
				return "combat"
			1:
				return "exploration"
			2:
				return "diplomacy"
			3:
				return "trade"
			4:
				return "intelligence"
			5:
				return "bureaucracy"
			_:
				return "generic"
	return "generic"

func _get_unit_reveal_radius(wm: Node, q: int, r: int, mission_type_tag: String, returning: bool) -> int:
	var base_radius: int = 1
	match mission_type_tag:
		"exploration", "kesif":
			base_radius = 2
		"intelligence", "istihbarat":
			base_radius = 2
		_:
			base_radius = 1
	if returning:
		base_radius = max(1, base_radius - 1)
	var terrain: String = _get_world_tile_terrain(wm, q, r)
	match terrain:
		"dag":
			base_radius = max(1, base_radius - 1)
		"orman":
			base_radius = max(1, base_radius - 1)
		"ova":
			base_radius = min(3, base_radius + 1)
		_:
			base_radius = base_radius
	return clampi(base_radius, 1, 3)

func _get_world_tile_terrain(wm: Node, q: int, r: int) -> String:
	if not ("world_map_tiles" in wm):
		return ""
	var key: String = str(q) + "," + str(r)
	if not wm.world_map_tiles.has(key):
		return ""
	var tile: Dictionary = wm.world_map_tiles[key]
	return String(tile.get("terrain_type", ""))

func _get_world_path_points(wm: Node, start_q: int, start_r: int, target_q: int, target_r: int) -> Array[Dictionary]:
	if wm and wm.has_method("find_world_map_path"):
		var result: Dictionary = wm.call("find_world_map_path", start_q, start_r, target_q, target_r, "shortest")
		if bool(result.get("ok", false)):
			var raw_path: Array = result.get("path", [])
			var typed_path: Array[Dictionary] = []
			for node in raw_path:
				if node is Dictionary:
					typed_path.append(node)
			if not typed_path.is_empty():
				return typed_path
	return [{"q": start_q, "r": start_r}, {"q": target_q, "r": target_r}]

func _sample_world_position_on_path(path_points: Array[Dictionary], progress: float, fallback_q: int, fallback_r: int) -> Dictionary:
	if path_points.is_empty():
		return {"q": fallback_q, "r": fallback_r}
	if path_points.size() == 1:
		return path_points[0]
	var p: float = clampf(progress, 0.0, 1.0)
	var segment_count: int = path_points.size() - 1
	var scaled: float = p * float(segment_count)
	var idx: int = mini(int(floor(scaled)), segment_count - 1)
	var local_t: float = scaled - float(idx)
	var a: Dictionary = path_points[idx]
	var b: Dictionary = path_points[idx + 1]
	var aq: float = float(a.get("q", fallback_q))
	var ar: float = float(a.get("r", fallback_r))
	var bq: float = float(b.get("q", fallback_q))
	var br: float = float(b.get("r", fallback_r))
	return {
		"q": int(round(lerpf(aq, bq, local_t))),
		"r": int(round(lerpf(ar, br, local_t)))
	}

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
		_apply_chain_rewards(chain.get("rewards", {}))
		if chain_id == RESCUE_CHAIN_ID:
			post_news(
				"village",
				tr("news.rescue_chain.complete.title"),
				tr("news.rescue_chain.complete.body"),
				Color(0.85, 1.0, 0.85),
				"success"
			)
		elif chain_id.begins_with("role_chain_"):
			post_news(
				"village",
				tr("news.role_chain.complete.title"),
				tr("news.role_chain.complete.body"),
				Color(0.85, 0.95, 1.0),
				"success"
			)
		elif chain_id.begins_with("story_chain_"):
			post_news(
				"village",
				tr("news.story_chain.complete.title"),
				tr("news.story_chain.complete.body"),
				Color(1.0, 0.92, 0.98),
				"success"
			)
			var vm: Node = get_node_or_null("/root/VillageManager")
			if vm and "village_morale" in vm:
				vm.village_morale = clampf(float(vm.village_morale) + 5.0, 0.0, 100.0)
		mission_chain_completed.emit(chain_id, chain["rewards"])


func _apply_chain_rewards(rewards: Dictionary) -> void:
	for reward_type in rewards:
		var amount = rewards[reward_type]
		match reward_type:
			"reputation":
				player_reputation = clampi(player_reputation + int(amount), 0, 100)
			"world_stability":
				world_stability = clampi(world_stability + int(amount), 0, 100)
			_:
				_apply_reward(reward_type, amount)

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
			var cm = missions[mission_id]
			if cm is Mission:
				_ensure_mission_has_world_objective_hex(cm)
			chain_missions.append(cm)
	
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

# Görev sistemi altyapısı (şablonlar + dünya olayları; statik placeholder görev yok)
func create_mission_chains():
	create_dynamic_mission_templates()
	_setup_world_event_templates()
	create_initial_world_events()

# --- DİNAMİK GÖREV ÜRETİMİ ---

# Dinamik görev şablonlarını oluştur
func create_dynamic_mission_templates():
	# Savaş görev şablonları
	dynamic_mission_templates["savas"] = {
		"name_keys": [
			"mission.dyn.savas.name.convoy",
			"mission.dyn.savas.name.enemy_swarm",
			"mission.dyn.savas.name.road_ambush",
			"mission.dyn.savas.name.route_clash",
			"mission.dyn.savas.name.enemy_fight",
		],
		"desc_keys": [
			"mission.dyn.savas.desc.convoy",
			"mission.dyn.savas.desc.enemy_ops",
			"mission.dyn.savas.desc.ambush",
			"mission.dyn.savas.desc.route_fight",
			"mission.dyn.savas.desc.convoy_security",
		],
		"location_keys": [
			"mission.dyn.loc.north", "mission.dyn.loc.south",
			"mission.dyn.loc.east", "mission.dyn.loc.west", "mission.dyn.loc.center",
		],
		"enemy_keys": [
			"mission.dyn.enemy.foe", "mission.dyn.enemy.bandit",
			"mission.dyn.enemy.rival", "mission.dyn.enemy.rebel", "mission.dyn.enemy.foreign",
		],
		"base_rewards": {"gold": 14, "wood": 3},
		"base_penalties": {"gold": -6, "cariye_injured": true},
		"difficulty_modifiers": {
			Mission.Difficulty.KOLAY: {"success_chance": 0.8, "duration": 8.0, "reward_multiplier": 0.7},
			Mission.Difficulty.ORTA: {"success_chance": 0.6, "duration": 12.0, "reward_multiplier": 1.0},
			Mission.Difficulty.ZOR: {"success_chance": 0.4, "duration": 18.0, "reward_multiplier": 1.5},
			Mission.Difficulty.EFSANEVİ: {"success_chance": 0.2, "duration": 25.0, "reward_multiplier": 2.0}
		}
	}
	
	# Keşif görev şablonları
	dynamic_mission_templates["kesif"] = {
		"name_keys": [
			"mission.dyn.kesif.name.explore",
			"mission.dyn.kesif.name.survey",
			"mission.dyn.kesif.name.mystery",
			"mission.dyn.kesif.name.resources",
			"mission.dyn.kesif.name.map",
		],
		"desc_keys": [
			"mission.dyn.kesif.desc.explore",
			"mission.dyn.kesif.desc.survey",
			"mission.dyn.kesif.desc.mystery",
			"mission.dyn.kesif.desc.resources",
			"mission.dyn.kesif.desc.map",
		],
		"location_keys": [
			"mission.dyn.place.forest", "mission.dyn.place.mountain",
			"mission.dyn.place.desert", "mission.dyn.place.lake", "mission.dyn.place.cave",
		],
		"area_keys": [
			"mission.dyn.area.unknown", "mission.dyn.area.abandoned",
			"mission.dyn.area.dangerous", "mission.dyn.area.mysterious", "mission.dyn.area.legendary",
		],
		"base_rewards": {"gold": 12, "wood": 2, "stone": 2},
		"base_penalties": {"gold": -4},
		"difficulty_modifiers": {
			Mission.Difficulty.KOLAY: {"success_chance": 0.9, "duration": 6.0, "reward_multiplier": 0.8},
			Mission.Difficulty.ORTA: {"success_chance": 0.7, "duration": 10.0, "reward_multiplier": 1.0},
			Mission.Difficulty.ZOR: {"success_chance": 0.5, "duration": 15.0, "reward_multiplier": 1.3},
			Mission.Difficulty.EFSANEVİ: {"success_chance": 0.3, "duration": 20.0, "reward_multiplier": 1.8}
		}
	}
	
	# Ticaret görev şablonları
	dynamic_mission_templates["ticaret"] = {
		"name_keys": [
			"mission.dyn.ticaret.name.trade",
			"mission.dyn.ticaret.name.resource",
			"mission.dyn.ticaret.name.market",
			"mission.dyn.ticaret.name.deal",
			"mission.dyn.ticaret.name.route",
		],
		"desc_keys": [
			"mission.dyn.ticaret.desc.trade",
			"mission.dyn.ticaret.desc.resource",
			"mission.dyn.ticaret.desc.market",
			"mission.dyn.ticaret.desc.deal",
			"mission.dyn.ticaret.desc.route",
		],
		"location_keys": [
			"mission.dyn.settlement.village", "mission.dyn.settlement.city",
			"mission.dyn.settlement.town", "mission.dyn.settlement.market", "mission.dyn.settlement.port",
		],
		"resource_keys": [
			"resource.gold", "resource.wood", "resource.stone", "resource.food", "resource.weapon",
		],
		"base_rewards": {"gold": 16, "trade_bonus": 0.1},
		"base_penalties": {"gold": -5, "reputation": -2},
		"difficulty_modifiers": {
			Mission.Difficulty.KOLAY: {"success_chance": 0.8, "duration": 8.0, "reward_multiplier": 0.8},
			Mission.Difficulty.ORTA: {"success_chance": 0.6, "duration": 12.0, "reward_multiplier": 1.0},
			Mission.Difficulty.ZOR: {"success_chance": 0.4, "duration": 16.0, "reward_multiplier": 1.4},
			Mission.Difficulty.EFSANEVİ: {"success_chance": 0.2, "duration": 22.0, "reward_multiplier": 2.0}
		}
	}
	
	print("🎲 Dinamik görev şablonları oluşturuldu")

# Başlangıç dünya olay şablonları (UI'da görünmez; yalnızca tetiklenince aktif olur)
func _setup_world_event_templates() -> void:
	world_event_templates = [
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
			"mission_modifiers": {"diplomasi": {"success_chance": 0.1, "rewards": {"gold": 5}}}
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


func create_initial_world_events() -> void:
	world_events.clear()

# --- DİNAMİK GÖREV ÜRETİMİ ---
func create_dynamic_mission(mission_type: String, difficulty: Mission.Difficulty = Mission.Difficulty.ORTA) -> Mission:
	if mission_type not in dynamic_mission_templates:
		return null
	
	var template = dynamic_mission_templates[mission_type]
	var mission = Mission.new()
	
	# Benzersiz ID oluştur
	mission.id = "dynamic_" + mission_type + "_" + str(next_mission_id)
	next_mission_id += 1
	
	# Rastgele isim ve açıklama seç (locale anahtarları)
	var name_key: String = template["name_keys"][randi() % template["name_keys"].size()]
	var desc_key: String = template["desc_keys"][randi() % template["desc_keys"].size()]
	var var_keys := _pick_dynamic_template_vars(template)
	mission.locale_name_key = name_key
	mission.locale_desc_key = desc_key
	mission.locale_vars = var_keys
	mission.name = _tr_mission_template(name_key, var_keys)
	mission.description = _tr_mission_template(desc_key, var_keys)
	
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
	if template.has("location_keys"):
		var loc_key: String = template["location_keys"][randi() % template["location_keys"].size()]
		mission.target_location = tr(loc_key)
	else:
		mission.target_location = tr("common.unknown")
	mission.distance = randf_range(1.0, 5.0)
	mission.risk_level = calculate_risk_level(difficulty, mission_type)
	_populate_default_player_map_strategies(mission, mission_type)
	_ensure_mission_has_world_objective_hex(mission)
	mission.set_meta("dynamic_type", mission_type)
	
	return mission

func _populate_default_player_map_strategies(mission: Mission, mission_type: String) -> void:
	if mission == null or mission.player_map_strategies.size() > 0:
		return
	match mission_type:
		"savas":
			mission.player_map_strategies = [
				{"text_key": "mission.strategy.savas.0", "cost": {"food": 5}, "success_chance": 0.25},
				{"text_key": "mission.strategy.savas.1", "cost": {"food": 15}, "success_chance": 0.5},
				{"text_key": "mission.strategy.savas.2", "cost": {"food": 10, "medicine": 5}, "success_chance": 0.75}
			]
		"kesif":
			mission.player_map_strategies = [
				{"text_key": "mission.strategy.kesif.0", "cost": {"food": 6}, "success_chance": 0.35},
				{"text_key": "mission.strategy.kesif.1", "cost": {"food": 13}, "success_chance": 0.55},
				{"text_key": "mission.strategy.kesif.2", "cost": {"food": 25}, "success_chance": 0.8}
			]
		"ticaret":
			mission.player_map_strategies = [
				{"text_key": "mission.strategy.ticaret.0", "cost": {"food": 1}, "success_chance": 0.32},
				{"text_key": "mission.strategy.ticaret.1", "cost": {"gold": 12}, "success_chance": 0.52},
				{"text_key": "mission.strategy.ticaret.2", "cost": {"food": 1, "gold": 20}, "success_chance": 0.68}
			]
		_:
			pass

# Şablon değişken anahtarlarını seç
func _pick_dynamic_template_vars(template: Dictionary) -> Dictionary:
	var var_keys := {}
	if template.has("location_keys"):
		var_keys["location"] = template["location_keys"][randi() % template["location_keys"].size()]
	if template.has("enemy_keys"):
		var_keys["enemy"] = template["enemy_keys"][randi() % template["enemy_keys"].size()]
	if template.has("area_keys"):
		var_keys["area"] = template["area_keys"][randi() % template["area_keys"].size()]
	if template.has("resource_keys"):
		var_keys["resource"] = template["resource_keys"][randi() % template["resource_keys"].size()]
	return var_keys


# Şablon doldurma (legacy)
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
	for event in get_active_world_events():
		if not (event is Dictionary):
			continue
		if not "mission_modifiers" in event or mission_type not in event["mission_modifiers"]:
			continue
		var modifiers = event["mission_modifiers"][mission_type]
		if "success_chance" in modifiers:
			mission.success_chance += modifiers["success_chance"]
			mission.success_chance = clamp(mission.success_chance, 0.1, 0.95)
		if "duration" in modifiers:
			mission.duration += modifiers["duration"]
			mission.duration = max(180.0, mission.duration)
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
			resources["gold"] = 6
		"kesif":
			resources["gold"] = 4
		"ticaret":
			resources["gold"] = 5
	
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
	
	# Bandit Activity etkisi: Tüm görevler daha tehlikeli
	if bandit_activity_active:
		risk_score += (bandit_risk_level + 1)  # +1 (LOW), +2 (MEDIUM), +3 (HIGH)
	
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


## Köy seyyah olayı: gerçek bir dinamik görev teklif eder (haber-only değil).
func offer_traveler_mission() -> Mission:
	var mission_types: Array[String] = ["savas", "kesif", "ticaret"]
	var selected_type: String = mission_types[randi() % mission_types.size()]
	var max_cariye_level: int = get_max_concubine_level()
	var selected_difficulty: Mission.Difficulty = Mission.Difficulty.KOLAY
	if max_cariye_level >= 3 and randf() < 0.35:
		selected_difficulty = Mission.Difficulty.ORTA
	var mission: Mission = create_dynamic_mission(selected_type, selected_difficulty)
	if mission == null:
		return null
	mission.id = "traveler_%d" % next_mission_id
	next_mission_id += 1
	var type_prefix: Dictionary = {
		"savas": "Seyyahın Savaş İpucu",
		"kesif": "Seyyahın Keşif Notu",
		"ticaret": "Seyyahın Ticaret Fırsatı",
	}
	var prefix: String = String(type_prefix.get(selected_type, "Seyyah Görevi"))
	mission.name = "%s: %s" % [prefix, mission.name]
	mission.description = "Köyünüze uğrayan bir seyyah şunu anlattı — %s" % mission.description
	mission.set_meta("traveler_offer", true)
	if try_enqueue_mission_spawn(mission, "village_surface_traveler", {
		"post_news": false,
		"brief_extra": {"traveler": true},
		"mechanical_mission": {
			"title": mission.name,
			"body": mission.description,
			"settlement_name": mission.target_location,
		},
	}):
		print("[MissionManager] Seyyah görevi (pipeline): %s" % mission.name)
		return mission
	missions[mission.id] = mission
	print("[MissionManager] Seyyah görevi: %s" % mission.name)
	return mission


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
		if mission is Dictionary:
			var status_text: String = String(mission.get("status", "")).to_lower()
			var is_available_dict: bool = status_text == "available" or status_text == "mevcut"
			if is_available_dict:
				missions_to_remove.append(mission_id)
		else:
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
			if try_enqueue_mission_spawn(new_mission, "dynamic_mission", {"post_news": false}):
				print("✨ Yeni dinamik görev (pipeline): " + new_mission.name)
			else:
				missions[new_mission.id] = new_mission
				print("✨ Yeni dinamik görev: " + new_mission.name)
	
	print("🔄 Görev rotasyonu tamamlandı")

# --- DÜNYA OLAYLARI YÖNETİMİ ---

# Dünya olayları timer'ı
var world_events_timer: float = 0.0
var world_events_interval: float = 120.0  # 2 dakikada bir dünya olayı kontrolü

func _world_event_elapsed_duration(event: Dictionary) -> Dictionary:
	var tm: Node = get_node_or_null("/root/TimeManager")
	if tm and tm.has_method("get_total_game_minutes") and event.has("start_game_minutes"):
		var now: int = int(tm.get_total_game_minutes())
		var start_g: int = int(event.get("start_game_minutes", 0))
		var dur_g: int = int(event.get("duration_game_minutes", int(event.get("duration", 60))))
		return {"elapsed": float(now - start_g), "duration": float(max(1, dur_g)), "use_game": true}
	if event.has("start_time"):
		var elapsed_rt: float = float(Time.get_unix_time_from_system()) - float(event["start_time"])
		var dur_rt: float = float(event.get("duration", 60.0))
		return {"elapsed": elapsed_rt, "duration": dur_rt, "use_game": false}
	return {"elapsed": 0.0, "duration": -1.0, "use_game": false}

# Dünya olaylarını işle (gerçek zamanlı: yalnızca süresi dolanları kapat)
func _expire_world_events_only() -> void:
	var active_events: Array[Dictionary] = []
	for event in world_events:
		var td: Dictionary = _world_event_elapsed_duration(event)
		if float(td.get("duration", -1.0)) < 0.0:
			continue
		var elapsed: float = float(td.get("elapsed", 0.0))
		var dur: float = float(td.get("duration", 1.0))
		if elapsed < dur:
			active_events.append(event)
		else:
			end_world_event(event)
	world_events = active_events

func update_world_events(delta: float) -> void:
	world_events_timer += delta
	if world_events_timer >= world_events_interval:
		world_events_timer = 0.0
		_expire_world_events_only()

func _maybe_roll_daily_world_event(day: int) -> void:
	if day - _last_world_event_spawn_day < DAILY_WORLD_EVENT_MIN_GAP_DAYS:
		return
	if not get_active_world_events().is_empty():
		return
	if randf() > DAILY_WORLD_EVENT_SPAWN_CHANCE:
		return
	start_random_world_event()
	_last_world_event_spawn_day = day

# Dünya olaylarını işle (legacy — günlük tick dışında çağrılmasın)
func process_world_events():
	_expire_world_events_only()

func post_news(category: String, title: String, content: String, color: Color = Color.WHITE, subcategory: String = "info", flags: Dictionary = {}):
	if _is_world_news_category(category) and not can_publish_world_news(flags):
		return
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
	
	# Oyun zamanını da sakla (oyun dakikası cinsinden)
	var game_time_minutes = 0
	if tm and tm.has_method("get_total_game_minutes"):
		game_time_minutes = tm.get_total_game_minutes()
	
	var news = {
		"id": _next_news_id,
		"category": category,
		"subcategory": subcategory,
		"title": final_title,
		"content": content,
		"time": time_text,
		"timestamp": int(Time.get_unix_time_from_system()),  # Geriye dönük uyumluluk için
		"game_time_minutes": game_time_minutes,  # Oyun zamanı (oyun dakikası)
		"color": emphasis_color,
		"original_color": color,
		"priority": priority,
		"read": false
	}
	_next_news_id += 1
	
	# Haberleri kuyruklara ekle
	var is_village = category in ["Başarı", "Bilgi", "village"]
	
	# <<< YENİ: Haberi hemen NPC'lere dağıt >>>
	if VillagerAiInitializer:
		# Send news without icon to save context
		var news_str = "%s: %s" % [title, content]
		print("MissionManager: Sending news to NPCs: ", news_str)
		VillagerAiInitializer.update_latest_news(news_str)
	
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

func _on_time_advanced(total_minutes: int, start_day: int, start_hour: int, start_minute: int) -> void:
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	var end_day: int = start_day
	if tm.has_method("get_day"):
		end_day = tm.get_day()
	var minutes_per_hour: int = 60
	var hours_per_day: int = 24
	if "MINUTES_PER_HOUR" in tm:
		minutes_per_hour = tm.MINUTES_PER_HOUR
	if "HOURS_PER_DAY" in tm:
		hours_per_day = tm.HOURS_PER_DAY
	var total_hours: float = float(total_minutes) / float(minutes_per_hour)
	var total_days: float = total_hours / float(hours_per_day)
	var current_day: int = start_day
	for i in range(int(total_days) + 1):
		if current_day <= end_day:
			_on_new_day(current_day)
		current_day += 1
	_update_active_missions_during_skip(total_hours)

func _update_active_missions_during_skip(total_hours: float) -> void:
	var completed_missions_list: Array = []
	for cariye_id in active_missions.keys():
		var mission_id = active_missions.get(cariye_id, "")
		if mission_id.is_empty():
			continue
		if not missions.has(mission_id):
			continue
		var mission = missions.get(mission_id)
		if not mission:
			continue
		if not mission.has_method("get_remaining_time"):
			continue
		var remaining_time = mission.get_remaining_time()
		if remaining_time <= 0.0:
			continue
		var new_remaining = remaining_time - total_hours
		if new_remaining <= 0.0:
			new_remaining = 0.0
			completed_missions_list.append({"cariye_id": cariye_id, "mission_id": mission_id})
		if mission.has_method("set_remaining_time"):
			mission.set_remaining_time(new_remaining)
		elif "remaining_time" in mission:
			mission.remaining_time = new_remaining
	for entry in completed_missions_list:
		var cariye_id: int = entry.get("cariye_id", -1)
		var mission_id: String = entry.get("mission_id", "")
		if cariye_id < 0 or mission_id.is_empty():
			continue
		if not missions.has(mission_id):
			active_missions.erase(cariye_id)
			continue
		var mission = missions.get(mission_id)
		if not mission:
			active_missions.erase(cariye_id)
			continue
		if not concubines.has(cariye_id):
			active_missions.erase(cariye_id)
			continue
		var cariye = concubines[cariye_id]
		if not cariye:
			active_missions.erase(cariye_id)
			continue
		var success_chance: float = 0.5
		if cariye.has_method("calculate_mission_success_chance"):
			success_chance = cariye.calculate_mission_success_chance(mission)
		var successful: bool = randf() < success_chance
		if mission.has_method("complete_mission"):
			var results = mission.complete_mission(successful)
			if cariye.has_method("complete_mission"):
				cariye.complete_mission(successful, mission_id)
			if has_method("process_mission_results"):
				process_mission_results(cariye_id, mission_id, successful, results)
			if successful:
				on_mission_completed(mission_id)
			mission_completed.emit(cariye_id, mission_id, successful, results)
			if successful and mission is Mission:
				_try_resolve_world_incident_for_completed_mission(mission as Mission)
				_try_grant_pending_role_for_completed_mission(mission as Mission)
		_register_world_map_returning_unit(cariye_id, mission_id, mission)
		active_missions.erase(cariye_id)

## Gün sonu: süreli üretim/tüccar/modifikator; `silent` yüklemelerde haber atmadan temizlik.
func prune_time_limited_state_for_day(day: int, silent: bool = false) -> void:
	var remaining_rm: Array[Dictionary] = []
	for m in active_rate_modifiers:
		if not m.has("expires_day") or int(m["expires_day"]) >= day:
			remaining_rm.append(m)
		elif not silent:
			post_news("world", tr("news.effect_ended.title"), tr("news.effect_ended.body") % [LocaleManager.get_resource_name(str(m.get("resource", "?"))), int(m.get("delta", 0))], Color(0.8, 0.8, 0.8), "info")
	active_rate_modifiers = remaining_rm

	var old_trader_count: int = active_traders.size()
	var remaining_traders: Array[Dictionary] = []
	for trader in active_traders:
		var leaves_day: int = int(trader.get("leaves_day", day + 1))
		if leaves_day > day:
			remaining_traders.append(trader)
		elif not silent:
			var trader_name = trader.get("name", tr("mc.trade.default_trader"))
			post_news("village", tr("news.trader_left.title"), tr("news.trader_left.body") % trader_name, Color(0.8, 0.8, 1), "info")
	active_traders = remaining_traders
	if active_traders.size() != old_trader_count:
		active_traders_updated.emit()

	_clean_expired_settlement_modifiers(day)

func _on_new_day(day: int):
	prune_time_limited_state_for_day(day, false)

	# Haritadaki komsu id'leri: WM `get_relation("Köy", ad)` tek kaynak; eski rastgele drift sadece haritada olmayanlara.
	sync_settlement_relations_from_world_map()
	for s in settlements:
		if not _mm_settlement_on_world_map(s.get("id", "")):
			var drel: int = randi_range(-2, 2)
			s["relation"] = clamp(int(s.get("relation", 50)) + drel, 0, 100)
		var dstab: int = randi_range(-1, 1)
		s["stability"] = clamp(int(s.get("stability", 70)) + dstab, 0, 100)

	# Olası çatışmaları simüle et ve görevlere yansıt
	_simulate_conflicts()

	# Ekonomik/diplomatik rastgele olaylar (seyrek)
	if randf() < 0.06:
		_trigger_trade_caravan()
	if world_stability < 45 and randf() < 0.10:
		_trigger_bandit_activity()
	if randf() < 0.05:
		_trigger_random_festival()
	_maybe_spawn_daily_dynamic_mission(day)
	_maybe_roll_daily_world_event(day)
	if world_stability < 35 and randf() < 0.06:
		_trigger_plague()
	if settlements.size() >= 2 and randf() < 0.05:
		_trigger_embargo_between_settlements()

func _count_available_non_chain_missions() -> int:
	var n: int = 0
	for mission_id in missions:
		var mission = missions[mission_id]
		if mission is Dictionary:
			var status_text: String = String(mission.get("status", "")).to_lower()
			if status_text == "available" or status_text == "mevcut":
				n += 1
			continue
		if mission == null:
			continue
		if mission.status != Mission.Status.MEVCUT:
			continue
		if mission.has_method("is_part_of_chain") and mission.is_part_of_chain():
			continue
		n += 1
	return n

func _maybe_spawn_daily_dynamic_mission(day: int) -> void:
	if day < _next_daily_dynamic_spawn_day:
		return
	if _count_available_non_chain_missions() >= DAILY_DYNAMIC_MAX_AVAILABLE:
		# Slot doluysa yarına tekrar dene.
		_next_daily_dynamic_spawn_day = day + 1
		return
	if randf() > DAILY_DYNAMIC_SPAWN_CHANCE:
		# Bugün spawn atlandıysa ertesi gün tekrar dene.
		_next_daily_dynamic_spawn_day = day + 1
		return
	var m: Mission = generate_random_dynamic_mission()
	if m == null:
		_next_daily_dynamic_spawn_day = day + 1
		return
	if try_enqueue_mission_spawn(m, "dynamic_mission", {
		"news_override": {
			"title": tr("news.new_map_mission.title"),
			"body": tr("news.new_map_mission.body") % get_mission_display_name(m),
			"category": "Dünya",
			"color": Color(0.9, 0.96, 1.0),
			"subcategory": "info",
		},
	}):
		_next_daily_dynamic_spawn_day = day + (1 if randf() < 0.62 else 2)
		return
	missions[m.id] = m
	mission_list_changed.emit()
	post_news("world", tr("news.new_map_mission.title"), tr("news.new_map_mission.body") % get_mission_display_name(m), Color(0.9, 0.96, 1.0), "info")
	# Bazen ertesi gün, bazen 2 gün sonra yeni görev.
	_next_daily_dynamic_spawn_day = day + (1 if randf() < 0.62 else 2)

func _simulate_conflicts():
	if settlements.size() < 2:
		return
	# Olasılık: dünya istikrarı ve genel gerginliğe bağlı
	var instability: float = 1.0 - float(world_stability) / 100.0
	var chance: float = clamp(0.04 + instability * 0.12, 0.03, 0.18)
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
		if not _mm_settlement_on_world_map(attacker.get("id", "")):
			attacker["relation"] = clamp(int(attacker.get("relation", 50)) - 3, 0, 100)
		if not _mm_settlement_on_world_map(defender.get("id", "")):
			defender["relation"] = clamp(int(defender.get("relation", 50)) - 6, 0, 100)
		defender["stability"] = clamp(int(defender.get("stability", 60)) - (2 if event_type != "skirmish" else 1), 10, 100)
	else:
		attacker["military"] = max(5, int(attacker.get("military", 30)) - loss_def)
		defender["military"] = max(5, int(defender.get("military", 30)) - loss_att)
		if not _mm_settlement_on_world_map(attacker.get("id", "")):
			attacker["relation"] = clamp(int(attacker.get("relation", 50)) - 6, 0, 100)
		if not _mm_settlement_on_world_map(defender.get("id", "")):
			defender["relation"] = clamp(int(defender.get("relation", 50)) - 3, 0, 100)
		attacker["stability"] = clamp(int(attacker.get("stability", 60)) - 1, 10, 100)
	# Haberler
	var at_name: String = attacker.get("name", "?")
	var df_name: String = defender.get("name", "?")
	var kind_text: String = ("sınır çatışması" if event_type == "skirmish" else ("baskın" if event_type == "raid" else "kuşatma"))
	if not try_enqueue_news("conflict_start", {
		"attacker": at_name,
		"defender": df_name,
		"event_type": event_type,
		"kind_text": kind_text,
	}, {
		"title": tr("news.conflict.start.title") % [at_name, kind_text, df_name],
		"body": tr("news.conflict.start.body") % [at_name, df_name],
		"category": "Dünya",
		"color": Color(1, 0.85, 0.8),
		"subcategory": "warning",
	}):
		post_news("world", tr("news.conflict.start.title") % [at_name, kind_text, df_name], tr("news.conflict.start.body") % [at_name, df_name], Color(1, 0.85, 0.8), "warning")
	var outcome: String = "%s üstün geldi" % at_name if attacker_wins else "%s saldırıyı püskürttü" % df_name
	var details: String = "Kayıplar - Saldıran:%d, Savunan:%d" % [loss_att, loss_def]
	if not try_enqueue_news("conflict_result", {
		"outcome": outcome,
		"details": details,
		"event_type": event_type,
		"kind_text": kind_text,
	}, {
		"title": tr("news.conflict.result.title") % outcome,
		"body": tr("news.conflict.result.body") % [details, kind_text],
		"category": "Dünya",
		"color": Color(1, 0.95, 0.7),
		"subcategory": "info",
	}):
		post_news("world", tr("news.conflict.result.title") % outcome, tr("news.conflict.result.body") % [details, kind_text], Color(1, 0.95, 0.7), "info")
	_create_conflict_missions(attacker, defender, event_type)
	if attacker_wins and randf() < 0.4:
		_add_settlement_trade_modifier(df_name, 1.25, 2, true, "conflict")

func _create_conflict_missions(attacker: Dictionary, defender: Dictionary, event_type: String = "skirmish"):
	var at_name: String = String(attacker.get("name", "?"))
	var df_name: String = String(defender.get("name", "?"))
	var defend := Mission.new()
	defend.id = "defend_%d" % Time.get_unix_time_from_system()
	defend.name = "Savunma Yardımı: %s" % df_name
	defend.description = "%s'nin saldırısına karşı %s'yi savun." % [at_name, df_name]
	defend.mission_type = Mission.MissionType.SAVAŞ
	defend.difficulty = Mission.Difficulty.ORTA
	defend.duration = 240.0
	defend.success_chance = 0.6
	defend.required_cariye_level = 2
	defend.required_army_size = 4
	defend.required_resources = {"gold": 8}
	defend.rewards = {"gold": 16, "wood": 3}
	defend.penalties = {"gold": -6}
	defend.target_location = df_name
	defend.status = Mission.Status.MEVCUT
	if not try_enqueue_mission_spawn(defend, "conflict_defend", {
		"post_news": false,
		"brief_extra": {"attacker": at_name, "defender": df_name, "situation": {"type": event_type}},
	}):
		missions[defend.id] = defend

	var raid := Mission.new()
	raid.id = "raid_%d" % (Time.get_unix_time_from_system() + 1)
	raid.name = "Yağma Fırsatı: %s" % df_name
	raid.description = "%s ve %s arasındaki kaostan faydalanarak kaynak yağmala." % [at_name, df_name]
	raid.mission_type = Mission.MissionType.SAVAŞ
	raid.difficulty = Mission.Difficulty.KOLAY
	raid.duration = 180.0
	raid.success_chance = 0.7
	raid.required_cariye_level = 1
	raid.required_army_size = 3
	raid.required_resources = {"gold": 5}
	raid.rewards = {"gold": 12, "stone": 2}
	raid.penalties = {"gold": -5, "reputation": -2}
	raid.target_location = df_name
	raid.status = Mission.Status.MEVCUT
	if try_enqueue_mission_spawn(raid, "conflict_raid", {
		"news_override": {
			"title": tr("news.raid_opportunity.title"),
			"body": tr("news.raid_opportunity.body"),
			"category": "village",
			"color": Color(0.8, 1, 0.8),
			"subcategory": "info",
		},
		"brief_extra": {"attacker": at_name, "defender": df_name},
	}):
		return
	missions[raid.id] = raid
	post_news("village", tr("news.raid_opportunity.title"), tr("news.raid_opportunity.body"), Color(0.8, 1, 0.8), "info")

# ESKİ FONKSİYON KALDIRILDI: cancel_trade_agreement_by_index
# Artık ticaret anlaşmaları yok, sadece aktif tüccarlar var

# Rastgele dünya olayı başlat
func start_random_world_event():
	var active_ids: Dictionary = {}
	for event in world_events:
		var td: Dictionary = _world_event_elapsed_duration(event)
		if float(td.get("duration", -1.0)) >= 0.0 and float(td.get("elapsed", 0.0)) < float(td.get("duration", 1.0)):
			active_ids[String(event.get("id", ""))] = true
	
	var available_events: Array[Dictionary] = []
	for template in world_event_templates:
		var eid := String(template.get("id", ""))
		if eid.is_empty() or active_ids.has(eid):
			continue
		available_events.append(template)
	
	if available_events.is_empty():
		return
	
	var selected_event: Dictionary = available_events[randi() % available_events.size()].duplicate(true)
	var tm_start: Node = get_node_or_null("/root/TimeManager")
	if tm_start and tm_start.has_method("get_total_game_minutes"):
		selected_event["start_game_minutes"] = int(tm_start.call("get_total_game_minutes"))
		selected_event["duration_game_minutes"] = int(selected_event.get("duration", 45))
	else:
		selected_event["start_time"] = Time.get_unix_time_from_system()
	world_events.append(selected_event)
	var eid: String = String(selected_event.get("id", ""))
	var evt_title: String = get_world_event_display_name(selected_event)
	var evt_body: String = get_world_event_display_description(selected_event)
	if not try_enqueue_news("world_event", {
		"event_type": eid,
		"id": eid,
	}, {
		"title": evt_title,
		"body": evt_body,
		"category": "Dünya",
		"color": Color(1, 0.8, 0.8),
		"subcategory": "warning",
	}):
		post_news("world", evt_title, evt_body, Color(1, 0.8, 0.8), "warning")

# Dünya olayını sonlandır
func end_world_event(event: Dictionary):
	var ended_name := get_world_event_display_name(event)
	world_events.erase(event)
	post_news("world", tr("news.world_event_ended.title") % ended_name, tr("news.world_event_ended.body"), Color(0.8, 0.8, 0.8), "info")

# Aktif dünya olaylarını al
func get_active_world_events() -> Array:
	var active = []
	for event in world_events:
		var td: Dictionary = _world_event_elapsed_duration(event)
		if float(td.get("duration", -1.0)) < 0.0:
			continue
		if float(td.get("elapsed", 0.0)) < float(td.get("duration", 1.0)):
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
	post_news("world", tr("news.production_effect.title"), tr("news.production_effect.body") % [LocaleManager.get_resource_name(resource), sign, delta, source], Color(0.8, 0.8, 1), "info")

# === YENİ TÜCCAR SİSTEMİ ===

# Tüccar tipleri
enum TraderType { NORMAL, RICH, POOR, SPECIAL, NOMAD }

# Köye yeni bir tüccar ekle (event tarafından çağrılır)
func add_active_trader(origin_settlement: Dictionary, arrives_day: int, stays_days: int = 3, trader_type: TraderType = TraderType.NORMAL) -> Dictionary:
	if settlements.is_empty():
		create_settlements()
	
	var settlement_name = origin_settlement.get("name", "Bilinmeyen Köy")
	var relation = int(origin_settlement.get("relation", 50))
	
	# Tüccar tipine göre konfigürasyon al
	var trader_config = _get_trader_config(trader_type, relation, origin_settlement)
	
	# Tüccar ismi oluştur (tipine göre)
	var trader_name = _generate_trader_name(trader_type)
	
	# Tüccarın sattığı ürünler (tipine göre)
	var products = _generate_trader_products(trader_type, relation, origin_settlement, trader_config)
	
	var trader = {
		"id": "trader_%d" % Time.get_unix_time_from_system(),
		"name": trader_name,
		"type": trader_type,
		"origin_settlement": settlement_name,
		"origin_settlement_id": origin_settlement.get("id", ""),
		"products": products,
		"arrives_day": arrives_day,
		"leaves_day": arrives_day + trader_config["stays_days"],
		"relation_multiplier": trader_config["relation_multiplier"],
		"relation": relation
	}
	
	active_traders.append(trader)
	active_traders_updated.emit()
	
	var product_text = ""
	for p in products:
		var res_name = _get_resource_display_name(p["resource"])
		product_text += "%s (%d altın), " % [res_name, p["price_per_unit"]]
	product_text = product_text.substr(0, product_text.length() - 2)  # Son virgülü kaldır
	
	var type_name = _get_trader_type_name(trader_type)
	_post_news_tr("village", "news.trader_arrived.title", "news.trader_arrived.body", Color(0.8, 1, 0.8), "success", [type_name, trader_name, product_text])
	
	return trader

# Tüccar tipine göre konfigürasyon al
func _get_trader_config(trader_type: TraderType, relation: int, origin_settlement: Dictionary) -> Dictionary:
	match trader_type:
		TraderType.RICH:
			return {
				"stays_days": 3,
				"relation_multiplier": 1.0 - ((relation - 50) * 0.004),  # Daha fazla indirim
				"product_count": randi_range(3, 4),
				"price_range": [80, 150]  # Daha pahalı
			}
		TraderType.POOR:
			return {
				"stays_days": 2,
				"relation_multiplier": 1.0 - ((relation - 50) * 0.002),  # Daha az indirim
				"product_count": randi_range(1, 2),
				"price_range": [30, 70]  # Daha ucuz
			}
		TraderType.SPECIAL:
			var special_resource = _get_settlement_special_resource(origin_settlement)
			return {
				"stays_days": 3,
				"relation_multiplier": 1.0 - ((relation - 50) * 0.005),  # Çok fazla indirim
				"product_count": randi_range(2, 3),
				"price_range": [40, 100],
				"special_resource": special_resource
			}
		TraderType.NOMAD:
			return {
				"stays_days": randi_range(4, 6),
				"relation_multiplier": 1.0 - ((relation - 50) * 0.003),
				"product_count": randi_range(4, 5),
				"price_range": [50, 120]
			}
		_:  # NORMAL
			return {
				"stays_days": 3,
				"relation_multiplier": 1.0 - ((relation - 50) * 0.003),
				"product_count": randi_range(2, 3),
				"price_range": [50, 130]
			}

# Yerleşimin özel kaynağını al (bias'a göre)
func _get_settlement_special_resource(settlement: Dictionary) -> String:
	var biases = settlement.get("biases", {})
	if biases.is_empty():
		return "food"  # Varsayılan
	
	# En yüksek bias'a sahip kaynağı bul
	var max_bias = 0
	var special_resource = "food"
	for resource in biases.keys():
		var bias_value = int(biases[resource])
		if bias_value > max_bias:
			max_bias = bias_value
			special_resource = resource
	
	return special_resource

# Tüccar ismi oluştur (tipine göre)
func _generate_trader_name(trader_type: TraderType) -> String:
	var prefixes: Array[String] = []
	var first_names = ["Ahmet", "Mehmet", "Ali", "Hasan", "Hüseyin", "İbrahim", "Mustafa", "Osman"]
	
	match trader_type:
		TraderType.RICH:
			prefixes = ["Zengin", "Varlıklı", "Büyük", "Ünlü"]
		TraderType.POOR:
			prefixes = ["Fakir", "Küçük", "Seyyar", "Yoksul"]
		TraderType.SPECIAL:
			prefixes = ["Uzman", "Özel", "Nadir", "Değerli"]
		TraderType.NOMAD:
			prefixes = ["Gezgin", "Göçebe", "Seyyah", "Dolaşan"]
		_:  # NORMAL
			prefixes = ["Normal"]
	
	first_names.shuffle()
	prefixes.shuffle()
	return prefixes[0] + " " + first_names[0] + " Tüccar"

# Tüccar ürünleri oluştur
func _generate_trader_products(trader_type: TraderType, relation: int, origin_settlement: Dictionary, config: Dictionary) -> Array[Dictionary]:
	var products: Array[Dictionary] = []
	var available_resources = ["food", "wood", "stone"]
	available_resources.shuffle()
	
	var product_count = config.get("product_count", 2)
	var price_range = config.get("price_range", [50, 130])
	var relation_multiplier = config.get("relation_multiplier", 1.0)
	
	# Özel tüccar için özel ürün ekle
	if trader_type == TraderType.SPECIAL:
		var special_resource = config.get("special_resource", "food")
		if not special_resource in available_resources:
			available_resources.append(special_resource)
		# Özel ürünü başa ekle
		available_resources.erase(special_resource)
		available_resources.insert(0, special_resource)
	
	for i in range(min(product_count, available_resources.size())):
		var resource = available_resources[i]
		var base_price = price_range[0] + randi_range(0, price_range[1] - price_range[0])
		
		# Özel tüccar için özel ürün indirimli
		if trader_type == TraderType.SPECIAL and resource == config.get("special_resource", ""):
			base_price = int(base_price * 0.7)  # %30 indirim
		
		var final_price = int(base_price * relation_multiplier)
		
		products.append({
			"resource": resource,
			"price_per_unit": final_price,
			"base_price": base_price
		})
	
	return products

# Tüccar tipi ismini al
func _get_trader_type_name(trader_type: TraderType) -> String:
	match trader_type:
		TraderType.RICH: return "Zengin Tüccar"
		TraderType.POOR: return "Fakir Tüccar"
		TraderType.SPECIAL: return "Özel Ürün Tüccarı"
		TraderType.NOMAD: return "Gezgin Tüccar"
		_: return "Tüccar"

# Aktif tüccarları al
func get_active_traders() -> Array[Dictionary]:
	return active_traders.duplicate(true)

# Tüccardan ürün satın al
func buy_from_trader(trader_id: String, resource: String, quantity: int) -> bool:
	var trader: Dictionary = {}
	for t in active_traders:
		if t.get("id") == trader_id:
			trader = t
			break
	
	if trader.is_empty():
		return false
	
	# Ürünü bul
	var product: Dictionary = {}
	for p in trader.get("products", []):
		if p.get("resource") == resource:
			product = p
			break
	
	if product.is_empty():
		return false

	var vce := get_node_or_null("/root/VillageCardEffects")
	if vce and vce.is_resource_trade_blocked(resource):
		return false

	var price_per_unit = int(product.get("price_per_unit", 0))
	var total_cost = price_per_unit * quantity
	
	# Altın kontrolü
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if not gpd or gpd.gold < total_cost:
		return false
	
	# Ödeme yap
	gpd.gold -= total_cost
	
	# Kaynak ekle
	var vm = get_node_or_null("/root/VillageManager")
	if vm:
		var current = vm.resource_levels.get(resource, 0)
		vm.resource_levels[resource] = current + quantity
	
	# İlişki artışı (satın alma sonrası)
	var settlement_id = trader.get("origin_settlement_id", "")
	var relation_gain = 1  # Temel +1 ilişki
	
	# Büyük alımlar bonus ilişki verir
	if quantity >= 25:
		relation_gain += 2  # +2 bonus
	elif quantity >= 10:
		relation_gain += 1  # +1 bonus
	
	_increase_settlement_relation(settlement_id, relation_gain)
	
	var res_name = _get_resource_display_name(resource)
	var relation_text = ""
	if relation_gain > 1:
		relation_text = " (+%d ilişki)" % relation_gain
	_post_news_tr("village", "news.purchase.title", "news.purchase.body", Color(0.8, 1, 0.8), "success", [], [quantity, res_name, total_cost, relation_text])
	
	return true

# Yerleşim ilişkisini artır
func _increase_settlement_relation(settlement_id: String, amount: int):
	if settlement_id.is_empty():
		return
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm and _mm_settlement_on_world_map(settlement_id) and wm.has_method("_get_settlement_display_name") and wm.has_method("change_relation"):
		var nm: String = String(wm.call("_get_settlement_display_name", settlement_id))
		wm.call("change_relation", "Köy", nm, amount, false)
		if amount > 0:
			for s in settlements:
				if s.get("id") == settlement_id:
					post_news("world", tr("news.relation_up.title"), tr("news.relation_up.body") % [s.get("name", "?"), amount, int(s.get("relation", 0))], Color(0.8, 1, 0.8), "info")
					break
		return
	for s in settlements:
		if s.get("id") == settlement_id:
			var old_relation = s.get("relation", 50)
			s["relation"] = clamp(old_relation + amount, 0, 100)
			if amount > 0:
				var settlement_name = s.get("name", "?")
				post_news("world", tr("news.relation_up.title"), tr("news.relation_up.body") % [settlement_name, amount, s["relation"]], Color(0.8, 1, 0.8), "info")
			break

# Kaynak isimlerini Türkçe'ye çevir
func _get_resource_display_name(resource: String) -> String:
	match resource:
		"food": return "Yemek"
		"wood": return "Odun"
		"stone": return "Taş"
		"water": return "Su"
		_: return resource.capitalize()

# Yerleşim ticaret modunu getir
func _get_trade_modifier_for_partner(partner: String, day: int) -> Dictionary:
	var base_mod: Dictionary = {"trade_multiplier": 1.0, "blocked": false}
	
	# Önce yerleşim-spesifik modifikasyonları kontrol et
	for m in settlement_trade_modifiers:
		var exp = int(m.get("expires_day", 0))
		if m.get("partner", "") == partner:
			if exp == 0 or exp >= day:
				base_mod = m
				break
	
	# Bandit Activity aktifse tüm yerleşimler için ticaret çarpanını uygula
	if bandit_activity_active:
		var current_mult = float(base_mod.get("trade_multiplier", 1.0))
		base_mod["trade_multiplier"] = current_mult * bandit_trade_multiplier
		# Eğer çarpan çok düşükse ticareti blokla
		if base_mod["trade_multiplier"] < 0.1:
			base_mod["blocked"] = true
	
	return base_mod

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
	post_news("world", tr("news.trade_mode.title") % partner, tr("news.trade_mode.body") % [effect_text, str(days)], Color(0.9, 0.95, 1), "info")

func create_settlements():
	# Havuzdan isim + daha fazla komsu yerlesim (harita dolulugu / ekonomi icin)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	const NEIGHBOR_SETTLEMENT_COUNT: int = 14
	settlements.clear()
	var used_names: Dictionary = {}
	for i in range(NEIGHBOR_SETTLEMENT_COUNT):
		var sid: String = "neighbor_%03d" % i
		var nm: String = WorldSettlementNames.pick_unique_settlement_name(rng, used_names)
		var roll: float = rng.randf()
		var typ: String = "village"
		var wealth: int = rng.randi_range(45, 65)
		var stability: int = rng.randi_range(50, 75)
		var military: int = rng.randi_range(15, 35)
		var relation: int = rng.randi_range(38, 78)
		if roll < 0.52:
			typ = "village"
		elif roll < 0.72:
			typ = "town"
			wealth = rng.randi_range(58, 78)
			military = rng.randi_range(22, 42)
		elif roll < 0.88:
			typ = "city"
			wealth = rng.randi_range(70, 88)
			stability = rng.randi_range(55, 82)
			military = rng.randi_range(35, 55)
		elif roll < 0.96:
			typ = "fort"
			wealth = rng.randi_range(40, 58)
			military = rng.randi_range(65, 88)
			stability = rng.randi_range(48, 68)
		else:
			typ = "outpost"
			wealth = rng.randi_range(48, 62)
			military = rng.randi_range(38, 55)
		var bias_pool: Array[String] = ["food", "wood", "stone"]
		var biases: Dictionary = {}
		var bias_n: int = rng.randi_range(1, 2)
		for _b in range(bias_n):
			var bk: String = bias_pool[rng.randi() % bias_pool.size()]
			biases[bk] = int(biases.get(bk, 0)) + rng.randi_range(1, 3)
		settlements.append({
			"id": sid,
			"name": nm,
			"type": typ,
			"relation": relation,
			"wealth": wealth,
			"stability": stability,
			"military": military,
			"biases": biases
		})
	post_news("world", tr("news.neighbors_discovered.title"), tr("news.neighbors_discovered.body") % settlements.size(), Color(0.8, 1, 0.8), "info")
	sync_settlement_relations_from_world_map()

## WM `get_relation("Köy", gorunen_ad)` [-100..100] -> MM liste UI/rota icin [0..100]
func sync_settlement_relations_from_world_map() -> void:
	if settlements.is_empty():
		return
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm != null and ("world_map_settlement_positions" in wm):
		var positions: Dictionary = wm.world_map_settlement_positions
		if not positions.is_empty() and wm.has_method("_get_settlement_display_name") and wm.has_method("get_relation"):
			for i in range(settlements.size()):
				var entry = settlements[i]
				if not (entry is Dictionary):
					continue
				var sid: String = String(entry.get("id", ""))
				if sid.is_empty() or not positions.has(sid):
					continue
				var nm: String = String(wm.call("_get_settlement_display_name", sid))
				var wr: int = int(wm.call("get_relation", "Köy", nm))
				var legacy: int = clampi(int(round(50.0 + float(wr) * 0.5)), 0, 100)
				settlements[i]["relation"] = legacy
	refresh_trade_route_stats_from_settlements()

## `trade_routes` baslangicta kurulur; diplomasi degisince risk/aktif ortalama guncellenir (mesafe urun sabit).
func refresh_trade_route_stats_from_settlements() -> void:
	if settlements.size() < 2:
		return
	if trade_routes.is_empty():
		_initialize_trade_routes()
		return
	var id_to_rel: Dictionary = {}
	for s in settlements:
		if s is Dictionary:
			id_to_rel[String(s.get("id", ""))] = float(s.get("relation", 50))
	for idx in range(trade_routes.size()):
		var route: Dictionary = trade_routes[idx]
		var fid: String = String(route.get("from", ""))
		var tid: String = String(route.get("to", ""))
		var rf: float = float(id_to_rel.get(fid, 50.0))
		var rt: float = float(id_to_rel.get(tid, 50.0))
		var avg: float = (rf + rt) / 2.0
		route["relation"] = avg
		route["risk"] = _calculate_route_risk(avg)
		route["active"] = avg >= 30.0
		trade_routes[idx] = route

func is_settlement_under_active_intel(settlement_id: String) -> bool:
	if settlement_id.is_empty():
		return false
	for cariye_id in active_missions:
		var mission_id: String = String(active_missions[cariye_id])
		if not missions.has(mission_id):
			continue
		var mission: Variant = missions[mission_id]
		if mission == null:
			continue
		var sid: String = ""
		if mission is Dictionary:
			sid = String(mission.get("target_settlement_id", ""))
		elif "target_settlement_id" in mission:
			sid = String(mission.target_settlement_id)
		if sid == settlement_id:
			return true
	return false

func _count_active_intel_missions() -> int:
	var seen: Dictionary = {}
	for cariye_id in active_missions:
		var mission_id: String = String(active_missions[cariye_id])
		if not missions.has(mission_id):
			continue
		var mission: Variant = missions[mission_id]
		if mission == null:
			continue
		var sid: String = ""
		if mission is Dictionary:
			sid = String(mission.get("target_settlement_id", ""))
		elif "target_settlement_id" in mission:
			sid = String(mission.target_settlement_id)
		if not sid.is_empty():
			seen[sid] = true
	return seen.size()

func get_intelligence_daily_news_cap() -> int:
	var cap: int = WORLD_NEWS_BASE_DAILY_CAP
	var wm: Node = get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("get_discovered_settlements"):
		var discovered: Array = wm.call("get_discovered_settlements")
		cap += mini(discovered.size(), 3)
	cap += mini(_count_active_intel_missions(), 2)
	cap += mini(active_traders.size(), 2)
	if wm and wm.has_method("get_living_world_role_modifiers"):
		var mods: Dictionary = wm.call("get_living_world_role_modifiers")
		var ajan_norm: float = clampf(float(mods.get("undiscovered_news_chance", 0.0)) / 0.50, 0.0, 1.0)
		cap += int(round(1.0 + 2.0 * ajan_norm))
	return clampi(cap, WORLD_NEWS_BASE_DAILY_CAP, WORLD_NEWS_MAX_DAILY_CAP)

func can_publish_world_news(news: Dictionary = {}) -> bool:
	if bool(news.get("skip_daily_cap", false)):
		return true
	var tm: Node = get_node_or_null("/root/TimeManager")
	var day: int = int(tm.get_day()) if tm and tm.has_method("get_day") else 0
	if day != _world_news_count_day_id:
		_world_news_count_day_id = day
		_world_news_count_day = 0
	if _world_news_count_day >= get_intelligence_daily_news_cap():
		return false
	_world_news_count_day += 1
	return true

func _is_world_news_category(category: String) -> bool:
	var cat: String = String(category).to_lower()
	return cat in ["world", "dünya", "dunya"]

func _mm_settlement_on_world_map(settlement_id: Variant) -> bool:
	var sid: String = String(settlement_id)
	if sid.is_empty():
		return false
	var wm: Node = get_node_or_null("/root/WorldManager")
	return wm != null and "world_map_settlement_positions" in wm and (wm.world_map_settlement_positions as Dictionary).has(sid)

# Ticaret rotalarını başlat
func _initialize_trade_routes():
	trade_routes = []
	
	# Yerleşimler arası rotalar oluştur
	if settlements.size() < 2:
		return
	
	for i in range(settlements.size()):
		for j in range(i + 1, settlements.size()):
			var from_settlement = settlements[i]
			var to_settlement = settlements[j]
			
			# Rota oluştur (ilişkiye göre aktif/pasif)
			var relation_from = from_settlement.get("relation", 50)
			var relation_to = to_settlement.get("relation", 50)
			var avg_relation = (relation_from + relation_to) / 2.0
			
			var route = {
				"id": "route_%s_%s" % [from_settlement.get("id", ""), to_settlement.get("id", "")],
				"from": from_settlement.get("id", ""),
				"from_name": from_settlement.get("name", ""),
				"to": to_settlement.get("id", ""),
				"to_name": to_settlement.get("name", ""),
				"products": _get_route_products(from_settlement, to_settlement),
				"distance": randf_range(1.0, 5.0),
				"risk": _calculate_route_risk(avg_relation),
				"active": avg_relation >= 30,  # 30+ ilişki gerekli
				"relation": avg_relation
			}
			
			trade_routes.append(route)

# Rota ürünlerini belirle
func _get_route_products(from_settlement: Dictionary, to_settlement: Dictionary) -> Array[String]:
	# Her yerleşimin bias'ına göre ürünler
	var from_biases = from_settlement.get("biases", {})
	var to_biases = to_settlement.get("biases", {})
	
	var products: Array[String] = []
	
	# From'dan To'ya giden ürünler (from'un fazla ürettiği)
	for resource in from_biases.keys():
		if from_biases[resource] > 1:
			products.append(resource)
	
	# To'dan From'a giden ürünler (to'nun fazla ürettiği)
	for resource in to_biases.keys():
		if to_biases[resource] > 1 and not resource in products:
			products.append(resource)
	
	# En az 1 ürün olsun
	if products.is_empty():
		products = ["food", "wood", "stone"]
	
	return products

# Rota risk seviyesini hesapla
func _calculate_route_risk(relation: float) -> String:
	if relation >= 70:
		return "Düşük"
	elif relation >= 50:
		return "Orta"
	elif relation >= 30:
		return "Yüksek"
	else:
		return "Çok Yüksek"

# Aktif rotaları al
func get_active_trade_routes() -> Array[Dictionary]:
	var active_routes: Array[Dictionary] = []
	for route in trade_routes:
		if route.get("active", false):
			active_routes.append(route)
	return active_routes

# Rota bul (ID ile)
func _find_route_by_id(route_id: String) -> Dictionary:
	for route in trade_routes:
		if route.get("id") == route_id:
			return route
	return {}

# Ticaret görevi oluştur (rota ve ürünlerle)
func create_trade_mission_for_route(cariye_id: int, route_id: String, products: Dictionary, soldier_count: int = 0) -> Mission:
	var route = _find_route_by_id(route_id)
	if route.is_empty():
		return null
	
	# Rota aktif mi kontrol et
	if not route.get("active", false):
		return null
	
	var mission = Mission.new()
	mission.id = "trade_route_%d" % Time.get_unix_time_from_system()
	mission.name = "Ticaret: %s → %s" % [route.get("from_name", "?"), route.get("to_name", "?")]
	mission.description = "%s'ye ticaret malı götür." % route.get("to_name", "?")
	mission.mission_type = Mission.MissionType.TİCARET
	mission.difficulty = _get_route_difficulty(route)
	mission.duration = route.get("distance", 2.0) * 60.0  # Mesafe * 60 dakika
	mission.success_chance = _calculate_trade_success_chance(route, cariye_id)
	mission.required_cariye_level = 1
	mission.required_army_size = soldier_count
	mission.required_resources = products  # Götürülecek mallar
	mission.rewards = _calculate_trade_rewards(route, products, cariye_id)
	mission.penalties = _calculate_trade_penalties(route)
	mission.target_location = route.get("to_name", "?")
	mission.distance = route.get("distance", 2.0)
	mission.risk_level = route.get("risk", "Orta")
	
	# Rota bilgisini mission'a ekle (tamamlama için)
	mission.set_meta("trade_route_id", route_id)
	mission.set_meta("trade_route", route)
	
	return mission

# Rota zorluğunu belirle
func _get_route_difficulty(route: Dictionary) -> Mission.Difficulty:
	var risk = route.get("risk", "Orta")
	match risk:
		"Düşük": return Mission.Difficulty.KOLAY
		"Orta": return Mission.Difficulty.ORTA
		"Yüksek": return Mission.Difficulty.ZOR
		"Çok Yüksek": return Mission.Difficulty.EFSANEVİ
		_: return Mission.Difficulty.ORTA

# Ticaret başarı şansını hesapla
func _calculate_trade_success_chance(route: Dictionary, cariye_id: int) -> float:
	var base_chance = 0.8  # %80 temel şans
	
	# Rota riskine göre düşüş
	var risk = route.get("risk", "Orta")
	match risk:
		"Düşük": base_chance = 0.9
		"Orta": base_chance = 0.8
		"Yüksek": base_chance = 0.7
		"Çok Yüksek": base_chance = 0.6
	
	# Cariye yeteneği bonusu
	if concubines.has(cariye_id):
		var cariye = concubines[cariye_id]
		var trade_skill = cariye.get_skill_level(Concubine.Skill.TİCARET)
		var skill_bonus = (trade_skill - 50) * 0.002  # Her 1 yetenek = %0.2 bonus
		base_chance += skill_bonus

	var vce := get_node_or_null("/root/VillageCardEffects")
	if vce:
		base_chance += vce.get_trade_success_bonus()

	return clamp(base_chance, 0.5, 0.98)  # Min %50, Max %98

# Ticaret ödüllerini hesapla
func _calculate_trade_rewards(route: Dictionary, products: Dictionary, cariye_id: int) -> Dictionary:
	var rewards: Dictionary = {}
	var total_profit = 0
	
	# Temel kâr hesaplama
	for resource in products.keys():
		var quantity = products[resource]
		var base_value = _get_resource_base_value(resource)
		var route_multiplier = 1.2 + (route.get("relation", 50) - 50) * 0.01  # İlişkiye göre kâr
		total_profit += int(base_value * quantity * route_multiplier)
	
	# Cariye yeteneği bonusu
	if concubines.has(cariye_id):
		var cariye = concubines[cariye_id]
		var trade_skill = cariye.get_skill_level(Concubine.Skill.TİCARET)
		var level = cariye.level
		
		var skill_bonus_multiplier = 1.0 + (trade_skill * 0.005)  # Her 1 yetenek = %0.5 bonus
		var level_bonus_multiplier = 1.0 + (level * 0.02)  # Her 1 seviye = %2 bonus
		
		# Özel yetenekler
		if trade_skill >= 100:
			skill_bonus_multiplier *= 1.1  # %10 ekstra (Efsane)
		elif trade_skill >= 90:
			skill_bonus_multiplier *= 1.05  # %5 ekstra (Efendi)
		elif trade_skill >= 80:
			skill_bonus_multiplier *= 1.02  # %2 ekstra (Usta)
		
		total_profit = int(total_profit * skill_bonus_multiplier * level_bonus_multiplier)
	
	rewards["gold"] = total_profit
	return rewards

# Ticaret cezalarını hesapla
func _calculate_trade_penalties(route: Dictionary) -> Dictionary:
	var penalties: Dictionary = {}
	var risk = route.get("risk", "Orta")
	
	match risk:
		"Düşük":
			penalties["gold"] = -4
		"Orta":
			penalties["gold"] = -6
		"Yüksek":
			penalties["gold"] = -9
		"Çok Yüksek":
			penalties["gold"] = -12
			penalties["cariye_injured"] = 1
	
	return penalties

# Kaynak temel değeri
func _get_resource_base_value(resource: String) -> int:
	match resource:
		"food": return 3
		"wood": return 3
		"stone": return 4
		_: return 3

# --- ZENGİN OLAYLAR ---

func _trigger_trade_caravan() -> void:
	# ESKİ SİSTEM: Artık kullanılmıyor, VillageManager'daki event sistemi kullanılacak
	# Bu fonksiyon sadece geriye dönük uyumluluk için bırakıldı
	pass

func _trigger_bandit_activity() -> void:
	_active_rate_add("wood", -1, 2, "Haydut Faaliyeti")
	_active_rate_add("stone", -1, 2, "Haydut Faaliyeti")
	_create_bandit_missions()

func _trigger_random_festival() -> void:
	if settlements.is_empty():
		return
	var s = settlements[randi() % settlements.size()]
	var partner = s.get("name","?")
	post_news("village", tr("news.festival.title"), tr("news.festival.body") % partner, Color(1, 0.95, 0.6), "success")
	# Ticarette indirim, gıdada küçük artı (2 gün)
	_add_settlement_trade_modifier(partner, 0.9, 2, false, "festival")
	_active_rate_add("food", 1, 2, "Festival")

func _trigger_plague() -> void:
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
	post_news("world", tr("news.embargo.title"), tr("news.embargo.body") % [pa, pb], Color(1, 0.8, 0.8), "warning")
	_add_settlement_trade_modifier(pa, 1.0, 3, true, "embargo")
	_add_settlement_trade_modifier(pb, 1.0, 3, true, "embargo")

# --- Olay kaynaklı görevler ---

func _create_escort_mission(partner: String) -> void:
	var m = Mission.new()
	m.id = "escort_%d" % Time.get_unix_time_from_system()
	m.name = "Kervanı Koru: %s" % partner
	m.description = "%s'den gelen kervanı güvenli şekilde pazara ulaştır." % partner
	m.mission_type = Mission.MissionType.SAVAŞ
	m.difficulty = Mission.Difficulty.ORTA
	m.duration = 240.0  # 240 oyun dakikası (4 saat, test için)
	m.success_chance = 0.65
	m.required_cariye_level = 2
	m.required_army_size = 4
	m.required_resources = {"gold": 6}
	m.rewards = {"gold": 14, "wood": 2}
	m.penalties = {"gold": -5}
	m.status = Mission.Status.MEVCUT
	if try_enqueue_mission_spawn(m, "escort", {
		"news_source": "escort",
		"facts": {"partner": partner, "settlement_name": partner},
	}):
		return
	missions[m.id] = m
	mission_list_changed.emit()
	post_news("village", tr("news.caravan_escort.title"), tr("news.caravan_escort.body"), Color(0.8, 1, 0.8), "info")

func _create_bandit_missions() -> void:
	_add_bandit_clear_mission()

# VillageManager bandit_activity event uyguladığında çağırır; "Haydut Temizliği" görevini ekler (yoksa).
func add_bandit_clear_mission() -> void:
	if not bandit_activity_active:
		return
	_add_bandit_clear_mission()

# Bandit Activity event aktifken çağrılır; "Haydut Temizliği" görevini listeye ekler (yoksa).
# Görev başarıyla tamamlanınca VillageManager bandit_activity event'ini kapatır.
func _add_bandit_clear_mission() -> void:
	for id in missions:
		if id.begins_with("bandit_clear_"):
			return  # Zaten var
	var clear = Mission.new()
	clear.id = "bandit_clear_%d" % Time.get_unix_time_from_system()
	clear.name = "Haydut Temizliği"
	clear.description = "Yollardaki haydutları temizle ve güvenliği sağla. Başarılı olursa haydut faaliyeti sona erer."
	clear.mission_type = Mission.MissionType.SAVAŞ
	clear.difficulty = Mission.Difficulty.ORTA
	clear.duration = 200.0  # 200 saniye (3.3 dakika, test için)
	clear.success_chance = 0.6
	clear.required_cariye_level = 2
	clear.required_army_size = 4
	clear.required_resources = {"gold": 5}
	clear.rewards = {"gold": 14, "stone": 2}
	clear.penalties = {"gold": -5}
	clear.status = Mission.Status.MEVCUT
	if try_enqueue_mission_spawn(clear, "bandit_clear", {
		"news_override": {
			"title": tr("news.bandit_activity.title"),
			"body": tr("news.bandit_activity.body"),
			"category": "Dünya",
			"color": Color(1, 0.8, 0.8),
			"subcategory": "warning",
		},
	}):
		return
	missions[clear.id] = clear
	mission_list_changed.emit()
	post_news("village", tr("news.bandit_cleanup.title"), tr("news.bandit_cleanup.body"), Color(0.9, 0.9, 1.0), "info")

func _create_aid_mission() -> void:
	var aid = Mission.new()
	aid.id = "aid_%d" % Time.get_unix_time_from_system()
	aid.name = "Yardım Görevi"
	aid.description = "Salgından etkilenen bölgelere yardım ulaştır."
	aid.mission_type = Mission.MissionType.DİPLOMASİ
	aid.difficulty = Mission.Difficulty.ORTA
	aid.duration = 240.0  # 240 oyun dakikası (4 saat, test için)
	aid.success_chance = 0.6
	aid.required_cariye_level = 2
	aid.required_army_size = 2
	aid.required_resources = {"gold": 6}
	aid.rewards = {"gold": 12, "reputation": 3}
	aid.penalties = {"gold": -5}
	aid.status = Mission.Status.MEVCUT
	if try_enqueue_mission_spawn(aid, "plague_aid", {
		"news_override": {
			"title": tr("news.plague.title"),
			"body": tr("news.plague.body"),
			"category": "Dünya",
			"color": Color(1, 0.6, 0.6),
			"subcategory": "warning",
		},
	}):
		return
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
	post_news("world", tr("news.stability_changed.title"), tr("news.stability_changed.body") % world_stability, Color(0.8, 1, 0.8), "info")

# Oyuncu seviyesine göre dinamik görev üretimi
func generate_level_appropriate_missions() -> Array:
	var generated_missions = []
	var max_level = get_max_concubine_level()
	
	# Seviyeye göre görev sayısı
	var mission_count = 2 + (max_level / 2)  # Seviye arttıkça daha fazla görev
	
	for i in range(mission_count):
		var mission = generate_random_dynamic_mission()
		if mission:
			if try_enqueue_mission_spawn(mission, "dynamic_mission", {"post_news": false}):
				generated_missions.append(mission)
			else:
				missions[mission.id] = mission
				generated_missions.append(mission)
	
	return generated_missions

# Özel durum görevleri (nadir görevler)
func generate_special_missions() -> Array:
	var special_missions = []
	
	# Oyuncu itibarı yüksekse özel görevler
	if player_reputation >= 80:
		var special_mission = create_special_mission("elite_contract")
		if special_mission:
			if try_enqueue_mission_spawn(special_mission, "special_elite", {"post_news": false}):
				special_missions.append(special_mission)
			else:
				missions[special_mission.id] = special_mission
				special_missions.append(special_mission)
	
	if world_stability <= 30:
		var emergency_mission = create_special_mission("emergency_response")
		if emergency_mission:
			if try_enqueue_mission_spawn(emergency_mission, "special_emergency", {"post_news": false}):
				special_missions.append(emergency_mission)
			else:
				missions[emergency_mission.id] = emergency_mission
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
			mission.required_resources = {"gold": 20}
			mission.rewards = {"gold": 40, "wood": 6, "stone": 4, "special_item": "elite_weapon"}
			mission.penalties = {"gold": -12, "reputation": -5}
			mission.target_location = "Elit Kalesi"
			mission.distance = 8.0
			mission.risk_level = "Yüksek"
		
		"emergency_response":
			mission.id = "special_emergency_" + str(next_mission_id)
			mission.name = "Acil Müdahale"
			mission.description = "Dünya istikrarı tehlikede! Hemen harekete geçin."
			mission.mission_type = Mission.MissionType.DİPLOMASİ
			mission.difficulty = Mission.Difficulty.ZOR
			mission.duration = 240.0  # 240 oyun dakikası (4 saat, test için)
			mission.success_chance = 0.4
			mission.required_cariye_level = 3
			mission.required_army_size = 4
			mission.required_resources = {"gold": 12}
			mission.rewards = {"gold": 22, "stability_bonus": 20, "reputation": 5}
			mission.penalties = {"gold": -8, "stability_penalty": -10}
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

func create_raid_mission(target_settlement: String, day: int = 0, difficulty: String = "medium", source: String = "", target_settlement_id: String = "") -> Dictionary:
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
		"required_resources": {"gold": 8, "weapon": 1, "armor": 1},
		"rewards": {"gold": 14, "equipment": {"weapon": 1, "armor": 1}},
		"penalties": {"gold": -6, "army_losses": 1},
		"status": "available",
		"day": day,
		"source": source,
		"target_settlement_id": target_settlement_id
	}
	
	next_mission_id += 1
	if try_enqueue_dict_mission_spawn(mission, "worldmap_raid", {
		"news_override": {
			"title": tr("news.raid_chance.title"),
			"body": tr("news.raid_chance.body") % target_settlement,
			"category": "Dünya",
			"color": Color(1, 0.8, 0.8),
			"subcategory": "warning",
		},
	}):
		print("⚔️ Baskın görevi (pipeline): %s (Gün: %d)" % [target_settlement, day])
		return mission
	missions[mission_id] = mission
	post_news("world", tr("news.raid_chance.title"), tr("news.raid_chance.body") % target_settlement, Color(1, 0.8, 0.8), "warning")
	print("⚔️ Baskın görevi oluşturuldu: %s (Gün: %d)" % [target_settlement, day])
	return mission

func get_world_map_action_preview(action_type: String, settlement_name: String, distance: int = 0, settlement_faction: String = "") -> Dictionary:
	var d: int = max(0, distance)
	var faction_id: String = settlement_faction.strip_edges()
	var preview: Dictionary
	match action_type:
		"trade":
			preview = {
				"duration_minutes": 150 + d * 15,
				"risk_level": "Dusuk",
				"title": "Ticaret",
				"target": settlement_name
			}
		"diplomacy":
			preview = {
				"duration_minutes": 180 + d * 15,
				"risk_level": "Dusuk",
				"title": "Diplomasi",
				"target": settlement_name
			}
		"raid":
			preview = {
				"duration_minutes": 220 + d * 20,
				"risk_level": "Orta",
				"title": "Baskin",
				"target": settlement_name
			}
		_:
			preview = {
				"duration_minutes": 120 + d * 10,
				"risk_level": "Orta",
				"title": "Eylem",
				"target": settlement_name
			}
	if faction_id.is_empty():
		return preview
	match action_type:
		"trade":
			preview["duration_minutes"] = WorldFactionProfiles.adjust_trade_duration(int(preview.get("duration_minutes", 0)), faction_id)
		"diplomacy":
			preview["duration_minutes"] = WorldFactionProfiles.adjust_diplomacy_duration(int(preview.get("duration_minutes", 0)), faction_id)
		"raid":
			preview["risk_level"] = WorldFactionProfiles.adjust_raid_risk_label(String(preview.get("risk_level", "Orta")), faction_id)
	preview["faction"] = faction_id
	preview["faction_label"] = WorldFactionProfiles.get_display_label(faction_id)
	return preview

func create_world_map_action_mission(action_type: String, settlement_id: String, settlement_name: String, day: int = 0, distance: int = 0) -> Dictionary:
	match action_type:
		"trade":
			return _create_world_map_trade_mission(settlement_id, settlement_name, distance)
		"diplomacy":
			return _create_world_map_diplomacy_mission(settlement_id, settlement_name, distance)
		"raid":
			return create_raid_mission(settlement_name, day, "medium", "world_map", settlement_id)
		_:
			return {}

func _create_world_map_trade_mission(settlement_id: String, settlement_name: String, distance: int) -> Dictionary:
	var mission: Mission = create_dynamic_mission("ticaret", Mission.Difficulty.ORTA)
	if mission == null:
		return {}
	mission.id = "worldmap_trade_" + str(next_mission_id)
	next_mission_id += 1
	mission.name = "Harita Ticaret: " + settlement_name
	mission.description = settlement_name + " ile harita üzerinden ticaret görevi."
	mission.locale_name_key = "mission.worldmap.trade.name"
	mission.locale_desc_key = "mission.worldmap.trade.desc"
	mission.locale_vars = {"target": settlement_name}
	mission.target_location = settlement_name
	mission.distance = max(1.0, float(distance))
	mission.risk_level = "Düşük"
	var actions: Array = []
	if not settlement_id.is_empty():
		actions.append({"action": "increase_relation", "settlement_id": settlement_id, "amount": 1})
	if try_enqueue_mission_spawn(mission, "worldmap_trade", {
		"news_override": {
			"title": tr("news.map_trade_order.title"),
			"body": tr("news.map_trade_order.body") % settlement_name,
			"category": "village",
			"color": Color(0.8, 1, 0.8),
			"subcategory": "info",
		},
		"post_publish_actions": actions,
	}):
		return {
			"id": mission.id,
			"type": "trade",
			"duration": mission.duration,
			"risk_level": mission.risk_level,
			"target": settlement_name,
			"pending_narrative": true,
		}
	missions[mission.id] = mission
	post_news("village", tr("news.map_trade_order.title"), tr("news.map_trade_order.body") % settlement_name, Color(0.8, 1, 0.8), "info")
	if not settlement_id.is_empty():
		_increase_settlement_relation(settlement_id, 1)
	return {
		"id": mission.id,
		"type": "trade",
		"duration": mission.duration,
		"risk_level": mission.risk_level,
		"target": settlement_name
	}

func _create_world_map_diplomacy_mission(settlement_id: String, settlement_name: String, distance: int) -> Dictionary:
	var mission := Mission.new()
	mission.id = "worldmap_diplomacy_" + str(next_mission_id)
	next_mission_id += 1
	mission.name = "Harita Diplomasi: " + settlement_name
	mission.description = settlement_name + " ile ilişkileri geliştirmek için diplomatik heyet gönder."
	mission.locale_name_key = "mission.worldmap.diplomacy.name"
	mission.locale_desc_key = "mission.worldmap.diplomacy.desc"
	mission.locale_vars = {"target": settlement_name}
	mission.mission_type = Mission.MissionType.DİPLOMASİ
	mission.difficulty = Mission.Difficulty.ORTA
	mission.duration = 180.0 + float(max(0, distance) * 15)
	mission.success_chance = 0.72
	mission.required_cariye_level = 1
	mission.required_army_size = 0
	mission.required_resources = {"gold": 6}
	mission.rewards = {"gold": 12, "reputation": 2}
	mission.penalties = {"gold": -5, "reputation": -1}
	mission.target_location = settlement_name
	mission.distance = max(1.0, float(distance))
	mission.risk_level = "Düşük"
	mission.status = Mission.Status.MEVCUT
	var dip_actions: Array = []
	if not settlement_id.is_empty():
		dip_actions.append({"action": "increase_relation", "settlement_id": settlement_id, "amount": 2})
	if try_enqueue_mission_spawn(mission, "worldmap_diplomacy", {
		"news_override": {
			"title": tr("news.map_diplomacy_order.title"),
			"body": tr("news.map_diplomacy_order.body") % settlement_name,
			"category": "Dünya",
			"color": Color(0.9, 0.95, 1.0),
			"subcategory": "info",
		},
		"post_publish_actions": dip_actions,
	}):
		return {
			"id": mission.id,
			"type": "diplomacy",
			"duration": mission.duration,
			"risk_level": mission.risk_level,
			"target": settlement_name,
			"pending_narrative": true,
		}
	missions[mission.id] = mission
	post_news("world", tr("news.map_diplomacy_order.title"), tr("news.map_diplomacy_order.body") % settlement_name, Color(0.9, 0.95, 1.0), "info")
	if not settlement_id.is_empty():
		_increase_settlement_relation(settlement_id, 2)
	return {
		"id": mission.id,
		"type": "diplomacy",
		"duration": mission.duration,
		"risk_level": mission.risk_level,
		"target": settlement_name
	}

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
		"required_resources": {"gold": 8, "weapon": 1, "armor": 1},
		"rewards": {"gold": 16, "stability_bonus": 15, "reputation": 3},
		"penalties": {"gold": -8, "stability_penalty": -20, "army_losses": 2},
		"status": "urgent",
		"day": day
	}
	
	next_mission_id += 1
	if try_enqueue_dict_mission_spawn(mission, "defense_dict", {
		"news_override": {
			"title": tr("news.defense_required.title"),
			"body": tr("news.defense_required.body") % attacker,
			"category": "Dünya",
			"color": Color(1, 0.3, 0.3),
			"subcategory": "critical",
		},
	}):
		print("🛡️ Savunma görevi (pipeline): %s (Gün: %d)" % [attacker, day])
		return mission
	missions[mission_id] = mission
	_post_news_tr("world", "news.defense_required.title", "news.defense_required.body", Color(1, 0.3, 0.3), "critical", [], [attacker])
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

func _get_available_soldier_worker_ids_for_mission(barracks: Node, exclude_mission_id: String) -> Array:
	"""Görevde olmayan asker worker ID'lerini döndür (başka raid'de kullanılanları çıkar)."""
	var busy: Array = []
	for mid in _raid_mission_extra:
		if mid == exclude_mission_id:
			continue
		var extra = _raid_mission_extra[mid]
		var wids = extra.get("assigned_soldier_worker_ids", [])
		if wids is Array:
			for w in wids:
				busy.append(int(w) if w is float else w)
	var available: Array = []
	for wid in barracks.assigned_worker_ids:
		var id_val = int(wid) if wid is float else wid
		if id_val not in busy:
			available.append(id_val)
	print("[RAID_DEBUG] _get_available_soldier_worker_ids: barracks_ids=%s busy=%s available=%s" % [
		str(barracks.assigned_worker_ids), str(busy), str(available)
	])
	return available

func get_raid_mission_extra(mission_id: String) -> Dictionary:
	"""Raid görevi için çıkış yönü ve asker worker ID'leri (VillageManager/ConcubineNPC okur)."""
	return _raid_mission_extra.get(mission_id, {})

func clear_raid_mission_extra(mission_id: String) -> void:
	"""Görev bitince/iptal edilince çağrılır."""
	_raid_mission_extra.erase(mission_id)

func get_total_soldiers_on_mission() -> int:
	"""Şu an görevde olan toplam asker sayısı (mevcut asker hesabı için)."""
	var total := 0
	for mid in _raid_mission_extra:
		var extra = _raid_mission_extra[mid]
		var wids = extra.get("assigned_soldier_worker_ids", [])
		if wids is Array:
			total += wids.size()
	return total

func _get_player_military_force() -> Dictionary:
	"""Get player's current military force from Barracks"""
	# Kışla binasını bul
	var barracks = _find_barracks()
	var force: Dictionary
	if barracks and barracks.has_method("get_military_force"):
		force = barracks.get_military_force()
	else:
		# Fallback: eski sistem
		force = {
			"units": {"infantry": 5, "archers": 3, "cavalry": 2},
			"equipment": {"weapon": 10, "armor": 8},
			"supplies": {"bread": 20, "food": 15},
			"gold": 500
		}
	# Köy roguelite kart etkilerinin (bkz. VillageCardEffects.gd) hangi taraf oyuncu
	# olduğunu ayırt edebilmesi için işaretlenir.
	force["is_player_force"] = true
	return force

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
			"supplies": {"bread": 10, "food": 8},
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
		"supplies": {"bread": int(wealth / 5), "food": int(wealth / 8)},
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
		"supplies": {"bread": attacker_strength * 3, "food": attacker_strength * 2},
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
		post_news("village", tr("news.battle_victory.title"), tr("news.battle_victory.body") % [get_mission_display_name(mission), gold_gain], Color(0.3, 1.0, 0.3), "success")
		
		# Update world stability
		world_stability = min(100, world_stability + 5)
		
	else:
		# Apply losses
		var gold_loss := int(mission.get("penalties", {}).get("gold", 0))
		if gold_loss > 0:
			GlobalPlayerData.add_gold(-gold_loss)
		# Gelişmiş kayıp etkileri
		_apply_village_defeat_effects(mission)
		
		# Apply stability penalty
		var stability_penalty := int(mission.get("penalties", {}).get("stability_penalty", 0))
		if stability_penalty > 0:
			world_stability = max(0, world_stability - stability_penalty)
		
		# Post failure news
		post_news("world", tr("news.battle_defeat.title"), tr("news.battle_defeat.body") % [get_mission_display_name(mission), gold_loss], Color(1.0, 0.3, 0.3), "critical")
		
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
		post_news("world", tr("news.unit_loss.title"), tr("news.unit_loss.body") % [losses, unit_type], Color(1.0, 0.7, 0.3), "warning")

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
		{"bread": 20, "food": 15},
		500
	)
	
	# Create test defender force  
	var defender: Dictionary = cr.create_force(
		{"infantry": 4, "archers": 2, "cavalry": 1},
		{"weapon": 6, "armor": 5},
		{"bread": 12, "food": 10},
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

	# Persist to disk
	_save_concubine_roles()
	
	return true

## Oyuncunun rol atamak için çağırdığı ASIL giriş noktası — `set_concubine_role`'ün aksine
## anlık/ücretsiz değil: rol NONE değilse önce bedel (altın + kaynak) ödenir, ardından bir
## eğitim görevi başlar; rol ancak bu görev başarıyla bitince gerçekten atanır (bkz.
## _try_grant_pending_role_for_completed_mission). Rolü bırakmak (NONE) hâlâ ücretsiz/anlıktır.
func request_concubine_role(cariye_id: int, role: int) -> Dictionary:
	if not concubines.has(cariye_id):
		return {"ok": false, "message": "Cariye bulunamadı."}
	var cariye: Concubine = concubines[cariye_id]
	if int(cariye.role) == role:
		return {"ok": false, "message": "Cariye zaten bu rolde."}
	if role == Concubine.Role.NONE:
		set_concubine_role(cariye_id, role)
		return {"ok": true, "message": ""}
	if get_pending_role_training(cariye_id) >= 0:
		return {"ok": false, "message": "Cariye zaten bir rol eğitiminde."}
	if cariye.status != Concubine.Status.BOŞTA:
		return {"ok": false, "message": "Cariye şu an boşta değil."}
	var vm := get_node_or_null("/root/VillageManager")
	if vm == null or not vm.has_method("get_role_training_cost"):
		return {"ok": false, "message": "Köy sistemi bulunamadı."}
	var cost: Dictionary = vm.get_role_training_cost(role)
	if cost.is_empty():
		return {"ok": false, "message": "Bu rol için eğitim tanımlı değil."}
	if not vm.can_afford_resources(cost):
		return {"ok": false, "message": "Yetersiz kaynak: %s" % _format_cost_for_display(cost)}
	if not vm.spend_resources(cost):
		return {"ok": false, "message": "Ödeme yapılamadı."}
	var mission: Mission = _build_role_training_mission(cariye_id, role, cariye.name)
	missions[mission.id] = mission
	if not assign_mission_to_concubine(cariye_id, mission.id, 0):
		missions.erase(mission.id)
		_refund_resources(cost)
		return {"ok": false, "message": "Eğitim görevi başlatılamadı."}
	mission_list_changed.emit()
	return {"ok": true, "message": "Eğitim görevi başladı: %s" % mission.name}


func _build_role_training_mission(cariye_id: int, role: int, cariye_name: String) -> Mission:
	var step: Dictionary = RoleMissionCatalog.get_role_training_step(role)
	var display_name: String = cariye_name.strip_edges()
	if display_name.is_empty():
		display_name = tr("cariye.unknown")
	var m := Mission.new()
	m.id = "role_training_%d_%d_%d" % [cariye_id, role, Time.get_unix_time_from_system()]
	m.name = tr(String(step.get("name_key", ""))) % display_name
	m.description = tr(String(step.get("desc_key", ""))) % display_name
	m.mission_type = int(step.get("type", Mission.MissionType.BÜROKRASİ)) as Mission.MissionType
	m.difficulty = Mission.Difficulty.ORTA
	m.duration = float(step.get("duration", 120.0))
	m.success_chance = float(step.get("success", 0.8))
	m.required_cariye_level = 1
	m.required_army_size = 0
	m.required_concubine_id = cariye_id
	m.required_concubine_role = -1
	m.required_resources = {}
	m.rewards = (step.get("rewards", {}) as Dictionary).duplicate(true)
	m.penalties = {}
	m.target_location = tr("mission.rescue_chain.target.village")
	m.distance = 0.1
	m.risk_level = tr("mission.rescue_chain.risk.low")
	m.allow_player_map_completion = false
	m.status = Mission.Status.MEVCUT
	m.grants_concubine_role = role
	return m


## Bir cariye şu an bir rol eğitim görevindeyse hangi rol için olduğunu döndürür, yoksa -1.
func get_pending_role_training(cariye_id: int) -> int:
	if not active_missions.has(cariye_id):
		return -1
	var mid: String = String(active_missions[cariye_id])
	var m = missions.get(mid)
	if m is Mission and (m as Mission).grants_concubine_role >= 0:
		return (m as Mission).grants_concubine_role
	return -1


func _format_cost_for_display(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(cost.get("gold", 0)) > 0:
		parts.append("%d altın" % int(cost["gold"]))
	for k in cost.keys():
		if str(k) == "gold":
			continue
		var amt: int = int(cost[k])
		if amt > 0:
			parts.append("%d %s" % [amt, LocaleManager.get_resource_name(str(k))])
	return ", ".join(parts)


## `request_concubine_role` içinde ödeme sonrası görev başlatma başarısız olursa harcanan
## kaynakları geri verir.
func _refund_resources(cost: Dictionary) -> void:
	var vm := get_node_or_null("/root/VillageManager")
	if vm == null:
		return
	var g: int = int(cost.get("gold", 0))
	if g > 0:
		var gpd := get_node_or_null("/root/GlobalPlayerData")
		if gpd:
			gpd.add_gold(g)
	for k in cost.keys():
		if str(k) == "gold":
			continue
		var amt: int = int(cost[k])
		if amt > 0 and vm.has_method("apply_resource_delta"):
			vm.apply_resource_delta(str(k), amt)


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

# --- CARIYE ROL PERSISTENCE ---
func _ensure_save_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("otto-man-save"):
		var err := dir.make_dir("otto-man-save")
		if err != OK:
			push_error("[MissionManager] Save dir create failed: user://otto-man-save/")

func _save_concubine_roles() -> void:
	_ensure_save_dir()
	var roles: Dictionary = {}
	for cariye_id in concubines.keys():
		var c: Concubine = concubines[cariye_id]
		roles[str(cariye_id)] = int(c.role)
	var path := _concubine_roles_base_dir() + ROLES_FILE
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(roles))
		f.close()
		print("[MissionManager] Cariye roller kaydedildi: ", path)
	else:
		push_error("[MissionManager] Kaydetme açılamadı: " + path)

func _load_concubine_roles() -> void:
	var path := _concubine_roles_base_dir() + ROLES_FILE
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if not (data is Dictionary):
		return
	for key in data.keys():
		var cid := int(key)
		if concubines.has(cid):
			var role_val := int(data[key])
			concubines[cid].role = Concubine.Role.values()[clamp(role_val, 0, Concubine.Role.values().size() - 1)]
	print("[MissionManager] Cariye roller yüklendi (", data.size(), ")")

# --- KÖY KAYIP ETKİLERİ ---
func _apply_village_defeat_effects(mission: Dictionary) -> void:
	# 1) Kaynak/altın kaybı
	var vm = get_node_or_null("/root/VillageManager")
	if vm and vm.has("resource_levels"):
		var res: Dictionary = vm.resource_levels
		for k in res.keys():
			var cur := int(res[k])
			var loss := int(round(float(cur) * LOSS_RESOURCE_PCT))
			if loss > 0:
				res[k] = max(0, cur - loss)
		# Güncelleme sinyali
		if vm.has_signal("village_data_changed"):
			vm.emit_signal("village_data_changed")

	# Ek altın kaybı
	if LOSS_GOLD_FLAT > 0:
		GlobalPlayerData.add_gold(-LOSS_GOLD_FLAT)

	# 2) İstikrar/moral
	world_stability = max(0, world_stability - LOSS_STABILITY_DELTA)

	# İsteğe bağlı: VillageManager'da moral varsa düşür
	if vm and vm.has("village_morale"):
		vm.village_morale = max(0, int(vm.village_morale) - LOSS_MORALE_DELTA)

	# 3) Bina hasarı (rasgele bir yerleşik bina)
	if randf() < LOSS_BUILDING_DAMAGE_CHANCE and vm and vm.village_scene_instance:
		var placed = vm.village_scene_instance.get_node_or_null("PlacedBuildings")
		if placed and placed.get_child_count() > 0:
			var idx: int = randi() % placed.get_child_count()
			var b = placed.get_child(idx)
			# Basit bir hasar alanı varsa düşür; yoksa sadece haber at
			if b and b.has("health"):
				b.health = max(1, int(b.health) - 1)
				post_news("world", tr("news.building_damaged.title"), tr("news.building_damaged.body") % b.name, Color(1, 0.7, 0.5), "warning")
			else:
				post_news("world", tr("news.building_hurt.title"), tr("news.building_hurt.body") % b.name, Color(1, 0.7, 0.5), "warning")

	post_news("world", tr("news.defense_lost.title"), tr("news.defense_lost.body"), Color(1.0, 0.5, 0.4), "critical")


func get_mission_display_name(mission: Variant) -> String:
	if mission == null:
		return "?"
	if mission is Mission:
		var ai_name: String = _ai_narrative_field(mission, "title")
		if not ai_name.is_empty():
			return ai_name
		if not mission.locale_name_key.is_empty():
			return _tr_mission_template(mission.locale_name_key, mission.locale_vars)
		return LocaleManager.get_mission_text(mission.id, "name", mission.name)
	if mission is Dictionary:
		var mid := str(mission.get("id", ""))
		var fallback := str(mission.get("name", "?"))
		if mid.is_empty():
			return fallback
		return LocaleManager.get_mission_text(mid, "name", fallback)
	return str(mission)


func get_mission_display_description(mission: Variant) -> String:
	if mission == null:
		return ""
	if mission is Mission:
		var ai_body: String = _ai_narrative_field(mission, "body")
		if not ai_body.is_empty():
			return ai_body
		if not mission.locale_desc_key.is_empty():
			return _tr_mission_template(mission.locale_desc_key, mission.locale_vars)
		return LocaleManager.get_mission_text(mission.id, "desc", mission.description)
	if mission is Dictionary:
		var mid := str(mission.get("id", ""))
		var fallback := str(mission.get("description", ""))
		if mid.is_empty():
			return fallback
		return LocaleManager.get_mission_text(mid, "desc", fallback)
	return ""


func _ai_narrative_field(mission: Mission, field: String) -> String:
	if mission.ai_narrative_mode not in ["narrative", "mechanical"]:
		return ""
	var locale: String = "tr"
	if LocaleManager and LocaleManager.has_method("get_locale"):
		locale = str(LocaleManager.get_locale())
	if mission.ai_narratives.has(locale):
		var block: Variant = mission.ai_narratives[locale]
		if block is Dictionary:
			return str(block.get(field, ""))
	for loc_key in mission.ai_narratives.keys():
		var block2: Variant = mission.ai_narratives[loc_key]
		if block2 is Dictionary and not str(block2.get(field, "")).is_empty():
			return str(block2.get(field, ""))
	return ""


func _tr_mission_template(key: String, var_keys: Dictionary = {}) -> String:
	if key.is_empty():
		return ""
	var text := tr(key)
	for ph in var_keys:
		var vk := str(var_keys[ph])
		var val: String
		if vk.begins_with("mission.") or vk.begins_with("wm.") or vk.begins_with("resource."):
			val = tr(vk)
			if val == vk:
				val = vk
		else:
			val = WorldSettlementNames.localize_name(vk)
		text = text.replace("{%s}" % ph, val)
	return text


func get_world_event_display_name(event: Dictionary) -> String:
	var id := str(event.get("id", ""))
	if id.is_empty():
		return str(event.get("name", tr("mc.news.event.unknown")))
	var tkey := "world_event.%s.name" % id
	var text := tr(tkey)
	return text if text != tkey else str(event.get("name", ""))


func get_world_event_display_description(event: Dictionary) -> String:
	var id := str(event.get("id", ""))
	if id.is_empty():
		return str(event.get("description", tr("mc.news.event.no_description")))
	var tkey := "world_event.%s.desc" % id
	var text := tr(tkey)
	return text if text != tkey else str(event.get("description", ""))


func _post_news_tr(
	category: String,
	title_key: String,
	content_key: String,
	color: Color = Color.WHITE,
	subcategory: String = "info",
	title_args: Array = [],
	content_args: Array = []
) -> void:
	var title := tr(title_key)
	var content := tr(content_key)
	if not title_args.is_empty():
		title = title % title_args
	if not content_args.is_empty():
		content = content % content_args
	post_news(category, title, content, color, subcategory)
