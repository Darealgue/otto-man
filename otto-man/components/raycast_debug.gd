extends RayCast2D

func _ready() -> void:
    print("Raycast initialized: ", name)
    print("Properties for ", name, ":")
    print("- Enabled: ", enabled)
    print("- Target pos: ", target_position)
    print("- Collision mask: ", collision_mask)
    print("- Collide with areas: ", collide_with_areas)
    print("- Collide with bodies: ", collide_with_bodies)
    print("- Hit from inside: ", hit_from_inside)
    print("- Global pos: ", global_position)
    print("- Local pos: ", position)
    print("- Parent: ", get_parent().name)

func _draw() -> void:
    if enabled:
        # Draw raycast line
        var color = Color.GREEN if is_colliding() else Color.RED
        draw_line(Vector2.ZERO, target_position, color, 2.0)
        
        # Draw collision point if hitting something
        if is_colliding():
            var collision_point = get_collision_point() - global_position
            draw_circle(collision_point, 5, Color.YELLOW)
            
        # Draw start and end points
        draw_circle(Vector2.ZERO, 3, Color.BLUE)  # Start point
        draw_circle(target_position, 3, Color.WHITE)  # End point

func _physics_process(_delta: float) -> void:
    queue_redraw()  # Update the debug visualization 