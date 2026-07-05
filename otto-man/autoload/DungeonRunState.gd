extends Node
## Zindan run'ı boyunca kurtarılan köylü/cariyeleri tutar.

signal collectibles_changed
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
## Bu run'da oynanacak bölüm sayısı (alıştırma: 1/2/3, tam run: 3).
var run_max_segments: int = MAX_SEGMENTS
## İlk 3 başarılı giriş alıştırma — boss yok, zorluk bonusu yok.
var is_warmup_run: bool = false
var warmup_completion_recorded: bool = false

## Bu run'ın zindanı (dünya haritası hex veya köy portalı)
var dungeon_id: String = ""
## Bu run'da dövülecek boss (BossRoomRegistry kimliği)
var run_boss_id: String = ""
## Bu run'da aktif mastery relic kimliği (DungeonProgress)
var run_active_relic_id: String = ""
## Bu zindanda önceki tamamlamalardan gelen sabit başlangıç zorluğu (kapılardan bağımsız)
var run_base_difficulty: int = 0

var _relic_hp_bonus_applied: float = 0.0

## Challenge birikimleri (bu run boyunca)
var run_segment_count: int = 0                # Seçilen challenge kapısı sayısı
var run_segments_completed: int = 0           # Gerçekten bitirilen bölüm sayısı (finish kapısı)
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
var collected_keys: Array[String] = []  # Run boyunca toplanan kapı anahtarları

const STEALTH_EXIT_BOSS_GOLD_FRACTION: float = 0.25
const DEFAULT_DUNGEON_KEY_ID: String = "dungeon_key"
const SEGMENT_EXIT_KEY_ID: String = "segment_exit_key"
const _DungeonLootDropSpawner = preload("res://interactables/dungeon/DungeonLootDropSpawner.gd")

## Alarm sonrası çıkış kapısı bu segmentte anahtar ister
var segment_exit_requires_key: bool = false
var segment_key_holder_id: String = ""
var segment_alarm_enemy_total: int = 0
var segment_combat_enemies_defeated: int = 0

## Run başlangıcı / reset
func start_run_from_village() -> void:
	_clear_relic_hp_bonus()
	run_active_relic_id = ""
	run_started = true
	run_segment_count = 0
	run_segments_completed = 0
	run_max_segments = MAX_SEGMENTS
	is_warmup_run = false
	warmup_completion_recorded = false
	boss_skipped = false
	stealth_clear = false
	stealth_exit_partial_gold_applied = 0
	_reset_challenge_state()
	clear_pending_rescued()
	collected_keys.clear()
	run_boss_id = _pick_run_boss_id()
	var dp: Node = get_node_or_null("/root/DungeonProgress")
	if is_instance_valid(dp):
		dungeon_id = String(dp.get("active_dungeon_id"))
		if dp.has_method("get_clear_count") and not is_warmup_run:
			run_base_difficulty = int(dp.call("get_clear_count", dungeon_id))
		else:
			run_base_difficulty = 0
		if dp.has_method("consume_stealth_skip_penalty"):
			enemy_count_offset += int(dp.call("consume_stealth_skip_penalty", dungeon_id))
		if dp.has_method("apply_run_start_bonuses"):
			dp.call("apply_run_start_bonuses", self)
	else:
		dungeon_id = ""
		run_base_difficulty = 0
	var stealth_mgr: Node = get_node_or_null("/root/StealthManager")
	if is_instance_valid(stealth_mgr) and stealth_mgr.has_method("reset_for_run"):
		stealth_mgr.call("reset_for_run")
	sync_warmup_limits()
	print("[DungeonRunState] Run başladı: zindan=%s alıştırma=%s tamamlanan=%d/%d (warmup_kayıt=%d)" % [
		dungeon_id,
		is_warmup_run,
		run_segments_completed,
		run_max_segments,
		_get_warmup_completions_for_log(),
	])


