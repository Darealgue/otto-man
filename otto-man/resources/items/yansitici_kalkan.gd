# yansitici_kalkan.gd
# UNCOMMON item - Block sırasında hasar yansıtır

extends ItemEffect

const REFLECT_PERCENTAGE = 0.5  # 50% of blocked damage reflected

func _init():
	item_id = "yansitici_kalkan"
	item_name = "Yansıtıcı Kalkan"
	description = "Block sırasında gelen hasarın %50'si düşmana yansır"
	flavor_text = "Savunma = saldırı"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.BLOCK
	affected_stats = []

func activate(player: CharacterBody2D):
	super.activate(player)
	
	# Connect to player_blocked signal
	if player.has_signal("player_blocked"):
		if not player.is_connected("player_blocked", _on_player_blocked):
			player.connect("player_blocked", _on_player_blocked)
		print("[Yansıtıcı Kalkan] ✅ Aktif - block yansıtma hazır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	
	if player.has_signal("player_blocked"):
		if player.is_connected("player_blocked", _on_player_blocked):
			player.disconnect("player_blocked", _on_player_blocked)
		print("[Yansıtıcı Kalkan] ❌ Deaktif")

func _on_player_blocked(blocked_damage: float, attacker: Node2D):
	if !attacker or blocked_damage <= 0:
		return
	
	# Reflect damage back to attacker
	var reflected_damage = blocked_damage * REFLECT_PERCENTAGE
	
	# Try to damage the attacker
	if attacker.has_method("take_damage"):
		attacker.take_damage(reflected_damage)
		print("[Yansıtıcı Kalkan] ⚡ Yansıtılan hasar: ", reflected_damage, " → ", attacker.name)
	elif attacker.has_node("Hurtbox"):
		var hurtbox = attacker.get_node("Hurtbox")
		if hurtbox.has_method("take_damage"):
			hurtbox.take_damage(reflected_damage)
			print("[Yansıtıcı Kalkan] ⚡ Yansıtılan hasar (hurtbox): ", reflected_damage)
