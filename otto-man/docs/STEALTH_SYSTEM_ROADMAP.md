# Zindan Stealth Sistemi – Yol Haritası

Bu doküman, zindanlara **gizlilik / suikast / alarm** oynanışının faz faz uygulanması için referans notudur.  
Uygulama sırası: **Faz 1 → Faz 2 → Faz 3 → Faz 4**. Her faz bitince oynanabilir test yapılır; sonraki faza geçilir.

---

## 1. Mevcut Durum Özeti

| Parça | Dosya / konum | Durum |
|-------|----------------|--------|
| Dairesel algılama | `enemy/base_enemy.gd` → `get_nearest_player_in_range()` | Aktif; `stats.detection_range` (~300 px) |
| Yönlü algılama (duvar yok) | `enemy/spearman/spearman_enemy.gd` → `get_player_in_front()` | Sadece spearman; LOS yok |
| Oyuncu eğilme | `player/states/ground/crouch_state.gd` | Crawl hızı, item bonusu (`Tünel Ustası`) |
| Segment run state | `autoload/DungeonRunState.gd` | Kurtarma, challenge birikimi; **alarm/stealth yok** |
| Kurtarma odası şansı | `scenes/level_generator.gd` | Garanti 1 köylü + 1 cariye dead-end; ekstra ~%12 |
| Boss odası | `scenes/boss_room_controller.gd` | Arenaya girince kapı kapanır; boss yenilmeden çıkış yok |
| Ambient (oturma) | `enemy/basic/basic_enemy.gd` | Oyuncu ~180 px yakında değilse patrol'da oturabilir |

**Eksik:** Görüş konisi, duvar arkası LOS, segment alarmı, gürültü, sessiz öldürme, stealth ödülleri, boss atlama.

---

## 2. Hedef Oynanış (Özet)

Oyuncu zindanda iki yol seçebilir:

1. **Stealth yolu** — Zamanlama, gizlilik, arkadan yaklaşma, bayıltma; düşmanlar **görüş konisi** ile algılar (duvar arkası görünmez).
2. **Alarm yolu** — Oyuncu yeterince uzun süre görüşe girerse **tüm segment alarm** moduna geçer; düşmanlar mevcut **dairesel algılama** kullanır, stealth taktikleri zayıflar.

Stealth başarılı segmentlerde **ek ödüller**; boss atlama **farklı risk profili** (tam cezasız değil).

---

## 3. Mimari Kararlar

### 3.1 StealthManager (autoload)

Yeni autoload: `autoload/StealthManager.gd` (veya `DungeonRunState` genişletmesi — tercih: **ayrı autoload**, sorumluluk ayrımı).

```gdscript
# Taslak API
var segment_alarm: bool = false
var stealth_score: int = 0          # sessiz kill, keşfedilmeden geçilen alan
var suspicion_events: int = 0

func reset_for_segment() -> void
func raise_alarm(reason: String = "") -> void
func is_stealth_mode() -> bool      # segment_alarm == false
func add_stealth_score(points: int) -> void
func get_rescue_chance_multiplier() -> float  # Faz 2+
```

- **Segment başında** `reset_for_segment()` (`level_generator` veya segment yüklemede).
- **Alarm bir kez tetiklenir**, segment sonuna kadar kalır (geri dönüş yok).
- `DungeonRunState` ile konuşur: rescue bonus, kamp çıkışı, boss skip koşulları.

### 3.2 StealthPerception (bileşen)

Yeni dosya: `components/stealth_perception.gd` — düşman node'una child veya `@onready` referans.

Sorumluluklar:

- Görüş **konisi** (açı + menzil + yön = `enemy.direction`)
- **Line-of-sight** raycast (`CollisionLayers.WORLD`)
- Gürültü kontrolü (Faz 2: `PlayerNoiseEmitter` ile)
- Çıktı: `VisibilityLevel` → `NONE` / `SUSPICIOUS` / `DETECTED`
- Alarm modunda: `get_nearest_player_in_range()` fallback (mevcut daire)

**Tek giriş noktası:** `BaseEnemy` içinde `target = _resolve_target()` → stealth moduna göre perception veya daire.

### 3.3 PlayerNoiseEmitter

Yeni dosya: `components/player_noise_emitter.gd` veya `player.gd` içinde küçük bölüm.

| Oyuncu durumu | Noise (taslak) |
|---------------|----------------|
| Idle / Walk | 0 |
| Run | 80 px |
| Crouch crawl | 0 |
| Saldırı (light) | 40 px |
| Saldırı (heavy) | 120 px |
| Düşmana çarpma | 100 px |

Düşman `noise_radius` içindeyse şüphe sayacı artar (görüşte değilse bile).

### 3.4 Algılama durum makinesi (düşman başına)

