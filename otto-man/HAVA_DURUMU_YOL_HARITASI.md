# Hava Durumu & Rüzgar Sistemi – Yol Haritası

Bu doküman, köy ve orman sahnelerinde **yağmur**, **rüzgar**, **deniz ripple**, **yer splash** ve **ağaç/çalı sallanması** için teknik yol haritasını tanımlar. Hava durumu **Autoload** üzerinden oyun içi zamana bağlı tutulur; sahne değişince (köy ↔ orman) aynı hava devam eder.

---

## 1. Genel Tasarım Özeti

| Özellik | Kaynak | Davranış |
|--------|--------|----------|
| Yağmur | Rastgele + storm event | Rastgele hafif/normal/yoğun; storm sırasında yoğun yağış |
| Rüzgar | Bağımsız + storm | Hafif/güçlü; storm’da hız artar, yağmur damla açısına etki eder |
| Storm event | VillageManager | `severe_storm` aktifken: yoğun yağmur + güçlü rüzgar + bulut hızı artar |
| Süre | TimeManager | Oyun içi dakika/saat; ormanda yağmura yakalanan oyuncu köye dönünce hava değişmiş olabilir |

---

## 2. Faz 0: WeatherManager (Autoload)

**Amaç:** Tek merkezden hava durumu; oyun içi zamana göre güncellenir, tüm sahneler aynı değerleri kullanır.

### 2.1 Sorumluluklar

- **Rain:** `rain_intensity` (0.0 = yok, 1.0 = sağanak); geçişler hafif ↔ yoğun (lerp ile).
- **Storm bağlantısı:** VillageManager’da `severe_storm` event’i aktifse → rain_intensity yüksek (örn. 0.85–1.0) ve storm süresince öyle kalır.
- **Rastgele yağmur:** Storm yokken belirli aralıklarla (oyun içi süre) “yağmur başlat/bitir” ve intensity’i kademeli değiştir.
- **Wind:** `wind_strength` (0.0–1.0), `wind_direction_angle` (derece, örn. 0 = sağa, 90 = aşağı). Storm’da rüzgar güçlü; rastgele hava da hafif rüzgar olabilir.
- **Zaman:** TimeManager’dan gün/dakika dinleyerek süreleri oyun içi tutmak (örn. yağmur 20–40 oyun dakikası).

### 2.2 Sinyaller (öneri)

- `weather_changed()` → sahneler rain/wind değerlerini günceller.
- İsteğe: `rain_intensity_changed(value)`, `wind_changed(strength, angle)`.

### 2.3 Storm entegrasyonu

- **Seçenek A:** VillageManager’a `event_started(ev: Dictionary)` ve `event_ended(ev: Dictionary)` sinyalleri eklenir; WeatherManager bu sinyallere bağlanır, `ev["type"] == "severe_storm"` ise storm moduna geçer/çıkar.
- **Seçenek B:** WeatherManager, TimeManager’ın `day_changed` sinyalinde VillageManager.events_active içinde `"severe_storm"` var mı diye bakar; varsa storm modu.

Öneri: **Seçenek A** (sinyal) daha temiz; event bitişi gün sonunda olduğu için `_update_events_for_new_day` içinde event sildiğinde `event_ended` emit edilir.

### 2.4 Dosya / Autoload

- Yeni script: `autoload/WeatherManager.gd`
- `project.godot` → `[autoload]` içine `WeatherManager="*res://autoload/WeatherManager.gd"` eklenir.

---

## 3. Faz 1: Yağmur Partikül Sistemi

**Amaç:** Havada yağmur damlaları; şiddet ve rüzgar yönüne göre miktar ve açı.

### 3.1 Teknik

- **GPUParticles2D** (tercih) veya CPUParticles2D.
- Tek bir “rain” sahnesi/prefab: hem köy hem orman bu sahneyi kullanır.
- Parametreler (script veya export ile WeatherManager’dan):
  - `amount` / `emitting` → rain_intensity’e göre (0 ise emit yok, 1’e yakın max).
  - Hız vektörü: düşey + rüzgar bileşeni → `wind_direction_angle` ve `wind_strength` ile yön ve yatay sapma.
- Damla görseli: İnce dikey çizgi texture (2–4 px geniş, 20–40 px yüksek, alpha gradient). Sen çizebilirsin veya placeholder beyaz çizgi.

### 3.2 Storm davranışı

- Storm aktifken: rain_intensity zaten yüksek (WeatherManager’dan); ekstra olarak partikül hızı/rüzgar bileşeni artırılabilir (aynı wind_strength ile).

### 3.3 Sahne yapısı

- Örn. `village/scenes/RainEffect.tscn` (veya `effects/RainEffect.tscn`) → root’ta Node2D, altında GPUParticles2D; script `RainController.gd` WeatherManager’ı dinler ve amount/direction’ı set eder.
- Köy ve orman sahnelerinde bu scene instance edilir; CanvasLayer veya ParallaxBackground’a yakın bir katmanda (yağmur önde veya arkada tercihe göre).

