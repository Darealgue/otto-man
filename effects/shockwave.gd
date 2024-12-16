# shockwave.gd
extends Area2D

var direction = Vector2.RIGHT
var speed = 300
var damage = 25
var lifetime = 2.0

func _ready():
	# Start lifetime timer
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage, direction)
