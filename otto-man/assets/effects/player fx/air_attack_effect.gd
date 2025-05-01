extends Node2D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Konumu hıza göre güncelle
	global_position += velocity * delta
	# Hızı sürtünme ile yavaşlat
	velocity = velocity.lerp(Vector2.ZERO, drag * delta)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # Düğüm adının bu olduğundan emin ol

# Efektin kendi hızı ve sürtünmesi
var velocity := Vector2.ZERO
var drag := 1.5 # Sürtünme/yavaşlama miktarı (ayarlanabilir)

# Dışarıdan hızı ayarlamak için fonksiyon
func set_initial_velocity(initial_vel: Vector2):
	velocity = initial_vel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animated_sprite.play("default") # Animasyon adını kontrol et
	animated_sprite.animation_finished.connect(queue_free)
