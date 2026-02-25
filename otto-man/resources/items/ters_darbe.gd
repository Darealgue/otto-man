# ters_darbe.gd
# UNCOMMON item - Perfect parry sonrası otomatik karşı saldırı

extends ItemEffect

func _init():
	item_id = "ters_darbe"
	item_name = "Ters Darbe"
	description = "Perfect parry sonrası otomatik karşı saldırı"
	flavor_text = "Savunma = saldırı"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.PARRY
	affected_stats = ["parry_counter"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Ters Darbe] ✅ Perfect parry sonrası otomatik karşı saldırı aktif")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Ters Darbe] ❌ Ters Darbe kaldırıldı")

func _on_perfect_parry():
	if not _player:
		return
	
	# Wait a tiny bit for parry animation to play
	await get_tree().create_timer(0.1).timeout
	
	# Transition to Attack state for automatic counter
	var state_machine = _player.get_node_or_null("StateMachine")
	if state_machine and state_machine.has_node("Attack"):
		print("[Ters Darbe] Otomatik karşı saldırı!")
		state_machine.transition_to("Attack")
