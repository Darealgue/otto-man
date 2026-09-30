# Item Sinerji Sistemi - Tasarım Dokümanı

> **2026-09-30 güncellemesi: güncel yön artık `docs/ITEM_PIPELINE_DESIGN.md`.**
> Bu dosyadaki §10-11 (tag sistemi, aile eşikleri, kaynak/sayaç modeli) tarihsel
> kayıt olarak duruyor ve o katman (element registry, tag alanı) hâlâ kodda
> yaşıyor — ama kullanıcı geri bildirimiyle "kaynak biriktir/oku" formülünün
> yeterince sinerjik hissettirmediği netleşti. Yeni yön "Boru Hattı Kompozisyonu":
> item'lar bir sayaç okumak yerine ortak bir eylemin (mermi/dodge/saldırı/parry/
> juggle/parkur) ADIMLARINI değiştiriyor. Yeni item tasarımı için önce
> `ITEM_PIPELINE_DESIGN.md`'ye bak.

## Felsefe
Sinerjiler, item'ların birbirini **tanımadan** birbirini **güçlendirmesini** sağlar. Oyuncu "bu ikisi birlikte çok güçlü!" hissini yaşar.

---

## 1. ELEMENT / ETKİ TİPLERİ (Tag Sistemi)

Item'ların yarattığı efektler kategorize edilir. Sinerji sistemi bu tag'lere bakar:

| Tag | Açıklama | Örnek Item'lar |
|-----|----------|----------------|
| `elemental_poison` | Zehir, DoT | Zehirli Hançer, Zehir Bulutu |
| `elemental_fire` | Ateş, yanma | Ateşli Kılıç, Alev Halesi |
| `elemental_ice` | Buz, donma | Donma Dokunuşu, Dondurucu Nefes |
| `elemental_lightning` | Şimşek, elektrik | (yeni: Şimşek Kalkanı) |
| `elemental_explosion` | Patlama | Barut Kesesi, Patlama Zinciri |
| `physical_knockback` | İtme, fiziksel | Zincirli Topuz, Topuz |
| `block` | Block mekaniği | Yansıtıcı Kalkan, Dikenli Zırh |
| `dot` | Zamanla hasar | Zehir, Yanma |
| `spawn` | Bir şey spawn eder | Ruh Avcısı, Barut Kesesi |

**Önemli:** Her efekt "proc" olduğunda kendi tag'ini yayar. Sinerji sistemi bunu dinler.

---

## 2. SİNERJİ TİPLERİ

### Tip A: AMPLIFIER (Güçlendirici)
> "Sen X yapıyorsun, ben X'i güçlendiriyorum"

| Sinerji | Tetikleyen | Amplifier Item | Sonuç |
|---------|------------|----------------|-------|
| Zehir Güçlendirme | Zehir efekti proc | Elemental Hasar Artırıcı | Zehir hasarı +%50 |
| Ateş Güçlendirme | Ateş efekti proc | Elemental Hasar Artırıcı | Yanma hasarı +%50 |
| Donma Güçlendirme | Buz efekti proc | Elemental Hasar Artırıcı | Donma süresi +%50 |

**Teknik:** Item "elemental_damage_boost" taşıyorsa, `elemental_poison/fire/ice` proc'larında hasar multiplier uygulanır.

---

### Tip B: TRIGGER (Tetikleyici)
> "Sen X yaptığında, ben Y yapıyorum"

| Sinerji | Tetikleyen Olay | Tepki Item | Sonuç |
|---------|-----------------|------------|-------|
| Block → Şimşek | Block başarılı | Şimşek Kalkanı | Bloklanan hasar kadar şimşek düşmana |
| Dodge → Bomba | Dodge tamamlandı | Barut Kesesi | Zaten var |
| Parry → Karşı vuruş | Perfect parry | Ters Darbe | Zaten var |
| Zehir → Patlama | Zehirli düşman öldü | Zehir + Ateş | Zehirli düşman patlar (kimyasal reaksiyon) |

**Teknik:** Item "on_block" dinler, block event'inde kendi efektini spawn eder.

---

### Tip C: MULTIPLIER (Çoğaltıcı)
> "Sen X spawn ediyorsun, ben 2. bir X daha spawn ediyorum"

| Sinerji | Kaynak Item | Multiplier Item | Sonuç |
|---------|-------------|-----------------|-------|
| Çift Şimşek | Şimşek Kalkanı | Elemental Çoğaltıcı | 2 düşmana şimşek |
| Çift Donma | Donma Dokunuşu | Elemental Çoğaltıcı | 2 düşman donar |
| Çift Patlama | Barut Kesesi | Patlama Çoğaltıcı | 2 bomba spawn |
| Çift Zehir | Zehir Bulutu | DoT Çoğaltıcı | Zehir 2x stack |

**Teknik:** "Elemental Duplication" item'ı, `elemental_*` veya `spawn` proc'larını dinler. Ana efekt spawn edildikten hemen sonra aynı efekt bir kez daha tetiklenir (farklı hedef veya aynı hedef 2x hasar).

---

### Tip D: CONVERSION (Dönüştürücü)
> "Sen X yapıyorsun, ben X'i Y'ye çeviriyorum"

| Sinerji | Kaynak | Conversion Item | Sonuç |
|---------|--------|-----------------|-------|
| Zehir → Ateş | Zehir proc | Ateş Ruhu | Zehirli düşman yanmaya başlar |
| Buz → Şimşek | Donma proc | Statik Tüy | Donan düşmana şimşek (su iletken) |
| Block → Zehir | Block | Zehirli Kalkan | Bloklanan hasar zehir olarak düşmana |

