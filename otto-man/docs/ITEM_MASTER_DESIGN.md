# Item Sistemi - Master Tasarım Rehberi

Bu doküman, tüm konuşmalardan çıkan item sisteminin **tek referans noktası**dır. Tasarım ve implementasyon sırasında buradan yararlanılır.

---

## 1. TASARIM FELSEFESİ

### Temel İlkeler
1. **Mekanik değişimi > Stat değişimi** – Item'lar oyun tarzını değiştirmeli, sadece sayı artırmamalı
2. **Artı + Eksi** – Her item'da trade-off olmalı
3. **Sinerji** – Item'lar birbirini tanımadan güçlendirmeli (tag + signal sistemi)
4. **Çok item** – Her run farklı hissettirmeli (pool, weight, anti-repeat)

### Saldırı Tipleri (Player)
| Tip | Açıklama |
|-----|----------|
| `normal_attack` | Temel combo (attack_1.x, attack_up, attack_down, air_attack) |
| `heavy_attack` | Güçlü vuruşlar (heavy_neutral, up_heavy, down_heavy, air_heavy) |
| `fall_attack` | Havadan aşağı çakılma |

---

## 2. İTEM KATEGORİLERİ

| Kategori | Açıklama | Örnek |
|----------|----------|-------|
| **MOVEMENT** | Dodge, jump, hareket değiştirir | Barut Kesesi, Kuş Kanadı |
| **ATTACK** | Saldırı mekaniği değiştirir | Çift Yönlü Kılıç, Uzun Mızrak |
| **ATTACK_CONVERSION** | Saldırı tipini elemente dönüştürür | Zehirli Tırnak, Gök Gürültüsü |
| **DEFENSE** | Block, parry değiştirir | Yansıtıcı Kalkan, Şimşek Kalkanı |
| **PASSIVE_AURA** | Sürekli alan etkisi | Kanlı Ayak İzleri, Alev Halesi |
| **PASSIVE_ON_KILL** | Öldürme sonrası | Kan Emici, Patlama Zinciri |
| **PASSIVE_ON_HIT** | Hasar alma/verme sonrası | Dikenli Deri, Yansıtıcı Ayna |
| **PASSIVE_SYNERGY** | Diğer elementleri güçlendirir | Elemental Amplifier, Elemental Çekilme |
| **PASSIVE_CHAOS** | Rastgele efektler | Şansın Kırbacı |
| **PASSIVE_SURVIVAL** | Hayatta kalma | İkinci Nefes, Fedai |

---

## 3. ELEMENT SİSTEMİ (Tag'ler)

| Tag | Element | Örnek Item'lar |
|-----|---------|----------------|
| `elemental_poison` | Zehir, DoT | Zehirli Hançer, Zehir Bulutu |
| `elemental_fire` | Ateş, yanma | Ateşli Kılıç, Alev Halesi |
| `elemental_ice` | Buz, donma | Donma Dokunuşu, Dondurucu Nefes |
| `elemental_lightning` | Şimşek | Şimşek Kalkanı, Gök Gürültüsü |
| `elemental_explosion` | Patlama | Barut Kesesi, Patlama Zinciri |

---

## 4. SİNERJİ TİPLERİ

| Tip | Mantık | Örnek |
|-----|--------|-------|
| **Amplifier** | X'i güçlendirir | Zehir + Elemental Amplifier |
| **Trigger** | X olduğunda Y yapar | Block + Şimşek Kalkanı |
| **Multiplier** | X 2 kez tetiklenir | Donma + Elemental Çekilme |
| **Conversion** | X'i Y'ye çevirir | Zehir + Zehir Ateşi = yanma |
| **Chain** | Zincirleme | Patlama → ölüm → patlama |

---

## 5. SİGNAL LİSTESİ (Game Core'a eklenecek)

