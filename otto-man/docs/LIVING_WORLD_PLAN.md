# Living World Plan (RimWorld Esintili, Otto Uyumlu)

## Hedef
- Haritanın sadece oyuncu hareketinde degil, zaman gecerken de "yasiyor" hissi vermesi.
- Kotu/iyi olaylarin yalnizca oyuncu koyunde degil, komsu koylerde de yasanmasi.
- Oyuncuya gelen haberlerin sistemik bir dunyanin parcasi gibi gorunmesi.

## Tasarim Prensipleri
- Mikro zincir: Her kriz 2-3 adimdan fazla olmayacak.
- Dusuk karmaşıklık: Event graph yerine state + trigger modeli.
- Data-driven: Olaylar ortak effect anahtarlariyla calisacak.
- Sinirli eszamanlilik: Global aktif kriz limiti ve koy-basi limit.
- Gecikmeli etki: Bugun olan seyler sonraki gunlerde yeni sonuc doguracak.

---

## Hizli Durum Tablosu (TL;DR)

### Yapildi (Foundation Hazir)

| Sistem | Modul | Hot Hook |
|---|---|---|
| Settlement state simulation | `_simulate_neighbor_settlements` | role_mods.* |
| Incident system (wolf/harvest/migrant) | `_create_settlement_incident` | role_mods.wolf_severity_mult |
| Event chain framework (drought/raid) | `_simulate_event_chains` | CHAIN_DEFINITIONS |
| Migration flow | `_simulate_settlement_migrations` | — |
| Inter-settlement trade flow | `_simulate_settlement_trade_flows` | role_mods.food_drift_bonus |
| Inter-settlement diplomacy FSM | `_simulate_settlement_diplomacy` | DIPLOMACY_STATE_* |
| Player war_support / mediation | `apply_war_support` / `apply_mediation` | menu opsiyonlari |
| Player↔settlement alliance | `propose_alliance` / `break_alliance` | `world_player_alliances` |
| Alliance hostility yayilimi | `_apply_alliance_hostility_diff` | role_mods.hostile_* |
| Hostile koy baskini | `_check_hostile_settlement_attacks` | role_mods.hostile_attack_chance_mult |
| Hostile koy yol riski | `_get_hostile_settlement_threat_bonus` | role_mods.hostile_route_risk_mult |
| Tribute (gunluk pasif kazanc) | `_try_apply_alliance_tribute` | role_mods.alliance_tribute_bonus |
| Shared Intel (pasif kesif) | `_apply_alliance_shared_intel` | role_mods.alliance_intel_radius_bonus |
| Defansif destek (multi-ally) | `_try_apply_alliance_defense_intervention` + `_pick_alliance_defenders` | role_mods.alliance_defense_* |
| Combat layer entegrasyonu | `_execute_village_defense(alliance_defender, defender_count)` | pending_attack.defender_count |
| Ofansif baskin gorevi | `launch_offensive_raid` + WorldMapScene menu | `get_offensive_raid_result_effects` |

### Sirada (Foundation Eksiklikleri)

| Oncelik | Konu | Durum |
|---|---|---|
| 1 | Combat layer entegrasyonu | ✅ Tamamlandi — `defender_intervention` + `defender_count` combat'a aktarildi, multi-ally bonus asker takviyesi + def_power carpani |
| 2 | Hostile koylere ofansif mission | ✅ Tamamlandi — `get_offensive_raid_options` / `launch_offensive_raid` + WorldMapScene menu butonu + MissionManager entegrasyon |
| 3 | Multi-ally savunma stack | ✅ Tamamlandi — `_pick_alliance_defenders(max_count=3)`, her ek muttefik bağimsiz sans + azalan stack penalti, combat'a yansir |

### Sonra (Polish / Genisletme)

- Tribute scaling (population factor) — ✅ `WorldManager._alliance_tribute_population_multiplier` + günlük tribute / harita tahmini
- Hostile yerleşim konvoy dışı — ✅ `_pick_trade_pair` içinde `is_settlement_hostile_to_player` (OPEN_WAR’a ek)
- Aid_call → MissionManager — ✅ komşu kriz: `relief_*` + `completes_incident_id`; muttefik çağrı: `ally_relief_*` + `completes_alliance_aid_settlement_id` + `apply_alliance_aid_mission_success` (çağrı açılışında görev `force_spawn`)
- Yeni cariye rolleri (Alim/Tibbiyeci) icin role_mods alanlari — ✅ `WorldManager`: Alim (Bürokrasi) → hasat/salgın şiddeti; Tibbiyeci (Diplomasi) → salgın şiddeti + nüfus kaybı çarpanı; `Concubine.Role` + görev merkezi rol menüsü

