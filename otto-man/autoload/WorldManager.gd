extends Node

# --- Feature Flags ---
@export var dynamic_world_enabled: bool = true

# --- Signals ---
signal world_event_started(event: Dictionary)
signal relation_changed(faction_a: String, faction_b: String, new_score: int)
signal war_state_changed(faction_a: String, faction_b: String, at_war: bool)
signal defense_deployment_started(attack_day: int)  # Askerlerin savaşa gitmesi için sinyal
signal defense_battle_completed(victor: String, losses: int)  # Savaş bitince askerlerin geri dönmesi için sinyal

# --- World State ---
var factions: Array[String] = ["Köy", "Kuzey", "Güney", "Doğu", "Batı"]
var settlements: Array[Dictionary] = [] # { name:String, faction:String, pop:int }
var relations: Dictionary = {}          # key "A|B" -> int (-100..100)
var active_wars: Array[Dictionary] = [] # { a:String, b:String, since_day:int }
var active_events: Array[Dictionary] = [] # { type:String, faction:String, magnitude:float, duration:int, started_day:int }

# Zamanlanmış saldırılar (köye gelecek saldırılar için uyarı + zamanlama)
var pending_attacks: Array[Dictionary] = [] # { attacker:String, warning_day:int, warning_hour:float, attack_day:int, attack_hour:float, deployed:bool }

# --- Internal ---
var _last_tick_day: int = 0
var _time_advanced_connected: bool = false

func _ready() -> void:
	# Connect to day changes
	var tm = get_node_or_null("/root/TimeManager")
	if tm:
		if tm.has_signal("day_changed"):
			tm.connect("day_changed", Callable(self, "_on_new_day"))
		if tm.has_signal("time_advanced") and not _time_advanced_connected:
			tm.connect("time_advanced", Callable(self, "_on_time_advanced"))
			_time_advanced_connected = true
		_last_tick_day = tm.get_day() if tm.has_method("get_day") else 0
	# Initialize basic relations as neutral
	for i in range(factions.size()):
		for j in range(i + 1, factions.size()):
			var key := _rel_key(factions[i], factions[j])
			relations[key] = 0

func _process(_delta: float) -> void:
	# Saat bazlı saldırı kontrolü için her frame kontrol et
	if dynamic_world_enabled:
		_check_pending_attacks()

func _rel_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func _on_time_advanced(total_minutes: int, start_day: int, start_hour: int, start_minute: int) -> void:
	if not dynamic_world_enabled:
		return
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	var end_day: int = start_day
	var end_hour: int = start_hour
	if tm.has_method("get_day"):
		end_day = tm.get_day()
	if tm.has_method("get_hour"):
		end_hour = tm.get_hour()
	var minutes_per_hour: int = 60
	var hours_per_day: int = 24
	if "MINUTES_PER_HOUR" in tm:
		minutes_per_hour = tm.MINUTES_PER_HOUR
	if "HOURS_PER_DAY" in tm:
		hours_per_day = tm.HOURS_PER_DAY
	var current_day: int = start_day
	var current_hour: int = start_hour
	var current_minute: int = start_minute
	var minutes_processed: int = 0
	while minutes_processed < total_minutes:
		current_minute += 1
		minutes_processed += 1
		if current_minute >= minutes_per_hour:
			current_minute = 0
			current_hour += 1
			if current_hour >= hours_per_day:
				current_hour = 0
				current_day += 1
				if current_day <= end_day:
					_simulate_day(current_day)
					_apply_world_events_to_village(current_day)
		if current_day < end_day or (current_day == end_day and current_hour < end_hour):
			_check_pending_attacks_during_skip(current_day, current_hour)