## Kamp / bölüm bitişi öncesi: DungeonProgress'ten alıştırma limitlerini yenile.
func sync_warmup_limits() -> void:
	var dp: Node = get_node_or_null("/root/DungeonProgress")
	if not is_instance_valid(dp):
		run_max_segments = MAX_SEGMENTS
		is_warmup_run = false
		return
	if dungeon_id.is_empty() and "active_dungeon_id" in dp:
		dungeon_id = String(dp.get("active_dungeon_id"))
	if not dp.has_method("configure_run_warmup"):
		return
	var warmup_cfg: Dictionary = dp.call("configure_run_warmup", dungeon_id)
	run_max_segments = int(warmup_cfg.get("max_segments", MAX_SEGMENTS))
	is_warmup_run = bool(warmup_cfg.get("is_warmup", false))
	if is_warmup_run:
		run_base_difficulty = 0
	elif dp.has_method("get_clear_count") and run_started:
		run_base_difficulty = int(dp.call("get_clear_count", dungeon_id))


func _get_warmup_completions_for_log() -> int:
	var dp: Node = get_node_or_null("/root/DungeonProgress")
	if not is_instance_valid(dp) or not dp.has_method("get_warmup_completions"):
		return -1
	return int(dp.call("get_warmup_completions", dungeon_id))

func end_run() -> void:
	_clear_relic_hp_bonus()
	run_started = false
	run_segment_count = 0
	run_segments_completed = 0
	run_max_segments = MAX_SEGMENTS
	is_warmup_run = false
	warmup_completion_recorded = false
	run_base_difficulty = 0
	run_active_relic_id = ""
	dungeon_id = ""
	run_boss_id = ""
	boss_skipped = false
	stealth_clear = false
	stealth_exit_partial_gold_applied = 0
	_reset_challenge_state()
	clear_pending_rescued()
	collected_keys.clear()


func has_dungeon_key(key_id: String) -> bool:
	if key_id.is_empty():
		return true
	return collected_keys.has(key_id)


func add_dungeon_key(key_id: String) -> bool:
	var id: String = key_id.strip_edges()
	if id.is_empty():
		return false
	if collected_keys.has(id):
		return false
	collected_keys.append(id)
	print("[DungeonRunState] Anahtar eklendi: %s (toplam %d)" % [id, collected_keys.size()])
	collectibles_changed.emit()
	return true


func reset_segment_exit_state() -> void:
	segment_exit_requires_key = false
	segment_key_holder_id = ""
	segment_alarm_enemy_total = 0
	segment_combat_enemies_defeated = 0
	collected_keys.erase(SEGMENT_EXIT_KEY_ID)
	collectibles_changed.emit()


## Zindan sahnesinde LevelGenerator node'unu bul (kök TestLevel değil).
func find_active_level_generator() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var root: Node = tree.current_scene
	if root.has_method("lock_finish_door_for_alarm"):
		return root
	var named: Node = root.get_node_or_null("LevelGenerator")
	if is_instance_valid(named):
		return named
	for child in root.get_children():
		if is_instance_valid(child) and child.has_method("lock_finish_door_for_alarm"):
			return child
	return null


func notify_segment_exit_key_obtained() -> void:
	var lg := find_active_level_generator()
	if is_instance_valid(lg) and lg.has_method("on_segment_exit_key_obtained"):
		lg.call("on_segment_exit_key_obtained")


func arm_segment_exit_key_lock() -> void:
	segment_exit_requires_key = true
	call_deferred("_snapshot_segment_enemy_quota")


func get_living_segment_key_holder() -> Node:
	return _find_living_key_holder()


func should_show_key_holder_arrow() -> bool:
	if not segment_exit_requires_key:
		return false
	if has_dungeon_key(SEGMENT_EXIT_KEY_ID):
		return false
	if segment_alarm_enemy_total <= 0:
		return false
	var half_threshold: int = int(ceil(float(segment_alarm_enemy_total) * 0.5))
	return segment_combat_enemies_defeated >= half_threshold and _find_living_key_holder() != null


