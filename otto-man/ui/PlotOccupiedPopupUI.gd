extends Control
class_name PlotOccupiedPopupUI
## Dolu parsel / bina: binanın üstünde yay üzerinde açılan yuvarlak tuşlar (Yükselt, Kat/Ev ekle, Silahlandır, Yükseltmeler, Yık, Vazgeç).
## Merkezin üstünde bina adı, seviye ve işçi sayısı bilgi kutusu görünür; yükseltme ve yıkım için aynı tuşlarla Onayla / Vazgeç sorulur.
## Eski parşömen popup'ın yerini aldı; sinyaller aynı (VillagePlotSystem değişmeden çalışır). Oyunu durdurmaz.

signal upgrade_requested
signal build_house_requested
signal demolish_requested
signal weaponize_requested
signal inventor_upgrades_requested
signal info_requested
signal closed

const _INVENTOR_WORKSHOP_SCENE_PATH := "res://village/buildings/InventorWorkshop.tscn"
const RING_ANCHOR_UP: float = 190.0     # halka merkezi, bina taban noktasının bu kadar üstünde (binanın gövdesi üstünde açılır)
const WRAP_CHARS: int = 38

var _ring: VillageActionRing = null
var _building: Node2D = null
var _is_open := false
var _pending_confirm_action: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ring = VillageActionRing.new()
	_ring.name = "PlotActionRing"
	add_child(_ring)
	_ring.chosen.connect(_on_ring_chosen)
	call_deferred("_reapply_full_rect")


func _reapply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_for_building(building: Node2D) -> void:
	_reapply_full_rect()
	_building = building
	_is_open = true
	_pending_confirm_action = ""
	_open_main_ring()


func hide_popup() -> void:
	_is_open = false
	_pending_confirm_action = ""
	if is_instance_valid(_ring):
		_ring.close_ring()
	_building = null
	closed.emit()


func _center_provider() -> Vector2:
	if not is_instance_valid(_building):
		return get_viewport_rect().size * 0.5
	return get_viewport().get_canvas_transform() * (_building.global_position + Vector2(0.0, -RING_ANCHOR_UP))


func _open_main_ring() -> void:
	if not is_instance_valid(_building) or not is_instance_valid(_ring):
		return
	var scene_path := String(_building.scene_file_path)
	var title: String = LocaleManager.get_building_name(scene_path) if not scene_path.is_empty() else String(_building.name)
	var lvl := int(_building.level) if "level" in _building else 1
	var max_lvl := int(_building.max_level) if "max_level" in _building else 1
	var workers := int(_building.assigned_workers) if "assigned_workers" in _building else 0
	var max_w := int(_building.max_workers) if "max_workers" in _building else 0
	var lines := PackedStringArray([tr("plot.level_display") % [lvl, max_lvl]])
	if max_w > 0:
		lines.append(tr("plot.workers_line") % [workers, max_w])

	var opts: Array[Dictionary] = []
	var upgrading: bool = "is_upgrading" in _building and bool(_building.is_upgrading)
	if _building.has_method("start_upgrade"):
		var up := {"id": "upgrade", "kind": "upgrade", "label": "", "sub": "", "disabled": false}
		if upgrading:
			up["label"] = tr("plot.upgrading")
			up["disabled"] = true
		elif lvl >= max_lvl:
			up["label"] = tr("plot.max_level")
			up["disabled"] = true
		else:
			up["label"] = tr("plot.upgrade_leveled") % (lvl + 1)
			up["sub"] = _format_upgrade_cost(scene_path, lvl + 1)
		opts.append(up)

	var supports_house_floor := false
	if is_instance_valid(VillageManager):
		supports_house_floor = VillageManager.can_build_residential_floor_on(_building) or VillageManager.has_pending_house_floor_on(_building)
	if supports_house_floor:
		var pending_min := VillageManager.get_pending_house_floor_minutes_on(_building)
		var hs := {"id": "house", "kind": "house", "label": "", "sub": "", "disabled": false}
		if pending_min > 0:
			hs["label"] = tr("plot.building")
			hs["sub"] = tr("plot.remaining_hours") % (float(pending_min) / 60.0)
			hs["disabled"] = true
		else:
			var has_floors := scene_path == VillageManager.HOUSE_SCENE_PATH
			if not has_floors:
				var ext := _building.get_node_or_null("ResidentialHousingExtension")
				if ext != null and "current_floors" in ext:
					has_floors = int(ext.current_floors) > 0
			hs["label"] = tr("plot.add_floor") if has_floors else tr("plot.build_house")
			hs["sub"] = _format_house_build_cost()
			hs["disabled"] = not VillageManager.can_build_residential_floor_on(_building)
		opts.append(hs)

	if _building.has_method("equip_soldier"):
		opts.append({"id": "weaponize", "kind": "weapon", "label": tr("plot.weaponize")})
	if scene_path == _INVENTOR_WORKSHOP_SCENE_PATH:
		opts.append({"id": "inventor", "kind": "inventor", "label": tr("plot.inventor_upgrades")})
	opts.append({"id": "demolish", "kind": "demolish", "label": tr("plot.demolish")})
	opts.append({"id": "cancel", "kind": "cancel", "label": tr("wm.cancel")})
	_ring.open_ring(opts, Callable(self, "_center_provider"), title, lines)


