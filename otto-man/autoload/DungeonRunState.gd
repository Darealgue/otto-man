extends Node
## Zindan run'ı boyunca kurtarılan köylü/cariyeleri tutar.
## Minigame başarılı olunca buraya eklenir; zindandan sağ çıkınca köye aktarılır.
## Ölümde veya yeni zindan girişinde temizlenir.

## Debug: Her levelda köylü + cariye kurtarma odası garanti et.
## Şu an cariye/köylü kurtarma testleri için varsayılanı true yaptık.
## Testler bitince tekrar false'a çevirebilirsin.
var debug_force_rescue_rooms: bool = true

var pending_rescued_villagers: Array = []  # Array of { appearance: dict, name: string }; boş dict = rastgele köylü
var pending_rescued_cariyes: Array = []  # Array of Dictionary: { isim, leverage, appearance }

## Yeni zindan run durumu alanları (kamp sahnesi / challenge kapıları için)
var run_started: bool = false

## Eski tier sistemi için kullanılan alanlar (geçiş sürecinde koruyoruz)
var current_tier: int = 0
var max_tier: int = 5

## Challenge birikimleri (bu run boyunca)
var run_segment_count: int = 0                # Kaç segment oynandı
var enemy_level_offset: int = 0               # Düşman seviyesi adım birikimi
var enemy_count_offset: int = 0               # Düşman sayısı (spawn kotası) adım birikimi
var trap_level_offset: int = 0                # Tuzak seviyesi adım birikimi
var trap_count_offset: int = 0                # Tuzak sayısı (ek grup) birikimi
var gold_multiplier_accumulated: float = 0.0  # Çıkışta uygulanacak ekstra altın çarpanı
var dungeon_size_offset: int = 0              # Harita boyutu adım birikimi
var guaranteed_rescue_next: bool = false      # Sonraki segmentte garanti kurtarma odası
var first_segment_played: bool = false       # İlk segment (tuzaksız, az düşman) oynandı mı

## Altın ve kurtarılan karakterler (run bazlı)
var pending_gold: int = 0        # Bu run boyunca toplanan, henüz köye aktarılmamış altın
var extracted_gold: int = 0      # Çıkış kapısından geçince köye aktarılacak altın miktarı

var rescued_characters: Array = []   # Bu run'da kurtarılan köylü/cariye verileri (detay formatını sen belirleyebilirsin)
var extracted_characters: Array = [] # Çıkış kapısından sonra köye ulaşanlar

## Run başlangıcı / reset
func start_run_from_village(max_tier_value: int = 5) -> void:
	run_started = true
	current_tier = 0
	max_tier = max_tier_value
	run_segment_count = 0
	first_segment_played = false
	_reset_challenge_state()
	pending_gold = 0
	extracted_gold = 0
	rescued_characters.clear()
	extracted_characters.clear()
	clear_pending_rescued()

func end_run() -> void:
	run_started = false
	current_tier = 0
	run_segment_count = 0
	first_segment_played = false
	_reset_challenge_state()
	pending_gold = 0
	extracted_gold = 0
	rescued_characters.clear()
	extracted_characters.clear()
	clear_pending_rescued()

## Basit yardımcılar
func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	pending_gold += amount

func add_rescued_character(data: Dictionary) -> void:
	# Dungeon kurtarma sistemi için daha detaylı bir yapı kullanmak istersen burayı genişletebilirsin.
	rescued_characters.append(data.duplicate(true))

## Eski API'yi koruyan basit yardımcılar (geçici)
func choose_initial_tier(tier: int) -> void:
	current_tier = clamp(tier, 1, max_tier)

func set_next_tier(tier: int) -> void:
	current_tier = clamp(tier, 1, max_tier)

## Challenge kapısından seçim yapıldığında çağrılacak fonksiyon
## challenge_data: {
##   enemy_level_delta, enemy_count_delta, trap_level_delta, trap_count_delta,
##   gold_multiplier_delta, dungeon_size_delta, guaranteed_rescue, is_normal
## }
func apply_challenge(challenge_data: Dictionary) -> void:
	if bool(challenge_data.get("is_exit", false)):
		return
	# Her kapı seçimi yeni bir segment anlamına geliyor
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

func calculate_partial_exit_rewards(gold_fraction: float = 0.25, survivor_chance: float = 0.5) -> void:
	# Altın
	if gold_fraction <= 0.0:
		extracted_gold = 0
	else:
		extracted_gold = int(floor(float(pending_gold) * gold_fraction))

	# Kurtarılan NPC'ler
	extracted_characters.clear()
	if survivor_chance <= 0.0:
		return
	for char_data in rescued_characters:
		if randf() <= survivor_chance:
			extracted_characters.append(char_data)

func clear_pending_on_death() -> void:
	# Ölümde tüm run ödüllerini sil
	pending_gold = 0
	rescued_characters.clear()
	extracted_gold = 0
	extracted_characters.clear()
	clear_pending_rescued()

func clear_pending_rescued() -> void:
	pending_rescued_villagers.clear()
	pending_rescued_cariyes.clear()

func add_pending_villager() -> void:
	pending_rescued_villagers.append({})

func add_pending_villager_data(villager_data: Dictionary) -> void:
	pending_rescued_villagers.append(villager_data.duplicate(true))

func add_pending_cariye(cariye_data: Dictionary) -> void:
	pending_rescued_cariyes.append(cariye_data.duplicate(true))

## Köye dönüşte çağrılır; veriyi döndürür ve listeyi temizler.
func get_and_clear_pending_rescued() -> Dictionary:
	var out := {
		"villagers": pending_rescued_villagers.duplicate(true),
		"cariyes": pending_rescued_cariyes.duplicate(true)
	}
	clear_pending_rescued()
	return out

## Kamp çıkışında kısmi dönüş: her kurtarılan için survivor_chance olasılığıyla listeye eklenir, listeler temizlenir.
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
