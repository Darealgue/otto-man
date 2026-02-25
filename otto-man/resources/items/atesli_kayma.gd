# RARE - Yerden kayarken zehir gibi düşen ateş partikülleri; ayak hizasında spawn, yere değince ateş patch'i
extends ItemEffect

const SlideFireScript = preload("res://effects/slide_fire_particles.gd")
const SPAWN_INTERVAL := 0.08

var _player: CharacterBody2D = null
var _slide_spawn_timer := 0.0

func _init():
	item_id = "atesli_kayma"
	item_name = "Ateşli Kayma"
	description = "Kayarken yere ateş bırakır; değen düşmanlar 1 ateş stack alır"
	flavor_text = "Kaydığın yer yanar"
	rarity = ItemRarity.RARE
	category = ItemCategory.SLIDE
	affected_stats = ["slide_trail_fire"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_slide_spawn_timer = 0.0
	print("[Ateşli Kayma] ✅ Kayarken ateş izi bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Ateşli Kayma] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	var sm = player.get_node_or_null("StateMachine")
	if not sm or not sm.current_state or sm.current_state.name != "Slide":
		_slide_spawn_timer = 0.0
		return
	var slide_node = player.get_node_or_null("StateMachine/Slide")
	var slide_dir = slide_node.get("slide_direction") if slide_node else sign(player.velocity.x)
	if slide_dir == 0.0:
		slide_dir = 1.0
	_slide_spawn_timer += delta
	if _slide_spawn_timer >= SPAWN_INTERVAL:
		_slide_spawn_timer = 0.0
		var tree = player.get_tree()
		if not tree or not tree.current_scene:
			return
		var origin = player.get_foot_position()
		var particles = Node2D.new()
		particles.set_script(SlideFireScript)
		tree.current_scene.add_child(particles)
		particles.setup(origin, slide_dir)
