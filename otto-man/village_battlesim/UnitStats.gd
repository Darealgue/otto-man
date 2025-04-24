extends Resource
class_name UnitStats

## Birimin görünen adı (UI için)
@export var display_name: String = "Birim" 
## Birimin içsel tür kimliği (mantık için)
@export var unit_type_id: String = "swordsman" 

@export_group("Temel İstatistikler")
## Maksimum Can Puanı
@export var max_hp: int = 100 
## Saldırı Gücü
@export var attack_damage: int = 10 
## Savunma Değeri (Hasar azaltma)
@export var defense: int = 2 
## Saniyedeki saldırı sayısı (örn: 1.0 = saniyede 1 saldırı)
@export var attack_speed: float = 1.5 
## Piksel/saniye cinsinden hareket hızı
@export var move_speed: float = 100.0 
## Birimin saldırabileceği maksimum piksel mesafesi
@export var attack_range: float = 40.0 
## Saldırının isabet etme şansı (0.0 ile 1.0 arası)
@export var hit_chance: float = 0.85 
## Gelen saldırıyı bloklama şansı (0.0 ile 1.0 arası)
@export var block_chance: float = 0.1 
## Menzilli mekanik mi kullanıyor?
@export var is_ranged: bool = false 

@export_group("Görsel")
## Bu birim türü için kullanılacak sprite dokusu (texture)
@export var texture: Texture2D = null 

# İleride seviye başına artışlar, özel yetenekler vb. buraya eklenebilir.

# Gerekirse başlangıç değerlerini ayarlamak veya kontroller yapmak için bir fonksiyon
func _init():
	# Başlangıçta canın 0'dan büyük olduğundan emin olalım
	if max_hp <= 0:
		max_hp = 1
	# Saldırı hızının pozitif olduğundan emin olalım
	if attack_speed <= 0:
		attack_speed = 0.1
