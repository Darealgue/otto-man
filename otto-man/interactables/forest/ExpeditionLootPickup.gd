class_name ExpeditionLootPickup
extends Area2D
## Sefer loot pickup (placeholder görsel). Dokununca taşınır loot'a eklenir.

@export var loot_type: String = ExpeditionLootType.SKY_FEATHER
@export var amount: int = 1

var _collected := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_placeholder_visual()
	_build_collision()


func _build_placeholder_visual() -> void:
	var lbl := ExpeditionLootType.make_emoji_label(ExpeditionLootType.placeholder_emoji(loot_type), 22)
	lbl.name = "EmojiVisual"
	add_child(lbl)


func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	col.shape = circle
	add_child(col)


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null or not ps.has_method("add_carried_expedition_loot"):
		return
	ps.add_carried_expedition_loot(loot_type, amount)
	_collected = true
	queue_free()
