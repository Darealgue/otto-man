extends Node2D

## Depo — temel kaynak kapasitesi bonusu; Lv1–3 yükseltilebilir.

@export var level: int = 1
@export var max_level: int = 3

var provides_storage: bool = true
var storage_bonus_all: int = 50

var is_upgrading: bool = false
var upgrade_timer: Timer = null
var upgrade_time_seconds: float = 10.0

signal upgrade_started
signal upgrade_finished
signal state_changed

const STORAGE_BONUS_BY_LEVEL := {1: 50, 2: 75, 3: 110}


func _ready() -> void:
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true
	upgrade_timer.timeout.connect(_on_upgrade_finished)
	add_child(upgrade_timer)
	_apply_storage_bonus()


func get_next_upgrade_cost() -> Dictionary:
	return BuildingUpgradeMixin.get_next_cost(self)


func start_upgrade() -> bool:
	return BuildingUpgradeMixin.start(self)


func _on_upgrade_finished() -> void:
	if not is_upgrading:
		return
	is_upgrading = false
	level = mini(max_level, level + 1)
	_apply_storage_bonus()
	upgrade_finished.emit()
	state_changed.emit()
	VillageManager.notify_building_state_changed(self)


func _apply_storage_bonus() -> void:
	storage_bonus_all = int(STORAGE_BONUS_BY_LEVEL.get(level, 50))


func get_production_info() -> String:
	return "Lv.%d • Depo kapasitesi: +%d (tüm temel kaynaklar)" % [level, storage_bonus_all]
