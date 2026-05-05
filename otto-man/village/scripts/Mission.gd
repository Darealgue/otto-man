extends Resource
class_name Mission

# Görev türleri
enum MissionType { SAVAŞ, KEŞİF, DİPLOMASİ, TİCARET, İSTİHBARAT, BÜROKRASİ }

# Görev zorluk seviyeleri
enum Difficulty { KOLAY, ORTA, ZOR, EFSANEVİ }

# Görev durumları
enum Status { MEVCUT, AKTİF, TAMAMLANDI, BAŞARISIZ, İPTAL }

# Görev zinciri türleri
enum ChainType { NONE, SEQUENTIAL, PARALLEL, CHOICE }

# Temel görev bilgileri
@export var id: String
@export var name: String
@export var description: String
@export var mission_type: MissionType
@export var difficulty: Difficulty
@export var duration: float  # Oyun dakikası cinsinden
@export var success_chance: float  # 0.0 - 1.0 arası

# Gereksinimler
@export var required_cariye_level: int = 1
@export var required_army_size: int = 0
@export var required_resources: Dictionary = {}  # {"gold": 100, "wood": 50}

# Ödüller ve cezalar
@export var rewards: Dictionary = {}  # {"gold": 500, "wood": 100}
@export var penalties: Dictionary = {}  # {"gold": -100, "cariye_injured": true}

# Görev detayları
@export var target_location: String = ""
@export var distance: float = 0.0  # Gün cinsinden
@export var risk_level: String = "Düşük"  # Düşük, Orta, Yüksek

# Harita / dünya sim köprüsü (EVENT_CONTRACT)
@export var target_settlement_id: String = ""
@export var world_hex_key: String = ""
@export var completes_incident_id: String = ""
## Muttefik yardim cagrisi (world_player_alliances aid_call); WM `apply_alliance_aid_mission_success`
@export var completes_alliance_aid_settlement_id: String = ""
## Oyuncu haritada world_hex_key konumuna giderek görevi tamamlayabilir (cariye şartsız).
@export var allow_player_map_completion: bool = true
## Oyuncu hedef hex'teyken kaynak harcayarak seçebileceği stratejiler (boşsa: tek zar, success_chance).
## Her öğe: { "text": String, "cost": { "food": 5, "medicine": 3 }, "success_chance": 0.25 }
@export var player_map_strategies: Array = []

# Görev zinciri bilgileri
@export var chain_id: String = ""  # Hangi zincire ait
@export var chain_type: ChainType = ChainType.NONE  # Zincir türü
@export var chain_order: int = 0  # Zincirdeki sıra
@export var prerequisite_missions: Array = []  # Önkoşul görevler
@export var unlocks_missions: Array[String] = []  # Bu görev tamamlandığında açılacak görevler
@export var chain_rewards: Dictionary = {}  # Zincir tamamlandığında verilecek ödüller

# Görev durumu
var status: Status = Status.MEVCUT
var assigned_cariye_id: int = -1
var start_time: int = 0  # Oyun zamanı (dakika cinsinden)
var end_time: int = 0  # Oyun zamanı (dakika cinsinden)

# Görev sonuçları
var completed_successfully: bool = false
var actual_rewards: Dictionary = {}
var actual_penalties: Dictionary = {}

func _init():
	# Varsayılan değerler
	id = "mission_" + str(randi())
	name = "İsimsiz Görev"
	description = "Görev açıklaması yok"
	mission_type = MissionType.KEŞİF
	difficulty = Difficulty.KOLAY
	duration = 180.0  # 180 oyun dakikası (3 saat) varsayılan
	success_chance = 0.7

# Görev başlat
func start_mission(cariye_id: int) -> bool:
	if status != Status.MEVCUT:
		return false
	
	status = Status.AKTİF
	assigned_cariye_id = cariye_id
	
	# Oyun zamanını kullan (dakika cinsinden)
	# Resource sınıfında scene tree'ye erişmek için Engine.get_main_loop() kullanıyoruz
	var time_manager = null
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var scene_tree = main_loop as SceneTree
		if scene_tree:
			time_manager = scene_tree.root.get_node_or_null("TimeManager")
	
	if time_manager and time_manager.has_method("get_total_game_minutes"):
		start_time = time_manager.get_total_game_minutes()
		# duration zaten oyun dakikası cinsinden, direkt kullan
		var duration_in_game_minutes = roundi(duration)
		end_time = start_time + duration_in_game_minutes
	else:
		# Fallback: gerçek zaman (eski sistem)
		start_time = int(Time.get_unix_time_from_system())
		end_time = start_time + int(duration)
	
	return true