---

### Tip E: CHAIN (Zincir)
> "Sen X yapıyorsun, X Y'yi tetikliyor, Y Z'yi tetikliyor"

| Sinerji | Zincir |
|---------|--------|
| Patlama Zinciri | Bomba öldürür → Patlama Zinciri tetiklenir → O da öldürür → Tekrar... |
| Zehir Yayılımı | Zehirli düşman ölür → Yakındaki 2 düşmana zehir bulaşır |
| Şimşek Sıçraması | Şimşek vurur → Yakındaki düşmana sıçrar → Ondan diğerine... |

---

## 3. ÖNERİLEN SİNERJİ HAVUZU

### Elemental Amplifier Item (Yeni)
```
[elemental_amplifier] Elemental Güçlendirici
  Artı: Tüm elemental hasarlar (zehir, ateş, buz, şimşek) +%40
  Eksi: Fiziksel hasar -%10
  tags: [amplifier, elemental]
```

### Block → Şimşek Item (Yeni)
```
[simsek_kalkani] Şimşek Kalkanı
  Artı: Block başarılı olduğunda, bloklanan hasarın %80'i şimşek olarak saldırgana
  Eksi: Block süresi -%15
  tags: [trigger, block, elemental_lightning]
  triggers_on: block_success
```

### Elemental Duplication Item (Yeni)
```
[elemental_cekilme] Elemental Çekilme (veya "İkiz Ruh")
  Artı: Spawn ettiğin elemental efektler (şimşek, donma, zehir bulutu, alev) 2. kez tetiklenir
  Eksi: Elemental olmayan hasar -%15
  tags: [multiplier, elemental]
  triggers_on: elemental_spawn
```

### Mevcut Item'ların Sinerji Potansiyeli

| Item | Tag'leri | Sinerji Partner'ları |
|------|---------|---------------------|
| Zehir Bulutu | elemental_poison, spawn, dot | Elemental Amplifier, DoT Çoğaltıcı |
| Zehirli Hançer | elemental_poison, dot | Elemental Amplifier |
| Ateşli Kılıç | elemental_fire, spawn | Elemental Amplifier, Çoğaltıcı |
| Alev Halesi | elemental_fire, aura | Elemental Amplifier |
| Donma Dokunuşu | elemental_ice | Elemental Amplifier, Çoğaltıcı |
| Dondurucu Nefes | elemental_ice, aura | Elemental Amplifier |
| Yansıtıcı Kalkan | block | Şimşek Kalkanı (ikisi birlikte = block + yansıma + şimşek) |
| Barut Kesesi | elemental_explosion, spawn | Patlama Çoğaltıcı, Patlama Zinciri |
| Patlama Zinciri | elemental_explosion, on_kill | Barut Kesesi (bomba öldürürse zincir) |

---

## 4. SİNERJİ TETİKLEME MİMARİSİ

### Event Akışı (Örnek: Block → Şimşek)

```
1. Oyuncu block yapar
2. Player/Combat: signal block_success(blocked_damage, attacker)
3. ItemManager bu signal'ı alır
4. ItemManager: "Hangi item'lar block_success dinliyor?"
   → Yansıtıcı Kalkan: hasarı yansıt (zaten var)
   → Şimşek Kalkanı: bloklanan hasar * 0.8 = şimşek spawn
5. Her iki efekt de uygulanır (çakışma yok)
```

### Event Akışı (Örnek: Elemental Çoğaltma)

```
1. Donma Dokunuşu proc'lar → 1 düşman donar
2. ItemManager: signal elemental_effect_spawned(effect_type: "freeze", target, source_item)
3. "Elemental Çekilme" item'ı bu signal'ı dinliyor
4. Ana efekt uygulandıktan SONRA, Çekilme: "Aynı efekti 2. hedefe uygula"
   → Yakındaki başka düşmanı bul, ona da donma uygula
5. Sonuç: 2 düşman donar
```

### Önemli: Sıra ve Öncelik

```
Sıra: PRE_PROC → PROC → POST_PROC

PRE_PROC: Amplifier'lar hasarı/efekti artırır (henüz uygulanmadan)
PROC: Ana efekt uygulanır
POST_PROC: Trigger'lar (block → şimşek), Multiplier'lar (2. efekt spawn)
```

Bu sayede:
- Amplifier önce hasarı yükseltir
- Sonra efekt uygulanır
- Sonra tetikleyici/çoğaltıcı item'lar devreye girer

---

## 5. SİNERJİ TANIMLARI (Veri Formatı)

```gdscript
# synergy_definitions.gd veya JSON
{
  "elemental_amplifier_synergy": {
    "type": "amplifier",
    "description": "Elemental hasarlar güçlenir",
    "required_tags": ["elemental_amplifier"],  # Bu item varsa
    "amplifies": ["elemental_poison", "elemental_fire", "elemental_ice", "elemental_lightning"],
    "multiplier": 1.4
  },
  "block_lightning_synergy": {
    "type": "trigger",
    "description": "Block şimşek çakar",
    "required_tags": ["simsek_kalkani"],
    "triggers_on": "block_success",
    "effect": "spawn_lightning",
    "formula": "blocked_damage * 0.8"
  },
  "elemental_duplication_synergy": {
    "type": "multiplier",
    "description": "Elemental efektler iki kez",
    "required_tags": ["elemental_cekilme"],
    "triggers_on": "elemental_effect_spawned",
    "action": "duplicate_effect",
    "target_selection": "nearest_other_enemy"
  }
}
```