---

## 4. Faz 2: Gökyüzü ve Bulutlar

**Amaç:** Yağmurda gökyüzü kararır; storm’da bulutlar hızlanır (rüzgar hissi).

### 4.1 Gökyüzü rengi

- **DayNightController** zaten sky gradient ve BackgroundTint’i güncelliyor.
- Yağmur overlay: WeatherManager.rain_intensity’e göre ek bir koyu/gri ton (lerp). İki yol:
  - DayNightController’a `rain_tint` veya `weather_darken` parametresi eklenir; WeatherManager’dan set edilir veya DayNightController WeatherManager’ı dinler.
  - Veya ParallaxBackground altında ek bir CanvasModulate (sadece sky layer’ları etkileyecek şekilde layer/priority ile) yağmur rengi uygular.

### 4.2 Bulut hızı

- **CloudManager** veya **cloud.gd**: Bulutların `current_speed` değeri WeatherManager.wind_strength ile scale edilir (örn. `speed * (1.0 + wind_strength * 0.5)`). Storm’da wind_strength yüksek olduğu için otomatik hızlanır.
- Yeni spawn edilen bulutlara hızı CloudManager veriyor; mevcut bulutlar için cloud.gd içinde `_process`’te global wind_strength okuyup hızı güncelleyebilir (veya CloudManager sinyal ile “wind_changed” dinleyip child cloud’lara iletebilir).

### 4.3 Bulut rengi (isteğe)

- Yağmurda bulutları koyulaştırmak: CloudManager spawn ederken modulate’ı WeatherManager’dan alır; veya tüm bulutların parent’ına bir CanvasModulate ile gri ton verilir.

---

## 5. Faz 3: Deniz Üzerinde Ripple (Partikül – Seçenek C)

**Amaç:** Köy sahnesindeki deniz (Water sprite) üzerinde damla düşmüş gibi çemberler.

### 5.1 Teknik

- **GPUParticles2D** (veya CPUParticles2D): Water node’unun üstünde (z_index), sadece su bölgesinde emit.
- Texture: Tek bir “ripple” (içi boş halka, yumuşak alpha). Sen çizebilirsin.
- Emit bölgesi: Water’ın global rect’i veya bir RectangleShape2D/Area2D ile sınırlı; rastgele pozisyonda spawn.
- Miktar: WeatherManager.rain_intensity’e göre (yağmur yokken 0, yoğunken sık).
- Kısa ömür: Scale 0→1→0 veya alpha fade; böylece “damla düştü” hissi.

### 5.2 Konum

- VillageScene’de Water’ın parent’ına (veya ParallaxBackground’a) “WaterRipples” node’u eklenir; içinde partikül sistemi. Script ile rain_intensity ve emit bölgesi güncellenir.

---

## 6. Faz 4: Yer Splash (Partikül)

**Amaç:** Yere düşen yağmur için splash; partikül ile, puddle ertelendi.

### 6.1 Teknik

- **GPUParticles2D**: Yer seviyesinde (örn. zemin collision’a yakın bir yükseklik) spawn; hız aşağı, ömür kısa, “splash” texture (küçük veya çizgi).
- Spawn alanı: Kamera görüş alanı veya tüm zemin genişliği; görünür bölgede rastgele x.
- Miktar: rain_intensity’e göre.
- Görsel: Küçük splash sprite (sen çizebilirsin – ince “v” veya birkaç damla); partikül texture olarak kullanılır.

### 6.2 Sahne

- Köy/orman root’a “GroundSplash” benzeri node; partikül + küçük script (WeatherManager’dan intensity okuyup amount ayarlar).

---

## 7. Faz 5: Rüzgar – Ağaç ve Çalı Sallanması

**Amaç:** Yağmurdan bağımsız rüzgar; arka plandaki ağaç ve çalı spriteleri hafif/güçlü sallanır.

### 7.1 Teknik

- **Sway script:** Her sallanacak sprite (ağaç, çalı) için pivot **altta** olacak şekilde (Sprite2D’de offset veya anchor); `rotation` = `sin(TIME * frekans) * wind_strength * genlik`.
- WeatherManager’dan `wind_strength` (ve isteğe `wind_direction_angle`) okunur; storm’da otomatik güçlü.
- Grup: “swayable” veya “wind_sway”; tek bir “WindSwayController” tüm swayable’lara erişip güncelleyebilir veya her biri kendi script’inde WeatherManager’ı okur.

### 7.2 Performans

- Çok sayıda ağaç/çalı varsa hepsine bireysel script yerine: ortak bir script (örn. `Swayable.gd`) sadece rotation günceller; frekans ve genlik export ile hafif farklılaştırılabilir (doğal görünüm).

### 7.3 Sahne entegrasyonu

