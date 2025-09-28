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
@export var duration: float  # Saniye cinsinden
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
var start_time: float = 0.0
var end_time: float = 0.0

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
	duration = 10.0
	success_chance = 0.7

# Görev başlat
func start_mission(cariye_id: int) -> bool:
	if status != Status.MEVCUT:
		return false
	
	status = Status.AKTİF
	assigned_cariye_id = cariye_id
	start_time = Time.get_unix_time_from_system()
	end_time = start_time + duration
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

# Kalan süre
func get_remaining_time() -> float:
	if status != Status.AKTİF:
		return 0.0
	
	var current_time = Time.get_unix_time_from_system()
	return max(0.0, end_time - current_time)

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