```
NONE ──(koni+LOS kısa)──► SUSPICIOUS ──(süre doldu)──► DETECTED
                              │                            │
                              └──(görüş kaybı)──► NONE      └──► StealthManager.raise_alarm()
```

| Aşama | Düşman davranışı | Segment etkisi |
|-------|------------------|----------------|
| NONE | Patrol / ambient | — |
| SUSPICIOUS | Dur, bak, yavaşla | — |
| DETECTED (1+ düşman) | Chase | `raise_alarm()` → tüm segment alarm |

**Taslak süreler:** Şüphe eşiği ~1.2 sn tam görüşte; alarm ~2.0 sn veya ilk `DETECTED` anında (Faz 1 testinde ayarlanır).

### 3.5 Debug overlay (Faz 1 zorunlu)

`StealthPerception` veya ayrı `StealthDebugDraw.gd`:

- Yeşil koni = normal mod
- Kırmızı daire = alarm modu
- Sarı = şüpheli düşman

`project.godot` veya debug flag ile açılır; release'te kapalı.

---

## 4. Denge Parametreleri (Taslak)

| Parametre | Değer | Not |
|-----------|-------|-----|
| Koni açısı | 75° | |
| Koni menzili | 240 px | Mevcut 300'den kısa |
| Şüphe süresi | 1.2 sn | Tam LOS |
| Alarm tetik | İlk DETECTED | Veya global şüphe birikimi |
| Stealth rescue bonus | %12 → %28 | `level_generator` rescue_chance |
| Boss skip altın | Boss loot'un %0–40'ı | Faz 4 |
| Boss skip sonraki segment | +1 enemy_count_offset | “Zindan hatırlıyor” |

Sayılar playtest ile güncellenir; bu tablo referans.

---

## 5. Faz Faz Uygulama

### Faz 1 — Çekirdek algılama + alarm (MVP)

**Durum:** ✅ Uygulandı (2026-06-13). BasicEnemy pilot; debug çizimi debug build'de açık.

**Hedef:** Bir zindan segmentinde BasicEnemy görüş konisi + duvar LOS + şüphe → segment alarm + alarmda dairesel algılama. Oynanabilir, debug çizimi açık.

#### 1.1 StealthManager autoload

- [ ] `autoload/StealthManager.gd` oluştur
- [ ] `project.godot` autoload kaydı
- [ ] `segment_alarm`, `reset_for_segment()`, `raise_alarm()`, signal `alarm_raised`
- [ ] Segment yüklenince reset: `level_generator.gd` veya mevcut segment init noktası

#### 1.2 StealthPerception bileşeni

- [ ] `components/stealth_perception.gd`
- [ ] `can_see_player(player) -> bool` (koni + LOS raycast)
- [ ] `update_suspicion(delta) -> VisibilityLevel`
- [ ] Alarm modunda `query_player_alarm() -> Node2D` (mesafe tabanlı)

#### 1.3 BaseEnemy entegrasyonu

- [ ] `base_enemy.gd`: `handle_behavior` içinde target çözümü stealth'e bağla
- [ ] Alarm sinyali: perception `DETECTED` → `StealthManager.raise_alarm()`
- [ ] Mevcut `get_nearest_player_in_range()` alarm fallback olarak kalsın

#### 1.4 BasicEnemy pilot

- [ ] `basic_enemy.gd`: patrol/chase alarm modunda eski davranış
- [ ] Şüpheli state: kısa durma / bakma (minimal anim veya idle)
- [ ] **Sadece BasicEnemy** — diğer tipler Faz 1 sonrası listeye alınır

#### 1.5 Debug

- [ ] Koni + alarm dairesi çizimi
- [ ] Konsol log: alarm nedeni, hangi düşman tetikledi

#### Faz 1 test checklist

- [ ] Düşman arkasından yürüyünce algılanmıyor
- [ ] Duvar arkasında durunca algılanmıyor
- [ ] Önünde 1.2+ sn durunca alarm
- [ ] Alarm sonrası arkadan yaklaşınca da chase
- [ ] Segment bitince alarm sıfırlanıyor

#### Faz 1 dokunulacak dosyalar

```
autoload/StealthManager.gd          (yeni)
components/stealth_perception.gd    (yeni)
enemy/base_enemy.gd                 (güncelle)
enemy/basic/basic_enemy.gd          (güncelle)
scenes/level_generator.gd           (segment reset)
project.godot                       (autoload)
```

---

### Faz 2 — Oyuncu stealth hissi + ödül kancaları

**Durum:** ✅ Uygulandı (2026-06-13). Gürültü, HUD, rescue bonus, şüphe işareti.

**Hedef:** Gürültü, UI geri bildirimi, stealth segmentte kurtarma şansı artışı.

#### 2.1 PlayerNoiseEmitter

