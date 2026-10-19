extends BaseInteractable

# Köy kuyusuna bağlanan günlük su çekme oyunu: oyuncu kuyuya yaklaşıp etkileşime girer, ritim minigame'ini (forest_water)
# oynar; başarılı olursa köy moraline +1 eklenir. Moral isteyen oyuncu kuyuyu sağamasın diye günde tek deneme hakkı vardır
# (başarılı ya da başarısız); yeni günde kuyu yeniden açılır. Kuyu düğümü (Well.gd) bu etkileşimi kendisi kurar.

const MORALE_REWARD: float = 1.0
const HITS_REQUIRED: int = 2
const SWEET_SPOT_WIDTH: float = 0.14
const META_LAST_DAY: StringName = &"well_morale_last_day"

var _time_manager: Node = null

func _ready() -> void:
	minigame_kind = "forest_water"
	require_interact_press = true
	auto_disable_on_success = true
	auto_disable_on_failure = true
	interact_arrow_offset = Vector2(0.0, -150.0)
	super._ready()
	_time_manager = get_node_or_null("/root/TimeManager")
	if _time_manager != null and _time_manager.has_signal("day_changed") and not _time_manager.day_changed.is_connected(_on_day_changed):
		_time_manager.day_changed.connect(_on_day_changed)
	if _already_used_today():
		set_interactable_enabled(false)

func _current_day() -> int:
	if _time_manager != null and _time_manager.has_method("get_day"):
		return int(_time_manager.get_day())
	return 0

func _already_used_today() -> bool:
	var vm := get_node_or_null("/root/VillageManager")
	return vm != null and vm.has_meta(META_LAST_DAY) and int(vm.get_meta(META_LAST_DAY)) == _current_day()

func _mark_used_today() -> void:
	var vm := get_node_or_null("/root/VillageManager")
	if vm != null:
		vm.set_meta(META_LAST_DAY, _current_day())

func _on_day_changed(_new_day: int) -> void:
	set_interactable_enabled(true)

func _build_minigame_context() -> Dictionary:
	var ctx := super._build_minigame_context()
	ctx["depth"] = 1
	ctx["difficulty"] = 1
	ctx["hits_required"] = HITS_REQUIRED
	ctx["sweet_spot"] = SWEET_SPOT_WIDTH
	# "morale" türü MinigameRouter'da taşınan kaynağa eklenmez; ödülü _on_minigame_success verir (+1 yazısı kuyunun üstünde çıkar).
	ctx["resource_type"] = "morale"
	ctx["resource_base"] = int(MORALE_REWARD)
	ctx["perfect_bonus"] = 0
	ctx["well_path"] = get_path()
	return ctx

func _on_minigame_started() -> void:
	# Oyuncu kuyudan uzaklaşıp minigame'i iptal etse de o günün hakkı sayılmasın diye hak sonuçta işaretlenir.
	pass

func _on_minigame_success(_payload: Dictionary) -> void:
	var vm := get_node_or_null("/root/VillageManager")
	if vm != null and "village_morale" in vm:
		vm.village_morale = minf(100.0, float(vm.village_morale) + MORALE_REWARD)
		if vm.has_signal("village_data_changed"):
			vm.emit_signal("village_data_changed")
	_mark_used_today()

func _on_minigame_failure(payload: Dictionary) -> void:
	# Uzaklaşıp iptal etmek hakkı yakmaz; gerçek bir başarısızlık yakar.
	if bool(payload.get("distance_cancelled", false)):
		set_interactable_enabled(true)
		return
	_mark_used_today()