func _check_pending_attacks_during_skip(day: int, hour: int) -> void:
	var remaining_attacks: Array[Dictionary] = []
	for attack in pending_attacks:
		var attack_day = attack.get("attack_day", day)
		var attack_hour: float = float(attack.get("attack_hour", 0.0))
		var deploy_time = attack_hour - 3.0
		var deploy_day = attack_day
		if deploy_time < 0.0:
			deploy_time += 24.0
			deploy_day -= 1
		var deployed: bool = bool(attack.get("deployed", false))
		if not deployed:
			if day > deploy_day or (day == deploy_day and float(hour) >= deploy_time):
				defense_deployment_started.emit(attack_day)
				attack["deployed"] = true
		var attack_time_reached = false
		if day > attack_day or (day == attack_day and float(hour) >= attack_hour):
			attack_time_reached = true
		if attack_time_reached:
			var attacker = attack.get("attacker", "Bilinmeyen")
			_execute_village_defense(attacker, day)
		else:
			remaining_attacks.append(attack)
	pending_attacks = remaining_attacks

func _on_new_day(day: int) -> void:
	if not dynamic_world_enabled:
		return
	if day <= _last_tick_day:
		return
	_last_tick_day = day
	_simulate_day(day)
	
	# Apply world event effects to village economy
	_apply_world_events_to_village(day)

func _simulate_day(day: int) -> void:
	# Rastgele olay başlatma şansı
	if randf() < 0.1:  # %10 şans
		var event_type = _get_random_event_type()
		var faction = factions[randi() % factions.size()]
		if faction != "Köy":  # Köy kendine olay başlatmasın
			var event = _create_event(event_type, faction, day)
			active_events.append(event)
			_post_event_news(event, day)
	
	# Köy saldırıları kontrolü (yeni saldırı tetikleme)
	_check_village_attacks(day)
	
	# Aktif olayları güncelle
	_update_active_events(day)
	# Not: Zamanlanmış saldırılar _process() içinde saat bazlı kontrol ediliyor

func _check_village_attacks(day: int) -> void:
	"""Köy saldırılarını kontrol et"""
	# Düşman fraksiyonları kontrol et
	for faction in factions:
		if faction == "Köy":
			continue
		
		var relation = get_relation("Köy", faction)
		
		# Düşman fraksiyonlar saldırı yapabilir
		if relation < -30 and randf() < 0.05:  # %5 şans
			_trigger_village_attack(faction, day)
		
		# Köy de saldırı yapabilir (oyuncu kontrolünde)
		if relation < -50 and randf() < 0.02:  # %2 şans
			_trigger_village_raid(faction, day)

func _trigger_village_attack(attacker_faction: String, day: int) -> void:
	"""Köye saldırı uyarısı ve zamanlaması - 6 saat sonra saldırı"""
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	
	# Mevcut saat bilgisini al
	var current_hour: float = 0.0
	if tm.has_method("get_hour"):
		current_hour = tm.get_hour()
	
	# Saldırı 6 saat sonra olacak
	var attack_hour = current_hour + 6.0
	var attack_day = day
	var warning_day = day
	var warning_hour = current_hour
	
	# Eğer 6 saat sonra gece yarısını geçiyorsa bir sonraki güne geç
	if attack_hour >= 24.0:
		attack_day += 1
		attack_hour = attack_hour - 24.0
	
	# Uyarı haberini şimdi gönder
	_post_world_news({
		"category": "world",
		"subcategory": "critical",
		"title": "🚨 Saldırı Uyarısı!",
		"content": "%s fraksiyonu köyümüze saldırı hazırlığı yapıyor! Saldırı 6 saat sonra bekleniyor. Askerlerinizi hazırlayın!" % attacker_faction,
		"day": day
	})
	
	# Zamanlanmış saldırıyı kaydet
	pending_attacks.append({
		"attacker": attacker_faction,
		"warning_day": warning_day,
		"warning_hour": warning_hour,
		"attack_day": attack_day,
		"attack_hour": attack_hour,
		"deployed": false
	})
	
	print("🛡️ Köye saldırı zamanlandı: %s -> 6 saat sonra (Gün %d, Saat %.1f)" % [attacker_faction, attack_day, attack_hour])

