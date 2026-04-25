extends Node
## Zindan run'ı boyunca kurtarılan köylü/cariyeleri tutar.
## Minigame başarılı olunca buraya eklenir; zindandan sağ çıkınca köye aktarılır.
## Ölümde veya yeni zindan girişinde temizlenir.

## Debug: Her levelda köylü + cariye kurtarma odası garanti et.
## Testler bitince tekrar false'a çevirebilirsin.
var debug_force_rescue_rooms: bool = false

var pending_rescued_villagers: Array = []  # Array of { appearance: dict, name: string }; boş dict = rastgele köylü
var pending_rescued_cariyes: Array = []  # Array of Dictionary: { isim, leverage, appearance }

## Zindan run durumu
var run_started: bool = false
const MAX_SEGMENTS: int = 3

## Challenge birikimleri (bu run boyunca)
var run_segment_count: int = 0                # Kaç segment oynandı
var enemy_level_offset: int = 0               # Düşman seviyesi adım birikimi
var enemy_count_offset: int = 0               # Düşman sayısı (spawn kotası) adım birikimi
var trap_level_offset: int = 0                # Tuzak seviyesi adım birikimi
var trap_count_offset: int = 0                # Tuzak sayısı (ek grup) birikimi
var gold_multiplier_accumulated: float = 0.0  # Çıkışta uygulanacak ekstra altın çarpanı
var dungeon_size_offset: int = 0              # Harita boyutu adım birikimi
var guaranteed_rescue_next: bool = false      # Sonraki segmentte garanti kurtarma odası

## Run başlangıcı / reset
func start_run_from_village() -> void:
	run_started = true
	run_segment_count = 0
	_reset_challenge_state()
	clear_pending_rescued()

func end_run() -> void:
	run_started = false
	run_segment_count = 0
	_reset_challenge_state()
	clear_pending_rescued()

func is_run_complete() -> bool:
	return run_started and run_segment_count >= MAX_SEGMENTS

func is_first_segment() -> bool:
	return run_started and run_segment_count <= 1

## Challenge kapısından seçim yapıldığında çağrılır
func apply_challenge(challenge_data: Dictionary) -> void:
	if bool(challenge_data.get("is_exit", false)):
		return
	run_segment_count += 1

	enemy_level_offset += int(challenge_data.get("enemy_level_delta", 0))
	enemy_count_offset += int(challenge_data.get("enemy_count_delta", 0))
	trap_level_offset += int(challenge_data.get("trap_level_delta", 0))
	trap_count_offset += int(challenge_data.get("trap_count_delta", 0))
	dungeon_size_offset += int(challenge_data.get("dungeon_size_delta", 0))

	var gold_delta: float = float(challenge_data.get("gold_multiplier_delta", 0.0))
	gold_multiplier_accumulated += gold_delta

	if bool(challenge_data.get("guaranteed_rescue", false)):
		guaranteed_rescue_next = true

func _reset_challenge_state() -> void:
	enemy_level_offset = 0
	enemy_count_offset = 0
	trap_level_offset = 0
	trap_count_offset = 0
	gold_multiplier_accumulated = 0.0
	dungeon_size_offset = 0
	guaranteed_rescue_next = false

## Kurtarma yardımcıları

func clear_pending_rescued() -> void:
	pending_rescued_villagers.clear()
	pending_rescued_cariyes.clear()

func add_pending_villager() -> void:
	pending_rescued_villagers.append({})

func add_pending_villager_data(villager_data: Dictionary) -> void:
	pending_rescued_villagers.append(villager_data.duplicate(true))

func add_pending_cariye(cariye_data: Dictionary) -> void:
	pending_rescued_cariyes.append(cariye_data.duplicate(true))

func get_and_clear_pending_rescued() -> Dictionary:
	var out := {
		"villagers": pending_rescued_villagers.duplicate(true),
		"cariyes": pending_rescued_cariyes.duplicate(true)
	}
	clear_pending_rescued()
	return out

func get_partial_exit_rescued(survivor_chance: float) -> Dictionary:
	var villagers: Array = []
	var cariyes: Array = []
	for v in pending_rescued_villagers:
		if randf() <= survivor_chance:
			villagers.append(v.duplicate(true) if v is Dictionary else v)
	for c in pending_rescued_cariyes:
		if randf() <= survivor_chance:
			cariyes.append(c.duplicate(true) if c is Dictionary else c)
	clear_pending_rescued()
	return { "villagers": villagers, "cariyes": cariyes }
