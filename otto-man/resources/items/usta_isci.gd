# usta_isci.gd
# LEGENDARY - Jeneralisti ödüllendirir. Kaç FARKLI boru hattına (Temas
# Saldırısı+Mermi, Kaçınma, Savunma, Havaya Fırlatma, Hareket/Parkur) item
# eklediğine göre periyodik olarak kesirli stamina iade eder: 3-4 hat küçük,
# 5 hat (hepsi) büyük bir puls. ItemManager.count_active_pipelines() ile
# hesaplanır (bkz. docs/ITEM_PIPELINE_DESIGN.md §7).

extends ItemEffect

const PULSE_INTERVAL := 4.0
const MIN_PIPELINES := 3
const PULSE_SMALL := 0.1   # 3-4 farklı hat
const PULSE_LARGE := 0.22  # 5 hat (hepsi)

var _tick_timer := 0.0

func _init():
	item_id = "usta_isci"
	item_name = tr("item.usta_isci.name")
	description = tr("item.usta_isci.description")
	flavor_text = "Her aleti kullanan, hiçbirine muhtaç kalmaz"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.SYNERGY
	affected_stats = ["pipeline_diversity_bonus"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_tick_timer = 0.0
	print("[Usta İşçi] ✅ Farklı boru hatlarına yayılmak periyodik stamina iade ediyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Usta İşçi] ❌ Kaldırıldı")

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	_tick_timer += delta
	if _tick_timer < PULSE_INTERVAL:
		return
	_tick_timer = 0.0
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	var pipeline_count: int = im.count_active_pipelines()
	if pipeline_count < MIN_PIPELINES:
		return
	var amount := PULSE_LARGE if pipeline_count >= 5 else PULSE_SMALL
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar") if get_tree() else null
	if stamina_bar and stamina_bar.has_method("restore_partial_charge"):
		stamina_bar.restore_partial_charge(amount)
