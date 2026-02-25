# Item Sistemi - Bug Önleyici Mimari Tasarım

## Amaç
Çok sayıda item/powerup üst üste geldiğinde bug, çakışma ve beklenmeyen davranışları önlemek için modüler, izole ve öngörülebilir bir sistem.

---

## 1. TEMEL PRENSİPLER

### 1.1 Tek Sorumluluk (Single Responsibility)
- Her item sadece KENDİ efektini uygular
- Item'lar birbirini TANIMAZ, birbirini ÇAĞIRMAZ
- Tüm koordinasyon merkezi bir manager üzerinden

### 1.2 Event-Driven Mimari
- Item'lar CORE game logic'i DEĞİŞTİRMEZ
- Bunun yerine SIGNAL'lara bağlanır
- Player/Enemy/Combat sistemi signal yayar → Item'lar dinler → Efekt uygular

```
[Player Dodge] → signal: player_dodged(direction, position)
    → Barut Kesesi dinler → bomba spawn eder
    → Rüzgar Pabucu dinler → ekstra dash uygular
    (Birbirinden habersiz, izole)
```

### 1.3 Merkezi Stat Sistemi
- Tüm stat değişiklikleri PlayerStats/ItemManager üzerinden
- Her item kendi modifier'ını kaydeder, kaldırırken TAM olarak geri alır
- Modifier'lar ID ile takip edilir (aynı item 2 kez eklenirse çakışma olmaz)

### 1.4 Temiz Aktivasyon/Deaktivasyon
- activate() çağrıldığında yapılan HER ŞEY deactivate()'te GERİ ALINMALI
- Memory leak yok: signal connection'lar disconnect edilmeli
- Spawn edilen node'lar (bomba, trail vb.) item kaldırılınca temizlenmeli

---

## 2. SİSTEM KATMANLARI

```
┌─────────────────────────────────────────────────────────────┐
│  GAME CORE (Player, Enemy, Combat)                          │
│  - Sadece signal yayar, item'lardan habersiz                 │
└──────────────────────────┬──────────────────────────────────┘
                           │ signals
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  ITEM MANAGER (Merkez Koordinatör)                          │
│  - Item registry, activation order, conflict check           │
│  - Signal'ları item'lara dağıtır                             │
└──────────────────────────┬──────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Item A      │  │  Item B      │  │  Item C      │
│  (izole)     │  │  (izole)     │  │  (izole)     │
│  Kendi       │  │  Kendi       │  │  Kendi       │
│  efektini    │  │  efektini    │  │  efektini    │
│  uygular     │  │  uygular     │  │  uygular     │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## 3. SIGNAL KATALOĞU (Item'ların Dinleyeceği Event'ler)

Player/Combat sisteminden yayılacak signal'lar - item'lar BUNLARA bağlanır:

| Signal | Parametreler | Ne Zaman | Örnek Item'lar |
|--------|--------------|----------|----------------|
| player_dodged | direction, start_pos, end_pos | Dodge tamamlandığında | Barut Kesesi, Rüzgar Pabucu |
| player_jumped | jump_count, position | Her zıplamada | Kuş Kanadı (triple jump) |
| player_attacked | direction, damage, hit_targets | Saldırı vurduğunda | Çift Yönlü Kılıç, Patlama Zinciri |
| player_blocked | blocked_damage, attacker | Block başarılı | Dikenli Zırh, Yansıtıcı Kalkan |
| player_parried | parry_direction | Perfect parry | Ters Darbe |
| player_took_damage | amount, source, position | Hasar alındığında | Yansıtıcı Ayna, Fedai |
| player_killed_enemy | enemy, position | Düşman öldürüldü | Kan Emici, Ruh Avcısı, Patlama Zinciri |
| player_moved | position, delta | Her frame hareket | Kanlı Ayak İzleri, Zehir Bulutu |
| player_near_enemies | enemies_array | Yakındaki düşmanlar | Dondurucu Nefes, Alev Halesi |
| enemy_touched_player | enemy, contact_point | Düşman oyuncuya değdi | Dikenli Deri, Donma Dokunuşu |

---

## 4. MODIFIER SİSTEMİ (Stat Değişiklikleri İçin)

```gdscript
# Her item kendi modifier'ını unique ID ile kaydeder
# ItemManager.add_modifier(item_id, stat_name, value, is_multiplier)
# ItemManager.remove_modifier(item_id)  # Tüm modifier'ları bu item'dan kaldır

