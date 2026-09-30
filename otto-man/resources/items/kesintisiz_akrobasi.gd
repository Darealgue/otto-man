# kesintisiz_akrobasi.gd
# RARE - Kenar tutunmadan (ledge grab) çıkarken (tırmanarak ya da bırakarak)
# çift zıplama hakkı otomatik yenilenir. Davranış ledge_grab_state.gd'nin
# _apply_kesintisiz_akrobasi()'sinde ItemManager.has_active_item() ile
# kontrol edilir — bu item pasif bir işarettir.

extends ItemEffect

func _init():
	item_id = "kesintisiz_akrobasi"
	item_name = tr("item.kesintisiz_akrobasi.name")
	description = tr("item.kesintisiz_akrobasi.description")
	flavor_text = "Kenar bırakmaz, sadece bir sonraki tutamağa taşır"
	rarity = ItemRarity.RARE
	category = ItemCategory.JUMP
	affected_stats = ["ledge_exit_double_jump"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Kesintisiz Akrobasi] ✅ Kenardan çıkış çift zıplamayı yeniliyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Kesintisiz Akrobasi] ❌ Kaldırıldı")
