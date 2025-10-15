# Spearman Enemy Sprites

## Required Sprite Files

Based on the plan, the following sprite files are needed for the spearman enemy:

### 1. Movement Animations
- `spearman_idle_border.png` - Idle/waiting pose (spear held vertically at side)
- `spearman_patrol_border.png` - Slow walking/patrol animation
- `spearman_charge_border.png` - Fast running charge (spear extended forward)

### 2. Air Movement
- `spearman_fall_border.png` - Falling animation
- `spearman_jump.png` - Jumping animation (if needed)

### 3. Damage and Death
- `spearman_hurt_border.png` - Taking damage (ONLY when not charging)
- `spearman_death_border.png` - Death animation

### 4. Optional
- `spearman_landing_border.png` - Landing animation (if needed)

## Animation Behavior

**Patrol/Idle:** Normal patrol and waiting
- Spear held at side, vertical or slightly angled
- Slow, relaxed movement

**Charge (Attack):** When player detected
- **Spear extended forward while running**
- **Unstoppable** during this state (immune to damage)
- Fast running animation
- **If hits player:** Falls back and briefly enters "hurt" state

**Hurt:** Normal situations
- Taking damage and knockback
- This animation does **NOT** work during charge (unstoppable)
- Works after hitting player (recoil)

**Death:** Standard death
- Spear drops, enemy falls to ground

## Size and Style
- **Canonman-sized** (medium enemy)
- Consistent with existing border sprite style
- Should match the visual style of other enemies in the game

## Total Required: 6-7 Sprite Animations
