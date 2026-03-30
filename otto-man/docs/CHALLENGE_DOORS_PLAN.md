# Kamp Kapıları: Challenge (Meydan Okuma) Sistemi – Plan

## 1. Mevcut Sistem (Özet)

- **Kamp kapıları:** "Seviye 1", "Seviye 2", "Seviye 3" gibi sabit seviye etiketleri.
- **DungeonRunState:** `current_tier` (1–9), `choose_initial_tier(t)`, `set_next_tier(t)`.
- **Level generator:** `current_level = drs.current_tier` → harita boyutu, düşman, tuzak, altın çarpanı hepsi bu tek sayıya bağlı.
- **Altın:** Toplanan her altın, `level_config.get_gold_multiplier(level)` ile anında çarpılıyor (run içinde).

---

## 2. Yeni Tasarım: Kapılar = Challenge (Meydan Okuma)

Kapıda **seviye numarası yerine** ne kazanıp ne kaybedeceği yazılsın; seçimler **biriksin**.  
**Önemli:** Kapılar sabit tarif değil; **her kampta kurallara bağlı prosedürel** üretilir. Aynı run'da bile bir sonraki kampta farklı +/− kombinasyonları çıkabilir.

---

### 2.1 "Normal" Kapı (Standart Artan Zorluk)

**Her kampta ilk kapı her zaman "Normal".** Sabit tarif, prosedürel değil.

- **Normal kapı seçilince run'a eklenenler:** +1 tuzak sayısı, +1 tuzak seviyesi, +1 düşman sayısı, +1 düşman seviyesi. **Ek ödül yok** (gold_multiplier = 0, guaranteed_rescue = false).
- **İlk segment (köyden ilk giriş):** Tuzaksız, az düşman, düşman seviyesi 1. Başlangıç birikimi 0.
- **Sadece Normal kapılardan tamamlarsa:** Biriken gold_multiplier = 0 → çıkışta **sadece topladığı altın**: `final_gold = dungeon_gold * 1.0`.

Normal kapı verisi (sabit): enemy_level_delta=1, enemy_count_delta=1, trap_level_delta=1, trap_count_delta=1, gold_multiplier_delta=0, dungeon_size_delta=0, guaranteed_rescue=false, is_normal=true.

---

### 2.2 Efekt Havuzları (Prosedürel Kapılar)

Kapı = risk (ceza) + ödül. Ceza **miktarları her kapıda değişebilir** (bazen +1, bazen +2 veya +3 "adım"). Bir adım = kodda tanımlı zorluk basamağı (seviye tablolarında +1, spawn sayısında makul artış vb.).

| Efekt (risk) | Açıklama | Prosedürel aralık | Birikim |
|--------------|----------|-------------------|---------|
| **enemy_level** | Düşman seviyesi kaç adım artacak | +1, +2 veya +3 | Run'da toplanır |
| **enemy_count** | Düşman sayısı (spawn kotası) kaç adım artacak | +1, +2 veya +3 | Run'da toplanır |
| **trap_level** | Tuzak seviyesi | +1, +2 veya +3 | Run'da toplanır |
| **trap_count** | Tuzak sayısı (ek grup) | +0, +1, +2 | Run'da toplanır |
| **map_size** | Harita uzunluğu | +0, +1 (veya +2) | Run'da toplanır |

| Efekt (ödül) | Açıklama | Nasıl | Birikim / kullanım |
|--------------|----------|-------|---------------------|
| **gold_multiplier** | Çıkışta altın çarpanı | **Adil:** Zorluk arttıkça multiplier aralığı yukarı kayar (yüksek risk → 0.5–1.0, düşük risk → 0.25–0.5). Sabit formül yok. | Run'da toplanır, köye çıkışta uygulanır |
| **guaranteed_rescue** | Sonraki segmentte garanti kurtarma | evet/hayır | Bir sonraki segmentte geçerli, sonra sıfırlanır |

**Şimdilik sadece bu iki ödül** (gold_multiplier + guaranteed_rescue) kullanılacak. Garanti hazine odası, garanti çeşme vb. segment bazlı ödüller ileride eklenebilir.  
**Ertelendi:** Run boyu buff’lar (hasar/savunma artışı, tuzak hasarı azalması vb.) – tasarım ve uygulama üzerine daha düşünmek gerekiyor; ilk sürümde yok.

- Prosedürel kapıda her ceza değeri aralıktan **rastgele** seçilir (+1 / +2 / +3).
- **Adil multiplier:** Ceza toplamı yüksekse bu kapıya verilen multiplier daha yüksek aralıktan seçilir; ekstra karmaşık formül yok.

---

### 2.3 Prosedürel Kapı Üretim Kuralları

