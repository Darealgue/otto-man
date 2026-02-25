# Item Sinerji Sistemi - Tasarım Dokümanı

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
