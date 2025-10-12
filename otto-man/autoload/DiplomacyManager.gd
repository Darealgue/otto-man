extends Node

# Feature flags
@export var diplomacy_enabled: bool = true

signal action_performed(actor: String, target: String, action: String, delta: int, cost: Dictionary)

# Config
var gift_cost_gold: int = 20
var threat_cost_gold: int = 0
var gift_delta: int = 5
var threat_delta: int = -5
var trade_agreement_delta: int = 3
var passage_rights_delta: int = 2

var trade_agreement_cost_gold: int = 50
var passage_rights_cost_gold: int = 10

var ally_threshold: int = 40
var enemy_threshold: int = -40

func perform_action(actor: String, target: String, action: String) -> bool:
	if not diplomacy_enabled:
		return false
	var wm = get_node_or_null("/root/WorldManager")
	if wm == null:
		return false
	var vm = get_node_or_null("/root/VillageManager")
	var cost: Dictionary = {"gold": 0}
	var delta: int = 0
	match action:
		"gift":
			cost["gold"] = gift_cost_gold
			delta = gift_delta
		"threat":
			cost["gold"] = threat_cost_gold
			delta = threat_delta
		"trade_agreement":
			cost["gold"] = trade_agreement_cost_gold
			delta = trade_agreement_delta
		"passage":
			cost["gold"] = passage_rights_cost_gold
			delta = passage_rights_delta
		_:
			return false
	# pay cost from GlobalPlayerData (central wallet)
	var gold_cost: int = int(cost.get("gold", 0))
	if gold_cost > 0:
		var gpd = get_node_or_null("/root/GlobalPlayerData")
		if gpd == null:
			return false
		if int(gpd.gold) < gold_cost:
			return false
		if gpd.has_method("add_gold"):
			gpd.add_gold(-gold_cost)
	# apply relation (no auto-news from WM since we post our own below)
	var cur: int = wm.get_relation(actor, target)
	wm.set_relation(actor, target, cur + delta, false)

	# optional side effects
	if action == "trade_agreement":
		var mm = get_node_or_null("/root/MissionManager")
		if mm and mm.has_method("add_trade_agreement"):
			# simple default agreement: small daily gold and tiny resource bonus for 5 days
			mm.add_trade_agreement(target, 30, {"food": 1}, 5, false)
	elif action == "passage":
		# could set a flag in WorldManager; placeholder: just news
		pass
	action_performed.emit(actor, target, action, delta, cost)
	_post_news(actor, target, action, delta, cost)
	return true

func get_action_label(action: String) -> String:
	match action:
		"gift":
			return "Hediye +%d (−%d altın)" % [gift_delta, gift_cost_gold]
		"threat":
			return "Tehdit %d" % threat_delta
		"trade_agreement":
			return "Ticaret Anlaşması +%d (−%d altın)" % [trade_agreement_delta, trade_agreement_cost_gold]
		"passage":
			return "Geçiş İzni +%d (−%d altın)" % [passage_rights_delta, passage_rights_cost_gold]
		_:
			return action

func get_stance(value: int) -> String:
	if value >= ally_threshold:
		return "Müttefik"
	if value <= enemy_threshold:
		return "Düşman"
	return "Tarafsız"

func _post_news(actor: String, target: String, action: String, delta: int, cost: Dictionary) -> void:
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		var title = "Diplomasi: %s → %s" % [actor, target]
		var body = "Eylem: %s, Etki: %d, Maliyet: %d altın" % [action, delta, int(cost.get("gold", 0))]
		mm.post_news("diplomacy", title, body, Color.SKY_BLUE)
