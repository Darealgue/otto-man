extends State

## Şok: oyuncu süre boyunca kontrolü kaybeder (stun): hareket, saldırı, dodge, blok yok.
## Süre `player.shock_duration` (StatusEffectManager.apply_shock ayarlar). Hasar alınırsa Hurt state'i
## devralır; şok görseli (sarı ton) durum yöneticisinin zamanlayıcısıyla ayrıca biter.
## Bu state sahnede değil, player.gd _ready içinde koda eklenir (bkz. player.gd "Shock").

const STOP_DECEL := 3000.0

var _timer: float = 0.0


func enter() -> void:
	super.enter()
	# Yarım kalan saldırıyı sıfırla (hurt state'iyle aynı yöntem)
	var attack_state = state_machine.get_node_or_null("Attack")
	if attack_state and attack_state.has_method("_reset_attack_state"):
		attack_state._reset_attack_state()
	if animation_player:
		animation_player.stop()
		if player.has_method("reset_sprite_visual_to_default"):
			player.reset_sprite_visual_to_default()
		if animation_player.has_animation("idle"):
			animation_player.play("idle")
	_timer = player.shock_duration


func physics_update(delta: float) -> void:
	_timer -= delta
	player.velocity.x = move_toward(player.velocity.x, 0.0, STOP_DECEL * delta)
	player.apply_move_and_slide()
	if _timer <= 0.0:
		state_machine.transition_to("Idle" if player.is_on_floor() else "Fall")