func _check_pending_attacks() -> void:
	"""Zamanlanmış saldırıları kontrol et ve gerçekleştir (saat bazlı)"""
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	
	var current_day: int = 0
	var current_hour: float = 0.0
	
	if tm.has_method("get_day"):
		current_day = tm.get_day()
	if tm.has_method("get_hour"):
		current_hour = tm.get_hour()
	
	var remaining_attacks: Array[Dictionary] = []
	
	for attack in pending_attacks:
		var attack_day = attack.get("attack_day", current_day)
		var attack_hour: float = float(attack.get("attack_hour", 0.0))
		var warning_day = attack.get("warning_day", current_day)
		var warning_hour: float = float(attack.get("warning_hour", 0.0))
		var deployed: bool = bool(attack.get("deployed", false))
		
		# Saldırıdan 3 saat önce askerleri deploy et (saldırıdan 6 saat sonra, deploy 3 saat önce = 3 saat sonra)
		var deploy_time = attack_hour - 3.0
		var deploy_day = attack_day
		if deploy_time < 0.0:
			deploy_time += 24.0
			deploy_day -= 1
		
		var should_deploy = false
		if current_day > deploy_day:
			should_deploy = true
		elif current_day == deploy_day and current_hour >= deploy_time:
			should_deploy = true
		
		if not deployed and should_deploy:
			defense_deployment_started.emit(attack_day)
			attack["deployed"] = true
			print("⚔️ Askerler savaşa hazırlanıyor, ekran dışına yürüyorlar (Saldırı: Gün %d, Saat %.1f)" % [attack_day, attack_hour])
		
		# Saldırı zamanı kontrolü
		var attack_time_reached = false
		if current_day > attack_day:
			attack_time_reached = true
		elif current_day == attack_day and current_hour >= attack_hour:
			attack_time_reached = true
		
		if attack_time_reached:
			# Saldırı zamanı geldi - otomatik savunma yap
			var attacker = attack.get("attacker", "Bilinmeyen")
			_execute_village_defense(attacker, current_day)
		else:
			# Henüz zamanı gelmedi
			remaining_attacks.append(attack)
	
	pending_attacks = remaining_attacks

func _execute_village_defense(attacker_faction: String, day: int) -> void:
	"""Köyün otomatik savunmasını gerçekleştir"""
	print("⚔️ Otomatik savunma başlıyor: %s saldırısı" % attacker_faction)
	
	# CombatResolver'ı bul
	var cr = get_node_or_null("/root/CombatResolver")
	if not cr:
		print("❌ CombatResolver bulunamadı! Basit bir hesapla savaş çözümlenecek.")
	
	# Köyün askeri gücünü al
	var mm = get_node_or_null("/root/MissionManager")
	if not mm:
		print("❌ MissionManager bulunamadı!")
		return
	
	var defender_force = mm._get_player_military_force()
	
	# Saldırgan gücünü hesapla
	var attacker_force = _get_attacker_force_for_defense(attacker_faction)
	
	# Savaşı çözümle
	var battle_result: Dictionary = {}
	if cr and cr.has_method("simulate_skirmish"):
		battle_result = cr.simulate_skirmish(attacker_force, defender_force)
	else:
		# Fallback: basit oranla sonuçlandır
		var atk_units: int = int(attacker_force.get("units", {}).get("infantry", 0)) + int(attacker_force.get("units", {}).get("archers", 0))
		var def_units: int = int(defender_force.get("units", {}).get("soldiers", 0))
		var atk_power: float = float(atk_units) * 1.0
		var def_power: float = float(def_units) * 1.2  # Savunma bonusu
		var defender_wins: bool = def_power >= atk_power * randf_range(0.8, 1.2)
		battle_result = {
			"victor": "defender" if defender_wins else "attacker",
			"defender_losses": int(max(0, round(def_units * randf_range(0.1, 0.5)))) if def_units > 0 else 0,
			"attacker_losses": int(max(0, round(atk_units * randf_range(0.2, 0.6))))
		}
	
	# Sonuçları işle
	_process_defense_result(attacker_faction, battle_result, day)

func _get_attacker_force_for_defense(attacker_faction: String) -> Dictionary:
	"""Savunma için saldırgan gücünü hesapla"""
	# İlişkiye göre saldırgan gücü belirle
	var relation = get_relation("Köy", attacker_faction)
	var base_strength = 5 + abs(relation) / 10  # Daha düşman = daha güçlü saldırı
	
	return {
		"units": {"infantry": int(base_strength), "archers": int(base_strength * 0.6)},
		"equipment": {"weapon": int(base_strength * 1.5), "armor": int(base_strength)},
		"supplies": {"bread": int(base_strength * 2), "water": int(base_strength * 1.5)},
		"gold": int(base_strength * 20)
	}

