# ItemManager.gd
# Central manager for all items in the game.
# Replaces/works alongside PowerupManager for the new item system.

extends Node

signal item_activated(item: ItemEffect)
signal item_deactivated(item: ItemEffect)
signal item_set_activated(set_id: String)
signal item_set_deactivated(set_id: String)

var player: CharacterBody2D
var active_items: Array[ItemEffect] = []
var active_item_sets: Array[String] = []
var _set_bonus_cache: Dictionary = {}
var enemy_kill_count: int = 0
const KILLS_PER_ITEM: int = 10  # Her 10 kill'de item seçimi

# Item selection UI
const ItemSelection = preload("res://ui/item_selection.tscn")
var _item_selection_open: bool = false

# Pilot items (will expand later)
const ITEM_SCENES: Dictionary = {
	"baklava": preload("res://resources/items/baklava.tscn"),
	"simit": preload("res://resources/items/simit.tscn"),
	"ayran": preload("res://resources/items/ayran.tscn"),
	"hizli_el": preload("res://resources/items/hizli_el.tscn"),
	"combo_ustasi": preload("res://resources/items/combo_ustasi.tscn"),
	"zeytinyagi": preload("res://resources/items/zeytinyagi.tscn"),
	"demir_kalkan": preload("res://resources/items/demir_kalkan.tscn"),
	"ruzgar_hanceri": preload("res://resources/items/ruzgar_hanceri.tscn"),
	"yansitici_kalkan": preload("res://resources/items/yansitici_kalkan.tscn"),
	"kalkan_ustasi": preload("res://resources/items/kalkan_ustasi.tscn"),
	"parry_ustasi": preload("res://resources/items/parry_ustasi.tscn"),
	"guc_kayasi": preload("res://resources/items/guc_kayasi.tscn"),
	"gokten_dusus": preload("res://resources/items/gokten_dusus.tscn"),
	"ters_darbe": preload("res://resources/items/ters_darbe.tscn"),
	"cift_vurus": preload("res://resources/items/cift_vurus.tscn"),
	"hizli_charge": preload("res://resources/items/hizli_charge.tscn"),
	"genis_dusus": preload("res://resources/items/genis_dusus.tscn"),
	"kus_kanadi": preload("res://resources/items/kus_kanadi.tscn"),
	"zehirli_tirnak": preload("res://resources/items/zehirli_tirnak.tscn"),
	"parry_ruhu": preload("res://resources/items/parry_ruhu.tscn"),
	"tunel_ustasi": preload("res://resources/items/tunel_ustasi.tscn"),
	"yildirim_adimi": preload("res://resources/items/yildirim_adimi.tscn"),
	"dodge_bombasi": preload("res://resources/items/dodge_bombasi.tscn"),
	"dikenli_kalkan": preload("res://resources/items/dikenli_kalkan.tscn"),
	"atesli_yumruk": preload("res://resources/items/atesli_yumruk.tscn"),
	"buzlu_kilic": preload("res://resources/items/buzlu_kilic.tscn"),
	"kaygan_yag": preload("res://resources/items/kaygan_yag.tscn"),
	"zehirli_dusus": preload("res://resources/items/zehirli_dusus.tscn"),
	"simsek_kalkani": preload("res://resources/items/simsek_kalkani.tscn"),
	"zaman_durdurucu": preload("res://resources/items/zaman_durdurucu.tscn"),
	"kum_saati": preload("res://resources/items/kum_saati.tscn"),
	"zehirli_dev": preload("res://resources/items/zehirli_dev.tscn"),
	"yildirim_dususu": preload("res://resources/items/yildirim_dususu.tscn"),
	"patlama_zinciri": preload("res://resources/items/patlama_zinciri.tscn"),
	"simsek_parmagi": preload("res://resources/items/simsek_parmagi.tscn"),
	"gok_gurultusu": preload("res://resources/items/gok_gurultusu.tscn"),
	"lav_cekici": preload("res://resources/items/lav_cekici.tscn"),
	"donma_cekici": preload("res://resources/items/donma_cekici.tscn"),
	"ates_topu_dususu": preload("res://resources/items/ates_topu_dususu.tscn"),
	"buzlu_kayma": preload("res://resources/items/buzlu_kayma.tscn"),
	"atesli_kayma": preload("res://resources/items/atesli_kayma.tscn"),
	"uzun_menzil": preload("res://resources/items/uzun_menzil.tscn"),
	"ucuncu_vurus": preload("res://resources/items/ucuncu_vurus.tscn"),
	"genis_darbe": preload("res://resources/items/genis_darbe.tscn"),
	"hizlanan_yumruk": preload("res://resources/items/hizlanan_yumruk.tscn"),
	"patlama_topuzu": preload("res://resources/items/patlama_topuzu.tscn"),
	"ruh_avcisi": preload("res://resources/items/ruh_avcisi.tscn"),
	"buz_cagi": preload("res://resources/items/buz_cagi.tscn"),
	"miknatis": preload("res://resources/items/miknatis.tscn"),
	"ikinci_nefes": preload("res://resources/items/ikinci_nefes.tscn"),
	"slide_simsegi": preload("res://resources/items/slide_simsegi.tscn"),
	"cift_ziplama": preload("res://resources/items/cift_ziplama.tscn"),
	"havada_kal": preload("res://resources/items/havada_kal.tscn"),
	"dodge_zehiri": preload("res://resources/items/dodge_zehiri.tscn"),
	"ortaoyunu": preload("res://resources/items/ortaoyunu.tscn"),
	"ziplama_zehiri": preload("res://resources/items/ziplama_zehiri.tscn"),
	"gorunmezlik_pelerini": preload("res://resources/items/gorunmezlik_pelerini.tscn"),
	"berserker_ruhu": preload("res://resources/items/berserker_ruhu.tscn"),
	"nazar_boncugu": preload("res://resources/items/nazar_boncugu.tscn"),
	"kan_tadi": preload("res://resources/items/kan_tadi.tscn"),
	"tas_yurek": preload("res://resources/items/tas_yurek.tscn"),
	"olumcul_sukut": preload("res://resources/items/olumcul_sukut.tscn"),
	"topuk_kirici": preload("res://resources/items/topuk_kirici.tscn"),
	"karagoz_laneti": preload("res://resources/items/karagoz_laneti.tscn"),
	"hacivat_golgesi": preload("res://resources/items/hacivat_golgesi.tscn"),
	"flank_avantaji": preload("res://resources/items/flank_avantaji.tscn"),
	"sessiz_ayakkabi": preload("res://resources/items/sessiz_ayakkabi.tscn"),
	"golge_pelerini": preload("res://resources/items/golge_pelerini.tscn"),
	"elemental_odak": preload("res://resources/items/elemental_odak.tscn"),
}

