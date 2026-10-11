extends RefCounted
## Köy felaketleri için karar seçenekleri (karar kartı verisi + uygulama mantığı).
## Event zaten tam etkisiyle başlar; oyuncu seçim yaparsa etki hafifler/biter, bir bedeli olur.
## Seçenek alanları:
##   cost: {kaynak: miktar} (altın "gold")      need_soldiers: gereken asker sayısı
##   mult: gelecek boş sefer olasılığı çarpanı   morale: moral değişimi
##   shorten: olayı N gün kısalt                 end: olayı hemen bitir
##   chance_end / fail_extend: şansla bitir, olmazsa N gün uzar     loss_chance: 1 asker kaybı olasılığı

const OPTIONS: Dictionary = {
	"famine": [
		{"id": "ration", "cost": {"food": 10}, "mult": 0.5, "morale": 3},
		{"id": "tighten", "cost": {}, "mult": 0.75, "morale": -5},
		{"id": "beg", "cost": {"gold": 8}, "shorten": 2},
	],
	"worker_strike": [
		{"id": "raise", "cost": {"gold": 15}, "end": true, "morale": 3},
		{"id": "suppress", "cost": {}, "need_soldiers": 3, "end": true, "morale": -10},
		{"id": "negotiate", "cost": {}, "chance_end": 0.6, "fail_extend": 2},
	],
	"wolf_attack": [
		{"id": "patrol", "cost": {}, "need_soldiers": 2, "mult": 0.4, "loss_chance": 0.3},
		{"id": "trap", "cost": {"stone": 10}, "mult": 0.5},
	],
	"disease": [
		{"id": "medicine", "cost": {"medicine": 3}, "end": true},
		{"id": "quarantine", "cost": {}, "morale": -5, "shorten": 3},
	],
	"pest": [
		{"id": "smoke", "cost": {"food": 5}, "mult": 0.5},
		{"id": "fell", "cost": {"wood": 8}, "end": true},
	],
}

const EMOJI: Dictionary = {
	"famine": "🌾", "worker_strike": "✊", "wolf_attack": "🐺", "disease": "🤒", "pest": "🐛",
}


static func has_decision(event_type: String) -> bool:
	return OPTIONS.has(event_type)


static func options_for(event_type: String) -> Array:
	return OPTIONS.get(event_type, [])


static func find_option(event_type: String, option_id: String) -> Dictionary:
	for o in options_for(event_type):
		if String(o.get("id", "")) == option_id:
			return o
	return {}


## Boş string = seçilebilir; değilse neden (çeviri anahtarı sonekine yarar: "cost" | "soldiers").
static func unavailable_reason(vm: Node, option: Dictionary) -> String:
	var cost: Dictionary = option.get("cost", {})
	for res in cost.keys():
		if _stock(vm, String(res)) < int(cost[res]):
			return "cost"
	var need: int = int(option.get("need_soldiers", 0))
	if need > 0 and int(vm.call("_count_active_soldiers")) < need:
		return "soldiers"
	return ""


static func _stock(vm: Node, res: String) -> int:
	if res == "gold":
		var gpd: Node = vm.get_node_or_null("/root/GlobalPlayerData")
		return int(gpd.get("gold")) if gpd != null and gpd.get("gold") != null else 0
	return int((vm.get("resource_levels") as Dictionary).get(res, 0))


static func _pay(vm: Node, cost: Dictionary) -> void:
	for res in cost.keys():
		var amount: int = int(cost[res])
		if String(res) == "gold":
			var gpd: Node = vm.get_node_or_null("/root/GlobalPlayerData")
			if gpd != null:
				if gpd.has_method("add_gold"):
					gpd.call("add_gold", -amount)
				else:
					gpd.set("gold", maxi(0, int(gpd.get("gold")) - amount))
		else:
			vm.call("apply_resource_delta", String(res), -amount)


## Seçeneği uygular. Başarılıysa true. `day`: bugünün gün sayısı.
static func apply(vm: Node, event_type: String, option: Dictionary, day: int) -> bool:
	if option.is_empty() or unavailable_reason(vm, option) != "":
		return false
	_pay(vm, option.get("cost", {}))
	var events: Array = vm.get("events_active")
	var morale: int = int(option.get("morale", 0))
	if morale != 0:
		vm.set("village_morale", clampf(float(vm.get("village_morale")) + float(morale), 0.0, 100.0))
	var ended := false
	if bool(option.get("end", false)):
		ended = true
	elif option.has("chance_end"):
		if randf() < float(option["chance_end"]):
			ended = true
		else:
			var extend: int = int(option.get("fail_extend", 0))
			for ev in events:
				if String(ev.get("type", "")) == event_type:
					ev["ends_day"] = int(ev.get("ends_day", day)) + extend
	if ended:
		vm.call("clear_event", event_type)
	else:
		for ev in events:
			if String(ev.get("type", "")) != event_type:
				continue
			if option.has("mult"):
				ev["decision_mult"] = minf(float(ev.get("decision_mult", 1.0)), float(option["mult"]))
			if option.has("shorten"):
				ev["ends_day"] = maxi(day, int(ev.get("ends_day", day)) - int(option["shorten"]))
	if option.has("loss_chance") and randf() < float(option["loss_chance"]):
		var mm: Node = vm.get_node_or_null("/root/MissionManager")
		if mm != null and mm.has_method("_apply_army_losses"):
			mm.call("_apply_army_losses", 1)
	vm.emit_signal("village_data_changed")
	return true
