# kan_tadi.gd
# UNCOMMON - Yakın dövüş vuruşu isabet ettikçe stack (max 3). Her stack: +%10 saldırı hızı, +%10 hareket hızı.

extends ItemEffect

const MAX_STACKS := 3
const BONUS_PER_STACK := 0.10  # +10%
const STACK_DURATION := 4.0  # saniye vuruş yoksa stack'ler düşer

var _player: CharacterBody2D = null
var _stacks: int = 0
var _stack_timer: float = 0.0

func _init():
	item_id = "kan_tadi"
	item_name = "Kan Tadı"
	description = "Vuruş isabet ettikçe güçlenirsin (en fazla 3 stack). Her stack: +%10 saldırı ve hareket hızı."
	flavor_text = "Kan döktükçe açılır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["attack_speed", "movement_speed"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_stacks = 0
	_stack_timer = 0.0
	_apply_stacks()
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_attack_landed):
			player.connect("player_attack_landed", _on_attack_landed)
	if player.has_signal("heavy_attack_hit"):
		if not player.is_connected("heavy_attack_hit", _on_heavy_hit):
			player.connect("heavy_attack_hit", _on_heavy_hit)
	print("[Kan Tadı] Vuruşta stack, +%10 hız (max 3)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		if _player.has_signal("player_attack_landed") and _player.is_connected("player_attack_landed", _on_attack_landed):
			_player.disconnect("player_attack_landed", _on_attack_landed)
		if _player.has_signal("heavy_attack_hit") and _player.is_connected("heavy_attack_hit", _on_heavy_hit):
			_player.disconnect("heavy_attack_hit", _on_heavy_hit)
		_stacks = 0
		_player.attack_speed_multiplier = 1.0
		_player.extra_speed_multiplier = 1.0
	_player = null

func _on_attack_landed(_attack_type: String, _damage: float, _targets: Array, _position: Vector2, effect_filter: String = "all"):
	if effect_filter == "elemental_only":
		return  # Karagöz gölgesi: sadece fiziksel; kan tadı stack uygulanmasın
	_add_stack()

func _on_heavy_hit(_enemy: Node):
	_add_stack()

func _add_stack():
	_stacks = mini(_stacks + 1, MAX_STACKS)
	_stack_timer = STACK_DURATION
	_apply_stacks()

func _apply_stacks():
	if not _player or not is_instance_valid(_player):
		return
	var bonus = _stacks * BONUS_PER_STACK
	_player.attack_speed_multiplier = 1.0 + bonus
	_player.extra_speed_multiplier = 1.0 + bonus

func process(player: CharacterBody2D, delta: float) -> void:
	if _stacks <= 0:
		return
	_stack_timer -= delta
	if _stack_timer <= 0:
		_stacks = 0
		_apply_stacks()