func _process_defense_result(attacker_faction: String, battle_result: Dictionary, day: int) -> void:
	"""Savunma sonuçlarını işle ve haber olarak bildir"""
	var victor = battle_result.get("victor", "defender")
	var defender_losses = battle_result.get("defender_losses", 0)
	var attacker_losses = battle_result.get("attacker_losses", 0)
	
	var vm = get_node_or_null("/root/VillageManager")
	var mm = get_node_or_null("/root/MissionManager")
	var barracks = mm._find_barracks() if mm else null
	
	if victor == "defender":
		# Köy savunmayı başardı
		_post_world_news({
			"category": "world",
			"subcategory": "success",
			"title": "✅ Savunma Başarılı",
			"content": "%s saldırısı püskürtüldü! Kayıplar: %d asker. Köy zarar görmedi." % [attacker_faction, defender_losses],
			"day": day
		})
		
		# Ölü askerleri kaldır
		if barracks and barracks.has_method("remove_soldiers"):
			barracks.remove_soldiers(defender_losses)
		
		# Küçük moral bonusu
		if vm:
			vm.village_morale = min(100.0, vm.village_morale + 2.0)
		
		# Askerlerin geri dönmesi için sinyal gönder
		defense_battle_completed.emit("defender", defender_losses)
		
	else:
		# Köy yenildi - zarar gör
		var gold_loss = randi_range(100, 300)
		var morale_loss = randi_range(5, 15)
		
		# Kaynak kaybı
		var gpd = get_node_or_null("/root/GlobalPlayerData")
		if gpd:
			gpd.gold = max(0, gpd.gold - gold_loss)
		
		# Moral kaybı
		if vm:
			vm.village_morale = max(0.0, vm.village_morale - morale_loss)
		
		# Ölü askerleri kaldır
		if barracks and barracks.has_method("remove_soldiers"):
			barracks.remove_soldiers(defender_losses)
		
		_post_world_news({
			"category": "world",
			"subcategory": "critical",
			"title": "❌ Savunma Başarısız",
			"content": "%s saldırısı köye zarar verdi! Kayıplar: %d asker, %d altın, %d moral." % [attacker_faction, defender_losses, gold_loss, morale_loss],
			"day": day
		})
		
		# Askerlerin geri dönmesi için sinyal gönder
		defense_battle_completed.emit("attacker", defender_losses)

func _trigger_village_raid(target_faction: String, day: int) -> void:
	"""Köyden saldırı başlat"""
	var raid_event = {
		"type": "village_raid",
		"attacker": "Köy",
		"target": target_faction,
		"day": day,
		"severity": "moderate"
	}
	
	# Saldırı haberini yayınla
	_post_world_news({
		"category": "world",
		"subcategory": "warning",
		"title": "Saldırı Fırsatı",
		"content": "%s fraksiyonuna saldırı fırsatı doğdu!" % target_faction,
		"day": day
	})
	
	# Saldırıyı MissionManager'a bildir
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("create_raid_mission"):
		mm.create_raid_mission(target_faction, day)

func _update_active_events(day: int) -> void:
	"""Aktif olayları güncelle"""
	var remaining_events: Array[Dictionary] = []
	
	for event in active_events:
		var started_day = event.get("started_day", day)
		var duration = event.get("duration", 0)
		
		if day - started_day < duration:
			remaining_events.append(event)
		else:
			# Olay süresi doldu
			_post_event_end_news(event, day)
	
	active_events = remaining_events

