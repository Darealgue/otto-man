extends Node

## Zindan eşlikçi kedisinin yöneticisi: seçili eşlikçi kedi (CatRoster), zindan seferinde oyuncuyu izleyen görsel kediyi kurar ve
## özelliğinin küçük avantajını uygular. Kediler ölümsüzdür; oyuncu ölürse kedi sonraki REST_RUNS_AFTER_DEATH seferde gelmez (dinlenir).
## Özellikler (küçük avantajlar; can yenileme YOK):
##   hunter    Avcı: aralıklarla yakındaki bir düşmana küçük hasar vurur (DungeonCatCompanion)
##   gold_nose Altın Burnu: zindanda toplanan altının %10'u kadar fazla (en az +1) (modify_gold)
##   agile     Çevik: hareket hızı +%3
##   sharp     Keskin Pati: temel hasar +%4
##   shadow    Gölge: dash bekleme süresi -%6

const _DungeonCat = preload("res://village/scripts/DungeonCatCompanion.gd")

const GOLD_NOSE_BONUS: float = 0.10
const STAT_TRAITS: Dictionary = {
	"agile": {"stat": "movement_speed", "factor": 1.03},
	"sharp": {"stat": "base_damage", "factor": 1.04},
	"shadow": {"stat": "dash_cooldown", "factor": 0.94},
}

signal companion_arrived(cat_id: String)
signal companion_left(cat_id: String)

var _node: Node2D = null
var _active_cat_id: String = ""          # şu an bu seferde eşlik eden kedi ("" = yok)
var _active_trait: String = ""
var _applied_stat: String = ""           # uygulanmış stat değişikliği (bitince geri alınır)
var _applied_factor: float = 1.0
var _preview_node: Node2D = null         # sefer başlamadan kampta uyuyan (salt görsel) kedi
var _perk_stat: String = ""
var _perk_amount: float = 0.0
var _was_run_started: bool = false
var _skip_this_run: bool = false         # bu sefer dinlenen kedi gelmez
var _tick: float = 0.5


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_update()


func _run_started() -> bool:
	var drs := get_node_or_null("/root/DungeonRunState")
	return drs != null and "run_started" in drs and bool(drs.run_started)


func _in_dungeon_scene() -> bool:
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	return gpd != null and gpd.has_method("uses_dungeon_loot_wallet") and bool(gpd.call("uses_dungeon_loot_wallet"))


const CAMP_SLEEP_OFFSET_X: float = 90.0     # kampta kedi çeşmenin bu kadar yanında uyur

func _in_camp_scene() -> bool:
	var cs: Node = get_tree().current_scene
	if cs != null and String(cs.scene_file_path).ends_with("CampScene.tscn"):
		return true
	var sm := get_node_or_null("/root/SceneManager")
	return sm != null and "current_scene_path" in sm and String(sm.current_scene_path) == String(sm.CAMP_SCENE)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _update() -> void:
	var run_now: bool = _run_started()
	_update_camp_preview(run_now)
	if run_now and not _was_run_started:
		_on_run_started()
	elif not run_now and _was_run_started:
		_on_run_ended()
	_was_run_started = run_now
	var player: Node2D = _player()
	var want: bool = run_now and _in_dungeon_scene() and player != null and not _skip_this_run \
			and not _active_cat_id.is_empty() and not bool(player.get("is_dead")) and not bool(player.get("pending_death"))
	# Sahne türü değişti (zindan <-> kamp): kediyi yeni moduyla yeniden kur.
	if want and is_instance_valid(_node) and bool(_node.get("camp_mode")) != _in_camp_scene():
		_despawn_visual()
	if want and not is_instance_valid(_node):
		_spawn(player)
	elif not want and is_instance_valid(_node):
		_despawn_visual()
	elif is_instance_valid(_node) and _node.get("player") != player and player != null:
		# Bölüm değişti, oyuncu düğümü yenilendi: kediyi yeni oyuncuya bağla.
		_node.set("player", player)
		_node.call("_snap_to_player")


## Sefer henüz başlamadıysa (ilk kamp, kapı seçilmedi) kamp sahnesinde eşlikçi kedi yine çeşmenin yanında uyur (salt görsel: stat yok,
## dinlenme sayacı tüketilmez). Sefer başlayınca ya da kamptan çıkınca kaldırılır; gerçek kedi _update ile kurulur.
func _update_camp_preview(run_now: bool) -> void:
	var player: Node2D = _player()
	var roster := get_node_or_null("/root/CatRoster")
	var want: bool = not run_now and player != null and roster != null and _in_camp_scene() \
			and not bool(player.get("is_dead")) and not bool(player.get("pending_death"))
	var id: String = ""
	if want:
		id = String(roster.get_companion_id())
		want = not id.is_empty() and roster.is_companion_eligible(id) and int(roster.get_rest_runs(id)) <= 0
	if want and not is_instance_valid(_preview_node):
		var prev_id := _active_cat_id
		_active_cat_id = id
		_spawn(player, true)
		_active_cat_id = prev_id
	elif not want and is_instance_valid(_preview_node):
		_preview_node.queue_free()
		_preview_node = null
	elif run_now and is_instance_valid(_preview_node):
		_preview_node.queue_free()
		_preview_node = null


## Yeni sefer: eşlikçi (varsa) belirlenir; dinlenen kedinin sayacı azalır ve bu sefer gelmez.
func _on_run_started() -> void:
	_skip_this_run = false
	_active_cat_id = ""
	_active_trait = ""
	var roster := get_node_or_null("/root/CatRoster")
	if roster == null:
		return
	var id: String = String(roster.get_companion_id())
	if id.is_empty() or not roster.is_companion_eligible(id):
		return
	if roster.consume_rest_for_new_run(id):
		_skip_this_run = true
		return
	_active_cat_id = id
	_active_trait = String(roster.get_trait(id))


