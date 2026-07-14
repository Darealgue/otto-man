# RARE - Hafif saldırı tuşunu basılı tutup bırakınca, tutma süresine göre menzil/hasarı artan
# tek bir mermi fırlatır (max 0.6s şarj). attack_state.gd'nin combo mantığına dokunmaz — Input'u
# doğrudan process() içinde izler, normal vuruşlar etkilenmeden yanında ek bir "şarjlı atış" sunar.
extends ItemEffect

const MIN_CHARGE_TIME := 0.15
const MAX_CHARGE_TIME := 0.6
const MAX_RANGE := 500.0
const MAX_DAMAGE_MULT := 2.0  # Tam şarjda temel hasarın 2 katı

var _player: CharacterBody2D = null
var _charging := false
var _charge_time := 0.0

func _init():
	item_id = "gerilmis_yay"
	item_name = "Gerilmiş Yay"
	description = "Hafif saldırıyı basılı tutup bırakırsan, şarj oranlı güçlü bir mermi fırlatırsın"
	flavor_text = "Sabreden ok, daha derin saplanır"
	rarity = ItemRarity.RARE
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["charged_shot"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_charging = false
	_charge_time = 0.0
	print("[Gerilmiş Yay] ✅ Hafif saldırıyı tutup bırakınca şarjlı mermi")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Gerilmiş Yay] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	if Input.is_action_pressed("attack"):
		_charging = true
		_charge_time = min(_charge_time + delta, MAX_CHARGE_TIME)
		return
	if _charging:
		_charging = false
		_fire_charged_shot(player, _charge_time)
	_charge_time = 0.0

func _fire_charged_shot(player: CharacterBody2D, charge_time: float) -> void:
	if charge_time < MIN_CHARGE_TIME:
		return
	var tree = player.get_tree()
	if not tree or not tree.current_scene:
		return
	var ratio: float = charge_time / MAX_CHARGE_TIME
	var direction := Vector2(player.facing_direction, 0.0)
	var base_damage: float = get_stat_value("base_damage")
	if base_damage <= 0.0:
		base_damage = 10.0
	var damage: float = base_damage * (1.0 + (MAX_DAMAGE_MULT - 1.0) * ratio)
	var proj = Node2D.new()
	proj.set_script(load("res://effects/light_attack_projectile.gd"))
	tree.current_scene.add_child(proj)
	var spawn_pos: Vector2 = player.global_position + Vector2(direction.x * 20.0, -22.0)
	proj.setup(spawn_pos, direction, damage)
	proj.max_distance = MAX_RANGE * max(0.2, ratio)
	_apply_projectile_upgrades(proj)

## Yansıyan Ok / Rüzgârın Nişanı / Yankı Oku / Kartal Bakışı bu mermiyi de yükseltir.
func _apply_projectile_upgrades(proj: Node) -> void:
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	if im.has_active_item("yansiyan_ok"):
		proj.bounce_remaining = 1
	if im.has_active_item("ruzgarin_nisani"):
		var RuzgarinNisani = load("res://resources/items/ruzgarin_nisani.gd")
		proj.element = RuzgarinNisani.detect_active_element(im)
	if im.has_active_item("yanki_oku"):
		proj.echo = true
	if im.has_active_item("kartal_bakisi"):
		proj.unlimited_range = true
