extends Node
## Yeni oyun tutorial oturumu: zindan segmenti + köyde devam için bayraklar.

signal dungeon_movement_lesson_completed

var run_tutorial: bool = false
var dungeon_movement_complete: bool = false
var village_tutorial_pending: bool = false


func reset_session_flags() -> void:
	run_tutorial = false
	dungeon_movement_complete = false
	village_tutorial_pending = false


func mark_started_tutorial_run() -> void:
	run_tutorial = true
	dungeon_movement_complete = false
	village_tutorial_pending = false


func mark_skipped_tutorial_run() -> void:
	run_tutorial = false
	dungeon_movement_complete = false
	village_tutorial_pending = false


func mark_dungeon_movement_complete() -> void:
	dungeon_movement_complete = true
	village_tutorial_pending = true
	dungeon_movement_lesson_completed.emit()


func is_village_tutorial_pending() -> bool:
	return village_tutorial_pending


func consume_village_tutorial_pending() -> bool:
	if not village_tutorial_pending:
		return false
	village_tutorial_pending = false
	return true