# Modifier'lar stack edilir, çakışma yok:
# Item A: base_damage += 0.2
# Item B: base_damage *= 1.1
# Item C: base_damage -= 0.1
# Sonuç: (base + 0.2 - 0.1) * 1.1
```

### Kurallar:
- Bonus'lar önce toplanır, sonra multiplier'lar uygulanır
- Her item kendi ID'si ile kayıt yapar
- Deactivate'te remove_modifier(item_id) MUTLAKA çağrılmalı

---

## 5. SPAWN/CHILD NODE YÖNETİMİ

Item'lar bomba, trail, minion gibi node spawn ederse:

```gdscript
# YANLIŞ: Doğrudan scene tree'e ekleme
get_tree().current_scene.add_child(bomb)

# DOĞRU: ItemManager'ın child container'ına ekleme
ItemManager.add_item_spawned(self, bomb)  # Item kaldırılınca otomatik temizlenir

# Veya item kendi child'ını tutar:
var bomb_instance = bomb_scene.instantiate()
add_child(bomb_instance)  # Item Node'un child'ı - item kaldırılınca birlikte gider
```

### Kural:
- Spawn edilen her şey Item'ın child'ı VEYA ItemManager'ın registry'sinde olmalı
- Item deactivate olunca tüm spawn'lar queue_free()

---

## 6. ÇAKIŞMA (CONFLICT) KURALLARI

Bazı item'lar birbirini dışlar:

| Çakışma | Item A | Item B | Çözüm |
|---------|--------|--------|-------|
| Dodge değiştirme | Barut Kesesi | Ağır Zırh | İkisi de dodge'u değiştiriyor - MUTUAL EXCLUSIVE tag |
| Hareket | Rüzgar Pabucu | Ağır Zırh | Farklı aspect'ler - birlikte olabilir |

### Çakışma Tanımı:
```gdscript
# ItemResource'da:
conflicts_with: ["barut_kesesi", "agir_zirh"]  # Bu itemlerle aynı anda olamaz
modifies_mechanic: "dodge"  # Bu mekaniği değiştiriyor - aynı mekaniği değiştiren max 1
```

---

## 7. UYGULAMA SIRASI (PRIORITY)

Aynı event'te birden fazla item tetiklenirse:

```gdscript
# Öncelik sırası (düşük numara = önce çalışır)
const PRIORITY = {
    "pre_damage": 0,      # Hasar hesaplanmadan önce
    "damage_modifier": 1, # Hasar hesaplanırken
    "post_damage": 2,     # Hasar uygulandıktan sonra
    "spawn_effect": 3,    # Görsel/efekt spawn
}
```

- Item'lar priority'ye göre sırayla çalışır
- Bir item "iptal" etmez (cancel), sadece kendi efektini ekler
- İptal gerekiyorsa → conflict sistemi kullan, birini seçtirme

---

## 8. TEST EDİLEBİLİRLİK

- Her item için unit test: activate → deactivate → state temiz mi?
- Her item izole test: Sadece bu item varken efekt doğru mu?
- Kombinasyon test: A+B+C birlikte crash/undefined yok mu?
- Stres test: 10 item aynı anda, 100 dodge, 100 attack → memory leak?

---

## 9. ÖZET CHECKLIST (Item Eklerken)

- [ ] Item sadece signal'lara bağlanıyor, core logic'e dokunmuyor mu?
- [ ] activate()'teki her şey deactivate()'te geri alınıyor mu?
- [ ] Spawn edilen node'lar temizleniyor mu?
- [ ] Stat modifier'lar unique ID ile kaydediliyor mu?
- [ ] conflicts_with tanımı var mı (gerekirse)?
- [ ] Başka item'ı direkt çağırmıyor mu?