func _snapshot_segment_enemy_quota() -> void:
	var living: int = 0
	var lg: Node = find_active_level_generator()
	if is_instance_valid(lg) and lg.has_method("count_placed_combat_enemies"):
		living = int(lg.call("count_placed_combat_enemies"))
	else:
		living = _count_placed_enemies_fallback()
	segment_alarm_enemy_total = living + segment_combat_enemies_defeated
	print("[DungeonRunState] Alarm düşman kotası: %d (canlı=%d, öldürülen=%d)" % [
		segment_alarm_enemy_total, living, segment_combat_enemies_defeated
	])


func _count_placed_enemies_fallback() -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var count: int = 0
	for node in tree.get_nodes_in_group("enemies"):
		if _is_valid_key_holder_node(node):
			count += 1
	return count


func _register_segment_enemy_defeated(enemy: Node) -> void:
	if not _is_valid_key_holder_node(enemy):
		return
	segment_combat_enemies_defeated += 1


func has_segment_key_holder() -> bool:
	return _find_living_key_holder() != null


func assign_segment_key_holder(enemy: Node) -> void:
	if not _is_valid_key_holder_node(enemy):
		push_warning("[DungeonRunState] Geçersiz anahtar taşıyıcı reddedildi @ %s" % (enemy.global_position if enemy is Node2D else Vector2.ZERO))
		return
	if has_segment_key_holder():
		return
	if not is_instance_valid(enemy):
		return
	var tree := get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group("enemies"):
			if is_instance_valid(node) and node != enemy and node.has_meta("holds_segment_exit_key"):
				node.remove_meta("holds_segment_exit_key")
				_clear_key_holder_marker(node)
	segment_key_holder_id = str(enemy.get_instance_id())
	enemy.set_meta("holds_segment_exit_key", true)


