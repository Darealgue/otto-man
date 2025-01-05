extends Node

# Attack Types
enum AttackType {
	LIGHT,
	HEAVY,
	FALL
}

func get_attack_config(type: AttackType) -> Dictionary:
	match type:
		AttackType.LIGHT:
			return {
				"damage": 15.0,  # Base damage for light attacks
				"knockback_force": 100.0,  # Reduced from 200 to 100 for lighter hits
				"knockback_up_force": 50.0,  # Reduced from 100 to 50 for smaller upward force
				"combo_multipliers": {
					"light_attack1": 1.0,  # First hit: normal damage and knockback
					"light_attack2": {
						"damage": 1.2,     # 20% more damage
						"knockback": 1.5   # 50% more knockback for the spinning attack
					},
					"light_attack3": {
						"damage": 1.5,     # 50% more damage
						"knockback": 2.0   # Double knockback for the final hit
					}
				}
			}
		AttackType.HEAVY:
			return {
				"damage": 30.0,  # Base damage for heavy attacks
				"knockback_force": 200.0,  # Reduced from 400 to 200
				"knockback_up_force": 100.0  # Reduced from 200 to 100
			}
		AttackType.FALL:
			return {
				"damage": 10.0,  # Weaker than light attacks
				"knockback_force": 150.0,  # Horizontal force on hit
				"knockback_up_force": -300.0,  # Negative for downward force
				"effects": {
					"ground_impact": true,     # Creates impact effect on ground
					"bounce_up": true,         # Makes player bounce up after hit
					"bounce_force": 400.0,     # How high player bounces
					"screen_shake": true,      # Shakes screen on impact
					"stun_duration": 0.5       # How long enemies are stunned
				}
			}
		_:
			return {
				"damage": 10.0,
				"knockback_force": 50.0,
				"knockback_up_force": 25.0
			} 