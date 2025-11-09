extends CanvasLayer

@onready var console = $Console
@onready var line_edit = $Console/VBoxContainer/LineEdit
@onready var output = $Console/VBoxContainer/RichTextLabel

var command_history: Array[String] = []
var history_index: int = -1
var is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Make sure we have all required nodes
	if !console or !line_edit or !output:
		push_error("Dev console is missing required nodes!")
		return
		
	console.hide()
	line_edit.text_submitted.connect(_on_command_submitted)
	
	# Initial output
	print_output("Developer Console")
	print_output("Type 'help' for available commands")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		toggle_console()
	elif is_open:
		if event.is_action_pressed("ui_up"):
			navigate_history(-1)
		elif event.is_action_pressed("ui_down"):
			navigate_history(1)

func toggle_console() -> void:
	is_open = !is_open
	if !console:
		return
		
	console.visible = is_open
	if is_open:
		line_edit.clear()
		line_edit.grab_focus()
		get_tree().paused = true
	else:
		get_tree().paused = false

func _on_command_submitted(command: String) -> void:
	if command.is_empty():
		return
		
	print_output("> " + command)
	command_history.append(command)
	history_index = command_history.size()
	line_edit.clear()
	
	var args = command.split(" ")
	var cmd = args[0].to_lower()
	args = args.slice(1)
	
	match cmd:
		"help":
			show_help()
		"clear":
			output.clear()
			print_output("Developer Console")
			print_output("Type 'help' for available commands")
		"powerup":
			handle_powerup_command(args)
		"heal":
			handle_heal_command(args)
		"damage":
			handle_damage_command(args)
		"kill":
			handle_kill_command()
		"god":
			handle_god_command()
		"reset":
			handle_reset_command()
		# === DÜNYA SİSTEMİ KOMUTLARI ===
		"force_event":
			handle_force_event_command(args)
		"set_relation":
			handle_set_relation_command(args)
		"spawn_war":
			handle_spawn_war_command(args)
		"world_stats":
			handle_world_stats_command()
		"village_stats":
			handle_village_stats_command()
		"add_resources":
			handle_add_resources_command(args)
		"set_morale":
			handle_set_morale_command(args)
		"recruit_soldier":
			handle_recruit_soldier_command(args)
		"barracks_info":
			handle_barracks_info_command()
		"force_attack":
			handle_force_attack_command(args)
		"test_battle":
			handle_test_battle_command(args)
		_:
			print_output("Unknown command: " + cmd)

func handle_powerup_command(args: Array) -> void:
	if args.is_empty():
		print_output("Usage: powerup <name>")
		return
		
	var file_name = args[0].to_snake_case() + ".tscn"
	var scene_path = "res://resources/powerups/scenes/" + file_name
	
	var powerup_scene = load(scene_path) as PackedScene
	if powerup_scene:
		PowerupManager.activate_powerup(powerup_scene)
		print_output("Activated powerup: " + args[0])
	else:
		print_output("Failed to load powerup: " + args[0])

