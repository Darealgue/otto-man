signal shield_broken

if has_shield:
	print("DEBUG: Shield blocked damage")
	has_shield = false
	shield_timer = 0.0  # Reset shield timer when shield is used
	if shield_sprite:
		var tween = create_tween()
		tween.tween_property(shield_sprite, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): shield_sprite.visible = false)
	shield_broken.emit()  # Emit the signal when shield breaks
	return 