- VillageScene (ve orman) içindeki ağaç/çalı Sprite2D’lere bu script eklenir; pivot alt ortada olacak şekilde ayarlanır.

---

## 8. Faz 6: Uçuşan Yapraklar

**Amaç:** Rüzgar hissini güçlendirmek; yaprak partikülleri.

### 8.1 Teknik

- **GPUParticles2D** (veya CPUParticles2D): Yaprak texture’ları (1–3 varyasyon); hız ve yön WeatherManager.wind_strength ve wind_direction_angle’a göre.
- Miktar: wind_strength’e bağlı (rüzgar yokken az/ya da 0, storm’da çok).
- Yerçekimi + rüzgar kuvveti ile parabolic hareket; hafif dönme (rotation) eklenebilir.

### 8.2 Görsel

- Birkaç yaprak sprite’ı (sen çizebilirsin); partikül sistemi bunlardan rastgele seçer veya tek texture yeterli.

### 8.3 Sahne

- Köy ve ormanda ayrı bir “FlyingLeaves” node’u; script WeatherManager’ı dinleyip amount ve velocity’yi ayarlar.

---

## 9. Faz 7: Orman Sahnesi ve Storm Event Kancası

### 9.1 Orman

- Aynı **WeatherManager** kullanılır; orman sahnesinde:
  - RainEffect (Faz 1) instance edilir.
  - Gökyüzü/renk (Faz 2) ormanın kendi sky/BackgroundTint’i varsa aynı mantıkla bağlanır.
  - Deniz yoksa Water Ripple (Faz 3) ormanda yok.
  - Ground Splash (Faz 4) ormanda da olur.
  - Ağaç/çalı sallanması (Faz 5) ormandaki sprite’lara aynı Swayable script’i eklenir.
  - Uçuşan yapraklar (Faz 6) ormanda da kullanılır.

### 9.2 Storm event kancası

- **VillageManager:** `_apply_event_effects(ev)` içinde `ev["type"] == "severe_storm"` ise WeatherManager’a “storm started” bildirimi (örn. `WeatherManager.set_storm_active(true, ev["level"])`).
- `_remove_event_effects(ev)` içinde `ev["type"] == "severe_storm"` ise `WeatherManager.set_storm_active(false)`.
- İsteğe: VillageManager’dan `event_started` / `event_ended` sinyali emit edilir; WeatherManager bu sinyallere bağlanır, böylece tekrar kodu VillageManager’da minimum olur.

---

## 10. Uygulama Sırası (Özet)

| Sıra | Faz | İş | Çıktı |
|------|-----|----|-------|
| 1 | 0 | WeatherManager Autoload + TimeManager + VillageManager storm bağlantısı | rain_intensity, wind_strength/direction, storm modu |
| 2 | 1 | Rain partikül sahnesi + RainController (wind açısı dahil) | Köyde/ormanda yağmur |
| 3 | 2 | DayNightController/BackgroundTint yağmur karartması; CloudManager/cloud hızı rüzgara göre | Gökyüzü + bulut tepkisi |
| 4 | 3 | Deniz ripple partikül (köy Water üstü) | Denizde damla çemberleri |
| 5 | 4 | Yer splash partikül | Zeminde splash |
| 6 | 5 | Swayable script + ağaç/çalıya uygulama | Rüzgarda sallanma |
| 7 | 6 | Uçuşan yaprak partikülü | Yapraklar |
| 8 | 7 | Orman sahnesine aynı efektler; VillageManager storm → WeatherManager | Tüm sahneler senkron |

---

## 11. Görsel Asset Özeti (Senin Çizmen Gerekenler)

| Asset | Kullanım | Not |
|-------|----------|-----|
| Yağmur damlası | Rain partikül texture | İnce dikey çizgi, 2–4×20–40 px, alpha |
| Ripple (halka) | Deniz ripple partikül | İçi boş daire, yumuşak kenar |
| Splash | Yer splash partikül | Küçük “v” veya damlacık formu |
| Yaprak (1–3) | Uçuşan yaprak partikül | Farklı boyut/açılar isteğe |

Puddle (su birikintisi) bu yol haritasında **ertelendi**; ileride ayrı bir faz olarak eklenebilir.

---

## 12. Notlar

- **Oyun içi süre:** TimeManager zaten 1 oyun dakikası = 2.5 gerçek saniye kullanıyor; WeatherManager yağmur sürelerini oyun dakikası cinsinden tutarak ormanda geçen süreyle köye dönüşte havanın değişmesi doğal kalır.
- **Test:** Dev console’dan `trigger_world_event severe_storm high` ile storm tetiklenebilir; WeatherManager storm’u algılayınca yoğun yağmur + güçlü rüzgar otomatik uygulanır.

Bu yol haritasına göre ilk adım **Faz 0 (WeatherManager)** ile başlayabilir; ardından Faz 1 (yağmur partikülü) gelir.
