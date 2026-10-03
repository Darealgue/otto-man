# artan_guc.gd
# UNCOMMON - Art arda inen light attack'lar birbirini güçlendirir: her ardışık
# vuruş bir öncekinden %10 güçlü (5. vuruşta +%40 tavan), art arda gelmezse
# (1.2sn) ya da saldırı dışında hasar alırsan sıfırlanır.

extends ItemEffect

const STREAK_TIMEOUT := 1.2
const DAMAGE_PER_STREAK := 0.10
const MAX_STREAK := 5

var _player: CharacterBody2D = null
var _hitbox: Node = null
var _streak := 0
var _streak_timer := 0.0

func _init():
	item_id = "artan_guc"
	item_name = tr("item.artan_guc.name")
	description = tr("item.artan_guc.description")
	flavor_text = "Her vuruş bir öncekini besler"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_streak"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_streak = 0
	_streak_timer = 0.0
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox:
		_hitbox = hitbox
		_hitbox.light_streak_damage_multiplier = 1.0
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
	print("[Artan Güç] ✅ Ardışık light attack'lar birbirini güçlendiriyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.light_streak_damage_multiplier = 1.0
	_hitbox = null
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Artan Güç] ❌ Kaldırıldı")

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if _streak_timer > 0.0:
		_streak_timer -= delta
		if _streak_timer <= 0.0:
			_streak = 0
			if _hitbox and is_instance_valid(_hitbox):
				_hitbox.light_streak_damage_multiplier = 1.0

## Kesintisiz Zincir aktifse streak penceresi uzar (bkz. kesintisiz_zincir.gd).
func _get_streak_timeout() -> float:
	var im = get_node_or_null("/root/ItemManager")
	if im and im.has_active_item("kesintisiz_zincir"):
		return STREAK_TIMEOUT * 2.0
	return STREAK_TIMEOUT

func _on_player_attack_landed(attack_type: String, _damage: float, _targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	# "ranged": Uzun Menzil'in dönüştürdüğü mermi isabetleri de zinciri besler. Çarpan her
	# swing başında enable_combo()'da hitbox.damage'e işlendiği ve mermi hasarı oradan
	# türediği için ranged'de de uygulanıyor.
	if effect_filter == "physical_only" or (attack_type != "normal" and attack_type != "ranged"):
		return
	_streak = mini(_streak + 1, MAX_STREAK)
	_streak_timer = _get_streak_timeout()
	# Bu vuruşun kendisi zaten indi; çarpanı SIRADAKİ vuruş için güncelliyoruz
	# (player_hitbox.gd enable_combo() bir sonraki swing başında okuyacak).
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.light_streak_damage_multiplier = 1.0 + float(_streak) * DAMAGE_PER_STREAK
