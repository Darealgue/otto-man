extends Node
class_name VillageWorldPopups
## Köy dünya etkileşim popup'ları — BuildMenuLayer üzerinde tek noktadan yönetim.

const _RestPopupScript := preload("res://ui/CampfireRestPopupUI.gd")
const _MentorPopupScript := preload("res://ui/MentorBriefPopupUI.gd")
const _ConcubinePopupScript := preload("res://ui/ConcubineMissionPopupUI.gd")
const _TraderPopupScript := preload("res://ui/TraderTradePopupUI.gd")
const _CardDraftPopupScript := preload("res://ui/VillageCardDraftUI.gd")

var _rest_popup: CampfireRestPopupUI
var _mentor_popup: MentorBriefPopupUI
var _concubine_popup: ConcubineMissionPopupUI
var _trader_popup: TraderTradePopupUI
var _card_draft_popup: VillageCardDraftUI


func setup(village_scene: Node2D) -> void:
	add_to_group("village_world_popups")
	var canvas := _resolve_canvas(village_scene)
	if not is_instance_valid(_rest_popup):
		_rest_popup = _RestPopupScript.new()
		_rest_popup.name = "CampfireRestPopup"
		canvas.add_child(_rest_popup)
	if not is_instance_valid(_mentor_popup):
		_mentor_popup = _MentorPopupScript.new()
		_mentor_popup.name = "MentorBriefPopup"
		canvas.add_child(_mentor_popup)
	if not is_instance_valid(_concubine_popup):
		_concubine_popup = _ConcubinePopupScript.new()
		_concubine_popup.name = "ConcubineMissionPopup"
		canvas.add_child(_concubine_popup)
	if not is_instance_valid(_trader_popup):
		_trader_popup = _TraderPopupScript.new()
		_trader_popup.name = "TraderTradePopup"
		canvas.add_child(_trader_popup)
	if not is_instance_valid(_card_draft_popup):
		_card_draft_popup = _CardDraftPopupScript.new()
		_card_draft_popup.name = "VillageCardDraftPopup"
		canvas.add_child(_card_draft_popup)


func _resolve_canvas(village_scene: Node2D) -> CanvasLayer:
	var canvas := village_scene.get_node_or_null("BuildMenuLayer") as CanvasLayer
	if is_instance_valid(canvas):
		return canvas
	canvas = get_tree().root.get_node_or_null("PlotPopupCanvas") as CanvasLayer
	if is_instance_valid(canvas):
		return canvas
	canvas = CanvasLayer.new()
	canvas.name = "PlotPopupCanvas"
	canvas.layer = 50
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(canvas)
	return canvas


func open_campfire_rest() -> void:
	if is_instance_valid(_rest_popup):
		_rest_popup.show_popup()


func open_mentor_brief() -> void:
	if is_instance_valid(_mentor_popup):
		_mentor_popup.show_popup()


func open_concubine_missions(concubine: Concubine) -> void:
	if is_instance_valid(_concubine_popup) and concubine != null:
		_concubine_popup.show_for_concubine(concubine)


func open_trader_trade(trader: Dictionary) -> void:
	if is_instance_valid(_trader_popup):
		_trader_popup.show_for_trader(trader)


func is_any_popup_open() -> bool:
	if is_instance_valid(_rest_popup) and _rest_popup._is_open:
		return true
	if is_instance_valid(_rest_popup) and _rest_popup.has_method("is_rest_sequence_active"):
		if _rest_popup.is_rest_sequence_active():
			return true
	if is_instance_valid(_mentor_popup) and _mentor_popup._is_open:
		return true
	if is_instance_valid(_concubine_popup) and _concubine_popup._is_open:
		return true
	if is_instance_valid(_trader_popup) and _trader_popup._is_open:
		return true
	if is_instance_valid(_card_draft_popup) and _card_draft_popup._is_open:
		return true
	return false


static func get_host() -> VillageWorldPopups:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("village_world_popups") as VillageWorldPopups