### Cariye Rolu Etki Haritasi (current)

```
KOMUTAN (savas)
  ├─ wolf_severity_mult              (incident sertligi)
  ├─ security_recovery_bonus         (gunluk toparlanma)
  ├─ post_incident_security_bonus    (olay sonrasi)
  ├─ hostile_attack_chance_mult      (hostile baskin)
  ├─ hostile_route_risk_mult         (hostile yol riski)
  ├─ alliance_defense_chance_bonus   (savunma sansi)
  └─ alliance_defense_range_bonus    (savunma menzili)

DIPLOMAT (diplomasi)
  ├─ incident_duration_mult          (kriz kisaltma)
  ├─ stability_recovery_bonus
  └─ post_incident_stability_bonus

AJAN (kesif)
  ├─ undiscovered_news_chance        (uzaktan duyum)
  └─ alliance_intel_radius_bonus     (muttefik kesif menzili)

TUCCAR (ticaret)
  ├─ food_drift_bonus                (gunluk erzak driftine)
  └─ alliance_tribute_bonus          (tribute miktari)

ALIM (bilgi / duzen)
  ├─ harvest_failure_severity_mult   (kitlik olayi siddeti)
  └─ plague_scare_severity_mult      (salgın söylentisi; Tibbiyeci ile carpilir)

TIBBIYECI (saglik)
  ├─ plague_scare_severity_mult      (salgın söylentisi siddeti)
  └─ plague_population_loss_mult     (salgında nüfus kaybı)
```

### Save/Load Durumu

| Alan | Durum |
|---|---|
| world_settlement_states/incidents/diplomacy/migrations/event_chains/relations | ✓ get_world_map_state |
| world_player_alliances | ✓ get_world_map_state |
| relations (faction) | ✓ faction_relations |
| pending_attacks (zamanli baskin/raid) | ✓ `get_world_map_state` → `pending_attacks` |
| MM settlements / trade_routes / ticaret modlari | ✓ `SaveManager` → missions bucket (`mm_settlements`, `mm_trade_routes`, `mm_settlement_trade_modifiers`); `relation` yuklemeden sonra WM ile yeniden eslenir |
| MM dunya simi (tuccar, uretim, bandit, itibar) | ✓ `mm_active_traders`, `mm_active_rate_modifiers`, `mm_player_reputation`, `mm_world_stability`, `mm_bandit_*`; yukleme sonrasi `prune_time_limited_state_for_day(gun, silent)` |
| MM gorev gecmisi | ✓ `mm_mission_history` (son 80 kayit); gun tik `MissionManager._last_tick_day` yuklemede `TimeManager` gunune esitlenir |

---

## Fazlar

### Faz 1 - Yasayan Koy Simulasyonu (Ilk uygulanacak)
- Her komsu koy icin hafif bir durum modeli:
  - nufus
  - erzak
  - guvenlik
  - istikrar
- Gunluk tick:
  - kucuk dogal degisimler
  - yeni kriz olasiligi
  - aktif kriz ilerlemesi ve bitisi
- Ilk kriz ailesi:
  - `wolf_attack` (guvenlik/erzak baskisi)
  - `harvest_failure` (erzak dususu)
  - `migrant_wave` (nufus artis + istikrar baskisi)
- Haber sistemi:
  - Kesfedilmis koyler icin tam haber
  - Kesfedilmemis koyler icin dusuk ihtimal "uzaktan duyum"
- Harita etkisi:
  - Krizdeki koy cevresinde yol olay riski artis bonusu

### Faz 2 - Ticaret Aglari ve Fiyat Baskisi
- Koylerin arz/acik profili uretilir.
- Basit konvoy simulasyonu (entity gerektirmeden).
- Riskli hatlarda kayip -> fiyat ve talep dalgalanmasi.
- Tuccar cariye aksiyonlariyla etki.

### Faz 3 - Diplomasi, Catisma ve Mudahale Operasyonlari
- Koyler arasi gerilim durum makinasi.
- Sinir catisma/savas tetikleri.
- Komutan, ajan, burokrat rolleri dogrudan dunya dengesine etki eder.
- Zincir gorevler sadece 2-3 adimli mikro akislarda tutulur.

### Faz 2.5 / Faz 3 Temelleri (eklendi)
Bu temeller mimari acidan kritik oldugu icin Faz 1/2 sirasinda eklendi.
Polish ve ek zincirler bu temellerin ustune yazilacak.

