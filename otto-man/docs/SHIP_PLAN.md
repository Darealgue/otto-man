# Otto-man — Bitirme Planı (Ship Plan)

> **Oluşturulma:** 2026-06-29  
> **Amaç:** Projeyi oynanabilir “bitmiş” release’e taşımak.  
> **Durum:** `[ ]` bekliyor · `[~]` devam · `[x]` bitti

---

## Mevcut durum özeti

**Çalışan çekirdek loop:** Köy → orman / zindan / dünya haritası → güvenli dönüş → cariye & görevler → köy gelişimi

**Güçlü (bitmiş sayılır):**
- Save/load (köy, dünya, görevler, tutorial)
- Zindan + kamp + challenge kapıları + segment modifier’lar
- Kurtarma odaları + «Kurtarılanın Yolu» cariye zinciri
- Item set sinerjileri
- Dünya haritası seyahat + olaylar + erzak/çöküş
- Stealth (temel; tüm düşman tiplerinde değil)
- Living world simülasyonu

**Devre dışı bayraklar:**
| Bayrak | Dosya | Etki |
|--------|-------|------|
| `BOSS_FIGHTS_ENABLED = true` | `boss_room_registry.gd` | Orb Scatter boss aktif |
| `DUNGEON_BOSS_ARENAS_ENABLED = true` | `scenes/level_generator.gd` | Son segment mini-boss arena |
| `SoundManager` | `autoload/SoundManager.gd` | Procedural SFX (click/hurt/death/kapı) |

---

## Aşama 1 — Oynanabilir release (öncelik)

| # | Madde | Durum | Efor | Not |
|---|--------|-------|------|-----|
| 1.1 | **Boss:** Orb Scatter açık (Tepegöz kapalı; ileride scatter varyantları) | `[x]` | — | `boss_room_registry.gd` |
| 1.2 | **Görev ödül/ceza uygulaması** — `wood`/`stone`/`food`/`reputation` vb. gerçek etki | `[x]` | M | `MissionManager._apply_reward/_apply_penalty` |
| 1.3 | **Köy tutorial C0–C4** — zindan tutorial sonrası akış | `[x]` | M | Skip-tutorial yolu hâlâ köy tutorial'ını atlar (bilinçli) |
| 1.4 | **Worker save/load sırası** — kayıtlı kimlik/görünüm `_ready` öncesi | `[x]` | M | `VillageManager._add_new_worker`, `Worker.gd` |
| 1.5 | **Temel SFX** — UI, hasar, kapı, ölüm | `[x]` | L | Procedural synth; gerçek asset sonra `_EXTERNAL_PATHS` |

---

## Aşama 2 — Loop derinliği

| # | Madde | Durum | Efor |
|---|--------|-------|------|
| 2.1 | Zindan mini-event odaları (tüccar + lanet) | `[x]` | M |
| 2.2 | Seyyah → gerçek görev | `[x]` | S |
| 2.3 | `pending_attacks` — oynanabilir segment veya net otomatik UI | `[x]` | L |
| 2.4 | Kapı anahtarı (`door.gd`) | `[x]` | S |
| 2.5 | Level boss arena (`DUNGEON_BOSS_ARENAS_ENABLED`) | `[x]` | M |
| 2.6 | Stealth — kalan düşman tipleri | `[x]` | M |

---

## Aşama 3 — İçerik & polish

| # | Madde | Durum | Efor |
|---|--------|-------|------|
| 3.1 | Placeholder görseller → sprite | `[x]` | M |
| 3.2 | Bina upgrade zinciri | `[x]` | M |
| 3.3 | Fraksiyon / landmark / mastery relic | `[x]` | M–L |
| 3.4 | LLM kapalı el yapımı haber şablonları | `[x]` | S |
| 3.5 | Rol görevleri + cariye hikâye zincirleri | `[x]` | L |

---

## Aşama 4 — Tam ürün (uzun vade)

- Köy savunması oynanabilir segmenti `[x]` — `village_battlesim` + köyde «Savaşa Katıl»
- Mevsim / kış döngüsü
- Köy festivali `[x]` — `VillageManager.village_festival` + düşük moral tetikleyicisi
- NPC-NPC diyalog `[x]` — `VillageNpcAmbientDirector` + 10 el yapımı sohbet (tr/en)
- Çoklu dil `[~]` — tr/en CSV; ayarlar menüsü; ambient + demo metinleri eklendi
- Resmi demo paketi `[~]` — `DemoPackConfig` + `docs/DEMO_PACK.md`

---

## Kritik envanter (referans)

| Sistem | Sorun | Dosya |
|--------|-------|-------|
| Boss | Kapalı | `boss_room_registry.gd`, `CampScene.gd` |
| Ses | Procedural SFX | `SoundManager.gd` |
| Görev ekonomisi | Print-only ödüller | `MissionManager.gd` |
| Köy tutorial | Kısmen | `TutorialManager.gd` |
| Köy savunması | Oynanabilir segment + otomatik yedek | `VillageDefenseBattleRunner`, `WorldManager` |
| Diplomasi passage | ✓ geçiş hakkı | `DiplomacyManager` + `WorldManager._passage_rights` |
| Seyyah | Dinamik görev | `MissionManager.offer_traveler_mission` |

---

## İlgili dokümanlar