func _post_event_end_news(event: Dictionary, day: int) -> void:
	"""Olay sona erdiğinde haber yayınla"""
	var event_type = event.get("type", "")
	var faction = event.get("faction", "")
	
	var title = ""
	var content = ""
	
	match event_type:
		"trade_boom":
			title = "Ticaret Patlaması Sona Erdi"
			content = "%s bölgesindeki ticaret patlaması sona erdi." % faction
		"famine":
			title = "Kıtlık Sona Erdi"
			content = "%s bölgesindeki kıtlık sona erdi." % faction
		"plague":
			title = "Salgın Sona Erdi"
			content = "%s bölgesindeki salgın sona erdi." % faction
		"war_declaration":
			title = "Savaş Sona Erdi"
			content = "%s bölgesindeki savaş sona erdi." % faction
		"rebellion":
			title = "İsyan Bastırıldı"
			content = "%s bölgesindeki isyan bastırıldı." % faction
	
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": title,
		"content": content,
		"day": day
	})
	# Dynamic world events simulation
	# 15% chance of any event on a random non-player faction
	if randi() % 100 < 15 and factions.size() > 1:
		var idx := 1 + int(randi() % (factions.size() - 1))
		var selected_faction := factions[idx]
		var random_event_type := _get_random_event_type()
		var ev := _create_event(random_event_type, selected_faction, day)
		active_events.append(ev)
		world_event_started.emit(ev)
		_post_event_news(ev, day)

	# Decay expired events
	var remaining: Array[Dictionary] = []
	for e in active_events:
		var started: int = int(e.get("started_day", day))
		var duration: int = int(e.get("duration", 0))
		if day - started < duration:
			remaining.append(e)
	active_events = remaining

func set_relation(a: String, b: String, value: int, post_news: bool = false) -> void:
	var key := _rel_key(a, b)
	var old_val: int = int(relations.get(key, 0))
	var new_val: int = clamp(value, -100, 100)
	relations[key] = new_val
	relation_changed.emit(a, b, new_val)
	
	# Optionally post news if the relation significantly changed
	if post_news and abs(new_val - old_val) >= 5:
		var change: int = new_val - old_val
		var subcategory: String = "info"
		if change > 0:
			subcategory = "success"
		elif change < 0:
			subcategory = "warning"
		_post_world_news({
			"category": "world",
			"subcategory": subcategory,
			"title": "İlişki Değişti",
			"content": "%s ile %s arasındaki ilişki %s%d oldu." % [a, b, "+" if change > 0 else "", change],
			"day": 0  # Will be filled by news system if needed
		})

func get_relation(a: String, b: String) -> int:
	var key := _rel_key(a, b)
	return int(relations.get(key, 0))

func start_war(a: String, b: String, day: int) -> bool:
	for w in active_wars:
		if (w.get("a", "") == a and w.get("b", "") == b) or (w.get("a", "") == b and w.get("b", "") == a):
			return false
	active_wars.append({ "a": a, "b": b, "since_day": day })
	war_state_changed.emit(a, b, true)
	_post_world_news({
		"category": "world",
		"subcategory": "critical",
		"title": "Savaş İlanı",
		"content": "%s ile %s arasında savaş patlak verdi!" % [a, b],
		"day": day
	})
	return true

func end_war(a: String, b: String, day: int) -> void:
	var next: Array[Dictionary] = []
	for w in active_wars:
		var wa := String(w.get("a", ""))
		var wb := String(w.get("b", ""))
		if (wa == a and wb == b) or (wa == b and wb == a):
			continue
		next.append(w)
	active_wars = next
	war_state_changed.emit(a, b, false)
	_post_world_news({
		"category": "world",
		"subcategory": "success",
		"title": "Barış",
		"content": "%s ile %s barış yaptı." % [a, b],
		"day": day
	})

func get_state() -> Dictionary:
	return {
		"relations": relations.duplicate(true),
		"active_wars": active_wars.duplicate(true),
		"active_events": active_events.duplicate(true)
	}

func set_state(state: Dictionary) -> void:
	if state.has("relations"):
		relations = state["relations"].duplicate(true)
	if state.has("active_wars"):
		active_wars = state["active_wars"].duplicate(true)
	if state.has("active_events"):
		active_events = state["active_events"].duplicate(true)

func _get_random_event_type() -> String:
	var event_types := ["trade_boom", "famine", "plague", "war_declaration", "rebellion"]
	return event_types[randi() % event_types.size()]

