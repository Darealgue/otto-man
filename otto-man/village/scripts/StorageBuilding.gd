extends Node2D

# Provides extra storage capacity when placed under PlacedBuildings
# VillageManager detects these properties to add capacity to basic resources
var provides_storage: bool = true
var storage_bonus_all: int = 50 # Flat capacity added to all basic resources

# Optional: future per-resource bonus example
# var storage_bonus := {"wood": 0, "stone": 0, "food": 0, "water": 0}


