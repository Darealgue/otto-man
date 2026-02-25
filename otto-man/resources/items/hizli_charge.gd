# hizli_charge.gd
# COMMON item - Heavy attack charge süresi -%50

extends ItemEffect

const CHARGE_SPEED_BOOST = 0.5  # %50 daha hızlı = animation speed 1.5x

func _init():
	item_id = "hizli_charge"
	item_name = "Hızlı Charge"
	description = "Heavy attack charge süresi -%50"
	flavor_text = "Daha hızlı hazırlık"
	rarity = ItemRarity.COMMON
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_charge_speed"]

func activate(player: CharacterBody2D):
	super.activate(player)
	var heavy_attack_state = player.get_node_or_null("StateMachine/HeavyAttack")
	if heavy_attack_state:
		# Increase animation speed by 50% (1.5x faster = charge time halved)
		if not heavy_attack_state.has_meta("original_animation_speed_hizli_charge"):
			heavy_attack_state.set_meta("original_animation_speed_hizli_charge", heavy_attack_state.ANIMATION_SPEED)
		heavy_attack_state.ANIMATION_SPEED = heavy_attack_state.ANIMATION_SPEED * (1.0 + CHARGE_SPEED_BOOST)
		print("[Hızlı Charge] ✅ Heavy attack charge süresi -%50")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	var heavy_attack_state = player.get_node_or_null("StateMachine/HeavyAttack")
	if heavy_attack_state and heavy_attack_state.has_meta("original_animation_speed_hizli_charge"):
		heavy_attack_state.ANIMATION_SPEED = heavy_attack_state.get_meta("original_animation_speed_hizli_charge")
		heavy_attack_state.remove_meta("original_animation_speed_hizli_charge")
		print("[Hızlı Charge] ❌ Heavy attack charge süresi eski haline döndü")
