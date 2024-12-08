extends Area2D

signal damaged(amount: int)

func _ready():
    # Make sure these match in the editor
    collision_layer = 8   # Layer 4 for hurtboxes
    collision_mask = 4    # Layer 3 for hitboxes
    
    add_to_group("hurtbox")

func take_damage(amount: int) -> void:
    print("Hurtbox received damage: ", amount)
    damaged.emit(amount)
    # Get the parent node (usually the character)
    if get_parent().has_method("take_damage"):
        get_parent().take_damage(amount) 