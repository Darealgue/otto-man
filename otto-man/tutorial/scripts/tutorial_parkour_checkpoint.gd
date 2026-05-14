extends Node
## Oyuncu [b]death zone[/b] [Area2D] içine girince [b]respawn[/b] işaretinin konumuna ışınlanır ve hız sıfırlanır.
## Sahneyi ben değiştirmiyorum — Godot'ta bu scripti bir düğüme ver, iki yolu bağla.

@export var death_zone: NodePath
## Parkur başı: genelde Marker2D veya boş bir Node2D.
@export var respawn_marker: NodePath


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	var area := _get_node_at_path(death_zone) as Area2D
	var marker := _get_node_at_path(respawn_marker) as Node2D
	if area == null:
		push_error("[TutorialParkourCheckpoint] death_zone (Area2D) NodePath ile atanmalı.")
		return
	if marker == null:
		push_error("[TutorialParkourCheckpoint] respawn_marker (Node2D / Marker2D) NodePath ile atanmalı.")
		return
	area.monitoring = true
	if not area.body_entered.is_connected(_on_death_zone_body_entered):
		area.body_entered.connect(_on_death_zone_body_entered.bind(marker))


func _get_node_at_path(p: NodePath) -> Node:
	if p.is_empty():
		return null
	return get_node_or_null(p)


func _on_death_zone_body_entered(body: Node2D, marker: Node2D) -> void:
	if body == null or marker == null or not is_instance_valid(marker):
		return
	if not body.is_in_group("player"):
		return
	var pl := body as CharacterBody2D
	if pl == null:
		return
	pl.global_position = marker.global_position
	pl.velocity = Vector2.ZERO
