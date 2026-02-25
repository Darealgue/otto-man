# topuk_kirici.gd
# UNCOMMON - Crouch veya slide'dan çıktıktan hemen sonra yapılan ilk vuruş ekstra hasar verir.

extends ItemEffect

# Bonus, crouch_state ve slide_state exit() içinde player.topuk_kirici_next_hit_bonus = 1.5 atanıyor.
# Attack ve HeavyAttack state'leri bu çarpanı uygulayıp sıfırlıyor.

func _init():
	item_id = "topuk_kirici"
	item_name = "Topuk Kırıcı"
	description = "Çömelmeden veya kaymadan çıktıktan hemen sonra yaptığın ilk vuruş ekstra hasar verir."
	flavor_text = "Ayağa kalkarken vur"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SLIDE
	affected_stats = ["post_crouch_slide_bonus"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Topuk Kırıcı] Crouch/slide sonrası ilk vuruş +%50")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if player and is_instance_valid(player):
		player.topuk_kirici_next_hit_bonus = 1.0
