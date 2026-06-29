extends RefCounted
## El yapımı köylü–köylü sohbet katalogu (LLM kapalıyken).

const CONVERSATIONS: Array[Dictionary] = [
	{
		"id": "morning_work",
		"tags": [],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.morning.a1", "duration": 3.2, "pause_after": 2.4},
			{"speaker": 1, "key": "ambient.conv.morning.b1", "duration": 3.2, "pause_after": 2.4},
			{"speaker": 0, "key": "ambient.conv.morning.a2", "duration": 3.0, "pause_after": 0.0},
		],
	},
	{
		"id": "well_queue",
		"tags": [],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.well.a1", "duration": 3.0, "pause_after": 2.2},
			{"speaker": 1, "key": "ambient.conv.well.b1", "duration": 3.0, "pause_after": 0.0},
		],
	},
	{
		"id": "morale_low",
		"tags": ["morale_low"],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.morale_low.a1", "duration": 3.5, "pause_after": 2.6},
			{"speaker": 1, "key": "ambient.conv.morale_low.b1", "duration": 3.5, "pause_after": 2.6},
			{"speaker": 0, "key": "ambient.conv.morale_low.a2", "duration": 3.2, "pause_after": 0.0},
		],
	},
	{
		"id": "morale_high",
		"tags": ["morale_high"],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.morale_high.a1", "duration": 3.0, "pause_after": 2.4},
			{"speaker": 1, "key": "ambient.conv.morale_high.b1", "duration": 3.0, "pause_after": 0.0},
		],
	},
	{
		"id": "trader_gossip",
		"tags": ["trader"],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.trader.a1", "duration": 3.2, "pause_after": 2.5},
			{"speaker": 1, "key": "ambient.conv.trader.b1", "duration": 3.2, "pause_after": 2.5},
			{"speaker": 0, "key": "ambient.conv.trader.a2", "duration": 3.0, "pause_after": 0.0},
		],
	},
	{
		"id": "night_rest",
		"tags": [],
		"lines": [
			{"speaker": 1, "key": "ambient.conv.night.b1", "duration": 3.0, "pause_after": 2.3},
			{"speaker": 0, "key": "ambient.conv.night.a1", "duration": 3.0, "pause_after": 0.0},
		],
	},
	{
		"id": "bakery",
		"tags": [],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.bakery.a1", "duration": 3.0, "pause_after": 2.2},
			{"speaker": 1, "key": "ambient.conv.bakery.b1", "duration": 3.0, "pause_after": 0.0},
		],
	},
	{
		"id": "defense_worry",
		"tags": ["defense_pending"],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.defense.a1", "duration": 3.5, "pause_after": 2.6},
			{"speaker": 1, "key": "ambient.conv.defense.b1", "duration": 3.5, "pause_after": 0.0},
		],
	},
	{
		"id": "festival_recall",
		"tags": ["festival_recent"],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.festival.a1", "duration": 3.2, "pause_after": 2.4},
			{"speaker": 1, "key": "ambient.conv.festival.b1", "duration": 3.2, "pause_after": 0.0},
		],
	},
	{
		"id": "guest_shelter",
		"tags": ["guests"],
		"lines": [
			{"speaker": 0, "key": "ambient.conv.guests.a1", "duration": 3.4, "pause_after": 2.5},
			{"speaker": 1, "key": "ambient.conv.guests.b1", "duration": 3.4, "pause_after": 0.0},
		],
	},
]


static func gather_context_tags(village_manager: Node) -> Array[String]:
	var tags: Array[String] = []
	if not is_instance_valid(village_manager):
		return tags
	if "village_morale" in village_manager:
		var morale: float = float(village_manager.get("village_morale"))
		if morale < 40.0:
			tags.append("morale_low")
		elif morale > 70.0:
			tags.append("morale_high")
	if village_manager.has_method("get_guest_villager_count"):
		if int(village_manager.call("get_guest_villager_count")) > 0:
			tags.append("guests")
	if village_manager.has_method("get_pending_attack_count"):
		if int(village_manager.call("get_pending_attack_count")) > 0:
			tags.append("defense_pending")
	var mm := village_manager.get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("get_active_traders"):
		var traders: Array = mm.call("get_active_traders")
		if not traders.is_empty():
			tags.append("trader")
	if village_manager.has_method("was_village_festival_recent"):
		if village_manager.call("was_village_festival_recent") == true:
			tags.append("festival_recent")
	return tags


static func pick_conversation(context_tags: Array[String]) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for conv in CONVERSATIONS:
		var required: Array = conv.get("tags", [])
		var ok := true
		for tag in required:
			if not context_tags.has(String(tag)):
				ok = false
				break
		if ok:
			eligible.append(conv)
	if eligible.is_empty():
		for conv in CONVERSATIONS:
			if (conv.get("tags", []) as Array).is_empty():
				eligible.append(conv)
	if eligible.is_empty():
		return {}
	eligible.shuffle()
	return eligible[0]
