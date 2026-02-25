# patlama_zinciri.gd
# UNCOMMON - Öldürdüğün düşman 2 saniye sonra patlar; hasar hem düşmanlara hem oyuncuya

extends ItemEffect

const DELAY_SECONDS := 2.0
const ChainExplosionScript = preload("res://effects/chain_explosion.gd")

func _init():
	item_id = "patlama_zinciri"
	item_name = "Patlama Zinciri"
	description = "Öldürdüğün düşman 2 sn sonra patlar (düşman + oyuncu hasar alabilir)"
	flavor_text = "Zincir patlama"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["on_kill_explosion"]

func on_enemy_killed(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var pos = enemy.global_position
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	# 2 saniye sonra patlama (oyun zamanı)
	var timer = tree.create_timer(DELAY_SECONDS)
	timer.timeout.connect(_spawn_explosion.bind(pos, tree), CONNECT_ONE_SHOT)

func _spawn_explosion(pos: Vector2, tree: SceneTree) -> void:
	if not tree or not tree.current_scene:
		return
	var explosion = Node2D.new()
	explosion.set_script(ChainExplosionScript)
	tree.current_scene.add_child(explosion)
	explosion.global_position = pos
