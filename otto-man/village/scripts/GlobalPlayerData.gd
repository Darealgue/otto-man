extends Node

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