---

## 6. OYUNCUYA GÖSTERİM

- **Seçim ekranında:** "Bu item X ile sinerji yapar" ipucu
- **Envanterde:** Aktif sinerjiler listesi
- **Proc anında:** Özel efekt/ses (şimşek çaktığında farklı bir "ding")
- **Sinerji açılış metni:** İlk kez sinerji tetiklendiğinde kısa popup: "⚡ Şimşek Kalkanı + Yansıtıcı Kalkan!"

---

## 7. YENİ İTEM ÖNERİLERİ (Sinerji Odaklı)

| ID | İsim | Ana Özellik | Sinerji Rolü |
|----|------|-------------|--------------|
| elemental_amplifier | Elemental Güçlendirici | Elemental +%40 | Amplifier |
| simsek_kalkani | Şimşek Kalkanı | Block → Şimşek | Trigger |
| elemental_cekilme | Elemental Çekilme | 2x elemental proc | Multiplier |
| zehir_atesi | Zehir Ateşi | Zehirli düşman yanar | Conversion |
| statik_tuy | Statik Tüy | Donan düşmana şimşek | Conversion |
| patlama_genislemesi | Patlama Genişlemesi | Patlama yarıçapı +%50 | Amplifier |
| zincir_simsek | Zincir Şimşek | Şimşek düşmanlar arası sıçrar | Chain |

---

## 8. ÖZET

| Sinerji Tipi | Ne Yapar | Örnek |
|--------------|----------|-------|
| **Amplifier** | Efekti güçlendirir | Zehir + Elemental Amplifier = daha güçlü zehir |
| **Trigger** | Olaya tepki verir | Block + Şimşek Kalkanı = blokta şimşek |
| **Multiplier** | Efekti çoğaltır | Donma + Elemental Çekilme = 2 düşman donar |
| **Conversion** | X'i Y'ye çevirir | Zehir + Zehir Ateşi = zehir yanar |
| **Chain** | Zincirleme tetikler | Patlama → ölüm → patlama → ... |

**Teknik anahtar:** Her efekt proc'unda `effect_procced(tag, params)` signal'ı yay. Sinerji item'ları bu signal'ı dinleyip kendi mantıklarını çalıştırsın.

---

## 9. SALDIRI TİPİ → ELEMENT DÖNÜŞTÜRÜCÜ İTEMLER

Oyuncunun **belirli saldırı tiplerini** elemental hasara dönüştüren item'lar. Her saldırı tipi ayrı item ile element kazanabilir.

### Oyun Saldırı Tipleri (Player State Machine)
| Saldırı Tipi | Açıklama | Animasyonlar |
|--------------|----------|--------------|
| **normal_attack** | Temel combo, hafif vuruşlar | attack_1.1, attack_1.2, attack_1.3, attack_1.4, attack_up, attack_down |
| **heavy_attack** | Güçlü, charge'li vuruşlar | heavy_neutral, up_heavy, down_heavy, air_heavy |
| **fall_attack** | Havadan aşağı çakılma | fall_attack |

### Dönüştürücü Item Konsepti

> "Bu saldırı tipinin tüm hasarı [element] olur + ek elemental efekt"

| Item ID | İsim | Dönüştürdüğü Saldırı | Element | Artı | Eksi |
|---------|------|---------------------|---------|------|------|
| zehirli_tirnak | Zehirli Tırnak | normal_attack | Poison | Normal vuruşlar zehir DoT verir | Normal hasar -%15 |
| atesli_yumruk | Ateşli Yumruk | normal_attack | Fire | Normal vuruşlar yakar | Yanma süresi kısa |
| buzlu_kilic | Buzlu Kılıç | normal_attack | Ice | Normal vuruşlar yavaşlatır/dondurur | Hasar -%10 |
| simsek_parmagi | Şimşek Parmak | normal_attack | Lightning | Normal vuruşlar şimşek çakar | Cooldown artar |
| zehirli_dev | Zehirli Dev | heavy_attack | Poison | Heavy vuruş zehir püskürtür (AoE) | Heavy charge süresi +%20 |
| gok_gurultusu | Gök Gürültüsü | heavy_attack | Lightning | Heavy vuruş şimşek indirir | Stamina maliyeti artar |
| lav_cekici | Lav Çekici | heavy_attack | Fire | Heavy vuruş alev dalgası | Hareket -%5 |
| donma_cekici | Donma Çekici | heavy_attack | Ice | Heavy vuruş donma AoE | Heavy cooldown uzar |
| zehirli_dusus | Zehirli Düşüş | fall_attack | Poison | Fall attack zehir bulutu bırakır | Fall damage riski |
| yildirim_dususu | Yıldırım Düşüşü | fall_attack | Lightning | Fall attack şimşek çakar | Fall attack süresi uzar |
| ates_topu_dususu | Ateş Topu Düşüşü | fall_attack | Fire | Fall attack alev patlaması | Patlama oyuncuyu da iter |
| buz_cagi | Buz Çağı | fall_attack | Ice | Fall attack donma dalgası | Yere inince kısa yavaşlama |