- Inter-settlement Relations
  - `world_settlement_relations: Dictionary` ("idA|idB" -> int -100..100)
  - Helpers: `get_settlement_relation`, `set_settlement_relation`, `change_settlement_relation`, `get_settlement_stance`
  - Konvoy basarisi/yagmasi iliskiyi etkiler (canli kullanim ornegi)
  - Save/Load: `set_world_map_state` icinde aktif

- Event Chain Framework (Mikro Zincir)
  - `world_event_chains: Array[Dictionary]`
  - Data-driven `CHAIN_DEFINITIONS` (sadece veri ekleyip yeni zincir uretilir)
  - Stages: id, duration, next; gunluk tickte ilerleme
  - On-enter etki + gerektiginde news yayinlama
  - Aktif zincir limiti: 4
  - Settlement basina max 1 aktif zincir
  - Save/Load: `set_world_map_state` icinde aktif
  - Ilk iki ornek zincir:
    - `drought_chain`: drought -> famine -> migration_pressure
    - `raid_chain`: raid_warning -> raid -> raid_aftermath
  - Seedleme: incident bittikten sonra olasiliksal (severity ile olcekli)

## Inter-settlement Diplomacy FSM (Faz 3 omurgasi)
Komsu koyler arasi savas/baris dinamigi icin kategorik state machine.
- `world_settlement_diplomacy: Dictionary` ("idA|idB" -> {state, since_day, last_changed_day, war_intensity})
- States: `peace`, `tension`, `cold_war`, `open_war`, `ceasefire`
- Threshold'lar (relation skoruna gore):
  - tension: <= -15
  - cold_war: <= -35
  - open_war: <= -65
  - peace recovery: >= -10
- Min sureler:
  - open_war: en az 3 gun
  - ceasefire: en az 4 gun
- Etkiler:
  - `open_war`: ticaret bloklanir, raid_chain seedleme olasiligi olusur (~%18 olasi gun)
  - `cold_war`: konvoy basarisi -%18
  - `tension`: konvoy basarisi -%8
  - `ceasefire`: konvoy basarisi -%5
- News: state degisimleri kesfedilmis pair'lar icin direkt, kesfedilmemiste duyum.
- Save/Load: `set_world_map_state` icinde aktif.
- Public API:
  - `get_settlement_diplomacy_state(a, b)` -> `{state, since_day, last_changed_day, war_intensity}`
  - `get_settlement_diplomacy_summary(settlement_id)` -> non-peace pair'larin listesi
  - `get_world_settlement_diplomacy()` -> tam map

## Migration Flow Model (Faz 3 omurgasi)
- `world_settlement_migrations: Array[Dictionary]`
- Bir koy `migration_pressure` zincir asamasina girince:
  - Hedef secimi: yakinlik + istikrar + guvenlik + erzak + iliski skoru
  - Aktif goc entry'si olusur (toplam + suresi + transferred)
- Gunluk tickte:
  - Kaynak nufusu azalir (min 20)
  - Hedef nufusu artar (max 260)
  - Hedefte erzak baskisi olusur
  - Hedef istikrari iliskiye gore daha az/cok zedelenir
- Tamamlandiginda iliski +1, news yayinlanir.
- Limitler: `MAX_ACTIVE_MIGRATIONS = 6`, kaynak basina ayni anda 1 aktif goc.
- Save/Load: `set_world_map_state` icinde aktif.

## Genisletme Rehberi (zayif AI icin)

### Yeni event chain zinciri eklemek
1. `CHAIN_DEFINITIONS`'a yeni `chain_type` ekle.
2. `_enter_event_chain_stage` icine her stage icin etki blogu yaz.
3. `_post_event_chain_stage_news` icine her stage icin haber metni ekle.
4. Gerekirse `_try_seed_event_chain_from_incident` icine seedleme sarti ekle.

### Yeni incident turu eklemek
1. `_create_settlement_incident` icindeki turler listesine ekle.
2. `_apply_settlement_incident_start_effects` icine baslangic etkisini yaz.
3. `_resolve_expired_settlement_incidents` icine olay sonu toparlanmayi yaz.
4. `_post_settlement_incident_news` icine baslik/icerik ekle.
5. `WorldMapScene._format_incident_type_label` icine etiket ekle.
6. Istege bagli: `_draw_settlement_incident_marker` icine renk/glyph.

### Yeni cariye rolu etkisi eklemek (Faz 1+)
1. `_get_living_world_role_modifiers` icine yeni `mods` anahtarlarini ekle.
2. Etkiyi kullanan fonksiyonu (`_create_settlement_incident`, `_simulate_neighbor_settlements`, `_post_settlement_incident_news`, `_resolve_expired_settlement_incidents`) ilgili anahtarla guncelle.
3. UI gorunurlugu icin `WorldMapScene._build_role_buffs_status_line` icine satir ekle.