- [ ] Run / crouch / saldırı noise değerleri
- [ ] `StealthPerception` noise ile şüphe artışı (LOS olmadan)

#### 2.2 UI / feedback

- [ ] Segment alarm göstergesi (küçük ikon veya kenar vinyet)
- [ ] İsteğe bağlı: düşman şüpheli iken `!` veya bakış animasyonu

#### 2.3 Kurtarma odası bonusu

- [ ] `level_generator.gd`: `rescue_chance` — `StealthManager.is_stealth_mode()` ise çarpan
- [ ] `DungeonRunState` ile uyum: `guaranteed_rescue_next` ayrı kalır

#### 2.4 Stealth score (temel)

- [ ] Alarm tetiklenmeden segment tamamlanınca `stealth_score += N`
- [ ] Henüz ödül bağlama zorunlu değil; log / debug yeterli

#### Faz 2 test checklist

- [ ] Koşarak düşman yakınından geçince şüphe / alarm
- [ ] Eğilerek geçince sessiz
- [ ] Stealth segmentte rescue dead-end oranı hissedilir artış (istatistik veya debug)
- [ ] Alarm UI net görünüyor

#### Faz 2 dokunulacak dosyalar

```
components/player_noise_emitter.gd  (yeni)
player/player.gd                    (noise hook)
player/states/ground/run_state.gd   (noise)
player/states/ground/crouch_state.gd
scenes/level_generator.gd           (rescue_chance)
ui/                                 (alarm göstergesi — yeni veya mevcut HUD)
```

---

### Faz 3 — Combat entegrasyonu + item iskeleti

**Durum:** ✅ Uygulandı (2026-06-13). Backstab, bayıltma, 2 stealth item, heavy + spearman.

**Hedef:** Arkadan vuruş, bayıltma, sessiz öldürme alarm tetiklemez; 1–2 stealth item.

#### 3.1 Backstab / stealth kill

- [ ] Arkadan saldırı tespiti: oyuncu `direction` vs düşman `direction`
- [ ] Koşul: `StealthManager.is_stealth_mode()` ve düşman şüpheli değil / alarm yok
- [ ] Yüksek çarpan veya bayıltma; alarm modunda normal hasar
- [ ] Sessiz öldürme: `raise_alarm` tetiklenmez (gürültülü dövüş tetikler — tasarım kararı)

#### 3.2 Bayıltma (knockout) — isteğe bağlı alt sistem

- [ ] Yeni state veya mevcut hurt üzerine `fainted` (kısa süre hareketsiz)
- [ ] Baygın düşmana taşıma / bağlama ertelenebilir; Faz 3'te sadece yerde bayılma yeterli

#### 3.3 Stealth item'ları (ilk set)