### Sinerji Potansiyeli
- **Elemental Amplifier** + Zehirli Tırnak = Çok güçlü zehir
- **Elemental Çekilme** + Gök Gürültüsü = 2 şimşek
- **Zehir Ateşi** + Zehirli Tırnak = Zehirli vuruşlar yakar
- Farklı saldırı tiplerine farklı element = Tam elemental build (normal=zehir, heavy=şimşek, fall=ateş)

### Teknik: Signal
```
player_attack_landed(attack_type: String, damage: float, targets: Array, position: Vector2)
# attack_type: "normal", "heavy", "fall"
# Item'lar bu signal'ı dinleyip kendi element'lerini uygular
```

---

## 10. V2 YOL HARİTASI — Çoklu Tag Sistemi + Merkezi Element Registry

> **Durum: Faz 1-4 uygulandı (2026-09-29).** 2026-09-29 tasarım sohbetinde
> kullanıcı, item'ların "movement / elemental / brawl" gibi genel sınıflara
> ayrılıp sinerjilerin bu sınıflar üzerinden kurulmasını istedi — deck-builder
> roguelike'lardaki (Slay the Spire, Balatro) tag-bazlı sinerji deseni. Aynı
> sohbette dört fazın tamamı koda döküldü: çoklu `tags` alanı, merkezi element
> registry, tag-bazlı `tri_element` seti (eski 3 item'lık ID listesi yerine),
> ve iki yeni "aile" sinerjisi (`restless_body` hareket ailesi, `brawler_instinct`
> dövüş ailesi). Aşağıdaki alt bölümler artık *plan* değil, *ne yapıldığının*
> kaydı — her birinin sonunda gerçek dosya/satır referansı var.

### 10.1 Neden gerekli — mevcut sistemde somut kanıt

Bölüm 1-9'daki sinerji mimarisi hâlâ **item ID'sine göre** çalışıyor, tag'e
göre değil. Bunun gerçek bir bakım sorunu olduğu `element_degisimi.gd`'de
(satır 42-50) görülüyor — "hangi elementler aktif?" sorusunu şöyle cevaplıyor:

```gdscript
var elements: Array[String] = []
if im.has_active_item("zehirli_tirnak") or im.has_active_item("zehirli_dev"):
    elements.append("poison")
if im.has_active_item("atesli_yumruk") or im.has_active_item("lav_cekici"):
    elements.append("fire")
# ... buzlu_kilic/donma_cekici, simsek_parmagi/gok_gurultusu için aynısı
```

İki sorun:
1. **Kopya kod.** Yeni bir zehir/ateş/buz/şimşek item'ı eklendiğinde bu liste
   `element_degisimi.gd` içinde elle güncellenmezse yeni item hiç fark
   edilmez. "Aktif element" sorusunu soran her yeni mekanik (dodge, dash,
   block-reflect...) aynı listeyi kendi içinde tekrar yazmak zorunda kalır.
2. **Zaten bir kanıt var: şimşek unutulmuş.** `elements` dizisine `"lightning"`
   ekleniyor (satır 50) ama `_trigger_explosion`'daki `match element:`
   bloğunda (satır 68-77) `"lightning"` case'i **yok** — yani şimşek elementi
   rastgele seçilirse patlamanın elemental kısmı sessizce hiçbir şey
   yapmıyor (sadece fiziksel hasar/knockback kalıyor). Bu tam olarak
   merkezi bir kayıt/uygulama katmanının önleyeceği türde bir hata: her
   yeni öğe eklendiğinde N farklı yerde elle senkron tutulması gereken bir
   liste yerine, tek bir yerden okunup tek bir yerden uygulanan bir kayıt.

`zehirli_sekme` (önceki partide eklendi) da aynı sınıfta bir kısayol:
"dodge temas hasarı verir" fikri element-agnostik olmalıydı, ama en hızlı
yol poison'u hardcode etmekti. Senin istediğin tam olarak bunun düzeltilmesi.

### 10.2 Faz 1 — Çoklu tag alanı (temel, kırılma riski yok)

`ItemEffect`'e (`resources/items/item_effect.gd`) mevcut tekli `category`
enum'unun **yanına**, onu bozmadan, çoklu bir tag listesi eklenir:

```gdscript
# item_effect.gd'ye eklenecek
var tags: Array[String] = []
func has_tag(t: String) -> bool: return tags.has(t)
```

Önerilen tag sözlüğü (kullanıcının movement/elemental/brawl örneğiyle
birebir):

| Tag ailesi | Örnekler | Kapsar |
|---|---|---|
| `movement` | dodge, dash, wall-jump, çift zıplama | Yer değiştirme eylemleri |
| `elemental_poison/fire/ice/lightning` | zehirli_tirnak, atesli_yumruk, buzlu_kilic, simsek_parmagi | Element veren/tüketen item'lar |
| `brawl` | hafif/ağır/düşüş vuruşu | Yakın dövüş |
| `defense` | block, parry | Savunma |
| `on_kill` | ruh_avcisi, koz_tutan | Öldürmeye tepki veren |
| `economy` | falci_kadin, sansli_nal | Meta/ekonomi |

Bu faz **sadece veri ekliyor**, hiçbir mevcut davranışı değiştirmiyor —
105 item'a (69+32+4) tag eklemek mekanik ama riski sıfıra yakın bir iş,
toplu/script yardımıyla hızlandırılabilir.

### 10.3 Faz 2 — Merkezi "aktif element" registry (senin somut örneğin tam burada çözülüyor)

`ItemManager`'a (`autoload/item_manager.gd`) tek bir sorgu + tek bir uygulama
fonksiyonu eklenir:

```gdscript
# Aktif "elemental_*" tag'li item'lardan türetilen element listesi
func get_active_elements() -> Array[String]:
    var out: Array[String] = []
    for item in active_items:
        for t in item.tags:
            if t.begins_with("elemental_"):
                var el = t.trim_prefix("elemental_")
                if not out.has(el):
                    out.append(el)
    return out

# Tek merkezi uygulama noktası — element-spesifik add_X_stack çağrılarının
# TEK yeri burası olur, başka hiçbir dosya bunu elle yapmaz
func apply_element_to_enemy(enemy: Node2D, element: String) -> void:
    match element:
        "poison":
            if enemy.has_method("add_poison_stack"):
                enemy.add_poison_stack(5, 1.0, 2.0)
        "fire":
            if enemy.has_method("add_burn_stack"):
                enemy.add_burn_stack()
        "ice":
            if enemy.has_method("add_frost_stack"):
                enemy.add_frost_stack(1)
        "lightning":
            pass  # TODO: lightning'in kendi stack/anlık-hasar mekaniği netleşince eklenir
```

> ✅ **Uygulandı** (`autoload/item_manager.gd` `get_active_elements()` /
> `apply_element_to_enemy()`) — lightning'in yukarıdaki TODO'su da çözüldü:
> lightning'in kalıcı bir stack sistemi yok (bkz. `simsek_parmagi.gd`, anlık
> zincir hasarı), bu yüzden merkezi fonksiyon onu tek seferlik doğrudan hasar
> (`take_damage`) olarak uyguluyor — poison/fire/ice ile aynı arayüzden, farklı
> bir davranışla.

