class_name WardTarget
extends Node2D

## Korunan köylü (Koruma challenge'ı). "ward_targets" grubundadır: düşmanlar oyuncu kadar bunu da
## hedef alır (bkz. BaseEnemy.get_nearest_player). Hasarı WardHurtbox üzerinden alır.
## GEÇİCİ SANAT: oturan tüccar sprite'ı + kod çizimi can çubuğu; köylü sprite'ı gelince
## _build_sprite() değiştirilir.

signal died(ward: WardTarget)
signal health_changed(ward: WardTarget, health: float, max_health: float)

const SPRITE_PATH := "res://assets/NPC/trader/Trader_sit_border.png"
const BAR_SIZE := Vector2(46.0, 6.0)
const BAR_OFFSET := Vector2(-23.0, -96.0)

@export var max_health: float = 60.0

var health: float = 60.0
var is_dead: bool = false
## Düşman kodunun oyuncuya özgü alanlara bakması ihtimaline karşı sabit değerler.
var velocity: Vector2 = Vector2.ZERO

var _sprite: Sprite2D = null
var _hurtbox: WardHurtbox = null
var _flash: float = 0.0


func _ready() -> void:
	add_to_group("ward_targets")
	health = max_health
	_build_sprite()
	_build_hurtbox()
	z_index = 3


func _build_sprite() -> void:
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(0.0, -48.0)
	if ResourceLoader.exists(SPRITE_PATH):
		_sprite.texture = load(SPRITE_PATH)
		_sprite.hframes = 10
		_sprite.frame = 0
	# Her köylü biraz farklı tonda (aynı sprite'ı paylaştıkları için ayırt edilebilsinler)
	_sprite.modulate = Color.from_hsv(randf(), 0.25, 1.0)
	add_child(_sprite)


func _build_hurtbox() -> void:
	_hurtbox = WardHurtbox.new()
	_hurtbox.name = "WardHurtbox"
	_hurtbox.ward = self
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(38.0, 70.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -38.0)
	_hurtbox.add_child(shape)
	add_child(_hurtbox)


## Düşman saldırısından hasar (WardHurtbox çağırır). Diğer take_damage imzalarıyla uyumlu.
func take_damage(amount: float, _kb: float = 0.0, _kb_up: float = 0.0, _apply_kb: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	_flash = 0.15
	health_changed.emit(self, health, max_health)
	if health <= 0.0:
		_die()
	queue_redraw()


func _die() -> void:
	is_dead = true
	remove_from_group("ward_targets")
	if is_instance_valid(_hurtbox):
		_hurtbox.set_deferred("monitoring", false)
		_hurtbox.set_deferred("monitorable", false)
	if is_instance_valid(_sprite):
		_sprite.modulate = Color(0.5, 0.2, 0.2, 0.55)
		_sprite.rotation = 1.2
	died.emit(self)
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if is_instance_valid(_sprite) and not is_dead:
			_sprite.self_modulate = Color(1.6, 0.6, 0.6) if _flash > 0.0 else Color.WHITE
		queue_redraw()


func _draw() -> void:
	if is_dead:
		return
	var ratio: float = clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(BAR_OFFSET - Vector2(1, 1), BAR_SIZE + Vector2(2, 2)), Color(0, 0, 0, 0.7))
	var col := Color(0.3, 0.9, 0.35).lerp(Color(0.95, 0.25, 0.2), 1.0 - ratio)
	draw_rect(Rect2(BAR_OFFSET, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), col)