## Yükseltme/yıkım gibi geri alınamayan kararlar için aynı tuşlarla "emin misin?" sorar: Onayla / Vazgeç.
## Vazgeçilirse ana halka tekrar açılır.
func _request_confirmation(action: String, title: String, message: String) -> void:
	_pending_confirm_action = action
	var opts: Array[Dictionary] = [
		{"id": "confirm", "kind": "confirm", "label": tr("wm.ok")},
		{"id": "cancel", "kind": "cancel", "label": tr("wm.cancel")},
	]
	_ring.open_ring(opts, Callable(self, "_center_provider"), title, _wrap(message, WRAP_CHARS))


static func _wrap(text: String, max_chars: int) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in text.split(" "):
		if not cur.is_empty() and cur.length() + 1 + word.length() > max_chars:
			out.append(cur)
			cur = word
		else:
			cur = word if cur.is_empty() else cur + " " + word
	if not cur.is_empty():
		out.append(cur)
	return out


func _on_ring_chosen(id: String) -> void:
	match id:
		"upgrade":
			_request_confirmation("upgrade", tr("plot.confirm_upgrade_title"), tr("plot.confirm_upgrade_message"))
		"demolish":
			_request_confirmation("demolish", tr("plot.confirm_demolish_title"), tr("plot.confirm_demolish_message"))
		"house":
			build_house_requested.emit()
			hide_popup()
		"weaponize":
			weaponize_requested.emit()
			hide_popup()
		"inventor":
			inventor_upgrades_requested.emit()
			hide_popup()
		"confirm":
			var action := _pending_confirm_action
			_pending_confirm_action = ""
			match action:
				"upgrade":
					upgrade_requested.emit()
				"demolish":
					demolish_requested.emit()
			hide_popup()
		"cancel":
			if not _pending_confirm_action.is_empty():
				_pending_confirm_action = ""
				_open_main_ring()   # onaydan vazgeçildi: ana halkaya dön
			else:
				hide_popup()
		_:
			hide_popup()


func _format_house_build_cost() -> String:
	if not is_instance_valid(VillageManager):
		return ""
	# Aktif VillageCardEffects kartlarını (altın çarpanı, kaynak muafiyeti, bedava inşa)
	# da yansıtan gerçek maliyet — gösterilen sayı her zaman gerçekte ödenenle eşleşsin.
	var cost: Dictionary = VillageManager.get_effective_build_cost(VillageManager.HOUSE_SCENE_PATH)
	return _format_cost(cost)


func _format_upgrade_cost(scene_path: String, target_level: int) -> String:
	return _format_cost(BuildingUpgradeConfig.get_cost(scene_path, target_level))


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for key in cost.keys():
		var amount := int(cost[key])
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, LocaleManager.get_resource_name(String(key))])
	if parts.is_empty():
		return ""
	return tr("plot.cost_prefix") + ", ".join(parts)