- `docs/FEEDBACK_BUILD_ROADMAP.md` — içerik fikir listesi
- `tutorial/TUTORIAL2_ROADMAP.txt` — köy tutorial detay
- `docs/STEALTH_SYSTEM_ROADMAP.md`
- `docs/LIVING_WORLD_PLAN.md`
- `BATTLE_STORY_TODO.md`

---

## Çalışma günlüğü

### 2026-06-29
- Ship plan oluşturuldu (bu dosya).
- Tepegöz devre dışı; harita erzak/çöküş sistemi eklendi.
- **Aşama 1.2 tamamlandı:** Görev ödül/ceza — köy kaynakları, itibar, istikrar, oran modifier’ları, asker kaybı.
- **Aşama 1.1 tamamlandı:** Orb Scatter boss aktif; kamp kapısında isim gösteriliyor.
- **Aşama 1.4 tamamlandı:** Köylü restore — kayıtlı `npc_info` + `appearance` spawn öncesi yükleniyor.
- **Aşama 1.3:** C0–C4 akışı mevcut (mentor inbox, UI gate, anında inşaat, digest). Skip-tutorial hâlâ köy tutorial'ını atlıyor.
- **Sıradaki:** Demo export veya kalan i18n.

### 2026-06-29 (devam 12)
- **1.5 Temel SFX:** `SoundManager` procedural synth (click, hurt, death, door); oyuncu/kapı hook'ları; SFX/Music bus otomatik; ayarlar senkronu.
- **Diplomasi geçiş hakkı:** `WorldManager.grant_passage_rights` — hedef köy hex'lerinde %28 seyahat indirimi, 7 gün.

### 2026-06-29 (devam 11)
- **NPC–NPC ambient diyalog:** `VillageNpcAmbientCatalog` (10 sohbet, bağlam etiketleri); `VillageNpcAmbientDirector` + konuşma balonu; oyuncu yakınında idle köylüler.
- **Demo paketi iskeleti:** `DemoPackConfig` autoload (gün sınırı + teaser); `docs/DEMO_PACK.md` export rehberi.

### 2026-06-29 (devam 10)
- **Ölüm sonrası mentor diyalogu:** `DeathMentorBrief` + MentorInbox; zindan/sefer/orman kaynağına göre dönüş metni; debuff açıklaması; iyileşince kapanış mesajı.
- **Köy festivali:** `village_festival` günlük event; moral + gıda (+ şanslı altın); düşük moralde ek tetikleme.

### 2026-06-29 (devam 9)
- **Köy savunması oynanabilir:** Saldırı anında köydeysen `village_battlesim` overlay; banner «Savaşa Katıl»; kayıp/zafer mevcut `_process_defense_result` ile uygulanır; köy dışında otomatik simülasyon.

### 2026-06-29 (devam 8)
- **3.5 tamamlandı:** 6 cariye rolü × 2 imza görevi (`RoleMissionCatalog`); rol atanınca zincir açılır; cariye başına 3 adımlı kişisel hikâye (leverage/seviye kilidi); Ajan/Diplomat rolleri aktif.

### 2026-06-29 (devam 7)
- **3.3 tamamlandı:** `WorldFactionProfiles` (komşu köy fraksiyonu → ticaret/diplomasi/baskın önizlemesi); haritada 8 landmark (harabe/kervan/mülteci) ziyaret ödülü; `DungeonProgress` mastery relic (Sağlam Kalp / Uğurlu Kese / Demir İrade) clear sayısına göre run başında uygulanır.

### 2026-06-29 (devam 6)
- **3.1 tamamlandı:** `InteractableVisualHelper`; zindan mini-event (tüccar/lanet) ve kamp çeşmesi decoration sprite.

### 2026-06-29 (devam 5)
- **3.2 tamamlandı:** `BuildingUpgradeMixin` + `BuildingUpgradeConfig` SSOT; tüm binalar kaynak+altın maliyeti; `requires_building` kilidi; Depo Lv1–3 yükseltme.

### 2026-06-29 (devam 4)
- **2.5 tamamlandı:** Mini-boss arena aktif; run'ın son segmentinde Shield Captain, major tier %50 daha fazla can.
- **2.6 tamamlandı:** Stealth algısı canonman, hunter, turtle, flying, summoner + varsayılan `handle_behavior`; miniboss arena dairesel algı.

### 2026-06-29 (devam 3)
- **2.4 tamamlandı:** `DungeonRunState.collected_keys`, `door._has_required_key()`, tüccar mini-event'ten anahtar satın alma.

### 2026-06-29 (devam 3)
- **3.4 tamamlandı:** LLM kapalıyken `AiNarrativeBrief` çoklu anahtar çözümlemesi (`incident.*` eşlemesi); Türkçe mechanical haber/görev şablonları `strings.csv`'de.

### 2026-06-29 (devam 2)
- **2.3 tamamlandı:** `pending_attacks` — köyde üst banner (geri sayım, asker, başarı tahmini), saldırı toast'u, savunma sonucu dialog.

### 2026-06-29 (devam)
- **1.5 ertelendi:** SFX / müzik sonraya bırakıldı.
- **2.2 tamamlandı:** Seyyah olayı `MissionManager.offer_traveler_mission()` ile gerçek dinamik görev üretiyor.
- **2.1 tamamlandı:** Yan yol dead-end'lerde tüccar / lanet mini-event (`DungeonEventInteractable`, `level_generator`).

---

*Her madde bitince durumu `[x]` yap; günlüğe kısa not düş.*
