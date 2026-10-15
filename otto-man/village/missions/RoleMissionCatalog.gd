class_name RoleMissionCatalog
extends RefCounted
## Cariye rol imza görevleri (rol × 2) ve kişisel hikâye zinciri (3 adım) şablonları.

const STORY_STAGE2_LEVERAGE: int = 4
const STORY_STAGE2_LEVEL: int = 3
const STORY_STAGE3_LEVERAGE: int = 7
const STORY_STAGE3_LEVEL: int = 5






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




static func get_story_chain_rewards() -> Dictionary:
	return {"gold": 30, "reputation": 6, "world_stability": 5}
