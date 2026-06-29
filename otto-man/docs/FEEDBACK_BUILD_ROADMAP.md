# Geri Bildirim Build'i — İçerik Yol Haritası

> **Amaç:** Resmi demo değil; tanıdıklara atılıp “oyun nasıl hissettiriyor?” fikri alınacak build.
> **Durum:** Fikir listesi — sırayla ele alınacak. Tamamlanan maddeler `[x]`, devam eden `[~]`, bekleyen `[ ]`.

---

## Bağlam

Otto-man hibrit loop: **köy → keşif (orman / zindan / harita) → güvenle dönüş → cariye & görevler**.

Arkadaş build'inde öncelik: oyuncunun loop'u anlaması, 30–60 dk içinde “bir şeyler yaptım” hissi, tekrar oynamak için çeşitlilik.

Resmi demo ihtiyaçları (sınır, teaser, pazarlama metni) bu listede **düşük öncelik** — ayrı bölümde.

---

## Öncelik 1 — Geri bildirim build'i için (yüksek ROI)

| # | Madde | Neden | İlgili dosya / sistem |
|---|--------|-------|------------------------|
| 1 | [~] **Köy tutorial inbox** — orman → Odun Kampı → işçi atama | Zindan tutorial var; köy tarafı kaybolma noktası | `tutorial/TUTORIAL2_ROADMAP.txt`, `VillageMentorNPC`, `TutorialManager` |
| 2 | [~] **Challenge kapı modifier'ları** — parry yok, tek can, gece modu vb. | Mevcut kapı sistemi sayısal; run çeşitliliği ucuz | `scenes/ChallengeDoorGenerator.gd`, `DungeonRunState` |
| 3 | [~] **1 ek boss + 2 elite düşman varyantı** | **Ertelendi** (Tepegöz yarım; boss şimdilik yok) | `boss/`, `enemy/` |
| 4 | [x] **Cariye kurtarma → ilk görev zinciri** | İlk kurtarmada «Kurtarılanın Yolu» 3 adım + tutorial | `MissionManager`, `VillageScene`, `TutorialManager` |
| 5 | [x] **Item set sinerjileri (3–4 set)** | 4 set × 2 parça bonus; seçim UI ipucu | `item_manager.gd`, item hook'ları |
| 6 | [ ] **Zindan mini-event odaları** — tüccar, lanet, antik kuyu | Kurtarma dışı sürpriz | `MinigameRouter`, `level_generator` |

---

## Öncelik 2 — Loop derinliği (feedback sonrası veya paralel)

| # | Madde | Not |
|---|--------|-----|
| 7 | [ ] Zindan biome / tema paketleri (mağara, harabe, yanmış kale) | Görsel + spawn ağırlığı |
| 8 | [ ] Bina upgrade zinciri (Lv2/Lv3) | Erken–orta oyun hedefi |
| 9 | [ ] Rol bazlı imza görevler (6 cariye rolü × 2–3 görev) | `MissionManager` görev tipleri genişletme |
| 10 | [ ] Cariye kişisel hikâye zincirleri (3 aşama, leverage ile) | Kalıcı köy bonusu veya unique unlock |
| 11 | [ ] Fraksiyon mekanik farkları (Kuzey/Güney/Doğu/Batı) | Ticaret, görev, risk profili |
| 12 | [ ] Harita landmark'ları (harabe, kervan, mülteci kampı) | Keşif anlamı |
| 13 | [ ] Köprü / nehir olayları | `WorldManager` köprü hedefi |
| 14 | [ ] Mastery unlock item'ları (zindan clear count → özel pool) | `DungeonProgress` |
| 15 | [ ] Run başlangıç relic'i (köyden çıkarken 1 pasif) | Cariye rolüne bağlanabilir |

---

## Öncelik 3 — Uzun vadeli / büyük parçalar

| # | Madde | Not |
|---|--------|-----|
| 16 | [x] Köy savunması segmenti (`pending_attacks` oynanabilir) | Zindan motoru + köy arka planı |
| 17 | [ ] Mevsim / kış döngüsü | `TimeManager`, üretim/tüketim modifier |
| 18 | [x] Köy festivali & moral event'leri | Moral sadece ceza değil ödül de |
| 19 | [x] Ölüm sonrası mentor diyalogu (debuff + kısa öğrenme metni) | Duygusal bağ |
| 20 | [ ] LLM kapalıyken “el yapımı” haber şablonları (5–10 adet) | `NarrativeSpawnPipeline`, `news_queue_*` |

---

## Resmi demo (şimdilik ertelenmiş)

| # | Madde |
|---|--------|
| — | Demo içerik sınırı (hangi zindan, kaç hex, kaç bina katmanı) |
| — | Demo sonu teaser / kilitli içerik gösterimi |
| — | Beta etiketi & beklenti metni |

---

## Önerilen çalışma sırası

1. Köy tutorial inbox *(anlama)*
2. Challenge modifier'ları *(çeşitlilik, düşük asset)*
3. Ek boss / elite *(ertelendi)*
4. Cariye görev zinciri *(hibrit loop)* ✓
5. Item set sinerjileri *(build derinliği)* ✓
6. Mini-event odaları *(sürpriz)*

Her madde bitince bu dosyada `[x]` işaretle; altına kısa not düş (tarih, ne yapıldı).

---

## Mevcut tasarım dokümanları (çakışmayı önle)

- `tutorial/TUTORIAL2_ROADMAP.txt` — köy tutorial detay
- `docs/CHALLENGE_DOORS_PLAN.md` — kapı sistemi
- `docs/ITEM_SYNERGY_DESIGN.md` — item sinerji mimarisi
- `docs/DUNGEON_RESCUE_PLAN.md` — kurtarma odaları
- `docs/LIVING_WORLD_PLAN.md` — dünya simülasyonu

---

*Son güncelleme: 2026-06-12 — geri bildirim build'i planı*

### Madde 1 notları (2026-06-12)
- TutorialManager: yeni oyun sıfırlama, kayıt/yükleme, skip tutorial → köy rehberi
- MissionCenter: inşa/işçi sayfasına otomatik yönlendirme + sadece Odun Kampı
- VillageScene: yan panel butonları tutorial adım 2–3'te gizlenir (kamp ateşi yolu)
- Test: yeni oyun (tutorial'lı / tutorial'sız) → köy → mentor → orman → inşa → işçi

### Madde 2 notları (2026-06-12)
- 4 segment modifier: `no_parry`, `no_heal`, `night_mode`, `light_only`
- Prosedürel kapılarda ~%48 şans; ek risk + altın bonusu; kapı etiketinde gösterilir
- Hook: block_state, player heavy, CampFountain, level darkness shader
- Test: kamp kapılarında renkli modifier etiketi gör → seç → etkisini segmentte doğrula

### Madde 4 notları (2026-06-12)
- İlk cariye kurtarmasında «Kurtarılanın Yolu» zinciri (3 görev, yalnızca kurtarılan cariye)
- Görev Merkezi haber + mentor tutorial; zincir bitince altın/itibar/istikrar bonusu
- Test: zindanda VIP kurtar → köye dön → Görev Merkezi → «Dinlen ve Anlat» ata → zinciri tamamla

### Madde 5 notları (2026-06-12)
- 4 item seti: Zehir Ustası, Demir Muhafız, Gök Vuruşu, Üç Element (2 parça = bonus)
- Seçim ekranında set ipucu; aktif setler üst bilgide
- Test: zehirli_tirnak + zehirli_dev al → zehir hasarı/stack artışını doğrula