### Yeni diplomasi state'i veya threshold'u eklemek
1. State sabitini (`DIPLOMACY_STATE_*`) ekle.
2. `_evaluate_diplomacy_transition` icindeki match bloklarina gecisleri yaz.
3. `_post_diplomacy_transition_news` icine baslik/icerik ekle.
4. Etkilenen sistemlerde (`_pick_trade_pair`, `_resolve_trade_convoy`, `_simulate_settlement_diplomacy`) yeni state'in etkisini ekle.
5. UI etiketi icin `WorldMapScene._format_diplomacy_state_label` icine ekle.

### Yeni oyuncu mudahale opsiyonu eklemek (Faz 3 hooklari)
1. `WorldManager` icine `get_<X>_options(settlement_id)` ve `apply_<X>(...)` ciftini ekle.
   - `option` formati: `{ id, label, type, cost: { gold, food, ... }, summary, ... }`.
2. `can_afford_diplomatic_intervention(option)` zaten `can_afford_settlement_aid`'i tekrar kullaniyor; gerekirse genislet.
3. `WorldMapScene`:
   - `_setup_settlement_action_menu` icine yeni `add_item("...", X)` ekle.
   - `_on_settlement_action_selected` match bloguna case ekle.
   - `_refresh_<X>_menu_item` yaz, popup acilirken `_try_prompt_settlement_actions_at_player_pos` icinden cagir.
   - `_execute_settlement_<X>` ve `_perform_<X>_now` cifti ekle, `_pending_aid_kind` degerini ayarla.
   - Onay metni icin `_build_aid_confirm_text` formati yeterlidir.
4. Sonuc reason kodlarini `_handle_intervention_result` match'ine ekle.

### Yeni ittifak hook'u eklemek (Faz 4 hooklari)
1. Yeni baglayici davranis icin `world_player_alliances[settlement_id]` dictionary'sine alan ekle.
   - Ornek: `auto_war_with_enemies`, `tribute_per_day`, `shared_intel`.
2. Etkiyi uygulayacak fonksiyonu yaz (`_simulate_player_alliances` icine cek veya ayri `_simulate_<x>_alliance_effect(day)`).
3. UI hook'u: `WorldMapScene._build_alliance_status_line` veya `_build_settlement_status_text` icine satir/etiket ekle.
4. Genisletilebilir ornekler:
   - **Otomatik dusmanlik**: muttefik koyun `OPEN_WAR` listesinde olan koyler oyuncu↔koy iliskisini her gun -1 dusurur.
   - **Vergi/destek**: muttefik koyden gunluk +1 altin (lojistik destek), `food_stock>=80` kosulunda.
   - **Istihbarat**: muttefigin gordugu hex'ler oyuncuya pasif kesfedilir.

Bu kurallarla mimariye dokunmadan icerik genisletilir.

## Veri Modeli (Faz 1)
- `world_settlement_states: Dictionary`
  - key: `settlement_id`
  - value: `{ id, name, population, food_stock, security, stability, crisis_pressure, last_updated_day }`
- `world_settlement_incidents: Array[Dictionary]`
  - `{ id, settlement_id, settlement_name, type, severity, started_day, duration, resolved, effects }`

## Faz 1 Olay Etkileri
- `wolf_attack`
  - anlik: guvenlik -8..-14, erzak -10..-22
  - sure sonu: guvenlik kismi toparlanma
- `harvest_failure`
  - anlik: erzak -16..-34, istikrar -4..-9
  - sure sonu: istikrar +2 toparlanma
- `migrant_wave`
  - anlik: nufus +4..+14, erzak -8..-20, istikrar -2..-8
  - sure sonu: entegrasyon olursa istikrar +3

## Simulasyon Sinirlari
- Global aktif incident limiti: 3
- Koy basi aktif incident limiti: 1
- Incident sureleri: 2-4 gun
- Gunluk yeni incident sansi:
  - baz: %9
  - dusuk guvenlikte ekstra +%4
  - dusuk erzakta ekstra +%5

## UI/Haber Kurallari
- Haber basliklari "Dunya" kategorisinde yayinlanir.
- Koy kesfedildi ise:
  - dogrudan koy ismiyle detayli haber.
- Koy kesfedilmedi ise:
  - dusuk ihtimalle belirsiz kaynaktan "duyum" haberi.