Bundan sonra **element üreten** item'lar (`zehirli_tirnak`, `atesli_yumruk`,
`buzlu_kilic`, `simsek_parmagi` ve ağır/düşüş eşdeğerleri) kendi
`elemental_*` tag'lerini taşır — davranışları değişmez, sadece kayıt
edilebilir hale gelirler.

**Element tüketen** her yeni/mevcut mekanik artık kendi elementini hardcode
etmek yerine merkezi API'yi sorar. Örnek — `zehirli_sekme` genelleşir:

```gdscript
# dodge_state.gd _zehirli_sekme_tick() içinde, poison'a sabitlemek yerine:
var elements := im.get_active_elements()
if elements.is_empty():
    node.take_damage(BASE_DAMAGE, 80.0, 60.0, true)  # element yoksa saf fiziksel
else:
    node.take_damage(BASE_DAMAGE, 80.0, 60.0, true)
    for el in elements:
        im.apply_element_to_enemy(node, el)  # birden fazla elementin varsa hepsi biner
```

Bu, senin tarif ettiğin "dodge sahip olduğun elemental hasarı versin" isteğinin
birebir karşılığı — ve `element_degisimi.gd`'deki gibi yeni bir sinerji
sorusu sorulduğunda artık 4 farklı `has_active_item` çifti yazmaya gerek
kalmaz, tek satır `im.get_active_elements()` yeterli olur.

### 10.4 Faz 3 — Tag-bazlı sinerji kuralları (ID listesi yerine tag)

`ITEM_SET_DEFINITIONS` (bkz. `item_manager.gd:168-193`) şu an item ID'lerini
elle listeliyor (`"items": ["zehirli_tirnak", "zehirli_dev", ...]`) — yeni bir
zehir item'ı eklendiğinde bu listeye de elle eklenmesi gerekiyor. Faz 1'in
tag'leri hazır olduktan sonra, **yeni** sinerji tanımları ID listesi yerine
tag sorgusu kullanabilir:

```gdscript
# "En az 2 farklı elemental_* tag'i aktifse elemental hasar +%25" — ID'siz,
# yeni bir zehir/ateş/buz/şimşek item'ı otomatik dahil olur
func get_active_tag_count(tag_prefix: String) -> int:
    var seen: Dictionary = {}
    for item in active_items:
        for t in item.tags:
            if t.begins_with(tag_prefix):
                seen[t] = true
    return seen.size()
```

Mevcut `ITEM_SET_DEFINITIONS`'a **dokunmaya gerek yok** — o zaten çalışıyor,
bu yeni sistem onun yanına, YENİ sinerjiler için eklenir. İkisi paralel
yaşayabilir.

> ✅ **Uygulandı, ama tasarlanandan daha entegre.** Ayrı bir
> `get_active_tag_count()` yerine `ITEM_SET_DEFINITIONS`'ın kendisi genişletildi:
> her tanım artık `"items": [...]` (eski, ID listesi) YA DA `"tag_prefix": "..."`
> (yeni, tag sayımı) taşıyabiliyor; `_recalculate_item_sets()` ikisini de aynı
> döngüde işliyor (`item_manager.gd` `_count_active_items_with_tag_prefix()` +
> `_recalculate_item_sets()`). Tek sistem, tek `_set_bonus_cache`, tek UI
> gösterimi (`ui/item_selection.gd:424-429` değişmeden çalışıyor). `tri_element`
> seti bizzat bu yolla dönüştürüldü: eski `["atesli_yumruk", "buzlu_kilic",
> "simsek_parmagi"]` (3 item, eşik 2) yerine `"tag_prefix": "elemental_"` (12
> item, eşik 3) — artık zehir ve tüm ağır/düşüş elemental item'ları da
> `base_enemy.gd:499`'da gerçekten tüketilen `elemental_damage_mult` bonusuna
> katkı veriyor; eskiden hiç katkı veremiyorlardı.

