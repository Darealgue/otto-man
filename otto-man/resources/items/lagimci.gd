# lagimci.gd
# UNCOMMON - Osmanlı istihkam eri: tünel kazar, duvar uçurur.
# Kayarken arkanda barut izi bırakırsın; iz 3 sn sonra ya da bir düşman değince patlar.
# Eksi: iz seni de yakar (Barut Zırhı iptal eder).
# Dodge Bombası'nın slide kardeşi; Kaygan Yağ ve Tünel Ustası ile sinerji.

extends ItemEffect

const PowderTrailScript = preload("res://effects/powder_trail.gd")
const SPAWN_INTERVAL := 0.16
## Ateşli Kayma ile aynı pay (bkz. slide_fire_particles kullanımı).
const FOOT_POSITION_CORRECTION := 50.0

var _player: CharacterBody2D = null
var _spawn_timer := 0.0

func _init():
	item_id = "lagimci"
	item_name = tr("item.lagimci.name")
	description = tr("item.lagimci.description")
	flavor_text = "Duvarı yıkan, altından geçendir"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SLIDE
	affected_stats = ["slide_trail_powder"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_spawn_timer = 0.0
	print("[Lağımcı] ✅ Kayarken barut izi bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Lağımcı] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	var sm = player.get_node_or_null("StateMachine")
	if not sm or not sm.current_state or sm.current_state.name != "Slide":
		_spawn_timer = 0.0
		return
	_spawn_timer += delta
	if _spawn_timer < SPAWN_INTERVAL:
		return
	_spawn_timer = 0.0
	var tree = player.get_tree()
	if not tree or not tree.current_scene:
		return
	# get_foot_position() sprite'ın -48 yerel ofsetini saymadığı için zeminin ALTINI
	# döndürüyor; Ateşli Kayma da aynı sebeple yukarı doğru pay veriyor. Aynı payı uygula,
	# yoksa barut izi zeminin içinde çiziliyor.
	var origin: Vector2 = player.global_position
	if player.has_method("get_foot_position"):
		origin = player.get_foot_position() + Vector2(0.0, -FOOT_POSITION_CORRECTION)
	var trail := Node2D.new()
	trail.set_script(PowderTrailScript)
	tree.current_scene.add_child(trail)
	trail.global_position = origin
