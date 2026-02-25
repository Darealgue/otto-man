# slide_simsegi.gd
# RARE - Slide sırasında şimşek çakar, yakındaki düşmanlara hasar. Eksi: Slide kontrolü -%20

extends ItemEffect

const LightningFlashScript = preload("res://effects/lightning_flash.gd")
const LIGHTNING_INTERVAL := 0.22
const LIGHTNING_RADIUS := 85.0
const LIGHTNING_DAMAGE := 5.0
const SLIDE_DURATION_MULT := 0.8  # -20% = slide daha kısa sürer

var _player: CharacterBody2D = null
var _timer := 0.0

func _init():
	item_id = "slide_simsegi"
	item_name = "Slide Şimşeği"
	description = "Kayarken şimşek çakar (yakındaki düşmanlara hasar). Slide kontrolü -%20"
	flavor_text = "Elektrikli kayma"
	rarity = ItemRarity.RARE
	category = ItemCategory.SLIDE
	affected_stats = ["slide_lightning", "slide_control"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_timer = 0.0
	var slide_state = player.get_node_or_null("StateMachine/Slide")
	if slide_state:
		if not slide_state.has_meta("original_slide_duration_slide_simsegi"):
			slide_state.set_meta("original_slide_duration_slide_simsegi", slide_state.SLIDE_DURATION)
		slide_state.SLIDE_DURATION = slide_state.get_meta("original_slide_duration_slide_simsegi") * SLIDE_DURATION_MULT
	print("[Slide Şimşeği] ✅ Kayarken şimşek (slide süresi -%20)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	var slide_state = player.get_node_or_null("StateMachine/Slide")
	if slide_state and slide_state.has_meta("original_slide_duration_slide_simsegi"):
		slide_state.SLIDE_DURATION = slide_state.get_meta("original_slide_duration_slide_simsegi")
		slide_state.remove_meta("original_slide_duration_slide_simsegi")
	_player = null
	print("[Slide Şimşeği] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	var sm = player.get_node_or_null("StateMachine")
	if not sm or not sm.current_state or sm.current_state.name != "Slide":
		_timer = 0.0
		return
	_timer += delta
	if _timer < LIGHTNING_INTERVAL:
		return
	_timer = 0.0
	var tree = player.get_tree()
	if not tree or not tree.current_scene:
		return
	var pos = player.global_position
	var flash = Node2D.new()
	flash.set_script(LightningFlashScript)
	tree.current_scene.add_child(flash)
	flash.global_position = pos
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if pos.distance_to(node.global_position) <= LIGHTNING_RADIUS and node.has_method("take_damage"):
			node.take_damage(LIGHTNING_DAMAGE, 0.0, 0.0, true)