### 10.5 Faz 4 — Aynı deseni `movement` ve `brawl`'a yaymak

Element için Faz 2-3'te kurulan desen ("merkezi sorgu + merkezi uygulama +
tag-bazlı amplifikasyon") diğer sınıflara da aynı şablonla uygulanır:

> ✅ **Uygulandı — ama planlanandan farklı, daha ucuz bir yoldan.** Yeni bir
> `movement`/`brawl` string tag'i eklemeye hiç gerek kalmadı: her item zaten
> TEK bir `ItemCategory` taşıyor (`item_effect.gd`), o zaten "bu item hangi
> aksiyona ait" sorusunu cevaplıyordu. `ITEM_SET_DEFINITIONS`'a üçüncü bir
> anahtar türü eklendi: `"category_family": [ItemCategory.X, ...]` — hangi
> kategorilerin bir "aile" saydığını gruplayan bir liste, `_recalculate_item_sets()`
> bunu da `tag_prefix`/`items` ile aynı döngüde sayıyor
> (`_count_active_items_with_category_family()`).

- **`restless_body`** (hareket ailesi — DODGE/SLIDE/WALL_SLIDE/JUMP/CROUCH
  kategorili 3+ item): aktifken dodge VE dash, `zehirli_sekme` item'ı hiç
  alınmamış olsa bile, içinden geçilen düşmanlara temas hasarı + aktif
  element(ler) uygular. Ortak mantık `ItemManager.apply_movement_contact_tick()`'te
  tek yerde; `dodge_state.gd` ve `dash_state.gd` sadece kendi "bu hareket
  başına bir kez vur" listesini tutup bu fonksiyonu çağırıyor — kopya kod yok.
  `zehirli_sekme` item'ının kendisi hâlâ aynı davranışı tek başına da açar
  (`has_active_item("zehirli_sekme") or active_item_sets.has("restless_body")`) —
  item bunun için hâlâ var, ama artık TEK yol o değil.
- **`brawl`** → `brawler_instinct` (LIGHT_ATTACK/HEAVY_ATTACK/FALL_ATTACK
  kategorili 4+ item): `player_attack_landed` zaten ortak sinyaldi, tek
  eksik onu item-özel değil MERKEZİ dinlemekti. `ItemManager.register_player()`
  artık bu sinyale bir kez bağlanıyor (`_on_global_attack_landed_brawl_family`)
  ve eşik sağlandığında HER isabetli vuruşa (saldırı tipi fark etmeden) aktif
  element(ler)i uyguluyor — oyuncunun "doğru" element item'ını bulmasına
  gerek kalmadan.

### 10.6 Zorluk değerlendirmesi — gerçekleşen

Tahmin doğru çıktı: mimari zor değildi, gerekli sinyaller zaten vardı.
Beklenenden de ucuza geldi çünkü `ItemCategory` enum'u zaten dolayı bir
"movement/brawl tag sistemi"ydi — Faz 4 için yeni item taglemeye hiç gerek
kalmadı, sadece var olan kategorileri gruplamak yetti. Toplam dokunulan
dosya: `item_effect.gd` (tags alanı), `item_manager.gd` (registry + iki
aile sinerjisi + tri_element'in tag'e taşınması), `dodge_state.gd` +
`dash_state.gd` (paylaşılan temas-hasarı çağrısı), `element_degisimi.gd`
(refactor, şimşek bug'ı yan etki olarak düzeldi), 12 elemental item dosyası
(tek satır tag eklemesi). Hiçbir mevcut ID-bazlı sistem (`ITEM_REQUIREMENTS`,
`items:` listeleri) kırılmadı — ikisi paralel yaşıyor.

---

## 11. V3 YOL HARİTASI — Gerçek Deck-Builder Sinerjisi (2026-09-29, henüz uygulanmadı)

> **Durum: tasarım aşaması.** Kullanıcı geri bildirimi: tag sistemi ve aile
> eşikleri (§10) "sinerji-benzeri" ama asıl istenen değil — bunlar sadece
> **sayma** yapıyor ("kaç tane X kategorili item'ın var → sabit bir bonus").
> Gerçek deck-builder hissi (Slay the Spire, Balatro, Risk of Rain 2) item'ların
> birbirinin **çıktısını okuyup dönüştürmesinden** gelir, sadece aynı havuzda
> toplanmalarından değil. Bu bölüm buna somut bir yol haritası.

### 11.1 Teşhis — neden tag'ler yetmedi

§10'daki `get_active_elements()` / `tri_element` / `restless_body` /
`brawler_instinct` hepsi **toplama** mekanikleri: "N tane X'in var mı? Öyleyse
sabit bir çarpan/davranış aç." Bu, ITEM_SET_DEFINITIONS'ın zaten yaptığı şeyin
(§ başında, `poison_mastery`/`iron_guard`/`sky_strike`) genellenmiş hali —
faydalı ama **item'lar hâlâ birbirini görmüyor**. Deck-builder hissi şuradan
gelir: item A'nın çıktısı (bir status stack'i, bir proc, bir öldürme) item B
için bir **girdi** olur ve B onu dönüştürür/büyütür/tetikler. Şu an bunun tek
gerçek örneği kodda zaten var ve hiç item'a bağlı değil:

```gdscript
# enemy/base_enemy.gd:510-515, add_burn_stack() içinde
func add_burn_stack() -> void:
    # Zehir + ateş = patlama: üzerinde zehir varken ateş alırsa AoE patlama
    if poison_stacks > 0:
        var explosion = POISON_FIRE_EXPLOSION_SCENE.instantiate()
        ...
```

Bu, **motorun kendisinde** (item'lardan bağımsız) yaşayan tek elemental
reaksiyon: zehirli bir düşman ateş alırsa patlıyor. Bunun tek başına var
olması önemli — proje zaten "iki farklı efekt üst üste binince üçüncü bir şey
olsun" fikrini bir kere uygulamış, sadece bir kere. **11.2'nin önerisi bu
deseni 6 kombinasyona genişletmek** — bu, kullanıcının tarif ettiği "hangi
item olduğu önemli değil, iki farklı element kaynağın varsa bir şey olur"
hissinin tam karşılığı ve **sıfır yeni item gerektirmiyor** (mevcut 12
elemental item otomatik olarak bu matrisin bir parçası olur, çünkü hepsi zaten
`add_poison_stack`/`add_burn_stack`/`add_frost_stack`'i çağırıyor).

### 11.2 Faz 1 (önerilen ilk adım) — Elemental Reaksiyon Matrisi

4 element (poison/fire/ice/lightning) = C(4,2) = **6 olası çift**. Şu an 1/6
dolu. Önerilen tam matris (isimler/sayılar ayarlanabilir taslak):

| Çift | Reaksiyon adı | Etki | Teknik tetik |
|---|---|---|---|
| Poison + Fire | **Patlama** (VAR) | AoE patlama, iki stack de tüketilir | `add_burn_stack()` içinde `poison_stacks > 0` |
| Fire + Ice | **Buhar Patlaması** | Geniş görüş-engelleyici bulut + knockback, frost stack'leri söner | `add_burn_stack()` içinde `frost_stacks > 0` |
| Ice + Lightning | **Kırılma (Shatter)** | Dondurulmuş düşman (frost_stacks yüksekse) çok yüksek bonus hasar + uzun stun, frost sıfırlanır | Şimşek hasarı uygulanan yerde (`item_manager.apply_element_to_enemy` "lightning" case'i) `frost_stacks` kontrolü |
| Poison + Lightning | **Uçucu Zehir** | Poison stack'leri anında tüketilip büyük patlayıcı hasara çevrilir, yakındaki zehirli düşmanlara sıçrar | Şimşek hasarı uygulanırken `poison_stacks > 0` |
| Poison + Ice | **Bulaşıcı Don** | Donmuş düşman patlarsa (frost dolarsa) zehiri yakındakilere de bulaştırır | `add_frost_stack()` içinde `poison_stacks > 0` VE frost cap'e ulaşınca |
| Fire + Lightning | **Aşırı Yüklenme** | Küçük ölçekli hem yanma hem şok zinciri (en zayıf ikili, iki DoT'un üst üste binmesi kadar basit tutulabilir) | `add_burn_stack()` içinde `add_frost_stack` yerine bir "recently_shocked" flag kontrolü |

**Neden bu Faz 1 olmalı:** Teknik olarak ucuz (hepsi `enemy/base_enemy.gd`'ye,
mevcut `add_X_stack()` fonksiyonlarının İÇİNE eklenen birkaç satır — tıpkı
zehir+ateş'in zaten yapıldığı gibi), **hiçbir yeni item gerektirmiyor** (12
mevcut elemental item otomatik olarak matrisin parçası olur), ve kullanıcının
"hangi item olduğu önemli değil" isteğinin en doğrudan karşılığı. Örnek build
hissi: "Buzlu Kılıç (ice, normal attack) + Gök Gürültüsü (lightning, heavy
attack) alırsan — hangi ikisi olursa olsun, aynı düşmana ikisini de vurunca
düşman parçalanıyor" — bu ikisinin BİRBİRİNİ TANIMASI gerekmiyor, ikisi de
sadece kendi elementini uyguluyor, reaksiyon motor seviyesinde oluyor.

### 11.3 Faz 2 — Genel "proc" event bus'ı (Bölüm 4'ün ilk kez gerçek uygulaması)

Bölüm 2-4'te tarif edilen Amplifier/Trigger/Multiplier/Chain mimarisi hiç
uygulanmadı çünkü item'lar birbirini SADECE ItemManager'ın hardcode ettiği ~12
spesifik sinyal üzerinden görebiliyor (`player_attack_landed`,
`player_dodged`, `perfect_parry`, `on_enemy_killed`, ...). Yeni bir "olay
türü" eklemek için (`item_manager.gd`'ye yeni sinyal + yeni `has_method`
kontrolü + player.gd'ye yeni sinyal tanımı) çekirdek dosyalara dokunmak
gerekiyor — bu da neden şu ana kadar sadece ~12 sabit tetikleyici var, item'lar
arasında keyfi bir olay grafiği yok, sorusunun cevabı.

Önerilen: `ItemManager`'a TEK bir genel yayın kanalı:

```gdscript
# item_manager.gd
signal effect_procced(tag: String, data: Dictionary)

func emit_proc(tag: String, data: Dictionary = {}) -> void:
    effect_procced.emit(tag, data)
    for item in active_items:
        if is_instance_valid(item) and item.has_method("_on_effect_procced"):
            item._on_effect_procced(tag, data)
```

Mevcut spesifik sinyaller (player_attack_landed vb.) **kaldırılmaz** — bu,
ONLARIN YANINA, aynı olayların bir kopyasını genel bir kanaldan da yayan bir
katman. Örnek entegrasyon noktaları (ekleme, mevcut davranışı bozmaz):
- `dodge_state.gd`/`dash_state.gd`: `im.emit_proc("movement", {"pos": end_pos})`
- `block_state.gd` parry başarılı: `im.emit_proc("parry", {"attacker": attacker})`
- `base_enemy.gd` bir status stack eklendiğinde: `im.emit_proc("status_applied", {"element": "poison", "enemy": self})`
- `item_manager.gd` `on_enemy_killed()`: `emit_proc("kill", {"enemy": enemy})`

Bundan sonra YENİ bir "trigger/amplifier" item'ı yazmak için çekirdek dosyaya
dokunmaya gerek kalmaz — sadece `_on_effect_procced(tag, data)` override edip
`tag`'e göre dallanır. Örnek (Bölüm 3'te zaten tasarlanmış, şimdi
uygulanabilir): **Elemental Çekilme** — "status_applied" proc'unu dinler,
yakındaki ikinci bir düşmana aynı elementi bir kez daha uygular.

### 11.4 Faz 3 — Stack OKUYAN "payoff" item'lar

Şu an `poison_stacks`/`burn_remaining_ticks`/`frost_stacks` sadece kendi DoT
tick'i tarafından okunuyor — hiçbir item "bu düşmanda kaç stack var?" diye
sormuyor. Bu, deck-builder'ların klasik "engine + payoff" ayrımının payoff
tarafı hiç yok demek. Örnek yeni LEGENDARY item'lar (Faz 2'nin proc bus'ını
kullanır):

- **"Stok Patlatma"**: `_on_effect_procced("status_applied", ...)` dinler, bir
  düşmanda 3 farklı element stack'i birikince (poison+frost+burn üçü de aktif)
  hepsini birden tüketip düşmanın MAX canının %X'i kadar doğrudan hasar verir.
- **"Aç Gözlü Toksin"**: normal saldırılar artık poison stack SAYISI kadar
  bonus hasar verir (`poison_stacks` okur) — poison'u DoT'tan "anlık büyük
  hasarın önkoşulu"na çevirir, poison-stacker build'ini farklı bir oynanışa
  iter.

### 11.5 Faz 4 (daha spekülatif, sonraya bırakılabilir) — Paylaşılan Combo/Momentum Sayacı

`koruk.gd` zaten kendi özel combo sayacını tutuyor (5 vuruşta 1 tutuşma).
Bunu tek bir **paylaşılan** `PlayerStats.combo_count` haline getirip birden
fazla item'ın hem besleyip hem okumasına izin vermek (Balatro'nun "chips"
sayacı gibi) ciddi bir yeniden yapılanma — mevcut item'ların combo mantığını
merkezi bir yere taşımak gerekir. Bu, Faz 1-3 oturduktan sonra, ayrı bir
tasarım kararı olarak ele alınmalı; şimdiden plana zorla sıkıştırılmıyor.

