extends Node
## Demo build sınırları — export öncesi `demo_mode_enabled = true` yap.

@export var demo_mode_enabled: bool = false
@export var max_game_days: int = 21
@export var show_teaser_on_limit: bool = true

var _limit_announced: bool = false


func is_demo_mode() -> bool:
	return demo_mode_enabled


func get_max_game_days() -> int:
	return maxi(1, max_game_days)


func is_day_limit_reached(day: int) -> bool:
	return demo_mode_enabled and day >= get_max_game_days()


func on_village_day_tick(current_day: int) -> void:
	if not demo_mode_enabled or _limit_announced:
		return
	if current_day < get_max_game_days():
		return
	_limit_announced = true
	if not show_teaser_on_limit:
		return
	var mm: Node = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		mm.post_news(
			"village",
			tr("demo.teaser.title"),
			tr("demo.teaser.body") % get_max_game_days(),
			Color(0.85, 0.75, 1.0),
			"info"
		)
	var tm: Node = get_node_or_null("/root/TutorialManager")
	if tm and tm.has_method("enqueue_message"):
		tm.enqueue_message(
			"demo_limit_reached",
			tr("demo.teaser.mentor"),
			"mentor",
			25
		)


func reset_for_new_game() -> void:
	_limit_announced = false
