class_name WardHurtbox
extends BaseHurtbox

## Korunan hedefin (köylü) hasar kutusu. Oyuncunun PlayerHurtbox'ıyla aynı katmandadır: düşman
## saldırı kutuları (EnemyHitbox) onu da yakalar. EnemyHitbox yalnızca "player_hurtbox" grubundaki
## kutuları oyuncu sayar, bu yüzden oyuncuya özel mantık (hitstop, parry) köylüde çalışmaz;
## hasarı burada kendimiz uygularız.

## Aynı saldırı kutusunun art arda vurmaması için (BaseHurtbox varsayılanı 0.1 sn çok kısa).
const HIT_COOLDOWN: float = 0.7

var ward: Node = null


func _ready() -> void:
	collision_layer = CollisionLayers.PLAYER_HURTBOX
	collision_mask = CollisionLayers.ENEMY_HITBOX
	monitoring = true
	monitorable = true
	super._ready()


func _on_area_entered(hitbox: Area2D) -> void:
	if not (hitbox is EnemyHitbox):
		return
	if hitbox.has_method("is_enabled") and not hitbox.is_enabled():
		return
	if hitbox.get_damage() <= 0.0:
		return
	if is_on_cooldown(hitbox):
		return
	store_hit_data(hitbox)
	start_cooldown(hitbox, HIT_COOLDOWN)
	if is_instance_valid(ward) and ward.has_method("take_damage"):
		ward.take_damage(hitbox.get_damage())
	hurt.emit(hitbox)
