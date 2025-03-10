class_name PatrolPoint
extends RefCounted

enum PointType {
    GROUND,
    PLATFORM,
    LEDGE,
    DROP_POINT
}

enum MovementType {
    WALK,
    JUMP_UP,
    JUMP_ACROSS,
    DROP_DOWN
}

var position: Vector2
var point_type: PointType
var movement_type: MovementType
var connections: Array[PatrolPoint] = []
var cost: float = INF  # Cost to reach this point from start
var total_cost: float = INF  # Total cost (cost + heuristic)
var parent: PatrolPoint = null  # For pathfinding

func _init(pos: Vector2, type: PointType = PointType.GROUND, movement: MovementType = MovementType.WALK):
    position = pos
    point_type = type
    movement_type = movement

func add_connection(point: PatrolPoint) -> void:
    if point not in connections:
        connections.append(point)
        # Add reverse connection if it doesn't exist
        if self not in point.connections:
            point.add_connection(self)

func get_connection_cost(other: PatrolPoint) -> float:
    var base_cost = position.distance_to(other.position)
    
    # Add additional cost based on movement type
    match movement_type:
        MovementType.WALK:
            return base_cost
        MovementType.JUMP_UP:
            return base_cost * 2.0  # Jumping up is more "expensive"
        MovementType.JUMP_ACROSS:
            return base_cost * 1.5  # Jumping across gaps is moderately expensive
        MovementType.DROP_DOWN:
            return base_cost * 1.2  # Dropping down is slightly more expensive than walking
    
    return base_cost

func reset_pathfinding() -> void:
    cost = INF
    total_cost = INF
    parent = null 