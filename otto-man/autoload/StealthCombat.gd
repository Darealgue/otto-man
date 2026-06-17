extends Node
## Stealth dövüş kuralları: arkadan vuruş, bayıltma, sessiz öldürme, gürültülü alarm.

const STEALTH_BACKSTAB_MULT: float = 3.0
const STEALTH_BACKSTAB_NOISE_MULT: float = 0.4
const FAINT_DURATION: float = 5.0
const STEALTH_KILL_SCORE: int = 5

const LIGHT_ATTACK_NAMES: Array[String] = [
	"attack_1", "attack_1.2", "attack_2", "attack_3",
	"up_light", "down_light", "air_attack1", "air_attack2", "air_attack3",
]


func is_stealth_active() -> bool:
	var sm: Node = get_node_or_null("/root/StealthManager")
	return is_instance_valid(sm) and sm.has_method("is_stealth_enabled") and sm.is_stealth_enabled() \
		and sm.has_method("is_stealth_mode") and sm.is_stealth_mode()


func is_stealth_backstab(player: Node, enemy: Node, attack_name: String = "") -> bool:
	if not is_stealth_active():
		return false
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return false
	if not _is_flank_hit(player.global_position, enemy):
		return false
	if _enemy_is_alert(enemy):
		return false
	if _player_is_crouching(player):
		return true
	return _is_light_attack_name(attack_name)


func apply_stealth_damage_mult(player: Node, enemy: Node, base_damage: float, attack_name: String = "") -> float:
	if is_stealth_backstab(player, enemy, attack_name):
		return base_damage * STEALTH_BACKSTAB_MULT
	return base_damage


func handle_melee_hit_on_enemy(enemy: Node, hitbox: Area2D, damage: float) -> void:
	if not is_stealth_active() or not is_instance_valid(enemy):
		return
	var player: Node = _get_player_from_hitbox(hitbox)
	if not is_instance_valid(player):
		return
	var attack_name: String = ""
	if hitbox is PlayerHitbox:
		attack_name = String((hitbox as PlayerHitbox).current_attack_name)
	if is_stealth_backstab(player, enemy, attack_name):
		_apply_quiet_hit_noise(player)
		var hp: float = float(enemy.get("health")) if enemy.get("health") != null else 999.0
		if damage < hp and enemy.has_method("apply_faint"):
			enemy.apply_faint(FAINT_DURATION)
		elif damage >= hp:
			var sm: Node = get_node_or_null("/root/StealthManager")
			if is_instance_valid(sm) and sm.has_method("add_stealth_score"):
				sm.add_stealth_score(STEALTH_KILL_SCORE)
		return
	if not _enemy_is_alert(enemy):
		var sm: Node = get_node_or_null("/root/StealthManager")
		if is_instance_valid(sm) and sm.has_method("raise_alarm"):
			sm.raise_alarm("combat", String(enemy.get("enemy_id")))


func _apply_quiet_hit_noise(player: Node) -> void:
	var emitter: Node = player.get_node_or_null("PlayerNoiseEmitter")
	if not is_instance_valid(emitter) or not emitter.has_method("emit_noise_event"):
		return
	var base_noise: float = 40.0
	if emitter.has_method("get_noise_multiplier"):
		var prev: float = float(emitter.get_noise_multiplier())
		emitter.set_noise_multiplier(prev * STEALTH_BACKSTAB_NOISE_MULT)
		emitter.emit_noise_event(base_noise * STEALTH_BACKSTAB_NOISE_MULT)
		emitter.set_noise_multiplier(prev)


func _get_player_from_hitbox(hitbox: Area2D) -> Node:
	if hitbox.has_meta("damage_source"):
		return hitbox.get_meta("damage_source")
	return hitbox.get_parent()


func _enemy_is_alert(enemy: Node) -> bool:
	if enemy.has_method("is_fainted") and enemy.is_fainted():
		return false
	if enemy.has_method("is_stealth_suspicious") and enemy.is_stealth_suspicious():
		return true
	var behavior: String = String(enemy.get("current_behavior"))
	if behavior in ["chase", "attack", "charge", "alert"]:
		return true
	if enemy.get("stealth_perception"):
		var sp: Node = enemy.stealth_perception
		if is_instance_valid(sp) and sp.get("visibility_level") != null:
			var vis: int = int(sp.visibility_level)
			if vis != 0:  # StealthPerception.VisibilityLevel.NONE
				return true
	return false


func _player_is_crouching(player: Node) -> bool:
	var sm_node: Node = player.get_node_or_null("StateMachine")
	if not sm_node or not sm_node.get("current_state"):
		return false
	return String(sm_node.current_state.name) == "Crouch"


func _is_light_attack_name(attack_name: String) -> bool:
	if attack_name.is_empty():
		return true
	if attack_name.find("heavy") != -1:
		return false
	if attack_name == "fall_attack":
		return false
	return true


func _is_flank_hit(attacker_pos: Vector2, enemy: Node) -> bool:
	if has_node("/root/DamageModifiers") and DamageModifiers.has_method("_is_flank_hit"):
		return DamageModifiers._is_flank_hit(attacker_pos, enemy)
	if not enemy.get("direction"):
		return false
	var enemy_dir: int = int(enemy.direction)
	var to_attacker: Vector2 = (attacker_pos - enemy.global_position).normalized()
	return (enemy_dir > 0 and to_attacker.x < -0.15) or (enemy_dir < 0 and to_attacker.x > 0.15)
