# Cariye Görsel Sistem Yol Haritası

Bu dokümantasyon, worker sistemindeki karakter yaratma mekanizmasını referans alarak cariyeler için görsel sistem oluşturma sürecini açıklar.

## 📋 Genel Bakış

**Hedef:** Cariyeler için worker'lardaki gibi rastgele görünüm oluşturma sistemi. Her cariye saç, kıyafet ve aksesuar kombinasyonlarından oluşan benzersiz bir görünüme sahip olacak.

## 🎯 Adım Adım Yol Haritası

### **AŞAMA 1: Asset Havuzlarının Hazırlanması**

#### 1.1. Asset Klasör Yapısı
```
res://assets/character_parts/concubine/
├── body/          # Kadın vücut modelleri
├── hair/          # Saç stilleri (kadın karakterler için)
├── clothing/      # Üst kıyafetler (kadın karakterler için)
├── pants/         # Alt kıyafetler (kadın karakterler için)
├── eyes/          # Göz stilleri
├── mouth/         # Ağız stilleri
└── accessories/   # Aksesuarlar (takı, başlık, vb.)
```

#### 1.2. Normal Map Klasörü
```
res://assets/character_parts/character_parts_normals/
└── (concubine asset'leri için normal map'ler)
```

**Not:** Worker sisteminde olduğu gibi, her diffuse texture için `_normal.png` uzantılı normal map dosyası gerekli.

---

### **AŞAMA 2: AppearanceDB'ye Cariye Fonksiyonları Ekleme**

#### 2.1. AppearanceDB.gd'ye Eklemeler

**Yapılacaklar:**
- Cariye asset havuzları tanımla (CONCUBINE_BODY_TEXTURES, CONCUBINE_HAIR_TEXTURES, vb.)
- Cariye renk paletleri tanımla (kadın karakterler için uygun renkler)
- `generate_random_concubine_appearance()` fonksiyonu ekle
- Aksesuar desteği ekle (opsiyonel ama önerilen)

**Örnek Yapı:**
```gdscript
# AppearanceDB.gd içine eklenecek
const CONCUBINE_BODY_TEXTURES = [
    "res://assets/character_parts/concubine/body/body_female_walk_gray.png"
]

const CONCUBINE_HAIR_TEXTURES = [
    "res://assets/character_parts/concubine/hair/hair_long_walk_gray.png",
    "res://assets/character_parts/concubine/hair/hair_short_walk_gray.png",
    "res://assets/character_parts/concubine/hair/hair_braided_walk_gray.png"
]

const CONCUBINE_CLOTHING_TEXTURES = [
    "res://assets/character_parts/concubine/clothing/dress_walk_gray.png",
    "res://assets/character_parts/concubine/clothing/tunic_walk_gray.png"
]

const CONCUBINE_ACCESSORY_TEXTURES = [
    "res://assets/character_parts/concubine/accessories/necklace_walk_gray.png",
    "res://assets/character_parts/concubine/accessories/earrings_walk_gray.png"
]

func generate_random_concubine_appearance() -> VillagerAppearance:
    # Worker sistemindeki gibi ama cariye asset'leri kullanarak
```

---

### **AŞAMA 3: Concubine Sınıfına Appearance Ekleme**

#### 3.1. Concubine.gd Güncellemeleri

**Yapılacaklar:**
- `VillagerAppearance` resource referansı ekle
- `@export var appearance: VillagerAppearance` property'si ekle
- Kayıt/yükleme sisteminde appearance'ı dahil et

**Kod Değişiklikleri:**
```gdscript
# Concubine.gd başına eklenecek
const VillagerAppearance = preload("res://village/scripts/VillagerAppearance.gd")

# Sınıf içine eklenecek
@export var appearance: VillagerAppearance = null
```

---

### **AŞAMA 4: Cariye Oluşturma Noktalarını Güncelleme**

#### 4.1. MissionManager.gd - create_initial_concubines()

**Yapılacaklar:**
- Her cariye oluşturulurken `AppearanceDB.generate_random_concubine_appearance()` çağrısı ekle
- Oluşturulan appearance'ı cariye'ye ata