func is_segment_key_holder(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.has_meta("holds_segment_exit_key") and bool(enemy.get_meta("holds_segment_exit_key")):
		return true
	if segment_key_holder_id.is_empty():
		return false
	return str(enemy.get_instance_id()) == segment_key_holder_id


func clear_stale_key_holder_id() -> void:
	var living: Node = _find_living_key_holder()
	if living == null:
		segment_key_holder_id = ""
		_clear_key_holder_meta_on_enemies()


func _clear_key_holder_meta_on_enemies() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(node) and node.has_meta("holds_segment_exit_key"):
			node.remove_meta("holds_segment_exit_key")
			_clear_key_holder_marker(node)


func _clear_key_holder_marker(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var marker: Node = enemy.get_node_or_null("SegmentExitKeyMarker")
	if is_instance_valid(marker):
		marker.queue_free()


func _is_valid_key_holder_node(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	var lg: Node = find_active_level_generator()
	if is_instance_valid(lg) and lg.has_method("is_placed_combat_enemy"):
		return bool(lg.call("is_placed_combat_enemy", enemy))
	if not enemy is Node2D:
		return false
	return (enemy as Node2D).global_position.length_squared() >= 160000.0


func _find_living_key_holder() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		if not is_segment_key_holder(node):
			continue
		if "current_behavior" in node and String(node.current_behavior) == "dead":
			continue
		if not _is_valid_key_holder_node(node):
			continue
		return node
	if not segment_key_holder_id.is_empty():
		segment_key_holder_id = ""
		_clear_key_holder_meta_on_enemies()
	return null


func handle_enemy_defeated(enemy: Node) -> void:
	_register_segment_enemy_defeated(enemy)
	if try_spawn_key_drop_from_enemy(enemy):
		return
	call_deferred("_ensure_alarm_key_available")


func _ensure_alarm_key_available() -> void:
	if not segment_exit_requires_key:
		return
	var sm := get_node_or_null("/root/StealthManager")
	if not is_instance_valid(sm) or not bool(sm.get("segment_alarm")):
		return
	if has_dungeon_key(SEGMENT_EXIT_KEY_ID):
		return
	clear_stale_key_holder_id()
	if has_segment_key_holder():
		return
	var lg: Node = find_active_level_generator()
	if not is_instance_valid(lg):
		return
	if lg.has_method("_collect_segment_key_holder_candidates"):
		var living: Array = lg.call("_collect_segment_key_holder_candidates")
		if not living.is_empty():
			if lg.has_method("_assign_segment_key_holder_deferred"):
				lg.call("_assign_segment_key_holder_deferred")
			return
	if lg.has_method("_spawn_emergency_key_drop"):
		lg.call("_spawn_emergency_key_drop", self)


func try_spawn_key_drop_from_enemy(enemy: Node) -> bool:
	if not is_segment_key_holder(enemy):
		return false
	segment_key_holder_id = ""
	if enemy.has_meta("holds_segment_exit_key"):
		enemy.remove_meta("holds_segment_exit_key")
	_clear_key_holder_marker(enemy)
	var pos: Vector2 = Vector2.ZERO
	if enemy is Node2D:
		pos = (enemy as Node2D).global_position
	if pos.length_squared() < 160000.0:
		var lg: Node = find_active_level_generator()
		if is_instance_valid(lg) and lg.has_method("get_alarm_key_fallback_drop_pos"):
			pos = lg.call("get_alarm_key_fallback_drop_pos")
		var players: Array = get_tree().get_nodes_in_group("player") if get_tree() else []
		if players.size() > 0 and players[0] is Node2D and pos.length_squared() < 160000.0:
			pos = (players[0] as Node2D).global_position + Vector2(0, -40)
	_DungeonLootDropSpawner.spawn_dungeon_key(pos, SEGMENT_EXIT_KEY_ID)
	print("[DungeonRunState] Anahtar düşürüldü @ %s" % pos)
	collectibles_changed.emit()
	return true


func _pick_run_boss_id() -> String:
	if not BossRoomRegistry.is_enabled():
		return ""
	return BossRoomRegistry.DEFAULT_BOSS_ID

func on_segment_completed() -> void:
	if not run_started:
		return
	run_segments_completed += 1
	print("[DungeonRunState] Bölüm tamamlandı: %d/%d (alıştırma=%s)" % [
		run_segments_completed, run_max_segments, is_warmup_run
	])


func is_run_complete() -> bool:
	if not run_started:
		return false
	sync_warmup_limits()
	return run_segments_completed >= run_max_segments

func should_offer_boss() -> bool:
	return run_started and is_run_complete() and not is_warmup_run

func try_finalize_warmup_progress() -> void:
	if warmup_completion_recorded:
		return
	if not run_started or not is_warmup_run or not is_run_complete():
		return
	var dp: Node = get_node_or_null("/root/DungeonProgress")
	if is_instance_valid(dp) and dp.has_method("record_warmup_complete"):
		dp.call("record_warmup_complete", dungeon_id)
		warmup_completion_recorded = true

func is_first_segment() -> bool:
	return run_started and run_segments_completed <= 0

## Boss yenilince saçılacak altın: kapılardan biriken gold_multiplier + segment + mastery.
const BOSS_SCATTER_GOLD_BASE: int = 20
const BOSS_SCATTER_GOLD_PER_MULTIPLIER: float = 45.0
const BOSS_SCATTER_GOLD_PER_SEGMENT: int = 5
const BOSS_SCATTER_GOLD_PER_CLEAR: int = 5

func get_boss_scatter_gold_total() -> int:
	var total: int = BOSS_SCATTER_GOLD_BASE
	total += int(round(gold_multiplier_accumulated * BOSS_SCATTER_GOLD_PER_MULTIPLIER))
	total += run_segments_completed * BOSS_SCATTER_GOLD_PER_SEGMENT
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


func _apply_relic_max_hp_bonus(amount: float) -> void:
	if amount <= 0.0:
		return
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps and ps.has_method("add_stat_bonus"):
		ps.call("add_stat_bonus", "max_health", amount)
		_relic_hp_bonus_applied = amount
		if ps.has_method("set_current_health") and ps.has_method("get_max_health"):
			ps.call("set_current_health", ps.call("get_max_health"), false)


func _clear_relic_hp_bonus() -> void:
	if _relic_hp_bonus_applied <= 0.0:
		return
	var ps: Node = get_node_or_null("/root/PlayerStats")
	if ps and ps.has_method("add_stat_bonus"):
		ps.call("add_stat_bonus", "max_health", -_relic_hp_bonus_applied)
	_relic_hp_bonus_applied = 0.0

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
