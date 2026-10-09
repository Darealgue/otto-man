# zehirli_yem.gd
# UNCOMMON - Hasar alınca zehir bulutu çıkar. Bir düşman gölgene vurursa da, sana vurulmuş gibi
# gölgenin yerinde aynı bulut çıkar. Her ikisi 1.5 sn'lik ortak bekleme süresini paylaşır.

extends ItemEffect

const COOLDOWN := 1.5

var _player: CharacterBody2D = null
var _cooldown_left: float = 0.0

func _init():
	item_id = "zehirli_yem"
	item_name = tr("item.zehirli_yem.name")
	description = tr("item.zehirli_yem.description")
	flavor_text = "Yem yutuldu"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["hit_poison_cloud"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_cooldown_left = 0.0

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

func process(_player_node: CharacterBody2D, delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

## Oyuncu hasar aldı (ItemManager `player_took_damage`'a otomatik bağlar).
func _on_player_took_damage(_amount: float, _attacker: Node2D) -> void:
	if not is_instance_valid(_player):
		return
	_spawn_cloud(_player.global_position)

## Bir düşman gölgeye vurdu (player_decoy.gd -> ItemManager.notify_item_event).
func _on_decoy_hit_by_enemy(decoy_pos: Vector2, _enemy_hitbox: Node) -> void:
	_spawn_cloud(decoy_pos)

func _spawn_cloud(position: Vector2) -> void:
	if _cooldown_left > 0.0:
		return
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	_cooldown_left = COOLDOWN
	var cloud := Node2D.new()
	cloud.set_script(preload("res://effects/poison_cloud.gd"))
	tree.current_scene.add_child(cloud)
	cloud.global_position = position