# Ön koşul: bu item_id sadece listelenen item'lar aktifken seçenekte çıkar (örn. Kum Saati → Zaman Durdurucu)
const ITEM_REQUIREMENTS: Dictionary = {
	"kum_saati": ["zaman_durdurucu"],
	"karagoz_laneti": ["ortaoyunu"],
	"hacivat_golgesi": ["ortaoyunu"],
}

## 2 parça = set bonusu (geri bildirim build — 4 set)
const ITEM_SET_DEFINITIONS: Dictionary = {
	"poison_mastery": {
		"name_key": "item.set.poison.name",
		"items": ["zehirli_tirnak", "zehirli_dev", "zehirli_dusus", "dodge_zehiri", "ziplama_zehiri"],
		"pieces_for_bonus": 2,
		"bonuses": {"poison_damage_mult": 1.4, "poison_max_stacks_bonus": 2},
	},
	"iron_guard": {
		"name_key": "item.set.guard.name",
		"items": ["yansitici_kalkan", "simsek_kalkani", "ters_darbe", "parry_ustasi", "dikenli_kalkan", "demir_kalkan"],
		"pieces_for_bonus": 2,
		"bonuses": {"block_reflect_mult": 1.35},
	},
	"sky_strike": {
		"name_key": "item.set.aerial.name",
		"items": ["yildirim_dususu", "ates_topu_dususu", "buz_cagi", "zehirli_dusus", "gokten_dusus", "genis_dusus"],
		"pieces_for_bonus": 2,
		"bonuses": {"fall_damage_mult": 1.3, "fall_effect_damage_mult": 1.35, "fall_effect_radius_mult": 1.2},
	},
	"tri_element": {
		"name_key": "item.set.elemental.name",
		"items": ["atesli_yumruk", "buzlu_kilic", "simsek_parmagi"],
		"pieces_for_bonus": 2,
		"bonuses": {"elemental_damage_mult": 1.25},
	},
}

