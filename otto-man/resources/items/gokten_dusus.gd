# gokten_dusus.gd  (Kıvılcım Yağmuru)
# UNCOMMON - Düşme saldırısı yere inince etrafa zıplayan kıvılcımlar saçılır; değdikleri düşman yanar.
# Eski "fall attack hasarı +%30" düz stat'ı bu fiille değiştirildi (id aynı kaldı). Stamina harcamaz.
# Gölgenin düşme vuruşu da kıvılcım saçar (apply_fall_attack_effect_at, ItemManager çağırır).

extends ItemEffect

const _EmberSparkScript = preload("res://effects/ember_spark.gd")
const SPARK_VELOCITIES := [
	Vector2(-260.0, -380.0), Vector2(-150.0, -460.0), Vector2(0.0, -520.0),
	Vector2(150.0, -460.0), Vector2(260.0, -380.0),
]

var _player: CharacterBody2D = null

func _init():
	item_id = "gokten_dusus"
	item_name = tr("item.gokten_dusus.name")
	description = tr("item.gokten_dusus.description")
	flavor_text = "Düştüğü yer kıvılcım olur"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.FALL_ATTACK
	tags = ["elemental_fire"]
	affected_stats = ["fall_sparks"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("fall_attack_impacted"):
		if not player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			player.connect("fall_attack_impacted", _on_fall_attack_impacted)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("fall_attack_impacted"):
		if _player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			_player.disconnect("fall_attack_impacted", _on_fall_attack_impacted)
	_player = null

func _on_fall_attack_impacted(position: Vector2) -> void:
	apply_fall_attack_effect_at(position, false)

func apply_fall_attack_effect_at(position: Vector2, _is_decoy: bool) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	for vel in SPARK_VELOCITIES:
		var spark := Node2D.new()
		spark.set_script(_EmberSparkScript)
		tree.current_scene.add_child(spark)
		spark.setup(position + Vector2(0.0, -6.0), vel)