func _create_event(type: String, faction: String, day: int) -> Dictionary:
	match type:
		"trade_boom":
			return {
				"type": "trade_boom",
				"faction": faction,
				"magnitude": 1.2,
				"duration": 5,
				"started_day": day,
				"effects": {"gold_multiplier": 1.2, "trade_bonus": 10}
			}
		"famine":
			return {
				"type": "famine",
				"faction": faction,
				"magnitude": 0.8,
				"duration": 7,
				"started_day": day,
				"effects": {"food_production": 0.5, "morale_penalty": -15}
			}
		"plague":
			return {
				"type": "plague",
				"faction": faction,
				"magnitude": 0.7,
				"duration": 10,
				"started_day": day,
				"effects": {"population_health": 0.6, "production_penalty": 0.3}
			}
		"war_declaration":
			return {
				"type": "war_declaration",
				"faction": faction,
				"magnitude": 1.0,
				"duration": 30,
				"started_day": day,
				"effects": {"military_focus": 1.5, "trade_disruption": 0.8}
			}
		"rebellion":
			return {
				"type": "rebellion",
				"faction": faction,
				"magnitude": 0.6,
				"duration": 14,
				"started_day": day,
				"effects": {"stability_penalty": -20, "production_chaos": 0.4}
			}
		_:
			return {"type": "unknown", "faction": faction, "magnitude": 1.0, "duration": 1, "started_day": day}

func _post_event_news(event: Dictionary, day: int) -> void:
	var type := String(event.get("type", "unknown"))
	var faction := String(event.get("faction", "Bilinmeyen"))
	var duration := int(event.get("duration", 0))
	var subcategory := "info"
	
	match type:
		"trade_boom":
			subcategory = "success"
		"famine", "plague", "rebellion":
			subcategory = "critical"
		"war_declaration":
			subcategory = "warning"
	
	var title := ""
	var content := ""
	
	match type:
		"trade_boom":
			title = "Ticaret Patlaması"
			content = "%s bölgesinde ticaret canlandı! (%d gün)" % [faction, duration]
		"famine":
			title = "Kıtlık"
			content = "%s bölgesinde kıtlık başladı! Gıda üretimi düştü. (%d gün)" % [faction, duration]
		"plague":
			title = "Salgın"
			content = "%s bölgesinde salgın hastalık yayıldı! Nüfus sağlığı tehlikede. (%d gün)" % [faction, duration]
		"war_declaration":
			title = "Savaş İlanı"
			content = "%s bölgesinde savaş patlak verdi! Ticaret kesintiye uğradı. (%d gün)" % [faction, duration]
		"rebellion":
			title = "İsyan"
			content = "%s bölgesinde isyan çıktı! İstikrar sarsıldı. (%d gün)" % [faction, duration]
	
	# Post news with proper subcategory for visual emphasis
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		mm.post_news("Dünya", title, content, Color.WHITE, subcategory)
	else:
		# Fallback to old system
		_post_world_news({
			"category": "world",
			"subcategory": subcategory,
			"title": title,
			"content": content,
			"day": day
		})

func _apply_world_events_to_village(day: int) -> void:
	"""Apply active world events to village economy"""
	var vm = get_node_or_null("/root/VillageManager")
	if not vm or not vm.has_method("apply_world_event_effects"):
		return
	
	# Apply effects of all active events
	for event in active_events:
		vm.apply_world_event_effects(event)
	
	# Remove effects of expired events
	var remaining: Array[Dictionary] = []
	for event in active_events:
		var started_day := int(event.get("started_day", day))
		var duration := int(event.get("duration", 0))
		if day - started_day < duration:
			remaining.append(event)
		else:
			# Event expired, remove its effects
			vm.remove_world_event_effects(event)
	active_events = remaining

func _post_world_news(news: Dictionary) -> void:
	# MissionManager'ın post_news metodunu kullan
	var mm = get_node_or_null("/root/MissionManager")
	if mm and mm.has_method("post_news"):
		var category = news.get("category", "world")
		var title = news.get("title", "Bilinmeyen")
		var content = news.get("content", "")
		var subcategory = news.get("subcategory", "info")
		
		# Category'yi MissionManager formatına çevir
		if category == "world":
			category = "Dünya"
		
		mm.post_news(category, title, content, Color.WHITE, subcategory)
	else:
		# Fallback: sinyal emit et
		if mm and mm.has_signal("news_posted"):
			mm.news_posted.emit(news)
		else:
			print("[WORLD NEWS] ", news)