## Cariye Rollerine Gelecek Baglanti Noktalari (Faz 1 hooklari)
- `KOMUTAN` (savas skill ile olcekli):
  - `wolf_attack` siddetini %30'a kadar azaltir.
  - Gunluk guvenlik toparlanmasi +1 ile +3.
  - Olay sonrasi guvenlik bonusu +1 ile +4.
- `DIPLOMAT` (diplomasi skill ile olcekli):
  - Tum incident sureleri %30'a kadar kisalir (en az 1 gun).
  - Gunluk istikrar toparlanmasi +1 ile +3.
  - Olay sonrasi istikrar bonusu +1 ile +4.
- `AJAN` (kesif skill ile olcekli):
  - Kesfedilmemis koy krizleri icin duyum ihtimali %30 -> %85'e kadar artar.
- `TUCCAR` (ticaret skill ile olcekli):
  - Komsu koylerin gunluk erzak driftine +1 ile +4 (Faz 2 hazirligi).

## Basari Kriterleri (Faz 1)
- Oyuncu 3-5 gun icinde en az 2 farkli komsu koy haberi gorur.
- Haritada gezerken krizli koy cevresinde olay riski gozle gorulur fark yaratir.
- Save/Load sonrasi settlement state ve aktif incidentler korunur.

## Oyuncu Diplomatik Mudahalesi (Faz 3 omurga)

Oyuncunun pasif izleyici degil aktif aktor olmasi icin diplomasi FSM'sine kaynakla mudahale edebilir.
Mevcut iki opsiyon (genisletilebilir):

### Savasta Destek (`apply_war_support`)
- **Kosul**: Hedef koy en az bir baska koy ile `open_war` durumunda.
- **Maliyet**: 80 altin + 35 erzak (sabitler `WAR_SUPPORT_GOLD_COST`, `WAR_SUPPORT_FOOD_COST`).
- **Etki**:
  - Desteklenen koy: guvenlik +10, istikrar +5.
  - Dusman koy: guvenlik -8, erzak -8.
  - `war_intensity` +1 (savas siddetlenir).
  - Player iliski: desteklenen +5, dusman -5.
  - "Savas Destegi" haberi.

### Aracilik (`apply_mediation`)
- **Kosul**: Iki koy `open_war` veya `cold_war` durumunda.
- **Maliyet**: 130 altin (sabit `MEDIATION_GOLD_COST`).
- **Etki**:
  - Iki koy arasi iliski +25.
  - `open_war` -> `ceasefire`, `cold_war` -> `tension` zorunlu gecisi.
  - Player iliski: her iki koy +3.
  - Haber: ilgili gecis haberi + "Aracilik" haberi.

### UI
- Settlement menusunde "Savasta Destek" ve "Aracilik Yap" satirlari.
- Aktif kosul yoksa veya kaynak yetmiyorsa pasif gorunur, etiket dinamik update edilir.
- Onay icin `_settlement_aid_confirm_dialog` paylasilir; `_pending_aid_kind` ile yonlendirilir.
- Settlement detay panelinde "Mudahale: savasta destek, aracilik" ipucu satiri.

### Tasarim Notlari
- `apply_*` cagrisinda kaynaklar `GlobalPlayerData` (gold) ve `GameManager` (resources) uzerinden dusulur.
- Tum etkiler ayni gun `world_map_updated` sinyaliyle UI'ya yansir.
- Haberler `_post_world_news` ile yayilir; oyuncu ekranda goruyor.
- Yeni mudahale opsiyonlari icin `Genisletme Rehberi` bolumunu takip et.

## Oyuncu↔Koy Ittifak Sistemi (Faz 4 omurga)

Oyuncunun pasif diplomatik mudahaleden cikip koylerle baglayici iliskiler kurabilmesi icin
"player alliance" katmani eklenir. Mevcut diplomasi FSM'i (koy-koy) bozulmaz; bu katman
oyuncu-koy iliskileri icin paralel calisir.

### Veri Modeli
- `world_player_alliances: Dictionary` (settlement_id -> alliance entry)
- Alliance entry alanlari:
  - `established_day`: ittifagin baslangic gunu.
  - `last_aid_call_day`: en son yardim cagrisinin acildigi gun (cooldown icin).
  - `aid_call_active`: aktif kriz cagrisi var mi?
  - `aid_call_started_day`: cagrinin acildigi gun.
  - `aid_call_reason`: "guvenlik" | "erzak" | gelecek tipler icin acik.
- Tum alanlar `get_world_map_state()` -> `set_world_map_state()` uzerinden persist edilir.

