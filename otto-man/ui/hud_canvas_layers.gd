extends RefCounted
class_name HudCanvasLayers

## CanvasLayer sıralaması: dünya karartması / efektler altta, HUD ve menüler üstte (tam parlaklık).

const WORLD_VIGNETTE := 10
const GAMEPLAY_FX := 15
const HUD := 200
const MENU := 210
const OVERLAY := 220
const DIALOG := 300
## Sahne geçişi karartması — HUD ve menülerin üstünde; hepsi birlikte kararır/aydınlanır.
const TRANSITION := 400

static func apply_to_scene_root(scene_root: Node) -> void:
	if scene_root == null:
		return
	_set_layer(scene_root.get_node_or_null("GameUI"), HUD)
	_set_layer(scene_root.get_node_or_null("PauseMenuLayer"), MENU)
	_set_layer(scene_root.get_node_or_null("ScreenDarknessLayer"), WORLD_VIGNETTE)
	_set_layer(scene_root.get_node_or_null("BuildMenuLayer"), MENU)
	for node_name in ["VillageStatusUI", "TimeDisplayUi", "WorkerAssignmentUI", "CariyeManagementUI"]:
		_set_layer(scene_root.get_node_or_null(node_name), HUD)
	var player := scene_root.get_node_or_null("Player")
	if player == null:
		var players := scene_root.get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	if player:
		var ui := player.get_node_or_null("UI")
		_set_layer(ui, HUD)
		if scene_root.get_node_or_null("GameUI") != null and ui is CanvasItem:
			(ui as CanvasItem).hide()


static func apply_to_autoload_fx() -> void:
	var fx := Engine.get_main_loop()
	if fx == null or not (fx is SceneTree):
		return
	var screen_effects: Node = (fx as SceneTree).root.get_node_or_null("ScreenEffects")
	if screen_effects == null:
		return
	var layer_node := screen_effects.get_node_or_null("CanvasLayer")
	_set_layer(layer_node, GAMEPLAY_FX)


static func _set_layer(node: Node, layer: int) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).layer = layer