### 11.6 Mevcut item'ların budanması — kullanıcı özgürlüğü verdi

114 item'ın önemli bir kısmı "düz stat sopası": tek bir sayıyı büyütüyor,
hiçbir şeyle etkileşmiyor (ör. `hizli_el` +%25 saldırı hızı, `combo_ustasi`
+%20 combo hasarı, `zeytinyagi` slide süresi). Bunlar deck-builder hissini
SEYRELTİYOR çünkü draft'ta bir slotu dolduruyorlar ama hikaye anlatmıyorlar.
Önerilen yaklaşım (uygulama sırasında, item item karar verilecek — burada
kesin liste yok, ilke var):
- **Zaten bir "fiil" veya element'e bağlı olanlar** (ör. `hizli_el` → light
  attack hızı) Faz 2-3'ün proc bus'ına bağlanabilir hale getirilip (ör. "hızlı
  saldırılar element stack'ini daha hızlı biriktirir") kalabilir.
  - **Tamamen izole flat bonus'lar** (belirli bir fiile/elemente bağlı
  olmayanlar) ya birer "temel" (starter havuzunda kalıp yeni oyuncuya fiilleri
  öğreten) rolüne indirgenir ya da 2-3'ü birleştirilip tek, daha anlamlı bir
  item'a dönüştürülür.
- Bu geçiş büyük hacimli olduğu için **Faz 1-3 sonuçları elde edilmeden**
  başlanmamalı — önce yeni sinerji iskeleti kurulmalı, sonra hangi eski
  item'ın o iskelete bağlanabildiği/bağlanamadığı netleşir.

### 11.7 Önerilen sıralama

1. **Faz 1 (Elemental Reaksiyon Matrisi)** — en yüksek his/emek oranı, sıfır
   yeni item, ~6 küçük ekleme `base_enemy.gd`'ye. Önerilen ilk somut adım.
2. **Faz 2 (proc bus)** — Faz 1'den bağımsız yapılabilir ama Faz 3-4'ün önkoşulu.
3. **Faz 3 (stack-okuyan payoff item'lar)** — Faz 2 bittikten sonra, 3-4 yeni
   LEGENDARY ile deck-builder hissini kanıtlar.
4. **Faz 4 (paylaşılan combo sayacı)** ve **11.6 (budama)** — Faz 1-3 oturduktan
   sonra, ayrı bir oturumda ele alınacak büyük yeniden yapılanmalar.
