extends Node

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

func add_dungeon_gold(amount: int) -> void:
	"""Add gold to dungeon inventory (temporary, until successful exit)."""
	dungeon_gold += amount
	print("GlobalPlayerData: Dungeon gold updated to ", dungeon_gold)
	# Emit signal for UI update
	if has_signal("dungeon_gold_changed"):
		dungeon_gold_changed.emit(dungeon_gold)

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
