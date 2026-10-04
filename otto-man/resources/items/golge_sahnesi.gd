# golge_sahnesi.gd
# UNCOMMON - Perfect parry yaptığında olduğun yerde 3 sn duran bir gölge kalır (2 sn bekleme).
# Gölge diğer gölge item'larıyla aynı sistemi kullanır (Gölge Bağı, Sönen Gölge, Karagöz/Hacivat).

extends ItemEffect

const DecoyScene = preload("res://effects/player_decoy.tscn")
const DECOY_LIFETIME := 3.0
const COOLDOWN := 2.0

var _player: CharacterBody2D = null
var _cooldown_left: float = 0.0

func _init():
	item_id = "golge_sahnesi"
	item_name = tr("item.golge_sahnesi.name")
	description = tr("item.golge_sahnesi.description")
	flavor_text = "Perde açılır, gölge sahneye çıkar"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.PARRY
	affected_stats = ["parry_decoy"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_cooldown_left = 0.0
	print("[Gölge Sahnesi] ✅ Perfect parry gölge bırakır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Gölge Sahnesi] ❌ Kaldırıldı")

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta

# ItemManager perfect_parry sinyaline otomatik bağlar
func _on_perfect_parry() -> void:
	if _cooldown_left > 0.0 or not is_instance_valid(_player):
		return
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	_cooldown_left = COOLDOWN
	var decoy = DecoyScene.instantiate()
	decoy.lifetime_override = DECOY_LIFETIME
	tree.current_scene.add_child(decoy)
	var flip: bool = _player.sprite.flip_h if _player.get("sprite") else false
	decoy.setup(_player.global_position, flip, _player)