| Item | Etki |
|------|------|
| Sessiz ayakkabı | Run noise −%50 |
| Gölge pelerini | Koni menzilinde −%20 (düşman perception'a debuff) |
| Bayıltma iğnesi / bomba | Küçük alan bayıltma (consumable) |
| Mevcut `Tünel Ustası` | Crawl hızı — stealth ailesinde kalır |

- [ ] Item effect hook: `ItemManager` veya mevcut item pattern
- [ ] Noise ve perception modifier'ları item'dan okunabilir olsun

#### 3.4 Diğer düşman tiplerine yayılım

Öncelik sırası (zindan spawn sıklığına göre ayarlanabilir):

1. [ ] `heavy_enemy.gd`
2. [ ] `spearman_enemy.gd` (mevcut dikdörtgen → perception'a taşı)
3. [ ] `firemage_enemy.gd`, `summoner_enemy.gd`
4. [ ] `flying_enemy.gd`, `hunter_enemy.gd` (özel: 360° veya geniş koni — ayrı tasarım)

#### Faz 3 test checklist

- [ ] Arkadan crouch + light attack tek düşmanı stealth modda indiriyor
- [ ] Alarm modda backstab bonusu yok / az
- [ ] Gürültülü combo alarm tetikliyor
- [ ] En az 1 stealth item noise veya perception'ı değiştiriyor

---

### Faz 4 — Boss atlama, kamp çıkışı, ekonomi

**Durum:** ✅ Uygulandı (2026-06-13). Final kampta gizli çıkış; boss skip ceza/ödül paketi.

**Hedef:** Alarm başlatılmamış run'da boss'u atlayarak çıkış; ödül/ceza paketi; stealth run meta'sı tamamlanır.

#### 4.1 Kamp / boss stealth çıkışı

- [x] Final kampta boss odası yanında **gizli çıkış kapısı** (sadece `!segment_alarm` ve son segment)
- [x] `boss_room_controller.gd` veya `CampScene.gd` entegrasyonu
- [x] Kapı görünürlüğü: stealth run'da hint (ışık, NPC diyalog, zayıf parıltı)

#### 4.2 Ödül / ceza paketi (boss skip)

| Kazanç | Kayıp |
|--------|-------|
| Boss dövüşü yok, zaman kazancı | Boss scatter altını yok veya az |
| Stealth mastery / başarım | `DungeonProgress.record_clear` farklı veya mastery düşük |
| Mevcut kurtarılan köylü/cariye korunur | Sonraki segment `enemy_count_offset +1` (opsiyonel) |

- [x] `DungeonRunState` veya `DungeonProgress` alanları: `boss_skipped`, `stealth_clear`
- [x] Altın: `get_boss_scatter_gold_total()` stealth çıkışta uygulanmaz

#### 4.3 Minigame kolaylığı (opsiyonel)

- [x] Stealth segmentte kurtarma minigame zorluk çarpanı < 1.0
- [x] Minigame kodu nerede ise oraya `StealthManager` hook

#### 4.4 Segment çıkış bonusu

- [x] Alarm yok + stealth_score > 0 → segment sonu ekstra altın veya `gold_multiplier_accumulated` küçük bonus
- [x] Challenge kapıları ile uyum: stealth bonus challenge gold'una **ek** mi **çarpan** mı — playtest

#### Faz 4 test checklist

- [ ] Stealth run: boss'a girmeden kamp çıkışı ile run tamamlanabiliyor
- [ ] Alarm run: gizli kapı kapalı / görünmez
- [ ] Boss dövülünce tam loot; skip'te fark net
- [ ] Ekonomi exploit yok (tekrar farm)

#### Faz 4 dokunulacak dosyalar

```
scenes/boss_room_controller.gd
scenes/CampScene.gd
scenes/door.gd
autoload/DungeonRunState.gd
autoload/DungeonProgress.gd (varsa)
autoload/StealthManager.gd
```

---

## 6. Sahne / Godot Editör Notları

Agent **`.tscn` / `.tres` dosyalarına yazmaz** (workspace kuralı). Aşağıdakiler editörde elle yapılır:

| Görev | Editör adımı |
|-------|----------------|
| StealthPerception child | BasicEnemy sahnesine boş Node2D + script (veya runtime `add_child`) |
| Debug draw | Enemy altına `Node2D` + `draw_*` override |
| Gizli kamp kapısı | Camp / boss chunk sahnesine ikinci `Door` node, başlangıçta `visible=false` |
| Alarm UI | Player UI CanvasLayer altına kontrol |

Script ile runtime ekleme tercih edilirse `.tscn` dokunulmaz.

---

## 7. Riskler ve Kaçınılacaklar

1. **Kapsam patlaması** — Tüm düşmanları Faz 1'de yapma; BasicEnemy pilot yeterli.
2. **Performans** — Çok düşmanda raycast: throttle (her 2–3 frame) veya sadece yakın düşmanlar LOS hesaplasın.
3. **Boss skip exploit** — Skip = düşük ödül + meta ceza; tam cezasız olmasın.
4. **Combo çakışması** — Backstab sadece stealth mod + fark edilmemiş düşman; juggle ayrı kalsın.
5. **Kopya kod** — Algılama mantığı sadece `StealthPerception` + `BaseEnemy`; spearman dikdörtgeni oraya taşınsın.

---

## 8. Ertelenen / İleride

- Köşe “kırpılmış” koni (duvar kenarında kısmi görüş)
- Gizlenme noktaları (barrel, gölge tile)
- Düşmanlar arası “haber verme” (ölü beden bulma)
- Stealth başarım / istatistik ekranı
- Çok oyunculu (yok say)

---

## 9. Uygulama Sırası (Tek Bakış)

```
Faz 1: StealthManager + StealthPerception + BasicEnemy + alarm + debug
         ↓ test
Faz 2: Noise + UI + rescue_chance bonus
         ↓ test
Faz 3: Backstab + bayıltma + item + diğer düşmanlar
         ↓ test
Faz 4: Boss skip kapısı + ekonomi + minigame hook ✅
         ↓ test + denge pass
```

---

## 10. İlgili Mevcut Dokümanlar

- `docs/DUNGEON_RESCUE_PLAN.md` — Kurtarma odası akışı (stealth rescue bonus buraya bağlanır)
- `docs/CHALLENGE_DOORS_PLAN.md` — Segment zorluk birikimi (boss skip cezası ile uyum)
- `docs/DUNGEON_CAMP_PLAN.txt` — Kamp geçişleri (gizli çıkış kapısı)
- `docs/DUNGEON_IMPROVEMENTS.txt` — Genel zindan iyileştirmeleri

---

*Oluşturulma: 2026-06-13 — Stealth sistem tasarım oturumu. Uygulama başlamadan önce bu dosyayı güncel tut.*
