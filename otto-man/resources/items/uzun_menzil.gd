# RARE - Light attack yapıldığında ileri doğru projectile fırlatır (ilk düşmana hasar)
extends ItemEffect

const ANGLED_FORWARD := 18.0       # Açılı atışta oyuncunun önünden başlama mesafesi
const ANGLED_BASE_HEIGHT := 33.0   # Yatay atışla aynı yükseklik (ok_yagmuru SPAWN_HEIGHT)
const ANGLED_HEIGHT_SHIFT := 14.0  # direction.y (±0.71) ile çarpılır: yukarı ~10 px yukarı, aşağı ~10 px aşağı

var _player: CharacterBody2D = null

func _init():
	item_id = "uzun_menzil"
	item_name = tr("item.uzun_menzil.name")
	description = tr("item.uzun_menzil.description")
	flavor_text = "Uzaktan da vurur"
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_ranged"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

func _on_player_light_attack_performed(direction: Vector2, position: Vector2, damage: float) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tree = _player.get_tree()
	if not tree or not tree.current_scene:
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	# Spawn: gelen position zaten oyuncuya yakın; hafif ek offset ile çıkış
	# Top güllesiyle aynı yükseklik (ok_yagmuru SPAWN_HEIGHT = 33 px); gelen position hitbox merkezinden (-22.5) hesaplanıyor
	var spawn_pos := position + direction * 10.0 + Vector2(0.0, -10.5)
	if absf(direction.y) > 0.1:
		# Açılı (yukarı/aşağı) atışta gelen position, eğik hitbox'ın oyuncuya bakan yüzünden hesaplanıyor ve
		# dönme yüzünden ters çıkıyordu (aşağı atış yukarıdan, yukarı atış aşağıdan doğuyordu). Burada doğrudan
		# oyuncuya göre kuruyoruz: yukarı atış yatay çıkışın üstünden, aşağı atış altından başlar.
		spawn_pos = _player.global_position + Vector2(signf(direction.x) * ANGLED_FORWARD, -ANGLED_BASE_HEIGHT + direction.y * ANGLED_HEIGHT_SHIFT)
	im.spawn_upgraded_projectile(tree.current_scene, spawn_pos, direction, damage * 0.7, -1.0, "ok", false, true)  # Çift Vuruş artık ikinci savuruşla geliyor (volley yok)