**Örnek:**
```gdscript
func create_initial_concubines():
    var cariye1 = Concubine.new()
    cariye1.id = next_concubine_id
    next_concubine_id += 1
    cariye1.name = "Ayla"
    # ... diğer özellikler ...
    
    # YENİ: Görünüm ata
    cariye1.appearance = AppearanceDB.generate_random_concubine_appearance()
    
    concubines[cariye1.id] = cariye1
```

#### 4.2. Dungeon'dan Cariye Kurtarma Noktası

**Yapılacaklar:**
- Dungeon'dan cariye kurtarıldığında görünüm oluştur ve ata
- İlgili fonksiyonu bul ve güncelle

**Not:** Dungeon'dan cariye kurtarma mekanizması henüz tam olarak görünmüyor, bu nokta ileride eklenecek.

---

### **AŞAMA 5: UI'da Cariye Görsellerini Gösterme**

#### 5.1. MissionCenter.gd - UI Güncellemeleri

**Yapılacaklar:**
- `create_concubine_list_card()` fonksiyonuna portrait/sprite ekle
- `_update_concubine_list_dynamic()` fonksiyonuna görsel gösterimi ekle
- Cariye detay sayfasına büyük portrait ekle

**İki Yaklaşım:**

**Yaklaşım A: Sprite2D ile Gerçek Zamanlı Render**
- Her cariye için küçük bir Sprite2D node'u oluştur
- Worker sistemindeki gibi sprite'ları birleştir
- UI'da göster

**Yaklaşım B: Portrait Texture (Önerilen)**
- Cariye oluşturulurken görünümü bir texture'a render et
- Texture'ı kaydet ve UI'da göster
- Daha performanslı ama daha karmaşık

**Önerilen: Yaklaşım B (başlangıç için basit texture, ileride render)**

#### 5.2. UI Node Yapısı

**create_concubine_list_card() güncellemesi:**
```gdscript
func create_concubine_list_card(cariye: Concubine, is_selected: bool) -> Panel:
    var card = Panel.new()
    # ... mevcut kod ...
    
    # YENİ: Portrait ekle
    var portrait = TextureRect.new()
    if cariye.appearance:
        # Görünümü texture'a çevir ve göster
        portrait.texture = _render_concubine_portrait(cariye.appearance)
    vbox.add_child(portrait)
    
    # ... diğer label'lar ...
```

---

### **AŞAMA 6: Görsel Render Sistemi (Opsiyonel ama Önerilen)**

#### 6.1. Portrait Render Fonksiyonu

**Yapılacaklar:**
- `VillagerAppearance`'dan portrait texture oluşturan fonksiyon
- Worker sistemindeki sprite birleştirme mantığını kullan
- UI için optimize edilmiş boyut (örn: 64x64 veya 128x128)

**Örnek Yapı:**
```gdscript
# MissionCenter.gd veya yeni bir ConcubinePortraitRenderer.gd
func _render_concubine_portrait(appearance: VillagerAppearance) -> Texture2D:
    # Worker.gd'deki update_visuals() mantığını kullanarak
    # sprite'ları birleştir ve texture'a çevir
    # Viewport kullanarak render et
```

---

### **AŞAMA 7: Kayıt/Yükleme Sistemi Güncellemesi**

#### 7.1. MissionManager.gd - Save/Load

**Yapılacaklar:**
- Cariye kaydedilirken appearance'ı da kaydet
- Yüklenirken appearance'ı geri yükle
- Eski kayıtlarla uyumluluk (appearance yoksa rastgele oluştur)

**Kod Yapısı:**
```gdscript
# Kayıt sırasında
func _save_concubines() -> void:
    var data = {}
    for id in concubines.keys():
        var c = concubines[id]
        data[id] = {
            "name": c.name,
            "level": c.level,
            # ... diğer özellikler ...
            "appearance": c.appearance  # YENİ
        }
    # ... kaydet ...
```

---

## 📝 Detaylı Görev Listesi

### ✅ Öncelik 1: Temel Altyapı
- [ ] **1.1** Asset klasör yapısını oluştur
- [ ] **1.2** Cariye asset'lerini hazırla (en az 2-3 seçenek her kategori için)
- [ ] **1.3** Normal map'leri hazırla
- [ ] **1.4** AppearanceDB.gd'ye CONCUBINE_* constant'larını ekle
- [ ] **1.5** `generate_random_concubine_appearance()` fonksiyonunu yaz