func handle_heal_command(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if !player or !player.has_method("heal"):
		print_output("No player found or player cannot heal")
		return
		
	var amount = 50.0  # Default heal amount
	if !args.is_empty():
		amount = float(args[0])
	
	player.heal(amount)
	print_output("Healed player for " + str(amount) + " health")

func handle_damage_command(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if !player or !player.has_method("take_damage"):
		print_output("No player found or player cannot take damage")
		return
		
	var amount = 10.0  # Default damage amount
	if !args.is_empty():
		amount = float(args[0])
	
	player.take_damage(amount)
	print_output("Dealt " + str(amount) + " damage to player")

func handle_kill_command() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if !player or !player.has_method("take_damage"):
		print_output("No player found or player cannot take damage")
		return
		
	player.take_damage(99999)
	print_output("Killed player")

func handle_god_command() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if !player:
		print_output("No player found")
		return
		
	if player.has_method("toggle_god_mode"):
		player.toggle_god_mode()
		print_output("Toggled god mode")
	else:
		print_output("Player does not have god mode functionality")

func handle_reset_command() -> void:
	get_tree().reload_current_scene()
	print_output("Reset scene")

# === DÜNYA SİSTEMİ KOMUT HANDLER'LARI ===
func handle_force_event_command(args: Array) -> void:
	if args.size() < 2:
		print_output("Usage: force_event <type> <faction>")
		print_output("Types: trade_boom, famine, plague, war_declaration, rebellion")
		return
	
	var event_type: String = args[0]
	var faction: String = args[1]
	
	var tm = TimeManager
	var current_day: int = tm.get_day() if tm.has_method("get_day") else 1
	
	var event: Dictionary = WorldManager._create_event(event_type, faction, current_day)
	WorldManager.active_events.append(event)
	WorldManager._post_event_news(event, current_day)
	
	print_output("Forced event: %s in %s" % [event_type, faction])

func handle_set_relation_command(args: Array) -> void:
	if args.size() < 3:
		print_output("Usage: set_relation <faction1> <faction2> <value>")
		return
	
	var faction1: String = args[0]
	var faction2: String = args[1]
	var value: int = int(args[2])
	
	WorldManager.set_relation(faction1, faction2, value, true)
	print_output("Set relation %s-%s to %d" % [faction1, faction2, value])

func handle_spawn_war_command(args: Array) -> void:
	if args.size() < 2:
		print_output("Usage: spawn_war <faction1> <faction2>")
		return
	
	var faction1: String = args[0]
	var faction2: String = args[1]
	
	var tm = TimeManager
	var current_day: int = tm.get_day() if tm.has_method("get_day") else 1
	
	var success: bool = WorldManager.start_war(faction1, faction2, current_day)
	if success:
		print_output("Started war between %s and %s" % [faction1, faction2])
	else:
		print_output("War already exists between %s and %s" % [faction1, faction2])

func handle_world_stats_command() -> void:
	print_output("=== DÜNYA İSTATİSTİKLERİ ===")
	print_output("Fraksiyonlar: %s" % str(WorldManager.factions))
	print_output("Aktif Savaşlar: %d" % WorldManager.active_wars.size())
	print_output("Aktif Olaylar: %d" % WorldManager.active_events.size())
	
	# Ortalama ilişki skoru
	var total_relations := 0
	var relation_count := 0
	for key in WorldManager.relations.keys():
		total_relations += WorldManager.relations[key]
		relation_count += 1
	
	if relation_count > 0:
		var avg_relation := float(total_relations) / float(relation_count)
		print_output("Ortalama İlişki: %.1f" % avg_relation)
	
	# Aktif olaylar detayı
	if not WorldManager.active_events.is_empty():
		print_output("Aktif Olaylar:")
		for event in WorldManager.active_events:
			var days_left: int = event.get("duration", 0) - (WorldManager._last_tick_day - event.get("started_day", 0))
			print_output("  - %s (%s): %d gün kaldı" % [event.get("type", ""), event.get("faction", ""), days_left])

func handle_village_stats_command() -> void:
	print_output("=== KÖY İSTATİSTİKLERİ ===")
	print_output("Moral: %.1f" % VillageManager.village_morale)
	print_output("Küresel Çarpan: %.2f" % VillageManager.global_multiplier)
	print_output("Kaynak Çarpanları: %s" % str(VillageManager.resource_prod_multiplier))
	
	# Kaynak seviyeleri
	print_output("Kaynak Seviyeleri:")
	for resource in VillageManager.resource_levels.keys():
		var level: int = VillageManager.resource_levels[resource]
		var cap: int = VillageManager._get_storage_capacity_for(resource)
		if cap > 0:
			print_output("  %s: %d/%d" % [resource, level, cap])
		else:
			print_output("  %s: %d" % [resource, level])
	
	# Ekonomi istatistikleri
	if VillageManager.economy_stats_last_day.has("day"):
		var stats: Dictionary = VillageManager.economy_stats_last_day
		print_output("Son Gün Ekonomi:")
		print_output("  Üretim: %.1f" % stats.get("total_production", 0))
		print_output("  Tüketim: %.1f" % stats.get("total_consumption", 0))
		print_output("  Net: %.1f" % stats.get("net", 0))

func handle_add_resources_command(args: Array) -> void:
	if args.size() < 2:
		print_output("Usage: add_resources <type> <amount>")
		print_output("Types: gold, wood, stone, food, water, metal, bread")
		return
	
	var resource_type: String = args[0]
	var amount: int = int(args[1])
	
	match resource_type:
		"gold":
			GlobalPlayerData.add_gold(amount)
			print_output("Added %d gold. Total: %d" % [amount, GlobalPlayerData.gold])
		"wood", "stone", "food", "water", "metal", "bread":
			# Kaynak seviyesini artır
			var current_level = VillageManager.resource_levels.get(resource_type, 0)
			VillageManager.resource_levels[resource_type] = current_level + amount
			print_output("Added %d %s. Total: %d" % [amount, resource_type, VillageManager.resource_levels[resource_type]])
			VillageManager.emit_signal("village_data_changed")
		_:
			print_output("Unknown resource type: " + resource_type)

func handle_set_morale_command(args: Array) -> void:
	if args.is_empty():
		print_output("Usage: set_morale <value>")
		return
	
	var morale := float(args[0])
	
	VillageManager.village_morale = clamp(morale, 0.0, 100.0)
	print_output("Set village morale to %.1f" % VillageManager.village_morale)
	VillageManager.emit_signal("village_data_changed")

func handle_recruit_soldier_command(args: Array) -> void:
	# Kışla binasını bul
	var barracks = _find_barracks()
	if not barracks:
		print_output("Kışla binası bulunamadı!")
		return
	
	if barracks.has_method("add_worker"):
		var success = barracks.add_worker()
		if success:
			print_output("Köylü asker yapıldı!")
		else:
			print_output("Köylü asker yapılamadı!")
	else:
		print_output("Kışla binası köylü atama metoduna sahip değil!")

func handle_barracks_info_command() -> void:
	# Kışla binasını bul
	var barracks = _find_barracks()
	if not barracks:
		print_output("Kışla binası bulunamadı!")
		return
	
	print_output("=== KIŞLA BİLGİLERİ ===")
	
	if barracks.has_method("get_military_force"):
		var force = barracks.get_military_force()
		print_output("Asker Gücü:")
		for unit_type in force.get("units", {}):
			var count = force["units"][unit_type]
			print_output("  %s: %d" % [unit_type, count])
		
		print_output("Ekipman:")
		for equip_type in force.get("equipment", {}):
			var count = force["equipment"][equip_type]
			print_output("  %s: %d" % [equip_type, count])
	
	if barracks.has_method("current_soldiers") and barracks.has_method("max_soldiers"):
		print_output("Kapasite: %d/%d" % [barracks.current_soldiers, barracks.max_soldiers])

func handle_force_attack_command(args: Array) -> void:
	if args.size() < 2:
		print_output("Usage: force_attack <attacker> <target>")
		return
	
	var attacker: String = args[0]
	var target: String = args[1]
	
	var tm = TimeManager
	var current_day: int = tm.get_day() if tm.has_method("get_day") else 1
	
	if attacker == "Köy":
		WorldManager._trigger_village_raid(target, current_day)
		print_output("Köyden %s'ye saldırı başlatıldı!" % target)
	elif target == "Köy":
		WorldManager._trigger_village_attack(attacker, current_day)
		print_output("%s'den köye saldırı başlatıldı!" % attacker)
	else:
		print_output("Sadece köy saldırıları destekleniyor!")

func handle_test_battle_command(args: Array) -> void:
	"""Immediately trigger a battle for testing (no 6-hour wait)"""
	var attacker = "Kuzey"
	if args.size() > 0:
		attacker = args[0]
	
	# Access WorldManager directly as autoload singleton
	if WorldManager.has_method("test_battle"):
		WorldManager.test_battle(attacker)
		print_output("⚔️ Test savaşı başlatıldı: %s -> Köy" % attacker)
		print_output("   (Battle story will be generated and posted to news)")
	else:
		print_output("❌ test_battle metodu bulunamadı!")


func _find_barracks() -> Node:
	"""Kışla binasını bul"""
	if not VillageManager or not VillageManager.village_scene_instance:
		return null
	
	var placed_buildings = VillageManager.village_scene_instance.get_node_or_null("PlacedBuildings")
	if not placed_buildings:
		return null
	
	for building in placed_buildings.get_children():
		if building.has_method("get_military_force"):
			return building
	
	return null

func show_help() -> void:
	var help_text = """Available commands:
	help - Show this help message
	clear - Clear console output
	powerup <name> - Activate a powerup
	heal [amount] - Heal the player (default: 50)
	damage [amount] - Damage the player (default: 10)
	kill - Instantly kill the player
	god - Toggle god mode
	reset - Reset the current scene
	
	=== DÜNYA SİSTEMİ ===
	force_event <type> <faction> - Force a world event
	set_relation <f1> <f2> <value> - Set faction relation (-100 to 100)
	spawn_war <f1> <f2> - Start war between factions
	world_stats - Show world statistics
	village_stats - Show village statistics
	add_resources <type> <amount> - Add resources to village
	set_morale <value> - Set village morale (0-100)
	
	=== ASKER SİSTEMİ ===
	recruit_soldier - Assign a villager as soldier
	barracks_info - Show barracks information
	force_attack <attacker> <target> - Force an attack (Köy/Kuzey/Güney/etc)
	test_battle [attacker] - Immediately trigger a battle for testing (default: Kuzey)"""
	print_output(help_text)

func print_output(text: String) -> void:
	if output:
		output.add_text(text + "\n")

func navigate_history(direction: int) -> void:
	if command_history.is_empty() or !line_edit:
		return
		
	history_index = clamp(history_index + direction, 0, command_history.size())
	
	if history_index < command_history.size():
		line_edit.text = command_history[history_index]
		line_edit.caret_column = line_edit.text.length()
	else:
		line_edit.clear() 