### Ittifak Kurma (`propose_alliance`)
- **Kosul**: `relation("Köy", settlement_name) >= ALLIANCE_MIN_RELATION` (varsayilan 70).
- **Maliyet**: 200 altin + 60 erzak (`ALLIANCE_PROPOSE_GOLD_COST`, `ALLIANCE_PROPOSE_FOOD_COST`).
- **Etki**: koy oyuncu icin "muttefik" rozeti tasir, +5 iliski, "Ittifak Kuruldu" haberi.

### Ittifak Bozma (`break_alliance`)
- **Kosul**: zaten muttefik olmak.
- **Maliyet**: yok; ancak iliski `ALLIANCE_BREAK_RELATION_PENALTY` (varsayilan -25) duser.
- **Etki**: aktif aid_call kapanir, "Ittifak Sona Erdi" haberi.

### Muttefik Kriz Cagrisi (`_simulate_player_alliances`)
- Her gun her muttefik icin `food_stock <= ALLIANCE_AID_CALL_FOOD_THRESHOLD` (25)
  veya `security <= ALLIANCE_AID_CALL_SECURITY_THRESHOLD` (25) kontrolu yapilir.
- Kriz tespit edilince ve `last_aid_call_day` cooldown'u (5 gun) doluysa
  `aid_call_active = true` olur, "Muttefik Yardim Cagrisi" haberi yayinlanir; ardindan
  `MissionManager.try_spawn_alliance_aid_relief_mission(..., force_spawn=true)` ile `ally_relief_<settlement_id>` gorevi acilir (zaten varsa yeniden uretilmez).
- Kriz cozulunce `aid_call_active = false`, "Muttefik Toparlandi" haberi yayinlanir.
- Kriz aktifken oyuncu yardim etmezse her gun `change_relation -1` ihmal cezasi.
- Oyuncu `apply_settlement_aid` ile yardim ederse aid_call kapanir, +5 iliski bonus.
- Oyuncu `ally_relief_*` gorevini basarili bitirirse `apply_alliance_aid_mission_success` (kriz hala aciksa
  kapanir, neden tipine gore koy state + iliski; kriz kendiliginden bittiyse hafif +2 iliski / bilgi haberi).

### UI
- Settlement aksiyon menusu: "Ittifak Onerisi" (id 7), "Ittifaki Boz" (id 8) eklenir.
- Onay icin `_settlement_aid_confirm_dialog` paylasilir; `_pending_aid_kind` ile yonlendirilir.
- Settlement detay paneli: "[Muttefik]" rozeti + aktif aid_call durumu.
- Map status label: aktif yardim cagrisi olan muttefiklerin listesi (yoksa "Muttefikler: N (sakin)").
- Map detay panel "Mudahale" ipucu satirina "ittifak" eklenir (uygunluk varsa).

### Hostility Yayilim (eklendi)
Muttefigin dusmanlari oyuncuyu da etkiler. Iki kademe:

1. **Anlik (propose_alliance sonrasi)**: muttefigin tum OPEN_WAR rakipleri icin
   `change_relation("Köy", enemy_name, ALLIANCE_HOSTILITY_INITIAL_PENALTY)` (-10).
   "Ittifak Yansimasi" haberi yayilir.
2. **Gunluk diff (`_apply_alliance_hostility_diff`)**: muttefigin `tracked_enemies` setine
   gore yeni dusman olduysa o koylere `ALLIANCE_HOSTILITY_NEW_ENEMY_PENALTY` (-8) uygulanir.
   `tracked_enemies` her gun guncellenir, eski dusmanlar set'ten cikar.

**Hostile esik**: `relation <= ALLIANCE_HOSTILITY_THRESHOLD` (-30) altina dusen koy
"oyuncuya dusmanca" sayilir.

**API**:
- `is_settlement_hostile_to_player(id)` — boolean kontrol.
- `get_player_hostile_settlements()` — tum hostile koyler ozet listesi.

