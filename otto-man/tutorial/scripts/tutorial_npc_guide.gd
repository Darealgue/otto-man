class_name TutorialNpcGuide
extends Node2D
## Tutorial rehberi: MentorCharacter giriş (duman → idle) / çıkış (smoke_bomb → duman).

const _MENTOR_VISUAL := preload("res://characters/mentor/MentorCharacter.tscn")

@onready var _mentor: MentorCharacter = $MentorCharacter as MentorCharacter


func _ready() -> void:
	visible = false
	if _mentor == null:
		var inst := _MENTOR_VISUAL.instantiate()
		inst.name = "MentorCharacter"
		add_child(inst)
		_mentor = inst as MentorCharacter


func play_entrance(at_world: Vector2) -> void:
	global_position = at_world
	visible = true
	if _mentor:
		await _mentor.play_entrance_sequence()


func depart_with_smoke_bomb() -> void:
	if _mentor:
		await _mentor.play_departure_sequence()
	visible = false


## Eski API — director artık play_entrance / depart_with_smoke_bomb kullanır.
func appear(at_world: Vector2) -> void:
	await play_entrance(at_world)


func disappear() -> void:
	await depart_with_smoke_bomb()
