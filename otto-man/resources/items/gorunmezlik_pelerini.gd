# gorunmezlik_pelerini.gd
# RARE - Dodge/dash sonrası kısa süre yarı saydam; düşmanlar aggro bırakır.
# Yarı saydamken ilk saldırı 3x hasar.

extends ItemEffect

const INVIS_DURATION := 3.0
const INVIS_ALPHA := 0.5
const FIRST_ATTACK_MULT := 3.0  # Görünmezken ilk vuruş 3x

var _player: CharacterBody2D = null
var _invis_timer := 0.0
var _saved_modulate: Color = Color(1, 1, 1, 1)
var _first_attack_ready := false

func _init():
	item_id = "gorunmezlik_pelerini"
	item_name = "Görünmezlik Pelerini"
	description = "Dodge veya dash atıldığında 3 saniye yarı saydam olursun; düşmanlar seni zor görür ve aggro bırakır."
	flavor_text = "Gölgeler arasında"
	rarity = ItemRarity.RARE
	category = ItemCategory.DODGE
	affected_stats = ["dodge_invis"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("dodge_started"):
		if not player.is_connected("dodge_started", _on_dodge_started):
			player.connect("dodge_started", _on_dodge_started)
	if player.has_signal("dash_started"):
		if not player.is_connected("dash_started", _on_dash_started):
			player.connect("dash_started", _on_dash_started)
	print("[Görünmezlik Pelerini] Dodge/dash başında 3 sn yarı saydamlık")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_end_invisibility()
	if _player:
		if _player.has_signal("dodge_started") and _player.is_connected("dodge_started", _on_dodge_started):
			_player.disconnect("dodge_started", _on_dodge_started)
		if _player.has_signal("dash_started") and _player.is_connected("dash_started", _on_dash_started):
			_player.disconnect("dash_started", _on_dash_started)
		_player = null
	_invis_timer = 0.0

func _on_dodge_started():
	_start_invisibility()

func _on_dash_started():
	_start_invisibility()

func _start_invisibility():
	if not _player or not is_instance_valid(_player):
		return
	_saved_modulate = _player.modulate
	var c := _saved_modulate
	_player.modulate = Color(c.r, c.g, c.b, c.a * INVIS_ALPHA)
	_player.remove_from_group("player")
	_invis_timer = INVIS_DURATION
	_first_attack_ready = true
	_player.gorunmezlik_first_attack_mult = FIRST_ATTACK_MULT

func _end_invisibility():
	if not _player or not is_instance_valid(_player):
		return
	_player.modulate = _saved_modulate
	_player.gorunmezlik_first_attack_mult = 1.0
	if not _player.is_in_group("player"):
		_player.add_to_group("player")
	_invis_timer = 0.0
	_first_attack_ready = false

func process(player: CharacterBody2D, delta: float) -> void:
	if _invis_timer <= 0:
		return
	_invis_timer -= delta
	if _invis_timer <= 0:
		_end_invisibility()
