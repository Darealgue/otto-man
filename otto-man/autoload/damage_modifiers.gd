# damage_modifiers.gd
# Oyuncunun tüm hasar modifier'larının tek kaynağı.
# Player hitbox ve decoy (Karagöz/Hacivat) buradan apply eder.
# Yeni item eklediğinde player'a xxx_mult koy, buraya bir satır ekle - hepsi otomatik çalışır.

extends Node

## Oyuncunun tüm per-target modifier'larını uygula.
## attacker_position: vuruşun geldiği nokta (flank için - player veya decoy pozisyonu)
func apply_player_modifiers(player: Node, base_damage: float, enemy: Node, attacker_position: Vector2, is_elemental: bool) -> float:
	if not is_instance_valid(player):
		return base_damage
	var dmg := base_damage
	# Görünmezlik Pelerini: ilk vuruş bonusu (tek kullanım)
	if player.get("gorunmezlik_first_attack_mult") and player.gorunmezlik_first_attack_mult > 1.0:
		dmg *= player.gorunmezlik_first_attack_mult
		player.gorunmezlik_first_attack_mult = 1.0
	# Flank Avantajı: arkadan vuruş (enemy gerekli)
	if is_instance_valid(enemy) and player.get("flank_damage_mult") and player.flank_damage_mult > 1.0:
		if _is_flank_hit(attacker_position, enemy):
			dmg *= player.flank_damage_mult
	# Elemental Odak / fiziksel çarpanlar
	if is_elemental and player.get("elemental_damage_mult"):
		dmg *= player.elemental_damage_mult
	elif not is_elemental and player.get("physical_damage_mult"):
		dmg *= player.physical_damage_mult
	return dmg

func _is_flank_hit(attacker_pos: Vector2, enemy: Node) -> bool:
	if not enemy.get("direction"):
		return false
	var enemy_dir: int = enemy.direction
	var to_attacker: Vector2 = (attacker_pos - enemy.global_position).normalized()
	return (enemy_dir > 0 and to_attacker.x < 0) or (enemy_dir < 0 and to_attacker.x > 0)
