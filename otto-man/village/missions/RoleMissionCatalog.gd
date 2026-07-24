class_name RoleMissionCatalog
extends RefCounted
## Cariye rol imza görevleri (rol × 2) ve kişisel hikâye zinciri (3 adım) şablonları.

const STORY_STAGE2_LEVERAGE: int = 4
const STORY_STAGE2_LEVEL: int = 3
const STORY_STAGE3_LEVERAGE: int = 7
const STORY_STAGE3_LEVEL: int = 5


## Rol KAZANILDIKTAN SONRA açılan, o role özel iki imza görevi — eğitim görevinden bilinçli
## olarak çok daha zor ve günler süren, ama çok daha ödüllü (bkz. LIVING_WORLD_PLAN.md'deki
## "tek skill, dört sonuç" felsefesiyle uyumlu: rol kazanmak gerçek bir yatırım karşılığı olmalı).
static func get_role_mission_steps(role: Concubine.Role) -> Array[Dictionary]:
	match role:
		Concubine.Role.KOMUTAN:
			return [
				{
					"name_key": "mission.role.komutan.1.name",
					"desc_key": "mission.role.komutan.1.desc",
					"type": Mission.MissionType.SAVAŞ,
					"duration": 1440.0,
					"success": 0.62,
					"rewards": {"gold": 60, "reputation": 6},
				},
				{
					"name_key": "mission.role.komutan.2.name",
					"desc_key": "mission.role.komutan.2.desc",
					"type": Mission.MissionType.SAVAŞ,
					"duration": 2160.0,
					"success": 0.55,
					"rewards": {"gold": 90, "reputation": 10},
				},
			]
		Concubine.Role.AJAN:
			return [
				{
					"name_key": "mission.role.ajan.1.name",
					"desc_key": "mission.role.ajan.1.desc",
					"type": Mission.MissionType.KEŞİF,
					"duration": 1440.0,
					"success": 0.64,
					"rewards": {"gold": 55, "wood": 4},
				},
				{
					"name_key": "mission.role.ajan.2.name",
					"desc_key": "mission.role.ajan.2.desc",
					"type": Mission.MissionType.İSTİHBARAT,
					"duration": 2160.0,
					"success": 0.56,
					"rewards": {"gold": 85, "reputation": 8},
				},
			]
		Concubine.Role.DİPLOMAT:
			return [
				{
					"name_key": "mission.role.diplomat.1.name",
					"desc_key": "mission.role.diplomat.1.desc",
					"type": Mission.MissionType.DİPLOMASİ,
					"duration": 1440.0,
					"success": 0.66,
					"rewards": {"gold": 58, "reputation": 8},
				},
				{
					"name_key": "mission.role.diplomat.2.name",
					"desc_key": "mission.role.diplomat.2.desc",
					"type": Mission.MissionType.DİPLOMASİ,
					"duration": 2160.0,
					"success": 0.58,
					"rewards": {"gold": 95, "reputation": 12},
				},
			]
		Concubine.Role.TÜCCAR:
			return [
				{
					"name_key": "mission.role.tuccar.1.name",
					"desc_key": "mission.role.tuccar.1.desc",
					"type": Mission.MissionType.TİCARET,
					"duration": 1440.0,
					"success": 0.68,
					"rewards": {"gold": 70, "food": 5},
				},
				{
					"name_key": "mission.role.tuccar.2.name",
					"desc_key": "mission.role.tuccar.2.desc",
					"type": Mission.MissionType.TİCARET,
					"duration": 2160.0,
					"success": 0.6,
					"rewards": {"gold": 105, "stone": 5},
				},
			]
		Concubine.Role.ALIM:
			return [
				{
					"name_key": "mission.role.alim.1.name",
					"desc_key": "mission.role.alim.1.desc",
					"type": Mission.MissionType.BÜROKRASİ,
					"duration": 1440.0,
					"success": 0.7,
					"rewards": {"gold": 50, "world_stability": 6},
				},
				{
					"name_key": "mission.role.alim.2.name",
					"desc_key": "mission.role.alim.2.desc",
					"type": Mission.MissionType.BÜROKRASİ,
					"duration": 2160.0,
					"success": 0.62,
					"rewards": {"gold": 75, "world_stability": 10},
				},
			]
		Concubine.Role.TIBBIYECI:
			return [
				{
					"name_key": "mission.role.tibbiyeci.1.name",
					"desc_key": "mission.role.tibbiyeci.1.desc",
					"type": Mission.MissionType.BÜROKRASİ,
					"duration": 1440.0,
					"success": 0.7,
					"rewards": {"gold": 52, "food": 4},
				},
				{
					"name_key": "mission.role.tibbiyeci.2.name",
					"desc_key": "mission.role.tibbiyeci.2.desc",
					"type": Mission.MissionType.BÜROKRASİ,
					"duration": 2160.0,
					"success": 0.62,
					"rewards": {"gold": 80, "reputation": 8},
				},
			]
		_:
			return []


## Rol atanmadan ÖNCE tamamlanması gereken tek adımlık "eğitim/sınav" görevi — bkz.
## MissionManager.request_concubine_role. Bu görev başarıyla biterse rol gerçekten atanır.
static func get_role_training_step(role: Concubine.Role) -> Dictionary:
	match role:
		Concubine.Role.KOMUTAN:
			return {
				"name_key": "mission.role_training.komutan.name",
				"desc_key": "mission.role_training.komutan.desc",
				"type": Mission.MissionType.SAVAŞ,
				"duration": 130.0,
				"success": 0.8,
				"rewards": {"gold": 10},
				"required_army_size": 2,  # Komutan adayı yanına asker alıp gider
			}
		Concubine.Role.AJAN:
			return {
				"name_key": "mission.role_training.ajan.name",
				"desc_key": "mission.role_training.ajan.desc",
				"type": Mission.MissionType.İSTİHBARAT,
				"duration": 120.0,
				"success": 0.8,
				"rewards": {"gold": 10},
			}
		Concubine.Role.DİPLOMAT:
			return {
				"name_key": "mission.role_training.diplomat.name",
				"desc_key": "mission.role_training.diplomat.desc",
				"type": Mission.MissionType.DİPLOMASİ,
				"duration": 120.0,
				"success": 0.8,
				"rewards": {"gold": 10},
			}
		Concubine.Role.TÜCCAR:
			return {
				"name_key": "mission.role_training.tuccar.name",
				"desc_key": "mission.role_training.tuccar.desc",
				"type": Mission.MissionType.TİCARET,
				"duration": 110.0,
				"success": 0.82,
				"rewards": {"gold": 10},
			}
		Concubine.Role.ALIM:
			return {
				"name_key": "mission.role_training.alim.name",
				"desc_key": "mission.role_training.alim.desc",
				"type": Mission.MissionType.BÜROKRASİ,
				"duration": 100.0,
				"success": 0.84,
				"rewards": {"gold": 10},
			}
		Concubine.Role.TIBBIYECI:
			return {
				"name_key": "mission.role_training.tibbiyeci.name",
				"desc_key": "mission.role_training.tibbiyeci.desc",
				"type": Mission.MissionType.BÜROKRASİ,
				"duration": 100.0,
				"success": 0.84,
				"rewards": {"gold": 10},
			}
		_:
			return {}


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
	return {"gold": 40, "reputation": 8}


static func get_story_chain_rewards() -> Dictionary:
	return {"gold": 30, "reputation": 6, "world_stability": 5}
