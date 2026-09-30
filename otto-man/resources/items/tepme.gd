# tepme.gd
# UNCOMMON - Havadayken yapılan heavy attack seni ters yöne fırlatır (patlama tepmesi).
# Heavy artık bir mobility aracı: hava dövüşünde yön değiştirme / kaçış.
# Eksi: her tepme %3 max can. Barut Zırhı bu bedeli iptal eder — o item
# sadece savunma değil, dikey bir build kilidi oluyor.

extends ItemEffect

const KICK_HORIZONTAL := 420.0
const KICK_VERTICAL := -260.0
const HEALTH_COST_RATIO := 0.03

var _player: CharacterBody2D = null

func _init():
	item_id = "tepme"
	item_name = tr("item.tepme.name")
	description = tr("item.tepme.description")
	flavor_text = "Her atışın bir de geri tepmesi vardır"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["air_heavy_recoil"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Tepme] ✅ Havada heavy → ters yöne fırlatır (%3 max can)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Tepme] ❌ Kaldırıldı")

func _on_heavy_attack_impact(attack_name: String) -> void:
	if not is_instance_valid(_player) or attack_name != "air_heavy":
		return
	var facing: float = _player.get_facing_direction() if _player.has_method("get_facing_direction") else 1.0
	if facing == 0.0:
		facing = 1.0
	_player.velocity = Vector2(-facing * KICK_HORIZONTAL, KICK_VERTICAL)

	# Bedel: Barut Zırhı patlama hasarına bağışıklık verdiği için tepmeyi de karşılar
	if ExplosionModifiers.player_immune_to_explosions():
		return
	var stats = get_node_or_null("/root/PlayerStats")
	if stats and stats.has_method("get_max_health") and stats.has_method("get_current_health") and stats.has_method("set_current_health"):
		var cost: float = maxf(1.0, float(stats.get_max_health()) * HEALTH_COST_RATIO)
		stats.set_current_health(float(stats.get_current_health()) - cost, false)
