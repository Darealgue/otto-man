# barut_dolgusu.gd
# RARE - Kısa sürede art arda öldürdükçe tüm barut patlamalarının alanı ve hasarı büyür: öldürme başına
# +%15, en fazla 5 katman (+%75); son öldürmeden 4 sn sonra sıfırlanır. Çarpan ExplosionModifiers
# üzerinden her patlama efektine uygulanır (ItemManager.get_explosion_chain_mult -> get_explosion_mult).

extends ItemEffect

const BONUS_PER_STACK := 0.15
const MAX_STACKS := 5
const WINDOW := 4.0

var _stacks: int = 0
var _timer: float = 0.0

func _init():
	item_id = "barut_dolgusu"
	item_name = tr("item.barut_dolgusu.name")
	description = tr("item.barut_dolgusu.description")
	flavor_text = "Her ölüm bir tutam barut"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["explosion_chain"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_stacks = 0
	_timer = 0.0

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_stacks = 0
	_timer = 0.0

func on_enemy_killed(_enemy: Node2D) -> void:
	_stacks = mini(_stacks + 1, MAX_STACKS)
	_timer = WINDOW

func process(_player_node: CharacterBody2D, delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_stacks = 0

func get_explosion_mult() -> float:
	return 1.0 + float(_stacks) * BONUS_PER_STACK