func _ready() -> void:
	var container = Node.new()
	container.name = "ActiveItems"
	add_child(container)
	set_process(true)

func _process(delta: float) -> void:
	# Scene transition sirasinda player veya item instance'i freed olabilir.
	# Typed item.process(player: CharacterBody2D, ...) cagrisi oncesi mutlaka validasyon yap.
	if not is_instance_valid(player):
		player = null
		return
	var invalid_items: Array[ItemEffect] = []
	for item in active_items:
		if not is_instance_valid(item):
			invalid_items.append(item)
			continue
		if item.has_method("process"):
			item.process(player, delta)
	for invalid_item in invalid_items:
		active_items.erase(invalid_item)

func _on_decoy_fall_attack_impacted(position: Vector2) -> void:
	# Gölge konumunda fall-attack efektini tüm ilgili itemlere uygula (hitbox aynası gibi tek noktadan)
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if item.has_method("apply_fall_attack_effect_at"):
			item.apply_fall_attack_effect_at(position, true)

func register_player(p: CharacterBody2D) -> void:
	# Gölge fall-attack: önceki oyuncudan disconnect (sahne değişince eski oyuncu freed olabilir)
	var old_player = player
	if is_instance_valid(old_player) and old_player.has_signal("decoy_fall_attack_impacted"):
		if old_player.is_connected("decoy_fall_attack_impacted", _on_decoy_fall_attack_impacted):
			old_player.decoy_fall_attack_impacted.disconnect(_on_decoy_fall_attack_impacted)
	player = p
	if player and player.has_signal("decoy_fall_attack_impacted"):
		if not player.is_connected("decoy_fall_attack_impacted", _on_decoy_fall_attack_impacted):
			player.decoy_fall_attack_impacted.connect(_on_decoy_fall_attack_impacted)
	# Reactivate any existing items for the new player
	for item in active_items:
		if item.has_method("activate"):
			item.activate(player)

func activate_item(item_scene: PackedScene) -> void:
	if !player:
		push_error("[ItemManager] No player registered!")
		return
		
	var item = item_scene.instantiate() as ItemEffect
	if !item:
		push_error("[ItemManager] Failed to instantiate item")
		return
	
	# Initialize item
	_initialize_item(item)
	
	# Add to scene tree and activate
	$ActiveItems.add_child(item)
	active_items.append(item)
	item.activate(player)
	item_activated.emit(item)
	_recalculate_item_sets()
	
	print("[ItemManager] ✅ Activated: ", item.item_name)