```
# Hareket
player_dodged(direction, start_pos, end_pos)
player_jumped(jump_count, position)
player_moved(position, delta)

# Saldırı
player_attack_landed(attack_type, damage, targets, position)  # attack_type: "normal", "heavy", "fall"
player_attacked(direction, damage, hit_targets)

# Savunma
player_blocked(blocked_damage, attacker)
player_block_success(blocked_damage, attacker)
player_parried(parry_direction)

# Hasar
player_took_damage(amount, source, position)
player_killed_enemy(enemy, position)
enemy_touched_player(enemy, contact_point)

# Elemental (sinerji için)
elemental_effect_spawned(effect_type, target, source_item, params)

# Durum
player_near_enemies(enemies_array)
health_changed(current, max)
player_died()
```

---

## 6. İTEM ÖZET LİSTESİ (Tüm Kategoriler)

### Hareket (6)
Barut Kesesi, Kuş Kanadı, Ağır Zırh, Rüzgar Pabucu, Görünmezlik Pelerini, Yerçekimi Tersi

### Saldırı Mekanik (7)
Uzun Mızrak, Çift Yönlü Kılıç, Zincirli Topuz, Ateşli Kılıç, Zehirli Hançer, Delici Mızrak, (Yansıtıcı Kalkan)

### Saldırı → Element Dönüştürücü (12)
Normal: Zehirli Tırnak, Ateşli Yumruk, Buzlu Kılıç, Şimşek Parmak
Heavy: Zehirli Dev, Gök Gürültüsü, Lav Çekici, Donma Çekici
Fall: Zehirli Düşüş, Yıldırım Düşüşü, Ateş Topu Düşüşü, Buz Çağı

### Savunma (4)
Dikenli Zırh, Ters Darbe, Kırılgan Kalkan, Kan Paktı

### Özel Mekanik (6)
Zaman Kristali, Hayalet El, Kan Bağı, Kaos Yüzüğü, Ayna, Yer Değiştirme

### Pasif - Alan (5)
Kanlı Ayak İzleri, Dondurucu Nefes, Alev Halesi, Zehir Bulutu, Yerçekimi Çekirdeği

### Pasif - Öldürme (5)
Kan Emici, Ruh Avcısı, Patlama Zinciri, Altın Dokunuş, Lanet Mirası

### Pasif - Temas (4)
Dikenli Deri, Yansıtıcı Ayna, Donma Dokunuşu, Kan Bağı (Pasif)

### Pasif - Kaotik (3)
Şansın Kırbacı, Hayalet El (Pasif), Titreyen El

### Pasif - Boyut/Fizik (4)
Dev İksiri, Cüce Tozu, Ağırlık Kemeri, Tüy

### Pasif - Ekonomi (4)
Manyetik Cüzdan, Aç Gözlü, Cömert Ruh, Lanetli Altın

### Pasif - Hayatta Kalma (4)
İkinci Nefes, Son Damla, Berserker Ruhu, Fedai

### Sinerji Odaklı (7)
Elemental Amplifier, Şimşek Kalkanı, Elemental Çekilme, Zehir Ateşi, Statik Tüy, Patlama Genişlemesi, Zincir Şimşek

---

## 7. UYGULAMA SIRASI (Önerilen)

1. ItemManager + base sınıflar
2. Signal'ları Player/Combat'a ekle
3. 5 pilot item (farklı kategorilerden)
4. Item seçim UI
5. 15 item'a çık
6. Elemental + Attack Conversion item'lar
7. Sinerji sistemi
8. Pool + weight + anti-repeat
9. Kalan item'lar

---

## 8. REFERANS DOSYALAR

| Dosya | İçerik |
|-------|--------|
| `ITEM_SYSTEM_ARCHITECTURE.md` | Bug önleme, mimari, signal kataloğu |
| `ITEM_SYNERGY_DESIGN.md` | Sinerji tipleri, conversion, amplifier |
| `ITEM_DATABASE.txt` | Tüm item'ların detaylı listesi (ID, artı, eksi, tag) |

---

*Bu doküman tüm tasarım kararlarının özetidir. Implementasyon sırasında güncellenebilir.*