### ✅ Öncelik 2: Concubine Sınıfı Entegrasyonu
- [ ] **2.1** Concubine.gd'ye appearance property'si ekle
- [ ] **2.2** MissionManager.create_initial_concubines()'i güncelle
- [ ] **2.3** Yeni cariye oluşturma noktalarını bul ve güncelle

### ✅ Öncelik 3: UI Entegrasyonu
- [ ] **3.1** MissionCenter.gd'de portrait gösterimi ekle
- [ ] **3.2** Cariye listesi kartlarına görsel ekle
- [ ] **3.3** Cariye detay sayfasına büyük portrait ekle
- [ ] **3.4** Görsel render fonksiyonunu yaz (basit texture veya sprite birleştirme)

### ✅ Öncelik 4: Kayıt/Yükleme
- [ ] **4.1** Save sistemine appearance ekle
- [ ] **4.2** Load sistemine appearance ekle
- [ ] **4.3** Eski kayıt uyumluluğunu test et

### ✅ Öncelik 5: Test ve İyileştirme
- [ ] **5.1** Farklı görünümlerin oluşturulduğunu test et
- [ ] **5.2** UI'da görsellerin doğru gösterildiğini test et
- [ ] **5.3** Performans optimizasyonu (gerekirse)

---

## 🔧 Teknik Detaylar

### Worker Sistemi Referansı

**Worker.gd'deki Önemli Noktalar:**
- `appearance: VillagerAppearance` property'si
- `update_visuals()` fonksiyonu sprite'ları birleştirir
- `VillagerAppearance` resource'u tüm görsel bilgileri tutar

**AppearanceDB.gd'deki Önemli Noktalar:**
- `generate_random_appearance()` fonksiyonu
- Asset path'leri constant olarak tanımlı
- `derive_normal_path()` helper fonksiyonu

### Cariye Sistemi Farkları

**Worker'dan Farklı Olanlar:**
- Cariyeler kadın karakterler (farklı asset'ler)
- Aksesuar desteği eklenebilir
- UI'da gösterim (sahne içinde değil)

**Benzer Olanlar:**
- Aynı `VillagerAppearance` resource kullanılabilir
- Aynı render mantığı kullanılabilir
- Aynı asset yapısı (diffuse + normal)

---

## 📌 Notlar ve Öneriler

1. **Asset Hazırlığı:** İlk aşamada en az 2-3 seçenek her kategori için yeterli. İleride genişletilebilir.

2. **Performans:** UI'da çok sayıda cariye varsa, portrait'leri önceden render edip cache'lemek iyi olur.

3. **Genişletilebilirlik:** Aksesuar sistemi başlangıçta opsiyonel ama eklenmesi önerilir.

4. **Test:** Her aşamada test edilmesi önerilir. Özellikle asset path'leri ve normal map'ler kritik.

5. **Worker Sistemi:** Worker sistemindeki kodları referans alarak benzer yapı kurulabilir.

---

## 🎨 Asset Gereksinimleri

### Minimum Asset Listesi (Başlangıç İçin)

**Body:**
- 1 kadın vücut modeli

**Hair:**
- 2-3 saç stili

**Clothing:**
- 2-3 üst kıyafet

**Pants:**
- 2-3 alt kıyafet

**Eyes:**
- 2-3 göz stili (worker'dan kullanılabilir)

**Mouth:**
- 2-3 ağız stili (worker'dan kullanılabilir)

**Accessories (Opsiyonel):**
- 1-2 aksesuar türü

**Toplam:** Her asset için diffuse texture + normal map gerekli.

---

## 🚀 Başlangıç Noktası

**İlk Adım:** AppearanceDB.gd'yi aç ve cariye asset havuzlarını ekle. Worker sistemindeki yapıyı kopyala ve cariye versiyonunu oluştur.

**İkinci Adım:** Concubine.gd'ye appearance property'si ekle ve MissionManager'da cariye oluştururken görünüm ata.

**Üçüncü Adım:** UI'da görselleri göster (başlangıçta basit texture, ileride render sistemi).

---

Bu yol haritası, worker sistemindeki karakter yaratma mekanizmasını referans alarak cariyeler için görsel sistem oluşturma sürecini adım adım açıklar. Her aşama bağımsız olarak test edilebilir ve genişletilebilir.
