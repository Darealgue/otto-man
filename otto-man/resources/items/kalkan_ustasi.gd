# kalkan_ustasi.gd
# COMMON item - %25 şansla normal block hiç stamina tüketmez.
# Not (2026-09-29): bu dosya önceden demir_kalkan ile BİREBİR AYNI efekti
# (block damage reduction %90) taşıyordu — iki COMMON starter item aynı şeyi
# yapıyordu, biri seçilince diğeri anlamsız kalıyordu. docs/ITEM_DATABASE_V2.txt
# bu item'ın gerçek tasarımını hep belgeliyordu (satır 19) ve tüketici taraf
# (block_state.gd:242-246, stamina_save_chance meta okuması) zaten koddaydı —
# sadece bu dosya o meta'yı hiç set etmiyordu. Şimdi belgelenen davranışa
# döndürüldü.

extends ItemEffect

const STAMINA_SAVE_CHANCE := 0.25  # %25 şansla block stamina tüketmez

func _init():
	item_id = "kalkan_ustasi"
	item_name = tr("item.kalkan_ustasi.name")
	description = tr("item.kalkan_ustasi.description")
	flavor_text = "Usta eli, boşa güç harcamaz"
	rarity = ItemRarity.COMMON
	category = ItemCategory.BLOCK
	affected_stats = ["block_stamina_save_chance"]

func activate(player: CharacterBody2D):
	super.activate(player)
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state:
		block_state.set_meta("stamina_save_chance", STAMINA_SAVE_CHANCE)
		print("[Kalkan Ustası] ✅ %25 şansla block stamina tüketmez")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	var block_state = player.get_node_or_null("StateMachine/Block")
	if block_state and block_state.has_meta("stamina_save_chance"):
		block_state.remove_meta("stamina_save_chance")
		print("[Kalkan Ustası] ❌ Kaldırıldı")