func _initialize_item(item: ItemEffect) -> void:
	# Ensure item has access to singletons
	if !item.player_stats:
		item.player_stats = get_node("/root/PlayerStats")
	
	# Connect signals if needed
	if item.has_method("_on_player_dodged") and player.has_signal("player_dodged"):
		if !player.is_connected("player_dodged", item._on_player_dodged):
			player.connect("player_dodged", item._on_player_dodged)
	
	if item.has_method("_on_player_slid") and player.has_signal("player_slid"):
		if !player.is_connected("player_slid", item._on_player_slid):
			player.connect("player_slid", item._on_player_slid)
	
	if item.has_method("_on_player_blocked") and player.has_signal("player_blocked"):
		if !player.is_connected("player_blocked", item._on_player_blocked):
			player.connect("player_blocked", item._on_player_blocked)
	
	if item.has_method("_on_player_attack_landed") and player.has_signal("player_attack_landed"):
		if !player.is_connected("player_attack_landed", item._on_player_attack_landed):
			player.connect("player_attack_landed", item._on_player_attack_landed)
	if item.has_method("_on_player_light_attack_performed") and player.has_signal("player_light_attack_performed"):
		if !player.is_connected("player_light_attack_performed", item._on_player_light_attack_performed):
			player.connect("player_light_attack_performed", item._on_player_light_attack_performed)
	
	if item.has_method("_on_perfect_parry") and player.has_signal("perfect_parry"):
		if !player.is_connected("perfect_parry", item._on_perfect_parry):
			player.connect("perfect_parry", item._on_perfect_parry)
	
	if item.has_method("_on_player_took_damage") and player.has_signal("player_took_damage"):
		if !player.is_connected("player_took_damage", item._on_player_took_damage):
			player.connect("player_took_damage", item._on_player_took_damage)
	
	if item.has_method("_on_fall_attack_impacted") and player.has_signal("fall_attack_impacted"):
		if !player.is_connected("fall_attack_impacted", item._on_fall_attack_impacted):
			player.connect("fall_attack_impacted", item._on_fall_attack_impacted)
	
	if item.has_method("_on_heavy_attack_performed") and player.has_signal("heavy_attack_performed"):
		if !player.is_connected("heavy_attack_performed", item._on_heavy_attack_performed):
			player.connect("heavy_attack_performed", item._on_heavy_attack_performed)
	if item.has_method("_on_heavy_attack_hit") and player.has_signal("heavy_attack_hit"):
		if !player.is_connected("heavy_attack_hit", item._on_heavy_attack_hit):
			player.connect("heavy_attack_hit", item._on_heavy_attack_hit)
	# Zehirli Dev kendi activate() içinde heavy_attack_impact bağlıyor (register_player uyumu için)
	if item.has_method("_on_heavy_attack_impact") and player.has_signal("heavy_attack_impact") and item.get("item_id") != "zehirli_dev":
		if !player.is_connected("heavy_attack_impact", item._on_heavy_attack_impact):
			player.connect("heavy_attack_impact", item._on_heavy_attack_impact)

func deactivate_item(item: ItemEffect) -> void:
	if !player or !item:
		return
		
	# Disconnect signals
	if item.has_method("_on_player_dodged") and player.has_signal("player_dodged"):
		if player.is_connected("player_dodged", item._on_player_dodged):
			player.disconnect("player_dodged", item._on_player_dodged)
	
	if item.has_method("_on_player_slid") and player.has_signal("player_slid"):
		if player.is_connected("player_slid", item._on_player_slid):
			player.disconnect("player_slid", item._on_player_slid)
	
	if item.has_method("_on_player_blocked") and player.has_signal("player_blocked"):
		if player.is_connected("player_blocked", item._on_player_blocked):
			player.disconnect("player_blocked", item._on_player_blocked)
	
	if item.has_method("_on_player_attack_landed") and player.has_signal("player_attack_landed"):
		if player.is_connected("player_attack_landed", item._on_player_attack_landed):
			player.disconnect("player_attack_landed", item._on_player_attack_landed)
	if item.has_method("_on_player_light_attack_performed") and player.has_signal("player_light_attack_performed"):
		if player.is_connected("player_light_attack_performed", item._on_player_light_attack_performed):
			player.disconnect("player_light_attack_performed", item._on_player_light_attack_performed)
	
	if item.has_method("_on_perfect_parry") and player.has_signal("perfect_parry"):
		if player.is_connected("perfect_parry", item._on_perfect_parry):
			player.disconnect("perfect_parry", item._on_perfect_parry)
	
	if item.has_method("_on_player_took_damage") and player.has_signal("player_took_damage"):
		if player.is_connected("player_took_damage", item._on_player_took_damage):
			player.disconnect("player_took_damage", item._on_player_took_damage)
	
	if item.has_method("_on_fall_attack_impacted") and player.has_signal("fall_attack_impacted"):
		if player.is_connected("fall_attack_impacted", item._on_fall_attack_impacted):
			player.disconnect("fall_attack_impacted", item._on_fall_attack_impacted)
	
	if item.has_method("_on_heavy_attack_performed") and player.has_signal("heavy_attack_performed"):
		if player.is_connected("heavy_attack_performed", item._on_heavy_attack_performed):
			player.disconnect("heavy_attack_performed", item._on_heavy_attack_performed)
	if item.has_method("_on_heavy_attack_hit") and player.has_signal("heavy_attack_hit"):
		if player.is_connected("heavy_attack_hit", item._on_heavy_attack_hit):
			player.disconnect("heavy_attack_hit", item._on_heavy_attack_hit)
	if item.has_method("_on_heavy_attack_impact") and player.has_signal("heavy_attack_impact") and item.get("item_id") != "zehirli_dev":
		if player.is_connected("heavy_attack_impact", item._on_heavy_attack_impact):
			player.disconnect("heavy_attack_impact", item._on_heavy_attack_impact)
	
	item.deactivate(player)
	active_items.erase(item)
	item.queue_free()
	item_deactivated.emit(item)
	_recalculate_item_sets()
	
	print("[ItemManager] ❌ Deactivated: ", item.item_name)