# Görev tamamla
func complete_mission(successful: bool) -> Dictionary:
	status = Status.TAMAMLANDI if successful else Status.BAŞARISIZ
	completed_successfully = successful
	
	var results = {
		"mission_id": id,
		"mission_name": name,
		"cariye_id": assigned_cariye_id,
		"successful": successful,
		"rewards": rewards if successful else {},
		"penalties": penalties if not successful else {},
		"duration": duration,
		"start_time": start_time,
		"end_time": end_time
	}
	
	return results

# Görev iptal et
func cancel_mission() -> bool:
	if status != Status.AKTİF:
		return false
	
	status = Status.İPTAL
	return true

# Görev süresi kaldı mı?
func is_completed() -> bool:
	return status == Status.TAMAMLANDI or status == Status.BAŞARISIZ or status == Status.İPTAL

# Kalan süre (oyun dakikası cinsinden)
func get_remaining_time() -> float:
	if status != Status.AKTİF:
		return 0.0
	
	# Oyun zamanını kullan
	# Resource sınıfında scene tree'ye erişmek için Engine.get_main_loop() kullanıyoruz
	var time_manager = null
	var main_loop = Engine.get_main_loop()
	if main_loop:
		var scene_tree = main_loop as SceneTree
		if scene_tree:
			time_manager = scene_tree.root.get_node_or_null("TimeManager")
	
	if time_manager and time_manager.has_method("get_total_game_minutes"):
		var current_time = time_manager.get_total_game_minutes()
		var remaining_minutes = end_time - current_time
		# Oyun dakikası cinsinden döndür
		return max(0.0, float(remaining_minutes))
	else:
		# Fallback: gerçek zaman (eski sistem) - gerçek saniyeyi oyun dakikasına çevir
		var current_time = Time.get_unix_time_from_system()
		var remaining_real_seconds = max(0.0, float(end_time) - current_time)
		# Gerçek saniyeyi oyun dakikasına çevir (1 oyun dakikası = 2.5 gerçek saniyesi)
		return remaining_real_seconds / 2.5

# Görev türü adı
func get_mission_type_name() -> String:
	match mission_type:
		MissionType.SAVAŞ: return "Savaş"
		MissionType.KEŞİF: return "Keşif"
		MissionType.DİPLOMASİ: return "Diplomasi"
		MissionType.TİCARET: return "Ticaret"
		MissionType.BÜROKRASİ: return "Bürokrasi"
		_: return "Bilinmeyen"

# Zorluk adı
func get_difficulty_name() -> String:
	match difficulty:
		Difficulty.KOLAY: return "Kolay"
		Difficulty.ORTA: return "Orta"
		Difficulty.ZOR: return "Zor"
		Difficulty.EFSANEVİ: return "Efsanevi"
		_: return "Bilinmeyen"

# Durum adı
func get_status_name() -> String:
	match status:
		Status.MEVCUT: return "Mevcut"
		Status.AKTİF: return "Aktif"
		Status.TAMAMLANDI: return "Tamamlandı"
		Status.BAŞARISIZ: return "Başarısız"
		Status.İPTAL: return "İptal"
		_: return "Bilinmeyen"

# --- GÖREV ZİNCİRİ FONKSİYONLARI ---

# Görev zincirinde mi?
func is_part_of_chain() -> bool:
	return chain_id != "" and chain_type != ChainType.NONE

# Zincir türü adı
func get_chain_type_name() -> String:
	match chain_type:
		ChainType.NONE: return "Bağımsız"
		ChainType.SEQUENTIAL: return "Sıralı"
		ChainType.PARALLEL: return "Paralel"
		ChainType.CHOICE: return "Seçimli"
		_: return "Bilinmeyen"

# Önkoşul görevler tamamlandı mı?
func are_prerequisites_met(completed_missions: Array[String]) -> bool:
	if prerequisite_missions.is_empty():
		return true
	
	for prereq_id in prerequisite_missions:
		if prereq_id not in completed_missions:
			return false
	
	return true

# Bu görev tamamlandığında hangi görevler açılacak?
func get_unlocked_missions() -> Array[String]:
	return unlocks_missions

# Zincir tamamlandı mı? (sadece sıralı zincirler için)
func is_chain_complete(chain_missions: Array[Mission]) -> bool:
	if chain_type != ChainType.SEQUENTIAL:
		return false
	
	# Tüm zincir görevleri tamamlandı mı?
	for mission in chain_missions:
		if mission.chain_id == chain_id and mission.status != Status.TAMAMLANDI:
			return false
	
	return true

# Zincir ödüllerini al
func get_chain_rewards() -> Dictionary:
	return chain_rewards

const MISSION_SAVE_SCHEMA: int = 1