func _on_run_ended() -> void:
	_despawn_visual()
	_active_cat_id = ""
	_active_trait = ""
	_skip_this_run = false


func _spawn(player: Node2D, preview: bool = false) -> void:
	var parent: Node = player.get_parent()
	if parent == null:
		return
	var cat: Node2D = _DungeonCat.new()
	cat.set("player", player)
	cat.set("cat_id", _active_cat_id)
	cat.set("trait_id", "" if preview else _active_trait)
	# Kamp sahnesinde kedi oyuncuyu izlemez, çeşmenin yanında uyur.
	if _in_camp_scene():
		var foot: Vector2 = player.global_position   # origin ayak hizasında (get_foot_position sprite boyuna göre ~60 px aşağıda)
		var fountain := get_tree().current_scene.get_node_or_null("Spots/FountainSpot") as Node2D if get_tree().current_scene != null else null
		var home_x: float = (fountain.global_position.x + CAMP_SLEEP_OFFSET_X) if fountain != null else (player.global_position.x + CAMP_SLEEP_OFFSET_X * 1.8)
		# Zemin y'si: çeşme noktasının zemini (CampScene kalabalığıyla aynı: spot.y - 4); oyuncunun o anki y'sine güvenme.
		var home_y: float = fountain.global_position.y if fountain != null else foot.y
		cat.set("camp_mode", true)
		cat.set("camp_home", Vector2(home_x, home_y))
	parent.add_child(cat)
	if preview:
		_preview_node = cat
		return
	_node = cat
	_apply_trait_stat()
	_apply_perk()
	companion_arrived.emit(_active_cat_id)


func _despawn_visual() -> void:
	if is_instance_valid(_node):
		_node.queue_free()
		companion_left.emit(_active_cat_id)
	_node = null
	_revert_trait_stat()
	_revert_perk()


func _apply_trait_stat() -> void:
	_revert_trait_stat()
	if not STAT_TRAITS.has(_active_trait):
		return
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null or not ps.has_method("add_stat_multiplier"):
		return
	var cfg: Dictionary = STAT_TRAITS[_active_trait]
	_applied_stat = String(cfg["stat"])
	_applied_factor = float(cfg["factor"])
	ps.add_stat_multiplier(_applied_stat, _applied_factor)


## Kedinin Mucit tarzı kalıcı bonusu (bir seviyelik: +5 hasar / +25 can / +1 stamina); kedi yanındayken geçerli.
func _apply_perk() -> void:
	_revert_perk()
	var roster := get_node_or_null("/root/CatRoster")
	var ps := get_node_or_null("/root/PlayerStats")
	if roster == null or ps == null or not ps.has_method("add_stat_bonus"):
		return
	var info: Dictionary = MetaUpgradeConfig.get_level_bonus(String(roster.get_perk(_active_cat_id)))
	if String(info["stat"]).is_empty():
		return
	_perk_stat = String(info["stat"])
	_perk_amount = float(info["amount"])
	ps.add_stat_bonus(_perk_stat, _perk_amount)


func _revert_perk() -> void:
	if _perk_stat.is_empty():
		return
	var ps := get_node_or_null("/root/PlayerStats")
	if ps != null and ps.has_method("add_stat_bonus"):
		ps.add_stat_bonus(_perk_stat, -_perk_amount)
	_perk_stat = ""
	_perk_amount = 0.0


func _revert_trait_stat() -> void:
	if _applied_stat.is_empty():
		return
	var ps := get_node_or_null("/root/PlayerStats")
	if ps != null and ps.has_method("add_stat_multiplier") and _applied_factor != 0.0:
		ps.add_stat_multiplier(_applied_stat, 1.0 / _applied_factor)
	_applied_stat = ""
	_applied_factor = 1.0


## Eşlikçi kedinin "item" bonusu: yeni seferin başında verilen ek başlangıç eşyası seçimi sayısı (dinlenen kedi vermez).
func get_extra_start_item_picks() -> int:
	var roster := get_node_or_null("/root/CatRoster")
	if roster == null:
		return 0
	var id: String = String(roster.get_companion_id())
	if id.is_empty() or not roster.is_companion_eligible(id) or int(roster.get_rest_runs(id)) > 0:
		return 0
	return 1 if String(roster.get_perk(id)) == "item" else 0


## Zindanda toplanan altın (GlobalPlayerData.credit_run_loot_gold): Altın Burnu özelliği %10 fazla (en az +1) verir.
func modify_gold(amount: int) -> int:
	if _active_trait != "gold_nose" or amount <= 0 or not is_instance_valid(_node):
		return amount
	return amount + maxi(1, int(round(float(amount) * GOLD_NOSE_BONUS)))


## Oyuncu öldü: eşlik eden kedi dinlenmeye geçer (sonraki REST_RUNS_AFTER_DEATH seferde gelmez).
func on_player_died() -> void:
	if _active_cat_id.is_empty():
		return
	var roster := get_node_or_null("/root/CatRoster")
	if roster != null:
		roster.start_rest(_active_cat_id)
	_despawn_visual()
	_skip_this_run = true
	_active_cat_id = ""
	_active_trait = ""


func reset_for_new_game() -> void:
	# Yeni oyunda PlayerStats zaten sıfırlandı: eski çarpanı geri almaya çalışma.
	_applied_stat = ""
	_applied_factor = 1.0
	_perk_stat = ""
	_perk_amount = 0.0
	if is_instance_valid(_node):
		_node.queue_free()
	_node = null
	_active_cat_id = ""
	_active_trait = ""
	_skip_this_run = false
	_was_run_started = false