func get_active_items() -> Array[ItemEffect]:
	return active_items

func has_active_item(item_id: String) -> bool:
	for item in active_items:
		if item and item.get("item_id") == item_id:
			return true
	return false

func clear_all_items() -> void:
	var current_player_valid: bool = is_instance_valid(player)
	for item in active_items.duplicate():
		if not is_instance_valid(item):
			active_items.erase(item)
			continue
		if current_player_valid:
			deactivate_item(item)
		else:
			# Player yoksa minimum guvenli temizlik: item'i dogrudan serbest birak.
			active_items.erase(item)
			item.queue_free()
	active_items.clear()
	active_item_sets.clear()
	_set_bonus_cache.clear()
	enemy_kill_count = 0  # Sonraki zindan run için sıfırla
	print("[ItemManager] 🗑️ All items cleared")

## Zindan/orman/test_level: ölen düşmandan bazen fiziksel altın (seviye çarpanı ile).
const ENEMY_GOLD_DROP_CHANCE_NORMAL := 0.25
const ENEMY_GOLD_DROP_CHANCE_PREMIUM := 0.50

## Daha zor türler: %50 şans, daha yüksek taban altın (çarpan aynı).
## (PackedStringArray() const ifadesi değil; düz dizi sabit kullan.)
const PREMIUM_ENEMY_PATH_MARKERS: Array[String] = [
	"heavy/",
	"summoner/",
	"canonman/",
	"firemage/",
	"hunter/",
]


func _enemy_loot_script_path(enemy: Node2D) -> String:
	var sc: Variant = enemy.get_script()
	if sc is Script:
		var rp: String = (sc as Script).resource_path
		if rp.is_empty():
			return ""
		return rp.to_lower()
	if enemy.scene_file_path:
		return str(enemy.scene_file_path).to_lower()
	return ""


func _is_turtle_enemy_for_loot(enemy: Node2D) -> bool:
	return _enemy_loot_script_path(enemy).find("turtle") != -1


func _is_summoner_spawned_flying_for_loot(enemy: Node2D) -> bool:
	# Typed class referansi (FlyingEnemy) her sahnede scope'da olmayabilir.
	# Summoner spawn kuslari zaten meta ile isaretleniyor; parser-safe kontrol.
	return bool(enemy.get_meta("summoner_summoned_bird", false))


func _is_premium_enemy_for_loot(enemy: Node2D) -> bool:
	var p: String = _enemy_loot_script_path(enemy)
	if p.is_empty():
		return false
	for m in PREMIUM_ENEMY_PATH_MARKERS:
		if m in p:
			return true
	return false