**UI**:
- Settlement detay paneli: muttefik degil ama hostile ise "[Sana karsi dusmanca] iliski: X" rozeti.
- Map status label: "Dusman koyler: A, B, C" (3'ten coksa "Dusman koyler: N (A, B, C ...)").

**Tasarim mantigi**: ittifak bedava degildir. Cok ittifak yaparsan bir kismi sayisal olarak
hostility birikir. Bu da ileride route risk multiplier, baskin sansi, ticaret blokaji gibi
ek hooklar icin saglam bir baz olusturur.

### Hostility Askeri/Yolculuk Sonuclari (eklendi)
Hostile koyler sadece sayisal degil, dunyada elle tutulur sonuclar uretir.

#### 1. Baskin sansi (`_check_hostile_settlement_attacks`)
- Her gun her hostile koy icin dusuk sansla baskin tetiklenir.
- Sans formulu: `clampf((-relation - 30) * 0.0007 + 0.005, 0.005, 0.05)`
  - Rel `-30` -> %0.5; Rel `-60` -> %2.5; Rel `-100` -> %5
- Komutan rolu (savas skill) `hostile_attack_chance_mult` ile %50'ye kadar azaltir.
- Tetiklenince mevcut `pending_attacks` akisina eklenir; `is_hostile_settlement: true` ve
  `settlement_id` meta alanlariyla. UI/savunma kodu ayni mekanikten yararlanir.
- Haber: "Dusman Koy Baskini" (kritik kategori, 6 saat uyari).

#### 2. Yol riski bonusu (`_get_hostile_settlement_threat_bonus`)
- Hostile bir koyun 4 hex menzilindeki tile'larin world travel event sansi yukselir.
- Bonus formulu: hostile basina `0.025 * (0.4 + 0.6 * severity) * proximity` (max %12).
- Severity: relation `-30` -> %0; relation `-100` -> %100.
- Komutan rolu `hostile_route_risk_mult` ile %30'a kadar azaltir.
- `_should_trigger_world_travel_event` icinde mevcut incident bonus'una eklenir.
- WorldMapScene preview'i `get_hostile_settlement_threat_bonus` cagrir; rota rengi/etiketi
  otomatik kirmizilasir.

#### Cariye Rolu Etkileri
- `KOMUTAN`: `hostile_attack_chance_mult` ve `hostile_route_risk_mult` (yeni).
  Foundation'a tek noktadan baglanir; ekstra rol etkisi eklemek icin sadece bu key'leri okuyan
  yeni helper yazmak yeterli.

#### UI
- Settlement detay paneli (hostile ama muttefik degil): "[Sana karsi dusmanca] iliski: X" rozeti
  + "Baskin riski + yakin hex'lerde yol riski yukselir" aciklamasi.
- Map status label: "Dusman koyler: A, B, C" ozet satiri (alliance line ile " | " birlesik).

### Ittifak Avantaj Sistemleri (eklendi)
Hostility maliyetinin karsiliginda ittifakin somut faydasi olmasi icin iki pasif sistem eklenir.

#### Tribute (gunluk pasif kazanc) — `_try_apply_alliance_tribute`
- **Kosullar**:
  - Muttefik koy stability >= `ALLIANCE_TRIBUTE_STABILITY_MIN` (50)
  - Muttefik koy food_stock >= `ALLIANCE_TRIBUTE_FOOD_MIN` (80)
  - aid_call aktif degil ve koy krizde degil.
- **Kazanc**:
  - Baz: `ALLIANCE_TRIBUTE_BASE_GOLD` (1) altin/gun.
  - Tuccar buff: +1 ile +3 altin (`alliance_tribute_bonus`).
  - %30 sansla ek 1 erzak; tuccar bonus >= 2 ise +1 erzak daha.
- **Maliyet (koy tarafi)**: gercek erzak akimi simgesel; verilen erzak `food_stock`'tan dusulur.
- **Haber**: gunluk toplu "Muttefik Lojistik Destegi" (kaynak koylerle birlikte).

#### Shared Intel (gunluk pasif kesif) — `_apply_alliance_shared_intel`
- **Kosul**: muttefik koy aid_call'da degil, krizde degil.
- **Etki**: muttefik koy hex'i etrafinda `ALLIANCE_INTEL_BASE_RADIUS` (2) menzilinde pasif kesif.
- **Ajan buff**: +1 ile +2 menzil (`alliance_intel_radius_bonus`); max menzil 5.
- `discover_tiles(..., source: "alliance")` ile cagrilir; mevcut kesif sistemi tekrar kullanilir.

#### Cariye Rolu Etkileri
- `TUCCAR`: `alliance_tribute_bonus` (+1 ile +3 altin/gun/eligible muttefik).
- `AJAN`: `alliance_intel_radius_bonus` (+1 ile +2 hex menzil).

#### UI
- Settlement detay paneli (muttefik koy):
  - "Tribute aktif: gunluk pasif altin/erzak" veya
  - "Tribute pasif: stabilite/erzak yetersiz" (kosul saglanmiyorsa).
- Map status label `_build_alliance_status_line` icine "Tribute: ~X altin + ~Y erzak/gun (eligible/total)" satiri.
- API: `get_estimated_daily_alliance_tribute()` UI uyumlu ozet sozluk doner.

#### Tasarim Mantigi
- Ittifak artik **denge**: hostility (zarar) <-> tribute + shared_intel (kazanc).
- Cariye seciminin haritada gozle gorulur, sayisal etkisi olur:
  - Komutan dusman koy baskinini ve yol riskini azaltir.
  - Tuccar tribute geliri arttirir.
  - Ajan harita kesfini hizlandirir.
  - Diplomat incident sureleri kisaltir.
- Bir muttefik krize girerse hem tribute hem intel otomatik durur (kriz oncelikli).

### Defansif Destek (eklendi)
Hostile bir koy oyuncuya baskin schedule ettiginde, mevcut muttefiklerden biri sansla savunmaya
mudahale eder. Foundation seviyesinde event yayini + stat etkisi olarak uygulanir; aktif combat
sistemine dokunmaz.

#### Akis (`_try_apply_alliance_defense_intervention`)
1. `_check_hostile_settlement_attacks` -> `_trigger_hostile_settlement_attack` cagrilir.
2. Scheduling sirasinda `_pick_alliance_defender(attacker_id)` cagrilir:
   - aid_call'da olmayan, krizde olmayan muttefikler.
   - `food_stock >= ALLIANCE_DEFENSE_FOOD_MIN` (60).
   - `security >= ALLIANCE_DEFENSE_SECURITY_MIN` (50).
   - Oyuncu koyune `ALLIANCE_DEFENSE_BASE_RANGE` (6) hex menzilinde (Komutan +2'ye kadar).
   - En yakin secilir.
3. Mudahale sansi: `ALLIANCE_DEFENSE_BASE_CHANCE` (0.55) * proximity + Komutan bonusu (0.20'ye kadar).
4. Basariliysa `_apply_alliance_defense_effects`:
   - Saldirgan koy `security -5`, `stability -3`.
   - Defender koy `security -2` (yipranma).
   - Player iliskisi: defender +3, attacker -3.
   - Defender↔attacker arasi `change_settlement_relation -10` (FSM dogal akisina yansir).
   - "Muttefik Savunma Destegi" haberi.
5. `pending_attacks` entry'sine meta: `defender_intervention`, `defender_settlement_id`,
   `defender_settlement_name`. Combat layer ileride bu meta'yi okuyup ek bonus uygulayabilir.

#### Cariye Rolu Etkileri
- `KOMUTAN`: `alliance_defense_chance_bonus` (+0.20'ye kadar) ve
  `alliance_defense_range_bonus` (+2 hex'e kadar). Cok yonlu defansif rol.

#### UI
- Settlement detay paneli (muttefik):
  - "Defans hazir: X/Y hex menzil" eligible ise.
  - "Defans hazir degil: <neden>" (krizde, erzak yetersiz, menzil disi vb.).
- API: `get_alliance_defender_eligibility(settlement_id)` -> `{eligible, reason, distance, max_range}`.

#### Tasarim Mantigi
- Ittifak iliskisi simdi defansif anlam kazaniyor: yakin + sagliklı muttefik = dunya
  saldirisinda yardim. Uzak/krizdeki muttefik bedava kalmiyor (sadece tribute/intel kaldı).
- Komutan rolu artik 4 farkli sistemi etkiliyor: incident severity, hostile route risk,
  hostile attack chance, alliance defense (chance + range). Tek skill, dort sonuc.
- Defender ile attacker arasinda otomatik gerilim olusarak FSM'i besler — yarinki diplomasi
  hareketi bugunkü savunmanin sonucu olur.

### Genisletme Hooklari (gelecek icerik)
- Combat layer ince ayar: `pending_attack.defender_intervention` / `defender_count` ile daha fazla dovus metrik baglantisi (temel entegrasyon mevcut).
- ~~Hostile ticaret: `_pick_trade_pair` oyuncuya dusmanca yerlesimi gonder/alici olarak elemiyor~~ (konvoy ekonomisi NPC-NPC; oyuncu koyu bu havuzda ayri ID degil).
- ~~Quest: aid_call → `ally_relief_*`~~ — uygulandi (`force_spawn` ile cağrı basina tek liste gorevi).
- ~~Tribute scaling (population)~~ — uygulandi (`_alliance_tribute_population_multiplier`).
- ~~Multi-ally savunma stack~~ — uygulandi (`_pick_alliance_defenders`); ek savas efektleri genisletilebilir.

## Uygulama Notu
- Bu planda once Faz 1 uygulanacak.
- Faz 2 ve Faz 3 icin altyapiyi bozmayacak sekilde minimal, geriye uyumlu alanlar acilacak.
- Faz 4 (oyuncu-koy ittifaklari) mevcut FSM'i bozmadan paralel katman olarak kurulur; uzerine
  icerik (otomatik dusmanlik, vergi, ortak istihbarat) genisletme rehberi ile eklenir.
