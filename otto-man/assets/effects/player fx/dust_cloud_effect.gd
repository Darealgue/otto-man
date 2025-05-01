extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # Eğer AnimatedSprite2D'nin adını değiştirmediysen bu çalışır

# Bu değişken, dışarıdan hangi animasyonun oynatılacağını belirleyecek.
# Instantiate ettikten hemen sonra bu değeri ayarlayacağız.
var animation_to_play : String = "puff_down" # Varsayılan olarak birini atayalım

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Belirtilen animasyonu oynat
	animated_sprite.play(animation_to_play)
	
	# Animasyon bittiğinde sahneyi silmek için sinyali bağla
	animated_sprite.animation_finished.connect(queue_free)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
