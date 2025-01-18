# Otto-Man Project Status

## Recently Implemented Features

### Enemy System
- **Base Enemy Class**
  - Health and damage system
  - Invulnerability frames
  - Damage numbers display
  - Sleep/wake system based on distance from player
  - Health bars
  - Death handling and object pooling

### Enemy Types
1. **Flying Enemy**
  - Movement patterns: chase, swoop, neutral
  - Stats configured (15 HP, 100 speed, 3 damage)
  - Can be summoned by Summoner enemy
  - Object pool integration
  - Powerup drop chance: 0.4
  - Scaling factors:
    - Health: 1.15x
    - Damage: 1.1x
    - Speed: 1.2x

2. **Heavy Enemy**
  - Uninterruptible states (charge, slam)
  - Special attacks: charge and ground slam
  - Parry system for charge attacks
  - Damage numbers and health display

3. **Summoner Enemy**
  - Configurable bird summoning (max_summon_count, summon_cooldown)
  - Current settings: max 1 bird, 10s cooldown
  - Birds become neutral on summoner death
  - Health: 30, Movement Speed: 200
  - Powerup drop chance: 0.6
  - Scaling factors:
    - Health: 1.2x
    - Speed: 1.1x

### Level Generation
- Chunk-based procedural generation
- Combat and platform chunks implemented
- Chunk activation/deactivation based on player distance
- Spawn point system for enemies

### Recent Changes
1. Fixed damage numbers display across all enemy types
2. Added configurable summoner stats in resource file
3. Improved chunk activation distances
4. Fixed spawn point reuse issues

## Current Issues/Bugs
- None currently reported

## Planned Features/Improvements
1. Additional enemy types
2. More chunk variations
3. Boss encounters
4. Power-up system expansion

## Core Technical Systems

### 1. Stat System Architecture
- Base Stats:
  - Uses Resource system for configuration
  - Supports runtime modification
  - Implements multiplier and bonus stacking
- Stat Calculation Formula: (base_value * multiplier) + bonus
- Stat Types:
  - Health (max_health, current_health)
  - Damage (base_damage, fall_attack_damage)
  - Movement (movement_speed, jump_force)
  - Cooldowns (shield_cooldown, dash_cooldown)
  - Combat (block_charges)

### 2. Combat Mechanics
- Hitbox/Hurtbox System:
  - Uses Godot's Area2D
  - Collision Layers:
    - Layer 5: Player hitbox (16)
    - Layer 6: Enemy hurtbox (32)
    - Layer 3: Enemy collision (4)
  - Group-based detection ("hurtbox", "enemy_hurtbox")
- Damage Application:
  - Supports knockback force
  - Handles invulnerability frames
  - Includes combo system
  - Uses damage multipliers

### 3. Enemy AI System
- State Machine Based:
  - Idle state
  - Chase state
  - Attack state
  - Hurt state
  - Death state
- Detection System:
  - Uses circular detection range
  - Configurable detection and attack ranges
  - Line of sight checking

### 4. Resource Management
- Uses Godot's Resource system for:
  - Enemy stats (.tres files)
  - Powerup configurations
  - Room/Chunk templates
- Runtime loading and modification
- Supports saving/loading

### 5. Scene Management
- Autoloaded Managers:
  - PlayerStats
  - PowerupManager
  - AttackManager
  - ChunkManager (converted from RoomManager)
- Scene Transitions:
  - Handles player persistence
  - Manages chunk loading
  - Maintains game state

### 6. Input System
- Custom input mapping:
  - Movement (WASD)
  - Jump (Space)
  - Block (Q)
- Controller support:
  - Analog movement
  - Button mapping
  - Deadzone configuration

### 7. Physics System
- Uses Godot's physics engine
- Custom gravity settings
- Collision layers:
  - Layer 1: Environment
  - Layer 2: Player
  - Layer 3: Enemies
  - Layer 4: Projectiles
- Raycasting for ground detection

### 8. UI System
- Health display
- Stamina bar
- Damage numbers
- Layer system:
  - Game UI: Layer 100
  - HUD elements
  - Damage numbers

## Performance Optimizations
- Chunk activation distance: 2500 pixels
- Chunk deactivation distance: 3500 pixels
- Enemy sleep system active
- Object pooling for:
  - Enemies
  - Damage numbers
  - Effects

## Development Environment
- Godot Engine v4.3
- Project Structure:
  - `/enemy/` - Enemy-related scripts and scenes
  - `/levels/` - Level generation and chunk system
  - `/effects/` - Visual effects and particles
  - `/resources/` - Configuration files and resources
  - `/autoload/` - Global managers and systems
  - `/components/` - Reusable game components
  - `/ui/` - User interface elements 