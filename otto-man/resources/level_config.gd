class_name LevelConfig extends Resource

# Base values (Level 1)
@export var base_length: int = 15  # Starting dungeon length
@export var length_increase_per_level: int = 2  # How many chunks to add per level

# Maximum values (to prevent levels from becoming too large)
@export var max_length: int = 40  # Maximum dungeon length

# Optional scaling factors
@export var branch_ratio: float = 0.2  # Number of branches relative to length
@export var dead_end_ratio: float = 0.15  # Number of dead ends relative to length
@export var combat_room_base_chance: float = 0.2  # Base chance for combat rooms
@export var combat_chance_increase: float = 0.02  # How much to increase combat chance per level

func get_length_for_level(level: int) -> int:
    var target_length = base_length + (level - 1) * length_increase_per_level
    return mini(target_length, max_length)  # Never exceed max_length

func get_num_branches_for_level(level: int) -> int:
    # Erken seviyeler: düz ana yol; ilerledikçe yan dallar artar
    if level <= 1:
        return 0
    if level <= 3:
        return 1
    var length = get_length_for_level(level)
    var scaled: int = floori(length * branch_ratio)
    return clampi(scaled, min_branches, max_branches)

func get_num_dead_ends_for_level(level: int) -> int:
    if level <= 2:
        return 0
    if level <= 4:
        return 1
    var length = get_length_for_level(level)
    var scaled: int = floori(length * dead_end_ratio)
    return clampi(scaled, min_dead_ends, max_dead_ends)

func get_combat_chance_for_level(level: int) -> float:
    return minf(combat_room_base_chance + (level - 1) * combat_chance_increase, 0.7)  # Cap at 70% chance

@export var min_branches: int = 2  # Minimum number of branch paths
@export var max_branches: int = 4  # Maximum number of branch paths
@export var min_dead_ends: int = 2  # Minimum number of dead ends
@export var max_dead_ends: int = 4  # Maximum number of dead ends
@export var combat_room_chance: float = 0.3  # Chance for a basic platform to be a combat room
@export var description: String = ""  # Optional description of this level configuration

## Seviyeye göre altın çarpanı (zindan tier risk-ödül). Seviye 1 daha az, 9'a doğru artar.
@export var gold_multiplier_base: float = 0.8
@export var gold_multiplier_per_level: float = 0.22

func get_gold_multiplier(level: int) -> float:
    if level < 1:
        return gold_multiplier_base
    return gold_multiplier_base + (level - 1) * gold_multiplier_per_level

## Dead end başına kurtarma odası (köylü/cariye) olma olasılığı — seviye arttıkça artar (0.0–1.0)
@export var rescue_room_chance_base: float = 0.12
@export var rescue_room_chance_per_level: float = 0.08

func get_rescue_room_chance(level: int) -> float:
    if level < 1:
        return rescue_room_chance_base
    return clampf(rescue_room_chance_base + (level - 1) * rescue_room_chance_per_level, 0.0, 0.85)

## Yan yol dead-end'lerde mini-event (tüccar / lanet) olasılığı
@export var dungeon_event_chance_base: float = 0.14
@export var dungeon_event_chance_per_level: float = 0.02

func get_dungeon_event_chance(level: int) -> float:
    if level < 1:
        return dungeon_event_chance_base
    return clampf(dungeon_event_chance_base + (level - 1) * dungeon_event_chance_per_level, 0.08, 0.32)

## Debug: Tüm dead end'lerde kurtarma odası zorla (test)
@export var debug_force_rescue_rooms_in_every_level: bool = false

func get_num_main_paths_for_level(level: int) -> int:
    # Every 4 levels, add one more main path
    # Level 1-4: 1 path
    # Level 5-8: 2 paths
    # Level 9-12: 3 paths
    # And so on...
    return (level - 1) / 4 + 1

## Bir dalın kendi içinden tekrar dallanabileceği maksimum derinlik (0 = ana yol, 1 = ana yoldan dal, 2 = daldan dal, ...)
@export var max_branch_depth_base: int = 1
@export var max_branch_depth_per_level: int = 5  # Her N seviyede bir derinlik +1
@export var max_branch_depth_cap: int = 3

func get_max_branch_depth_for_level(level: int) -> int:
    if level <= 2:
        return 0
    if level <= 5:
        return 1
    if level < 1:
        return max_branch_depth_base
    var extra: int = (level - 1) / maxi(1, max_branch_depth_per_level)
    return mini(max_branch_depth_base + extra, max_branch_depth_cap)

## İki farklı yol/dal segmenti bitişik hücrelere düşünce, aralarında bir kavşak (bağlantı) oluşma olasılığı.
## Zar tutmazsa iki hücre bitişik ama bağlantısız kalır (yollar birbirine değmez).
@export var path_junction_chance_base: float = 0.35
@export var path_junction_chance_per_level: float = 0.0

func get_path_junction_chance(level: int) -> float:
    # Düşük seviyede kavşak az: arap saçı yerine okunabilir yol
    if level <= 2:
        return 0.05
    if level <= 4:
        return 0.12
    if level <= 6:
        return 0.22
    if level < 1:
        return path_junction_chance_base
    return clampf(path_junction_chance_base + (level - 1) * path_junction_chance_per_level, 0.0, 0.45)
