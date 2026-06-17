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

## Bu run'ın zindanı (dünya haritası hex veya köy portalı)
var dungeon_id: String = ""
## Bu run'da dövülecek boss (BossRoomRegistry kimliği)
var run_boss_id: String = "tepegoz"
## Bu zindanda önceki tamamlamalardan gelen sabit başlangıç zorluğu (kapılardan bağımsız)
var run_base_difficulty: int = 0

## Challenge birikimleri (bu run boyunca)
var run_segment_count: int = 0                # Kaç segment oynandı
var enemy_level_offset: int = 0               # Düşman seviyesi adım birikimi
var enemy_count_offset: int = 0               # Düşman sayısı (spawn kotası) adım birikimi
var trap_level_offset: int = 0                # Tuzak seviyesi adım birikimi
var trap_count_offset: int = 0                # Tuzak sayısı (ek grup) birikimi
var gold_multiplier_accumulated: float = 0.0  # Çıkışta uygulanacak ekstra altın çarpanı
var dungeon_size_offset: int = 0              # Harita boyutu adım birikimi
var guaranteed_rescue_next: bool = false      # Sonraki segmentte garanti kurtarma odası
var active_segment_modifiers: Array[String] = []  # Seçilen kapının segment modifier'ları
var boss_skipped: bool = false                # Boss atlanarak stealth çıkış yapıldı
var stealth_clear: bool = false               # Tüm run alarm olmadan tamamlandı (stealth çıkış)
var stealth_exit_partial_gold_applied: int = 0  # Gizli çıkışta eklenen kısmi boss altını

const STEALTH_EXIT_BOSS_GOLD_FRACTION: float = 0.25

## Run başlangıcı / reset
func start_run_from_village() -> void:
	run_started = true
	run_segment_count = 0
	boss_skipped = false
	stealth_clear = false
	stealth_exit_partial_gold_applied = 0
	_reset_challenge_state()
	clear_pending_rescued()
	run_boss_id = _pick_run_boss_id()
	var dp: Node = get_node_or_null("/root/DungeonProgress")
	if is_instance_valid(dp):
		dungeon_id = String(dp.get("active_dungeon_id"))
		if dp.has_method("get_clear_count"):
			run_base_difficulty = int(dp.call("get_clear_count", dungeon_id))
		if dp.has_method("consume_stealth_skip_penalty"):
			enemy_count_offset += int(dp.call("consume_stealth_skip_penalty", dungeon_id))
	else:
		dungeon_id = ""
		run_base_difficulty = 0
	var stealth_mgr: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(stealth_mgr) and stealth_mgr.has_method("reset_for_run"):
		stealth_mgr.call("reset_for_run")

func end_run() -> void:
	run_started = false
	run_segment_count = 0
	run_base_difficulty = 0
	dungeon_id = ""
	run_boss_id = BossRoomRegistry.DEFAULT_BOSS_ID
	boss_skipped = false
	stealth_clear = false
	stealth_exit_partial_gold_applied = 0
	_reset_challenge_state()
	clear_pending_rescued()


func _pick_run_boss_id() -> String:
	# MVP: her run Tepegöz. İleride dungeon_id / clear sayısına göre genişletilir.
	return BossRoomRegistry.DEFAULT_BOSS_ID

func is_run_complete() -> bool:
	return run_started and run_segment_count >= MAX_SEGMENTS

func is_first_segment() -> bool:
	return run_started and run_segment_count <= 1

## Boss yenilince saçılacak altın: kapılardan biriken gold_multiplier + segment + mastery.
const BOSS_SCATTER_GOLD_BASE: int = 20
const BOSS_SCATTER_GOLD_PER_MULTIPLIER: float = 45.0
const BOSS_SCATTER_GOLD_PER_SEGMENT: int = 5
const BOSS_SCATTER_GOLD_PER_CLEAR: int = 5

func get_boss_scatter_gold_total() -> int:
	var total: int = BOSS_SCATTER_GOLD_BASE
	total += int(round(gold_multiplier_accumulated * BOSS_SCATTER_GOLD_PER_MULTIPLIER))
	total += run_segment_count * BOSS_SCATTER_GOLD_PER_SEGMENT
	total += run_base_difficulty * BOSS_SCATTER_GOLD_PER_CLEAR
	return maxi(BOSS_SCATTER_GOLD_BASE, total)