func to_save_dict() -> Dictionary:
	var prereq: Array = []
	if prerequisite_missions is Array:
		prereq = prerequisite_missions.duplicate()
	var unlocks: Array[String] = []
	if unlocks_missions is Array:
		for u in unlocks_missions:
			unlocks.append(str(u))
	var meta_out: Dictionary = {}
	for mk in get_meta_list():
		meta_out[str(mk)] = get_meta(mk)
	var d: Dictionary = {
		"schema": MISSION_SAVE_SCHEMA,
		"id": id,
		"name": name,
		"description": description,
		"mission_type": int(mission_type),
		"difficulty": int(difficulty),
		"duration": duration,
		"success_chance": success_chance,
		"required_cariye_level": required_cariye_level,
		"required_army_size": required_army_size,
		"required_resources": required_resources.duplicate(true),
		"rewards": rewards.duplicate(true),
		"penalties": penalties.duplicate(true),
		"target_location": target_location,
		"distance": distance,
		"risk_level": risk_level,
		"target_settlement_id": target_settlement_id,
		"world_hex_key": world_hex_key,
		"completes_incident_id": completes_incident_id,
		"completes_alliance_aid_settlement_id": completes_alliance_aid_settlement_id,
		"allow_player_map_completion": allow_player_map_completion,
		"player_map_strategies": _duplicate_strategy_rows_for_save(),
		"chain_id": chain_id,
		"chain_type": int(chain_type),
		"chain_order": chain_order,
		"prerequisite_missions": prereq,
		"unlocks_missions": unlocks,
		"chain_rewards": chain_rewards.duplicate(true),
		"status": int(status),
		"assigned_cariye_id": assigned_cariye_id,
		"start_time": start_time,
		"end_time": end_time
	}
	if not meta_out.is_empty():
		d["meta"] = meta_out
	return d

func _duplicate_strategy_rows_for_save() -> Array:
	var out: Array = []
	for item in player_map_strategies:
		if item is Dictionary:
			var row: Dictionary = item.duplicate(true)
			if row.get("cost") is Dictionary:
				row["cost"] = row["cost"].duplicate(true)
			out.append(row)
	return out

static func from_save_dict(d: Dictionary) -> Mission:
	if d.is_empty():
		return null
	var m := Mission.new()
	m.id = str(d.get("id", ""))
	m.name = str(d.get("name", "Gorev"))
	m.description = str(d.get("description", ""))
	m.mission_type = int(d.get("mission_type", MissionType.KEŞİF)) as MissionType
	m.difficulty = int(d.get("difficulty", Difficulty.KOLAY)) as Difficulty
	m.duration = float(d.get("duration", 180.0))
	m.success_chance = float(d.get("success_chance", 0.7))
	m.required_cariye_level = int(d.get("required_cariye_level", 1))
	m.required_army_size = int(d.get("required_army_size", 0))
	if d.get("required_resources") is Dictionary:
		m.required_resources = d["required_resources"].duplicate(true)
	if d.get("rewards") is Dictionary:
		m.rewards = d["rewards"].duplicate(true)
	if d.get("penalties") is Dictionary:
		m.penalties = d["penalties"].duplicate(true)
	m.target_location = str(d.get("target_location", ""))
	m.distance = float(d.get("distance", 0.0))
	m.risk_level = str(d.get("risk_level", "Dusuk"))
	m.target_settlement_id = str(d.get("target_settlement_id", ""))
	m.world_hex_key = str(d.get("world_hex_key", ""))
	m.completes_incident_id = str(d.get("completes_incident_id", ""))
	m.completes_alliance_aid_settlement_id = str(d.get("completes_alliance_aid_settlement_id", ""))
	m.allow_player_map_completion = bool(d.get("allow_player_map_completion", true))
	m.player_map_strategies = []
	if d.get("player_map_strategies") is Array:
		for item in d["player_map_strategies"]:
			if item is Dictionary:
				var row: Dictionary = item.duplicate(true)
				if row.get("cost") is Dictionary:
					row["cost"] = row["cost"].duplicate(true)
				m.player_map_strategies.append(row)
	m.chain_id = str(d.get("chain_id", ""))
	m.chain_type = int(d.get("chain_type", int(ChainType.NONE))) as ChainType
	m.chain_order = int(d.get("chain_order", 0))
	m.prerequisite_missions = []
	if d.get("prerequisite_missions") is Array:
		for p in d["prerequisite_missions"]:
			m.prerequisite_missions.append(p)
	m.unlocks_missions = []
	if d.get("unlocks_missions") is Array:
		for u in d["unlocks_missions"]:
			m.unlocks_missions.append(str(u))
	if d.get("chain_rewards") is Dictionary:
		m.chain_rewards = d["chain_rewards"].duplicate(true)
	m.status = int(d.get("status", int(Status.MEVCUT))) as Status
	m.assigned_cariye_id = int(d.get("assigned_cariye_id", -1))
	m.start_time = int(d.get("start_time", 0))
	m.end_time = int(d.get("end_time", 0))
	if d.get("meta") is Dictionary:
		for mk in d["meta"].keys():
			m.set_meta(str(mk), d["meta"][mk])
	return m
