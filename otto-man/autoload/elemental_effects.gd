# elemental_effects.gd
# Merkezi elemental efekt sistemi.
#
# Yeni element eklemek için:
# 1. _register_defaults() içine: register("yeni_element", _apply_yeni_element)
# 2. _apply_yeni_element(enemy, params) fonksiyonunu yaz
# 3. Hacivat/hacivat_golgesi.gd'de _get_elemental_type() içine item kontrolü ekle (element döndürmek için)
#
# Decoy, projectile, player hitbox vb. tüm sistemler apply_to_enemy() çağırır.

extends Node

## Element adı -> (enemy, params) -> void
var _handlers: Dictionary = {}

func _ready() -> void:
	_register_defaults()

func _register_defaults() -> void:
	register("poison", _apply_poison)
	register("fire", _apply_fire)
	register("frost", _apply_frost)
	register("lightning", _apply_lightning)
	# Yeni elementler buraya eklenir:
	# register("explosion", _apply_explosion)

## Yeni element kaydet. Item'lar veya modlar kendi efektlerini ekleyebilir.
func register(element: String, handler: Callable) -> void:
	_handlers[element] = handler

## Düşmana elemental efekt uygula. element boşsa hiçbir şey yapmaz.
func apply_to_enemy(enemy: Node, element: String, params: Dictionary = {}) -> void:
	if not element or element.is_empty():
		return
	if not is_instance_valid(enemy):
		return
	if _handlers.has(element):
		_handlers[element].call(enemy, params)

func _apply_poison(enemy: Node, params: Dictionary) -> void:
	if enemy.has_method("add_poison_stack"):
		enemy.add_poison_stack(
			params.get("max_stacks", 3),
			params.get("damage_per_stack", 1.0),
			params.get("tick_interval", 1.5)
		)

func _apply_fire(enemy: Node, params: Dictionary) -> void:
	if enemy.has_method("add_burn_stack"):
		enemy.add_burn_stack()

func _apply_frost(enemy: Node, params: Dictionary) -> void:
	if enemy.has_method("add_frost_stack"):
		enemy.add_frost_stack(params.get("amount", 1))

func _apply_lightning(enemy: Node, params: Dictionary) -> void:
	# Şimşek: yavaşlatma (frost) veya özel lightning efekti
	if enemy.has_method("add_frost_stack"):
		enemy.add_frost_stack(1)
