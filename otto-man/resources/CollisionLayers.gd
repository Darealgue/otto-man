extends Resource
class_name CollisionLayers

# Centralized collision layer bit masks.
# Does not modify ProjectSettings; only provides readable names for existing bits.

# Common world/environment
const WORLD: int = 1 << 0          # Layer 1

# Player body
const PLAYER: int = 1 << 1          # Layer 2

# Building slots or interaction points (used in village/player)
const BUILDING_SLOT: int = 1 << 2   # Layer 3

# Player combat layers
const PLAYER_HURTBOX: int = 1 << 3  # Layer 4 (8)
const PLAYER_HITBOX: int = 1 << 4   # Layer 5 (16)

# Enemy combat layers
const ENEMY_HURTBOX: int = 1 << 5   # Layer 6 (32)
const ENEMY_HITBOX: int = 1 << 6    # Layer 7 (64)

# Platform/one-way platforms
const PLATFORM: int = 1 << 9        # Layer 10 (512)

# Enemy projectiles (used by effects/shockwave.gd)
const ENEMY_PROJECTILE: int = 1 << 8  # Layer 9 (256)
 
# Generic items (coins, pickups)
const ITEM: int = 1 << 12            # Layer 13 (4096)

# Utility masks
const NONE: int = 0
const ALL: int = 0xFFFFFFFF         # All 32 layers

static func mask_of(layers: Array[int]) -> int:
    var mask: int = 0
    for layer in layers:
        mask |= int(layer)
    return mask


