class_name WorldLandmarkConfig
extends RefCounted
## Dünya haritası landmark türleri, görünen adlar ve ziyaret ödülleri.

const TARGET_COUNT: int = 8
const MIN_DIST_FROM_VILLAGE: int = 5
const MIN_DIST_BETWEEN: int = 6

const POI_TYPES: Array[String] = [
	"landmark_ruins",
	"landmark_caravan",
	"landmark_refugee",
]


static func get_display_name(poi_type: String) -> String:
	match poi_type:
		"landmark_ruins":
			return "Harabe"
		"landmark_caravan":
			return "Kervan Kampı"
		"landmark_refugee":
			return "Mülteci Kampı"
		_:
			return "Keşif Noktası"


static func get_visit_blurb(poi_type: String) -> String:
	match poi_type:
		"landmark_ruins":
			return "Eski harabelerde malzeme ve bir miktar altın bulunur."
		"landmark_caravan":
			return "Kervancılar kısa süreli ticaret kolaylığı sağlar."
		"landmark_refugee":
			return "Mülteci kampı köy moralini yükseltir."
		_:
			return "Bu noktayı ziyaret etmek küçük bir ödül verir."


static func build_visit_reward(poi_type: String, rng: RandomNumberGenerator) -> Dictionary:
	match poi_type:
		"landmark_ruins":
			return {
				"kind": "resources",
				"wood": 2 + rng.randi_range(0, 1),
				"stone": 1 + rng.randi_range(0, 1),
				"gold": 6 + rng.randi_range(0, 6),
			}
		"landmark_caravan":
			var resources: Array[String] = ["food", "wood", "stone"]
			return {
				"kind": "trade_buff",
				"resource": resources[rng.randi_range(0, resources.size() - 1)],
				"delta": -8,
				"days": 3,
			}
		"landmark_refugee":
			return {
				"kind": "morale",
				"morale": 4.0 + float(rng.randi_range(0, 2)),
			}
		_:
			return {"kind": "none"}
