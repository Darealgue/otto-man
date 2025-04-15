extends Node2D

@export var unit_scene: PackedScene
@export var unit_stats_swordsman: UnitStats
@export var unit_stats_archer: UnitStats
@export var unit_stats_cavalry: UnitStats
@export var unit_stats_spearman: UnitStats
@export var unit_stats_shieldbearer: UnitStats
@export var battle_area: Rect2 = Rect2(0, 0, 1920, 1080)
@export var player_unit_count: int = 10
@export var enemy_unit_count: int = 10

# <<< YENİ: Sıralı Spawn Ayarları >>>
@export var units_per_row: int = 8
@export var unit_spacing: float = 50.0 # Birimler arası yatay boşluk
@export var row_spacing: float = 60.0   # Sıralar arası dikey boşluk
@export var player_spawn_start: Vector2 = Vector2(150, 250) # Sol üst köşe
@export var enemy_spawn_start: Vector2 = Vector2(1770, 250)  # Sağ üst köşe
@export var spawn_random_offset: float = 10.0 # Pozisyona eklenecek rastgelelik

var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []

var battle_over: bool = false
var winner_team_id: int = -1

func _ready() -> void:
	print("Battle Scene Ready!")

	# Birimleri yarat
	# <<< GÜNCELLENDİ: Dairesel spawn yerine sıralı spawn >>>
	# Oyuncu birimleri
	for i in range(player_unit_count):
		var unit_instance = unit_scene.instantiate() as Unit
		
		# Sıra ve Sütun Hesapla
		var row = i / units_per_row
		var col = i % units_per_row
		
		# Pozisyon Hesapla (Soldan sağa, yukarıdan aşağıya)
		var spawn_x = player_spawn_start.x + col * unit_spacing + randf_range(-spawn_random_offset, spawn_random_offset)
		var spawn_y = player_spawn_start.y + row * row_spacing + randf_range(-spawn_random_offset, spawn_random_offset)
		var spawn_pos = Vector2(spawn_x, spawn_y)
		
		# Birim türünü belirle
		var stats_to_use: UnitStats = unit_stats_swordsman # Varsayılan Kılıçlı
		if i % 4 == 0 and unit_stats_cavalry != null:
			stats_to_use = unit_stats_cavalry
		elif i % 5 == 3 and unit_stats_shieldbearer != null: # Öncelikli olarak Kalkanlı (Atlı değilse)
			stats_to_use = unit_stats_shieldbearer
		elif i % 3 == 1 and unit_stats_archer != null: # Sonra Okçu
			stats_to_use = unit_stats_archer
		elif i % 3 == 2 and unit_stats_spearman != null: # Sonra Mızraklı
			stats_to_use = unit_stats_spearman
		elif unit_stats_swordsman == null:
			printerr("Cannot spawn unit, default Swordsman stats are null and no other type could be assigned!")
			continue
		
		unit_instance.stats = stats_to_use
		unit_instance.team_id = 0
		unit_instance.global_position = spawn_pos
		unit_instance.battle_scene_ref = self 
		unit_instance.battle_area_limit = battle_area 
		unit_instance.name = "%s_%s" % [unit_instance.stats.unit_type_id.capitalize(), unit_instance.get_instance_id()]
		add_child(unit_instance)
		player_units.append(unit_instance)
		unit_instance.died.connect(_on_unit_died)
		# print("Spawned %s for team 0 at %s" % [unit_instance.name, unit_instance.global_position.round()]) # Logu kapatalım

	# Düşman birimleri
	for i in range(enemy_unit_count):
		var unit_instance = unit_scene.instantiate() as Unit
		
		# Sıra ve Sütun Hesapla
		var row = i / units_per_row
		var col = i % units_per_row
		
		# Pozisyon Hesapla (Sağdan sola, yukarıdan aşağıya)
		var spawn_x = enemy_spawn_start.x - col * unit_spacing + randf_range(-spawn_random_offset, spawn_random_offset)
		var spawn_y = enemy_spawn_start.y + row * row_spacing + randf_range(-spawn_random_offset, spawn_random_offset)
		var spawn_pos = Vector2(spawn_x, spawn_y)

		# Birim türünü belirle
		var stats_to_use: UnitStats = unit_stats_swordsman # Varsayılan Kılıçlı
		if i % 4 == 0 and unit_stats_cavalry != null:
			stats_to_use = unit_stats_cavalry
		elif i % 5 == 3 and unit_stats_shieldbearer != null:
			stats_to_use = unit_stats_shieldbearer
		elif i % 3 == 1 and unit_stats_archer != null:
			stats_to_use = unit_stats_archer
		elif i % 3 == 2 and unit_stats_spearman != null:
			stats_to_use = unit_stats_spearman
		elif unit_stats_swordsman == null:
			printerr("Cannot spawn unit, default Swordsman stats are null and no other type could be assigned!")
			continue

		unit_instance.stats = stats_to_use
		unit_instance.team_id = 1
		unit_instance.global_position = spawn_pos
		unit_instance.battle_scene_ref = self
		unit_instance.battle_area_limit = battle_area
		unit_instance.name = "%s_%s" % [unit_instance.stats.unit_type_id.capitalize(), unit_instance.get_instance_id()]
		add_child(unit_instance)
		enemy_units.append(unit_instance)
		unit_instance.died.connect(_on_unit_died)
		# print("Spawned %s for team 1 at %s" % [unit_instance.name, unit_instance.global_position.round()]) # Logu kapatalım

func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if battle_over:
		return

	var current_player_units = player_units.size()
	var current_enemy_units = enemy_units.size()

	if current_player_units == 0 and current_enemy_units > 0:
		_end_battle(1)
	elif current_enemy_units == 0 and current_player_units > 0:
		_end_battle(0)
	elif current_player_units == 0 and current_enemy_units == 0:
		_end_battle(-2)

func _end_battle(winning_team: int) -> void:
	if battle_over:
		return 
		
	battle_over = true
	winner_team_id = winning_team
	
	if winner_team_id == 0:
		print("-------------------")
		print("  PLAYER KAZANDI!  ")
		print("-------------------")
	elif winner_team_id == 1:
		print("-------------------")
		print("  DÜŞMAN KAZANDI!  ")
		print("-------------------")
	elif winner_team_id == -2:
		print("-------------------")
		print("     BERABERE!     ")
		print("-------------------")

func _on_unit_died(unit: Unit) -> void:
	print("DEBUG: BattleScene received died signal from %s (Team %d)" % [unit.name, unit.team_id])
	if unit.team_id == 0:
		if player_units.has(unit):
			player_units.erase(unit)
			print("DEBUG: Removed %s from player_units. Remaining: %d" % [unit.name, player_units.size()])
		else:
			print("WARN: Died unit %s (Team 0) not found in player_units?" % unit.name)
	elif unit.team_id == 1:
		if enemy_units.has(unit):
			enemy_units.erase(unit)
			print("DEBUG: Removed %s from enemy_units. Remaining: %d" % [unit.name, enemy_units.size()])
		else:
			print("WARN: Died unit %s (Team 1) not found in enemy_units?" % unit.name)
	else:
		print("ERROR: Died unit %s has unknown team_id %d" % [unit.name, unit.team_id])
