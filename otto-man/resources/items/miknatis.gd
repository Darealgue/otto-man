# miknatis.gd
# UNCOMMON - Belli mesafeden paraları (altın) oyuncuya doğru çeker

extends ItemEffect

const PULL_RADIUS := 280.0
const PULL_FORCE := 380.0   # RigidBody2D (düşen altın) için kuvvet
const PULL_SPEED_STATIC := 320.0  # Node2D (level tile altını) için piksel/sn

var _player: CharacterBody2D = null

func _init():
	item_id = "miknatis"
	item_name = "Mıknatıs"
	description = "Belli mesafeden paraları oyuncuya doğru çeker"
	flavor_text = "Paralar sana gelsin"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["magnet_pull"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Mıknatıs] ✅ Paraları çekme aktif")

func deactivate(_p: CharacterBody2D):
	super.deactivate(_p)
	_player = null
	print("[Mıknatıs] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	var tree = get_tree()
	if not tree:
		return
	var player_pos = player.global_position
	var coins = tree.get_nodes_in_group("collectible_gold")
	for node in coins:
		if not is_instance_valid(node):
			continue
		# Hem level tile hem düşen altın: "collected" yoksa veya false ise çek
		if node.get_meta("collected", false):
			continue
		var dist = player_pos.distance_to(node.global_position)
		if dist > PULL_RADIUS or dist < 1.0:
			continue
		var dir = (player_pos - node.global_position).normalized()
		var rb = node as RigidBody2D
		if rb:
			rb.apply_central_force(dir * PULL_FORCE)
		else:
			# Level tile üstündeki statik altın (Node2D): konumu oyuncuya doğru taşı
			node.global_position += dir * PULL_SPEED_STATIC * delta