func apply_stealth_exit_partial_boss_gold() -> int:
	var total: int = get_boss_scatter_gold_total()
	var partial: int = int(floor(float(total) * STEALTH_EXIT_BOSS_GOLD_FRACTION))
	if partial <= 0:
		return 0
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if is_instance_valid(gpd) and gpd.has_method("add_dungeon_gold"):
		gpd.call("add_dungeon_gold", partial)
	stealth_exit_partial_gold_applied = partial
	print("[DungeonRunState] Stealth çıkış boss altını (kısmi): %d / %d" % [partial, total])
	return partial

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

	active_segment_modifiers.clear()
	var mods: Variant = challenge_data.get("modifiers", [])
	if mods is Array:
		for m in mods:
			var mid := String(m)
			if not mid.is_empty() and mid not in active_segment_modifiers:
				active_segment_modifiers.append(mid)

func has_segment_modifier(modifier_id: String) -> bool:
	return modifier_id in active_segment_modifiers

func get_active_segment_modifiers() -> Array[String]:
	return active_segment_modifiers.duplicate()

func clear_active_segment_modifiers() -> void:
	active_segment_modifiers.clear()

func get_segment_modifier_display_names() -> Array[String]:
	const NAMES: Dictionary = {
		"no_parry": "Parry yok",
		"no_heal": "İyileşme yok",
		"night_mode": "Gece",
		"light_only": "Sadece hafif",
	}
	var out: Array[String] = []
	for m in active_segment_modifiers:
		out.append(String(NAMES.get(m, m)))
	return out

func _reset_challenge_state() -> void:
	enemy_level_offset = 0
	enemy_count_offset = 0
	trap_level_offset = 0
	trap_count_offset = 0
	gold_multiplier_accumulated = 0.0
	dungeon_size_offset = 0
	guaranteed_rescue_next = false
	active_segment_modifiers.clear()

## Kurtarma yardımcıları

func clear_pending_rescued() -> void:
	pending_rescued_villagers.clear()
	pending_rescued_cariyes.clear()

func add_pending_villager(fragile: bool = false) -> void:
	pending_rescued_villagers.append({"fragile": fragile})


func add_pending_villager_data(villager_data: Dictionary, fragile: bool = false) -> void:
	var entry: Dictionary = villager_data.duplicate(true)
	entry["fragile"] = fragile
	pending_rescued_villagers.append(entry)


func add_pending_cariye(cariye_data: Dictionary, fragile: bool = false) -> void:
	var entry: Dictionary = cariye_data.duplicate(true)
	entry["fragile"] = fragile
	pending_rescued_cariyes.append(entry)


func count_fragile_rescued() -> Dictionary:
	var villagers: int = 0
	var cariyes: int = 0
	for v in pending_rescued_villagers:
		if v is Dictionary and bool((v as Dictionary).get("fragile", false)):
			villagers += 1
	for c in pending_rescued_cariyes:
		if c is Dictionary and bool((c as Dictionary).get("fragile", false)):
			cariyes += 1
	return {"villagers": villagers, "cariyes": cariyes}


func purge_fragile_rescues() -> Dictionary:
	var villagers_lost: int = 0
	var cariyes_lost: int = 0
	var kept_villagers: Array = []
	for v in pending_rescued_villagers:
		if v is Dictionary and bool((v as Dictionary).get("fragile", false)):
			villagers_lost += 1
		else:
			kept_villagers.append(v.duplicate(true) if v is Dictionary else v)
	var kept_cariyes: Array = []
	for c in pending_rescued_cariyes:
		if c is Dictionary and bool((c as Dictionary).get("fragile", false)):
			cariyes_lost += 1
		else:
			kept_cariyes.append(c.duplicate(true) if c is Dictionary else c)
	pending_rescued_villagers = kept_villagers
	pending_rescued_cariyes = kept_cariyes
	if villagers_lost > 0 or cariyes_lost > 0:
		print("[DungeonRunState] Kırılgan kurtarmalar kaçtı — köylü=%d cariye=%d" % [villagers_lost, cariyes_lost])
	return {"villagers": villagers_lost, "cariyes": cariyes_lost}


func _strip_fragile_flags_for_delivery(entries: Array) -> Array:
	var out: Array = []
	for entry in entries:
		if entry is Dictionary:
			var d: Dictionary = (entry as Dictionary).duplicate(true)
			d.erase("fragile")
			out.append(d)
		else:
			out.append(entry)
	return out

func get_and_clear_pending_rescued() -> Dictionary:
	var out := {
		"villagers": _strip_fragile_flags_for_delivery(pending_rescued_villagers.duplicate(true)),
		"cariyes": _strip_fragile_flags_for_delivery(pending_rescued_cariyes.duplicate(true))
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
