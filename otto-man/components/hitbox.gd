extends Area2D

@export var damage: int = 1

func _ready():
    # Make sure these match in the editor
    collision_layer = 4  # Layer 3 for hitboxes
    collision_mask = 8   # Layer 4 for hurtboxes
    
    # Connect the area entered signal
    area_entered.connect(_on_hitbox_area_entered)

func _on_hitbox_area_entered(area: Area2D) -> void:
    print("Hitbox detected area: ", area.name)
    if not area.is_in_group("hurtbox"):
        print("Area is not a hurtbox")
        return
    print("Valid hurtbox detected")