func _is_dungeon_like_for_loot() -> bool:
	var sm := get_node_or_null("/root/SceneManager")
	if sm:
		var cur = sm.get("current_scene_path")
		if cur:
			var cur_s := str(cur)
			var ds = sm.get("DUNGEON_SCENE")
			var fs = sm.get("FOREST_SCENE")
			if cur_s == ds or cur_s == fs:
				return true
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path:
		var fp: String = scene.scene_file_path
		if "test_level" in fp or "forest" in fp:
			return true
	return false


func _find_decoration_spawner_for_loot() -> DecorationSpawner:
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("decoration_spawner"):
		if n is DecorationSpawner and (n as Node).is_inside_tree():
			return n as DecorationSpawner
	return null


func _try_spawn_enemy_dungeon_gold(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not _is_dungeon_like_for_loot():
		return
	if _is_turtle_enemy_for_loot(enemy):
		return
	if _is_summoner_spawned_flying_for_loot(enemy):
		return
	var premium: bool = _is_premium_enemy_for_loot(enemy)
	var chance: float = ENEMY_GOLD_DROP_CHANCE_PREMIUM if premium else ENEMY_GOLD_DROP_CHANCE_NORMAL
	if randf() > chance:
		return
	var sp := _find_decoration_spawner_for_loot()
	if sp == null:
		return
	var base: int
	if premium:
		base = randi_range(5, 10)
	else:
		base = randi_range(1, 3)
	var total: int = sp.get_scaled_dungeon_gold(base)
	var pos: Vector2 = enemy.global_position
	sp.call_deferred("spawn_enemy_gold_burst", pos, total, premium)


# Called when an enemy is killed
func on_enemy_killed(enemy: Node2D = null) -> void:
	enemy_kill_count += 1
	_try_spawn_enemy_dungeon_gold(enemy)
	_try_drop_expedition_loot_on_kill(enemy)
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and drs.has_method("handle_enemy_defeated") and enemy != null:
		drs.call("handle_enemy_defeated", enemy)

	# Notify items that listen to enemy kills
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if item.has_method("on_enemy_killed"):
			item.on_enemy_killed(enemy)
	
	# Check if we've reached the kill threshold for an item (tek seçim ekranı açık olsun)
	if enemy_kill_count % KILLS_PER_ITEM == 0 and not _item_selection_open:
		await get_tree().create_timer(0.2).timeout
		show_item_selection()


const _DungeonLootDropSpawner = preload("res://interactables/dungeon/DungeonLootDropSpawner.gd")
const ENEMY_LOOT_DROP_CHANCE := 0.05
const ENEMY_LOOT_DROP_CHANCE_PREMIUM := 0.09
const MAX_EXPEDITION_LOOT_DROPS_PER_SEGMENT := 3

var _segment_expedition_loot_drops: int = 0


func reset_segment_expedition_loot_drops() -> void:
	_segment_expedition_loot_drops = 0


func _try_drop_expedition_loot_on_kill(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not _is_dungeon_like_for_loot():
		return
	if _segment_expedition_loot_drops >= MAX_EXPEDITION_LOOT_DROPS_PER_SEGMENT:
		return
	if _is_turtle_enemy_for_loot(enemy):
		return
	if _is_summoner_spawned_flying_for_loot(enemy):
		return
	var premium: bool = _is_premium_enemy_for_loot(enemy)
	var chance: float = ENEMY_LOOT_DROP_CHANCE_PREMIUM if premium else ENEMY_LOOT_DROP_CHANCE
	if randf() > chance:
		return
	var loot_type: String = _DungeonLootDropSpawner.pick_random_enemy_loot_type()
	_DungeonLootDropSpawner.spawn_expedition_loot(enemy.global_position, loot_type, 1)
	_segment_expedition_loot_drops += 1


func show_item_selection() -> void:
	if !player:
		return
	if _item_selection_open:
		return
	_item_selection_open = true
	var selection_ui = ItemSelection.instantiate()
	selection_ui.tree_exiting.connect(_on_item_selection_closed)
	get_tree().root.add_child(selection_ui)
	
	# Get random 3 items from available pool
	var available_items = get_random_items(3)
	selection_ui.setup_items(available_items)
	get_tree().paused = true

func _on_item_selection_closed() -> void:
	_item_selection_open = false

func get_random_items(count: int = 3) -> Array[PackedScene]:
	var available_scenes: Array[PackedScene] = []
	
	for item_id in ITEM_SCENES:
		# Zaten seçilmiş item tekrar çıkmasın
		if has_active_item(item_id):
			continue
		# Ön koşullu item: gerekli item(lar) yoksa seçenekte gösterme
		if item_id in ITEM_REQUIREMENTS:
			var reqs: Array = ITEM_REQUIREMENTS[item_id]
			var all_met := true
			for req_id in reqs:
				if not has_active_item(req_id):
					all_met = false
					break
			if not all_met:
				continue
		available_scenes.append(ITEM_SCENES[item_id])
	
	available_scenes.shuffle()
	return available_scenes.slice(0, min(count, available_scenes.size()))

func has_item(item_id: String) -> bool:
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if item.item_id == item_id:
			return true
	return false

# İkinci Nefes: ölüm anında çağrılır; true dönerse oyuncu 1 canla dirilir (PlayerStats canı 1 yapar)
func try_revive_player() -> bool:
	if not player:
		return false
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if item.has_method("try_revive_player") and item.try_revive_player():
			return true
	return false


func get_set_bonus(bonus_key: String, default_value: float = 1.0) -> float:
	return float(_set_bonus_cache.get(bonus_key, default_value))


func get_set_bonus_int(bonus_key: String, default_value: int = 0) -> int:
	return int(_set_bonus_cache.get(bonus_key, default_value))


func get_active_item_sets() -> Array[String]:
	return active_item_sets.duplicate()


func get_set_hint_if_selected(item_id: String) -> String:
	var best := ""
	for set_id in ITEM_SET_DEFINITIONS.keys():
		var def: Dictionary = ITEM_SET_DEFINITIONS[set_id]
		var members: Array = def.get("items", [])
		if not item_id in members:
			continue
		var owned := _count_owned_set_pieces(members)
		if not has_active_item(item_id):
			owned += 1
		var needed := int(def.get("pieces_for_bonus", 2))
		var set_name := tr(String(def.get("name_key", set_id)))
		if set_id in active_item_sets:
			best = "⚡ " + set_name + " — " + tr("item.set.active_short")
		elif owned >= needed:
			best = "🔗 " + set_name + " — " + tr("item.set.will_activate")
		elif owned == needed - 1:
			best = "🔗 " + set_name + " — " + tr("item.set.one_more")
	return best


func _count_owned_set_pieces(member_ids: Array) -> int:
	var n := 0
	for mid in member_ids:
		if has_active_item(String(mid)):
			n += 1
	return n


func _recalculate_item_sets() -> void:
	var previous := active_item_sets.duplicate()
	active_item_sets.clear()
	_set_bonus_cache.clear()
	for set_id in ITEM_SET_DEFINITIONS.keys():
		var def: Dictionary = ITEM_SET_DEFINITIONS[set_id]
		var members: Array = def.get("items", [])
		var owned := _count_owned_set_pieces(members)
		if owned >= int(def.get("pieces_for_bonus", 2)):
			active_item_sets.append(set_id)
			var bonuses: Dictionary = def.get("bonuses", {})
			for key in bonuses.keys():
				_set_bonus_cache[key] = bonuses[key]
	for set_id in active_item_sets:
		if set_id not in previous:
			item_set_activated.emit(set_id)
			print("[ItemManager] ✨ Set aktif: ", tr(String(ITEM_SET_DEFINITIONS[set_id].get("name_key", set_id))))
	for set_id in previous:
		if set_id not in active_item_sets:
			item_set_deactivated.emit(set_id)
