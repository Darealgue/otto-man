class_name RoleMissionCatalog
extends RefCounted
## Cariye rol imza görevleri (rol × 2) ve kişisel hikâye zinciri (3 adım) şablonları.

const STORY_STAGE2_LEVERAGE: int = 4
const STORY_STAGE2_LEVEL: int = 3
const STORY_STAGE3_LEVERAGE: int = 7
const STORY_STAGE3_LEVEL: int = 5


static func get_role_mission_steps(role: Concubine.Role) -> Array[Dictionary]:
	match role:
		Concubine.Role.KOMUTAN:
			return [
				{
					"name_key": "mission.role.komutan.1.name",
					"desc_key": "mission.role.komutan.1.desc",
					"type": Mission.MissionType.SAVAŞ,
					"duration": 140.0,
					"success": 0.78,
					"rewards": {"gold": 16, "reputation": 2},
				},
				{
					"name_key": "mission.role.komutan.2.name",
					"desc_key": "mission.role.komutan.2.desc",
					"type": Mission.MissionType.SAVAŞ,
					"duration": 180.0,
					"success": 0.72,
					"rewards": {"gold": 22, "reputation": 3},
				},
			]
		Concubine.Role.AJAN:
			return [
				{
					"name_key": "mission.role.ajan.1.name",
					"desc_key": "mission.role.ajan.1.desc",
					"type": Mission.MissionType.KEŞİF,
					"duration": 130.0,
					"success": 0.8,
					"rewards": {"gold": 14, "wood": 1},
				},
				{
					"name_key": "mission.role.ajan.2.name",
					"desc_key": "mission.role.ajan.2.desc",
					"type": Mission.MissionType.İSTİHBARAT,
					"duration": 170.0,
					"success": 0.74,
					"rewards": {"gold": 20, "reputation": 2},
				},
			]
		Concubine.Role.DİPLOMAT:
			return [
				{
					"name_key": "mission.role.diplomat.1.name",
					"desc_key": "mission.role.diplomat.1.desc",
					"type": Mission.MissionType.DİPLOMASİ,
					"duration": 150.0,
					"success": 0.82,
					"rewards": {"gold": 15, "reputation": 3},
				},
				{
					"name_key": "mission.role.diplomat.2.name",
					"desc_key": "mission.role.diplomat.2.desc",
					"type": Mission.MissionType.DİPLOMASİ,
					"duration": 190.0,
					"success": 0.76,
					"rewards": {"gold": 24, "reputation": 4},
				},
			]
		Concubine.Role.TÜCCAR:
			return [
				{
					"name_key": "mission.role.tuccar.1.name",
					"desc_key": "mission.role.tuccar.1.desc",
					"type": Mission.MissionType.TİCARET,
					"duration": 140.0,
					"success": 0.84,
					"rewards": {"gold": 18, "food": 1},
				},
				{
					"name_key": "mission.role.tuccar.2.name",
					"desc_key": "mission.role.tuccar.2.desc",
					"type": Mission.MissionType.TİCARET,
					"duration": 175.0,
					"success": 0.78,
					"rewards": {"gold": 26, "stone": 1},
				},
			]
		Concubine.Role.ALIM:
			return [
				{
					"name_key": "mission.role.alim.1.name",
					"desc_key": "mission.role.alim.1.desc",
					"type": Mission.MissionType.BÜROKRASİ,
					"duration": 120.0,
					"success": 0.86,
					"rewards": {"gold": 12, "world_stability": 2},
				},
				{
					"name_key": "mission.role.alim.2.name",
					"desc_key": "mission.role.alim.2.desc",
					"type": Mission.MissionType.BÜROKRASİ,
					"duration": 165.0,
					"success": 0.8,
					"rewards": {"gold": 18, "world_stability": 3},
				},
			]
		Concubine.Role.TIBBIYECI:
			return [
				{
					"name_key": "mission.role.tibbiyeci.1.name",
					"desc_key": "mission.role.tibbiyeci.1.desc",
					"type": Mission.MissionType.BÜROKRASİ,
					"duration": 125.0,
					"success": 0.85,
					"rewards": {"gold": 13, "food": 1},
				},
				{
					"name_key": "mission.role.tibbiyeci.2.name",
					"desc_key": "mission.role.tibbiyeci.2.desc",
					"type": Mission.MissionType.BÜROKRASİ,
					"duration": 160.0,
					"success": 0.79,
					"rewards": {"gold": 19, "reputation": 2},
				},
			]
		_:
			return []


static func get_story_steps() -> Array[Dictionary]:
	return [
		{
			"name_key": "mission.story.1.name",
			"desc_key": "mission.story.1.desc",
			"type": Mission.MissionType.BÜROKRASİ,
			"duration": 100.0,
			"success": 0.9,
			"rewards": {"gold": 10},
			"unlock_leverage": 0,
			"unlock_level": 0,
		},
		{
			"name_key": "mission.story.2.name",
			"desc_key": "mission.story.2.desc",
			"type": Mission.MissionType.DİPLOMASİ,
			"duration": 140.0,
			"success": 0.82,
			"rewards": {"gold": 16, "reputation": 2},
			"unlock_leverage": STORY_STAGE2_LEVERAGE,
			"unlock_level": STORY_STAGE2_LEVEL,
		},
		{
			"name_key": "mission.story.3.name",
			"desc_key": "mission.story.3.desc",
			"type": Mission.MissionType.BÜROKRASİ,
			"duration": 180.0,
			"success": 0.75,
			"rewards": {"gold": 24, "reputation": 4},
			"unlock_leverage": STORY_STAGE3_LEVERAGE,
			"unlock_level": STORY_STAGE3_LEVEL,
		},
	]


static func get_role_chain_rewards() -> Dictionary:
	return {"gold": 15, "reputation": 4}


static func get_story_chain_rewards() -> Dictionary:
	return {"gold": 30, "reputation": 6, "world_stability": 5}
