# zehirli_tirnak.gd
# UNCOMMON item - Light attack'lar zehir DoT verir (max 5 stack)

extends ItemEffect

const MAX_STACKS = 5
const DAMAGE_PER_STACK = 1.0  # 2 saniyede 1 hasar per stack
const TICK_INTERVAL = 2.0  # 2 saniyede bir tick

func _init():
	item_id = "zehirli_tirnak"
	item_name = "Zehirli Tırnak"
	description = "Light attack'lar zehir verir (max 5 stack, 2 sn'de 1 hasar/stack)"
	flavor_text = "Zehirli dokunuş"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["poison_dot"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Connect to player_attack_landed signal
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
		print("[Zehirli Tırnak] ✅ Light attack'lar zehir verir (max 5 stack)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# Disconnect signal
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Zehirli Tırnak] ❌ Zehirli Tırnak kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, position: Vector2, effect_filter: String = "all"):
	if effect_filter == "physical_only":
		return  # Hacivat gölgesi: sadece elemental; zehir stack uygulanmasın
	if not _player or attack_type != "normal":
		return  # Only for light attacks
	
	# Apply poison stack to all targets
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		# Find the enemy node
		# target is usually the enemy itself (BaseEnemy) passed from attack_state.gd
		var enemy = null
		
		# Check if target itself is BaseEnemy (has add_poison_stack method)
		if target.has_method("add_poison_stack"):
			enemy = target
		# Check parent (in case target is a hurtbox or other child node)
		elif target.get_parent():
			var parent = target.get_parent()
			if parent.has_method("add_poison_stack"):
				enemy = parent
			# Try grandparent
			elif parent.get_parent() and parent.get_parent().has_method("add_poison_stack"):
				enemy = parent.get_parent()
		
		# Add poison stack (Çift Vuruş varsa 2 stack ekle - sinerji)
		if enemy and is_instance_valid(enemy):
			var stacks_to_add = 1
			var im = get_node_or_null("/root/ItemManager")
			if im and im.has_method("has_item") and im.has_item("cift_vurus"):
				stacks_to_add = 2
			for i in range(stacks_to_add):
				enemy.add_poison_stack(MAX_STACKS, DAMAGE_PER_STACK, TICK_INTERVAL)
