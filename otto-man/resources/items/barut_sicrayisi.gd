# barut_sicrayisi.gd
# UNCOMMON - Hava zıplamasında (çift zıplama) arkanda yer çekiminden etkilenen bir bomba bırakırsın.
# Bomba düşer; zemine ya da bir düşmana değince patlar (2 sn fünye), yakındaki düşmanları havaya
# fırlatır (gerçek fırlatma, hava kombolarına köprü). Oyuncuya zarar vermez. Hareket hattının barut
# köprüsü. Olay: jump_state.gd çift zıplamada `_on_air_jump(pos)` yayar. Bomba: effects/jump_bomb.gd.

extends ItemEffect

const _JumpBombScript = preload("res://effects/jump_bomb.gd")

func _init():
	item_id = "barut_sicrayisi"
	item_name = tr("item.barut_sicrayisi.name")
	description = tr("item.barut_sicrayisi.description")
	flavor_text = "Havada fitil tutuşur"
	category = ItemCategory.JUMP
	affected_stats = ["air_jump_bomb"]

func _on_air_jump(pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var bomb := Node2D.new()
	bomb.set_script(_JumpBombScript)
	tree.current_scene.add_child(bomb)
	bomb.setup(pos + Vector2(0.0, -4.0), Vector2(0.0, 60.0))