- **Kapı sayısı:**
  - **İlk kamp:** 3 kapı (1 Normal + 2 prosedürel).
  - **Sonraki kamplar:** 1 Normal + **rastgele sayıda** prosedürel kapı (örn. 2–4). Toplam kapı sayısı her kamp açılışında değişebilir; **Normal her zaman mevcut**.

- **Normal kapı:** Her kampta **ilk sırada** sabit Normal kapı; 2.1'deki sabit tarif uygulanır.

- **Diğer kapılar (prosedürel):**
  - Risk: En az 1, en fazla 3 risk efekti; her birinin **değeri aralıktan rastgele** (+1, +2 veya +3).
  - Ödül: 0–2 ödül (gold_multiplier aralıktan; guaranteed_rescue evet/hayır).
  - **Adil multiplier:** Ceza toplamı yüksekse gold_multiplier daha yüksek aralıktan seçilir.

- **Çeşitlilik:** Aynı kampta iki kapı birebir aynı olamaz; tekrarlanırsa yeniden üret.

- **Rastgelelik:** **Mümkün olduğunca rastgele:** seed sabitlemesi yok; her kamp açılışında yeni rastgele kapı seti ve özellikleri üretilir.

Çıktı: **ChallengeDoorGenerator** → kapı listesi (her biri delta dict + label_short).

---

### 2.4 Birikim Mantığı

- **Run başında:** Tüm birikimler 0.
- **Kapı seçilince:** O kapının değerleri run'a eklenir (birikir).
- **Her yeni segment:** Aynı birikimlerle harita üretilir; zorluk giderek artar.
- **Köye çıkış:** Toplam altın `*= (1.0 + biriken_altın_çarpanı)` yapılır. Normal kapılardan tamamlarsa biriken = 0 → sadece topladığı altın çıkar.

---

## 3. Veri Yapısı

### 3.1 DungeonRunState (güncel)

- `run_segment_count: int` – Bu run'da kaç segment oynandı (köyden giriş = 0, ilk kamp sonrası = 1, …).
- `enemy_level_offset: int` – Kapılardan biriken düşman seviyesi (adım).
- `enemy_count_offset: int` – Kapılardan biriken düşman sayısı (spawn kotası adımı).
- `trap_level_offset: int` – Kapılardan biriken tuzak seviyesi.
- `trap_count_offset: int` – Kapılardan biriken tuzak sayısı (ek grup).
- `gold_multiplier_accumulated: float` – Kapılardan biriken altın çarpanı toplamı.
- `dungeon_size_offset: int` – Kapılardan biriken harita boyutu.
- `guaranteed_rescue_next: bool` – Bir sonraki segmentte garanti kurtarma odası; segment girilince false.

Kapı seçilince: `apply_challenge(challenge_data: Dictionary)`.

### 3.2 Üretilmiş Kapı Verisi (prosedürel çıktı)

Her kapı = Dictionary:

