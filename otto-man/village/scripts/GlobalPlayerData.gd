extends Node

## Konsolda zindan altını akışını izlemek için (false yap kapat).
const DEBUG_DUNGEON_GOLD: bool = false

signal dungeon_gold_changed(new_amount: int)

# Oyuncu Verileri

var gold: int = 100 # Başlangıç altını
var asker_sayisi: int = 5 # Başlangıç asker sayısı

# İlişkiler (Örnek)
var iliskiler: Dictionary = {
	"komsu_koy": 0,
	"kraliyet": 0
}

# Envanter (Basit liste)
var envanter: Array[String] = []

# Zindan/Orman envanteri (geçici - başarıyla çıkınca global'e eklenir)
var dungeon_gold: int = 0  # Zindanda/ormanda toplanan altınlar

# Buraya zamanla başka global veriler eklenebilir
# (Teknolojiler, genel olaylar vb.)

func _ready() -> void:
	print("GlobalPlayerData Ready. Gold: ", gold)

# --- Veri Güncelleme Fonksiyonları (Gerekirse) ---

func add_gold(amount: int) -> void:
	gold += amount
	print("GlobalPlayerData: Gold updated to ", gold)
	# Belki bir UI güncelleme sinyali yayılabilir

func add_item_to_inventory(item_name: String) -> void:
	envanter.append(item_name)
	print("GlobalPlayerData: Item added to inventory: ", item_name)
	# Belki bir UI güncelleme sinyali yayılabilir

func update_relationship(target: String, change: int) -> void:
	if iliskiler.has(target):
		iliskiler[target] += change
		print("GlobalPlayerData: Relationship with %s updated to %d" % [target, iliskiler[target]])
	else:
		print("GlobalPlayerData: Unknown relationship target: ", target)

func change_asker_sayisi(change: int) -> void:
	asker_sayisi += change
	asker_sayisi = max(0, asker_sayisi) # Negatif olamaz
	print("GlobalPlayerData: Asker sayısı updated to ", asker_sayisi)

func uses_dungeon_loot_wallet() -> bool:
	var sm: Node = get_node_or_null("/root/SceneManager")
	if is_instance_valid(sm) and sm.has_method("uses_dungeon_loot_wallet"):
		return bool(sm.call("uses_dungeon_loot_wallet"))
	return false


## Tek giriş: zindan/orman/kamp/boss odasında dungeon_gold, aksi halde köy altını.
func credit_run_loot_gold(amount: int, popup_world_pos: Variant = null) -> void:
	if amount <= 0:
		return
	if uses_dungeon_loot_wallet():
		add_dungeon_gold(amount)
	else:
		add_gold(amount)
	if popup_world_pos is Vector2:
		show_gold_pickup_popup_at(popup_world_pos as Vector2, amount)
	_play_pickup_sfx(popup_world_pos)


func _play_pickup_sfx(world_pos: Variant = null) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm == null or not sm.has_method("play_sfx"):
		return
	var pos: Vector2 = world_pos if world_pos is Vector2 else Vector2.ZERO
	sm.play_sfx("pickup", pos)


func add_dungeon_gold(amount: int) -> void:
	"""Add gold to dungeon inventory (temporary, until successful exit)."""
	if amount <= 0:
		return
	dungeon_gold += amount
	if DEBUG_DUNGEON_GOLD:
		print("[DungeonGold] add_dungeon_gold(+%s) -> total=%s, emit dungeon_gold_changed" % [amount, dungeon_gold])
	# Emit signal for UI update
	if has_signal("dungeon_gold_changed"):
		dungeon_gold_changed.emit(dungeon_gold)
	# Bölüm sonu raporu için kalıcı toplam (dungeon_gold hasarla/ölümle azalabilir/sıfırlanabilir).
	var drs := get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and "gold_collected_total" in drs:
		drs.gold_collected_total += amount

func transfer_dungeon_gold_to_global() -> int:
	"""Transfer dungeon gold to global gold. Returns amount transferred."""
	var transferred = dungeon_gold
	if transferred > 0:
		gold += transferred
		dungeon_gold = 0
		print("GlobalPlayerData: Transferred %d gold from dungeon to global (total: %d)" % [transferred, gold])
		if has_signal("dungeon_gold_changed"):
			dungeon_gold_changed.emit(0)
	return transferred

func clear_dungeon_gold() -> void:
	"""Clear dungeon gold (on death)."""
	var lost = dungeon_gold
	dungeon_gold = 0
	print("GlobalPlayerData: Cleared %d dungeon gold (death penalty)" % lost)
	if has_signal("dungeon_gold_changed"):
		dungeon_gold_changed.emit(0)


## Ana menüden «Yeni oyun»: kayıttan kalan altın, envanter vb. kalmasın.
func reset_for_new_game() -> void:
	gold = 100
	asker_sayisi = 5
	iliskiler = {
		"komsu_koy": 0,
		"kraliyet": 0
	}
	envanter.clear()
	dungeon_gold = 0
	if has_signal("dungeon_gold_changed"):
		dungeon_gold_changed.emit(0)
	print("GlobalPlayerData: reset_for_new_game (defaults)")

func lose_dungeon_gold_by_fraction(fraction: float) -> int:
	"""Lose a fraction of currently carried dungeon gold. Returns lost amount."""
	fraction = clampf(fraction, 0.0, 1.0)
	if fraction <= 0.0 or dungeon_gold <= 0:
		return 0
	var loss := int(floor(float(dungeon_gold) * fraction))
	if loss <= 0:
		return 0
	dungeon_gold = max(0, dungeon_gold - loss)
	if has_signal("dungeon_gold_changed"):
		dungeon_gold_changed.emit(dungeon_gold)
	var drs := get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and "gold_lost_total" in drs:
		drs.gold_lost_total += loss
	return loss


## Dünya uzayında toplanan altın miktarını sarı yazı + beyaz kontür ile yukarı süzülüp sildirir.
func show_gold_pickup_popup_at(world_pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var tree := get_tree()
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene == null:
		return
	var holder := Node2D.new()
	holder.name = "GoldPickupPopup"
	holder.z_as_relative = false
	holder.z_index = 1200
	scene.add_child(holder)
	holder.global_position = world_pos + Vector2(0, -26)
	var lbl := Label.new()
	holder.add_child(lbl)
	lbl.text = "+%d" % amount
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font_color = Color(1.0, 0.92, 0.2, 1.0)
	ls.font_size = 22
	ls.outline_size = 5
	ls.outline_color = Color.WHITE
	lbl.label_settings = ls
	lbl.reset_size()
	lbl.position = Vector2(-lbl.size.x * 0.5, -lbl.size.y * 0.5)
	lbl.modulate.a = 1.0
	var tw: Tween = scene.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	var rise := holder.global_position + Vector2(0, -70)
	tw.tween_property(holder, "global_position", rise, 0.72)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.72)
	tw.finished.connect(holder.queue_free)