- `enemy_level_delta: int` (1–3 prosedürel; Normal'da 1)
- `enemy_count_delta: int` (1–3 prosedürel; Normal'da 1)
- `trap_level_delta: int` (1–3 veya 0–2)
- `trap_count_delta: int` (0–2)
- `gold_multiplier_delta: float` (0 veya aralıktan; Normal'da 0)
- `dungeon_size_delta: int` (0, 1 veya 2)
- `guaranteed_rescue: bool`
- `is_normal: bool` (opsiyonel; Normal kapıyı işaretler)
- `label_short: String` – Kapıda görünecek metin (efektlerden üretilir).

CampScene: her kapıya `challenge_data` meta; seçimde `drs.apply_challenge(door.get_meta("challenge_data"))`.

---

## 4. Generator Tarafında Kullanım

- **Effective enemy level:** `effective_enemy = 1 + drs.enemy_level_offset`
- **Effective trap level:** `effective_trap = 1 + drs.trap_level_offset`
- **Düşman sayısı (spawn kotası):** Mevcut max_spawns formülüne `drs.enemy_count_offset` eklenir (uygun oranla; kodda birim “adım” tanımlanır).
- **Tuzak sayısı (ek grup):** `drs.trap_count_offset` mevcut trap groups formülüne eklenir.
- **Harita boyutu:** `length = level_config.get_length_for_level(1) + dungeon_size_offset * N` (N = chunk birimi).
- **Garanti kurtarma:** `drs.guaranteed_rescue_next == true` ise bu segmentte en az bir rescue; sonra `guaranteed_rescue_next = false`.
- **Altın:** Run içinde ham toplanır; köye çıkışta `final_gold = dungeon_gold * (1.0 + drs.gold_multiplier_accumulated)`.

---

## 5. Akış (Kısa)

1. **Köyden zindan:** Run başlatılır, birikimler 0, segment 0. Kamp açılır.
2. **Kamp açıldığında:** İlk kapı Normal (sabit); diğerleri prosedürel üretilir. İlk kamp 3 kapı; sonraki kamplar 1 Normal + rastgele 2–4 prosedürel (+ çıkış kapısı).
3. **Kapı seçimi:** Seçilen kapının `challenge_data`'sı `apply_challenge` ile run'a eklenir; zindan sahnesine geçilir.
4. **Zindan:** Generator effective level'ları ve offset'leri run state'ten okur; ilk segmentte tuzaksız/az düşman/base seviye.
5. **Segment biter:** `run_segment_count += 1`; `guaranteed_rescue_next` kullanıldıysa sıfırlanır; kamp sahnesine dönülür.
6. **Çıkış kapısı (köye dön):** `final_gold = dungeon_gold * (1.0 + gold_multiplier_accumulated)`; altın köye aktarılır; run biter.

---

## 6. Dikkat Edilmesi Gerekenler

1. **Altın:** Run içinde toplama anında çarpan kaldırılır (veya 1.0); çarpan sadece köye çıkışta uygulanır.
2. **Normal kapı:** Standart artan zorluk; ek ödül yok. Sadece Normal ile tamamlarsa çıkışta sadece topladığı altın.
3. **Garanti kurtarma:** Layout'ta en az bir rescue zorunlu; segment sonunda bayrak sıfırlanır.
4. **enemy_count_offset:** Kodda “1 adım = X ek spawn” veya “max_spawns formülüne +Y” şeklinde makul oran tanımlanır.
5. **Eski current_tier:** Kaldırılır; yerine effective level'lar ve offset'ler kullanılır.

---

## 7. Uygulama Sırası (Yol Haritası)

1. **DungeonRunState:** Birikim alanları (enemy_level_offset, enemy_count_offset, trap_level_offset, trap_count_offset, gold_multiplier_accumulated, dungeon_size_offset, guaranteed_rescue_next). `apply_challenge(dict)`. Segment sayacı.
2. **ChallengeDoorGenerator:** Normal sabit; prosedürel kapılar: ceza miktarları 1–3 (veya 0–2) rastgele, adil multiplier aralığı, kapı sayısı ilk kamp 3 / sonraki 1 Normal + rastgele 2–4. Seed yok; mümkün olduğunca rastgele.
3. **CampScene:** Kapı sayısını üreticiden al; 1 Normal + N prosedürel spawn; label_short; seçimde apply_challenge; çıkışta gold çarpanı.
4. **Level generator:** Effective enemy/trap level, enemy_count_offset, trap_count_offset, map size, guaranteed_rescue_next; ilk segment base kolay.
5. **Altın:** Run içi çarpan kaldır; köye çıkışta biriken çarpan uygula.
6. **Test:** Normal / prosedürel kapılar, birikim, çıkış altını.

---

## 8. Netleşen Kararlar (özet)

| Konu | Karar |
|------|--------|
| **Normal kapı** | Her kampta ilk kapı; standart artan zorluk (+1 tuzak/düşman seviye ve sayısı); ek ödül yok. Sadece Normal ile tamamlarsa sadece topladığı altın çıkar. |
| **Kapı sayısı** | İlk kamp: 3 (1 Normal + 2 prosedürel). Sonraki kamplar: 1 Normal + rastgele 2–4 prosedürel; default (Normal) her zaman mevcut. |
| **Rastgelelik** | Mümkün olduğunca rastgele; seed sabitlemesi yok. Her kamp açılışında yeni kapı seti ve özellikleri. |
| **Denge formülü** | Yok. Sadece “adil”: zorluk arttıkça multiplier aralığı yukarı kayar (yüksek risk → daha yüksek aralıktan seç). |
| **Ceza miktarları** | Her kapıda değişebilir; +1, +2 veya +3 “adım” (enemy_level, enemy_count, trap_level vb.). Kodda bir adımın oranı tanımlanır. |

---

## 9. İleride Genişletme

- **Yeni ödüller (segment bazlı):** Garanti hazine odası, garanti çeşme/iyileşme, garanti dükkân vb. – havuzda tanımlanıp generator’da seçilebilir.
- **Buff ödülleri (ertelendi):** Run boyu hasar/savunma artışı, tuzak hasarı azalması vb. tasarım ve uygulama daha düşünüldükten sonra eklenebilir.
- Yeni risk efektleri: Havuza ekle; apply_challenge ve generator’da oku.
- Segment’e göre aralık: İlk kampta daha dar, ilerledikçe genişleyebilir.
