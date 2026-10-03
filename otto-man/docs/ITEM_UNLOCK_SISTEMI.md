# Item Unlock Sistemi — Tasarım

Zindan ilerlemesine bağlı kalıcı item koleksiyonu. Oyuncu dar bir başlangıç havuzuyla başlar; zindan tamamladıkça yeni item'lar **kalıcı olarak** havuzuna girer. Her zindan farklı bir playstyle + element ailesi verir.

İlgili dosyalar:
- `autoload/item_manager.gd` — havuz, `get_random_items()`, ön koşullar, setler
- `autoload/DungeonProgress.gd` — zindan başına alıştırma/clear sayacı (tetik noktaları)
- `autoload/DungeonRunState.gd` — run durumu, altın
- `interactables/dungeon/DungeonEventInteractable.gd` — zindan içi tüccar

---

## 1. NEDEN

Şu an `ITEM_SCENES` içindeki ~100 item'ın tamamı ilk run'dan itibaren havuzda. Sonuç: oyuncu hiçbir item'ı tanımıyor, gelen 3 kart build'e bağlanmıyor, her run bulanık. Havuzu daraltmak run'ları **okunabilir** yapar. Meta-progression ikincil kazanç; asıl kazanç savaş netliği.

---

## 2. TEMEL AYRIM

| Kavram | Ne | Nerede belirlenir |
|--------|-----|-------------------|
| **Koleksiyon** | Kalıcı olarak açılmış item'lar | Hangi zindanı tamamladın |
| **Draft** | Run içinde teklif edilen 3 kart | Koleksiyondan rastgele |

Kritik: **zindan teması neyi açtığını belirler, neyi çekebildiğini değil.** Zehir item'larını bir kez açtıktan sonra ateş zindanında da draft'a gelirler. Zindan seçimi kalıcı bir yatırım, tekrarlanan bir vergi değil.

### Farm baskısı neden oluşmaz

Her zindanın unlock havuzu **tükenir**. Zehir zindanındaki 11 kararın hepsini verdiysen orayı tekrar oynamak koleksiyon vermez. Optimal oyun otomatik olarak "sıradaki dokunulmamış zindan" olur.

**Tükenmiş zindan ölü değil:** unlock yerine ekonomik ödülü artar (altın çarpanı, kaynak). Koleksiyon için değersiz, köy ekonomisi için değerli.

### Derinlik vs genişlik kuralı

> Her zindan, her temanın **giriş seviyesi** (COMMON/UNCOMMON) item'ını düşük ihtimalle verebilir. Bir temanın **RARE/LEGENDARY'si ve set tamamlayıcıları** sadece kendi zindanından çıkar.

Hiçbir şeye tamamen kilitlenmezsin; ama `poison_mastery` setini tamamlamak için zehir zindanına gitmen gerekir.

---

## 3. ZİNDAN HARİTASI

6 zindan (`WorldManager.TARGET_DUNGEON_COUNT`), her biri bir playstyle + onu ifade eden bir element. **Temalar harita üretiminde sabit atanır** — "zehir zindanı" bir *yer*, bir sıra numarası değil.

| # | Zindan | Playstyle | Element | Set |
|---|--------|-----------|---------|-----|
| 1 | Ateş | Saldırganlık, combo | Ateş | `tri_element` (seed) |
| 2 | Buz | Savunma, kontrol | Buz | `iron_guard` |
| 3 | Zehir | Vur-kaç, sabır | Zehir | `poison_mastery` |
| 4 | Fırtına | Mobilite, hava, menzil | Şimşek | `sky_strike` |
| 5 | Barut | Ağır vuruş, yıkım | Patlama | — |
| 6 | Gölge | Hile, sinerji | Karagöz/gölge | — |

**Dağıtım ilkesi: kategori ≠ tema.** Item'lar koddaki `ItemCategory` enum'una göre değil, *ne yapmanı sağladıklarına* göre dağıtıldı. Kategori "hangi tuşla tetikleniyor"u söyler, tema "hangi build'i kuruyor"u. Bu yüzden 8 parry item'ı 4 ayrı zindana dağılır: `zaman_durdurucu` Buz'dadır (kontrol), `golge_adimi` Gölge'dedir (pozisyon hilesi), `firlatma_parry` Fırtına'dadır (düşmanı havaya fırlatır — hava dövüşü açar).

**Tema saflığı zorunlu değil.** Kasıtlı sürprizler bırakıldı; bkz. Zindan 1'deki `Kor Gömlek` adayı (bölüm 5.7).

### Akrobat hırsız ilkesi

Oyuncu karakteri akrobat bir hırsız. Zindanda altın/loot toplamak bir **beceri ifadesi**: mobility hareketleriyle düşmanlara hiç dokunmadan haritayı soymak geçerli ve kasıtlı bir stratejidir — "sadece para için zindana girmek" desteklenen bir oynanış.

**Sonucu:** toplama, erişme, konumlanma gibi beceri gerektiren eylemleri otomatikleştiren item tasarlanmaz. `miknatis` (altın çekme) bu yüzden oyundan tamamen çıkarıldı — baseline özellik olarak da eklenmez. Tersine, bu fanteziyi besleyen item'lar (dokunmadan geçme, sıyrılma, çalma) güçlü adaylardır: `tepme`, `lagimci`, `yankesici` bu ilkeden doğdu.

**6. zindan en son açılır.** Sebep hem tematik hem mekanik: `ortaoyunu` zinciri (`karagoz_laneti`, `hacivat_golgesi`) ve sinerji item'ları (`element_degisimi`, `elemental_odak`) ancak elinde elementler varken anlamlı. Sinerji zindanı doğal olarak sonuncu.

---

## 4. BAŞLANGIÇ LOADOUT'U (19 item)

**Element yok.** Elementler zindan ödülü. Başlangıç havuzu oyuncuya *fiilleri* öğretir: vur, blokla, parry'le, zıpla, kay, düş, emekle.

| Item | Rarity | Kategori |
|------|--------|----------|
| `baklava` | COMMON | STAMINA |
| `simit` | COMMON | STAMINA |
| `ayran` | COMMON | STAMINA |
| `hizli_el` | COMMON | LIGHT_ATTACK |
| `combo_ustasi` | COMMON | LIGHT_ATTACK |
| `cift_vurus` | UNCOMMON | LIGHT_ATTACK |
| `ucuncu_vurus` | UNCOMMON | LIGHT_ATTACK |
| `demir_kalkan` | COMMON | BLOCK |
| `kalkan_ustasi` | COMMON | BLOCK |
| `parry_ruhu` | UNCOMMON | PARRY |
| `cift_ziplama` | COMMON | JUMP |
| `kus_kanadi` | COMMON | JUMP |
| `zeytinyagi` | COMMON | SLIDE |
| `gokten_dusus` | COMMON | FALL_ATTACK |
| `guc_kayasi` | COMMON | HEAVY_ATTACK |
| `hizli_charge` | COMMON | HEAVY_ATTACK |
| `ruzgar_hanceri` | UNCOMMON | DODGE |
| `tunel_ustasi` | COMMON | CROUCH |
| `topuk_kirici` | UNCOMMON | SLIDE |

**Zayıf item kuralı:** zayıf item **ödül olamaz, başlangıçta olur.** Ödül olarak hayal kırıklığı yaratan item (emekleme hızı, koşullu küçük bonus) baseline araç olarak sorunsuz. `tunel_ustasi` ve `topuk_kirici` bu yüzden burada.

**Set kontrolü:** başlangıçta hiçbir set tamamlanmıyor. `demir_kalkan` (`iron_guard`) ve `gokten_dusus` (`sky_strike`) tek parça olarak duruyor — ikinci parça zindandan gelmeli. Bu yüzden `genis_dusus` bilerek başlangıca alınmadı: o da `sky_strike` üyesi, ikisi birlikte seti bedavaya tamamlardı.

**Tamamen kaldırılan:** `miknatis` (altın çekme). Ne item ne baseline özellik — bkz. bölüm 3, akrobat hırsız ilkesi.

---

## 5. ZİNDAN BAŞINA UNLOCK HAVUZLARI

Her zindan iki alt havuza ayrılır. Kod tarafında ayrım `item_manager.gd` içindeki `DUNGEON_THEME_POOLS` sözlüğünde **açık liste** olarak tutulur (rarity'den türetilmez): çalışma anında sahne instantiate etmeyi gerektirmez, aşağıdaki tablolarla birebir eşleşir ve kasıtlı istisnalara izin verir. Listelerin bütünlüğünü `_validate_unlock_pools()` debug build'de doğrular.

- **Keşif havuzu** = COMMON + UNCOMMON → keşif run 1-3 ödülü
- **Boss havuzu** = RARE + LEGENDARY → boss clear ödülü

`*` = ön koşullu item; ebeveyniyle **bedava** gelir, unlock kararı sayılmaz (bkz. bölüm 7).

### 5.1 Zindan 1 — Ateş / Saldırganlık
**Keşif:** `atesli_yumruk`, `ates_topu_dususu`, `hizlanan_yumruk`, `pala_kilici`, `kan_tadi`, `taskin_guc`, `koz_tutan`†, `koruk`†, `tavlanmis_celik`†
**Boss:** `atesli_kayma`, `genis_darbe`, `berserker_ruhu`, `ocak`†

† = yeni tasarım, henüz kodda yok (bkz. bölüm 5.7)

### 5.2 Zindan 2 — Buz / Savunma-Kontrol
**Keşif:** `buzlu_kilic`, `donma_cekici`, `buz_cagi`, `yansitici_kalkan`, `dikenli_kalkan`, `ters_darbe`, `parry_ustasi`, `olumcul_sukut`, `sansli_nal`, `parry_zirhi`, `savunma_ofkesi`
**Boss:** `buzlu_kayma`, `nazar_boncugu`, `son_kale`, `cuppe_degil_zirh`, `panzehir_derisi`, `zaman_durdurucu` → `kum_saati`*, `kalkan_kuresi`

### 5.3 Zindan 3 — Zehir / Vur-kaç
**Keşif:** `zehirli_tirnak`, `zehirli_dev`, `zehirli_dusus`, `dodge_zehiri`, `ziplama_zehiri`, `ceset_tekmesi`, `les_gazi`, `kaygan_yag`
**Boss:** `gorunmezlik_pelerini`, `hayalet_adim`, `flank_avantaji`, `sabir_tasi`†, `yankesici`†, `serbetci`†, `kan_bedeli`*

### 5.4 Zindan 4 — Fırtına / Mobilite-Hava-Menzil
**Keşif:** `gok_gurultusu`, `yildirim_dususu`, `yildirim_adimi`, `havada_kal`, `sekme_tabanligi`, `genis_dusus`, `firlatma_parry`
**Boss:** `simsek_parmagi`, `slide_simsegi`, `simsek_kalkani`, `duvar_ustasi`, `uzun_menzil`, `ok_yagmuru` → `kartal_bakisi`*, `yanki_oku`*, `ruzgarin_nisani`*, `yansiyan_ok`*, `gerilmis_yay`*

### 5.5 Zindan 5 — Barut / Ağır Vuruş
**Keşif:** `patlama_zinciri`, `kara_barut`, `dodge_bombasi`, `lav_cekici`, `falya`†, `lagimci`†, `tepme`†
**Boss:** `patlama_topuzu`, `barut_zirhi`, `tuzak_fisildayan`, `cenk_meydani`, `yikim_muhru`, `ikinci_nefes`, `cevher_dili`, `tas_yurek`

### 5.6 Zindan 6 — Gölge / Hile-Sinerji
**Keşif:** `golge_pelerini`, `sessiz_ayakkabi`, `ruh_avcisi`, `element_izi`, `ruh_akisi`, `keskin_nazar`
**Boss:** `ortaoyunu` → `karagoz_laneti`*, `hacivat_golgesi`*; `golge_adimi`, `element_degisimi`, `elemental_odak`, `falci_kadin`
**Zincir:** `sadik_golge`* — ebeveyni `ruh_avcisi` keşif havuzunda, orada açılırsa bedava gelir.

### 5.7 Yeni Ateş Item'ları (tasarlandı, kodlanacak)

Teşhis: `atesli_yumruk` yanma **uyguluyor** ama yanmayı **ödüllendiren** hiçbir şey yoktu. Ateş build'i kurulamıyordu; üstüne ateş sürülmüş bir saldırganlık build'i vardı. Ayrıca ateşin blok/parry karşılığı hiç yoktu.

**Köz Tutan** — `koz_tutan`, COMMON, SPECIAL
Yanan bir düşman öldüğünde alev en yakın düşmana sıçrar.
Eksisi yok; zincirin kilidini açan parça. `patlama_zinciri`nin ateş kardeşi.

**Körük** — `koruk`, UNCOMMON, STAMINA
Combo sayacı 5'i geçince vücudun tutuşur; 4 sn boyunca yakındaki düşmanlar yanar.
**Eksi:** tutuşukken aldığın hasar +%20.
Zindanın kimliğiyle birebir: saldırganlığı ödüllendirir, riski artırır.

**Tavlanmış Çelik** — `tavlanmis_celik`, UNCOMMON, BLOCK
Blok yaptığında kalkanın kızarır; 3 sn içindeki blok saldırganı yakar.
**Eksi:** kızgın kalkanla blok stamina'yı 2 kat harcar.
`simsek_kalkani`nin ateş kardeşi; ateşe eksik olan savunma verb'ünü verir.

**Ocak** — `ocak`, RARE, SPECIAL
Yanarak ölen düşman yere 3 sn kalan bir kor bırakır: üstünden geçen düşman yanar, sen geçersen +stamina.
Alan kontrolü; `les_gazi` / ceset ekonomisiyle sinerji.

**Değerlendirilip alınmayanlar:** `Kundakçı` (yanma tazeleme + stack limiti, eksi: yanmayanlara −%10 hasar), `Sıcak Demir` (şarjlı heavy yanma, eksi: şarjda −%30 hız), `Kor Gömlek` (perfect parry → 3 sn tüm light attack'ler yakar — Buz'un parry tekelini kıran kasıtlı sürpriz). İleride Ateş genişletilirse aday.

### 5.8 Yeni Barut Item'ları (tasarlandı, kodlanacak)

Teşhis: keşif havuzundaki 4 item de patlamayı **uyguluyordu**, hiçbiri patlamayı bir kaynağa çevirmiyordu. Zindanın tasarım dili net — *kendi silahın seni de yakar*: `patlama_zinciri` oyuncuya da hasar verir, `kara_barut` her patlamada %3 max can alır, `barut_zirhi` (RARE) bu bağışıklığı satar. Yeni item'lar bu ekonomiyi besliyor.

**Falya** — `falya`, COMMON, HEAVY_ATTACK
*Topun ateşleme deliği.* Tam şarj edilmiş heavy attack küçük bir patlama ekler; eksik şarjda patlama yok.
Eksisi yok, giriş item'ı. `hizli_charge` (başlangıçta) ile doğrudan sinerji; `patlama_topuzu` (RARE) bunun büyük kardeşi — öğretici basamak.

**Lağımcı** — `lagimci`, UNCOMMON, SLIDE
*Osmanlı istihkam eri: tünel kazar, duvar uçurur.* Kayarken arkanda barut izi bırakırsın; iz 3 sn sonra ya da bir düşman değince patlar.
**Eksi:** iz seni de yakar.
`dodge_bombasi`nin slide kardeşi; `kaygan_yag` ve `tunel_ustasi` ile sinerji.

**Tepme** — `tepme`, UNCOMMON, HEAVY_ATTACK
Havadayken yapılan heavy attack seni ters yöne fırlatır (patlama tepmesi). Heavy artık bir mobility aracı.
**Eksi:** her tepme %3 max can.
Mobiliteyi canla satın alıyorsun; `barut_zirhi` bunu bedavaya çevirdiği için o item sadece savunma değil, dikey bir build kilidi oluyor.

### 5.9 Yeni Zehir Item'ları (tasarlandı, kodlanacak)

Teşhis: boss havuzundaki 3 RARE'in üçü de stealth/pozisyondu (`gorunmezlik_pelerini`, `hayalet_adim`, `flank_avantaji`). **Zehrin kendisinin RARE'i yoktu** — bütün `zehirli_*` item'ları UNCOMMON. Zehir build'inin tavanı ve `poison_mastery` setinin kapstone'u eksikti; zindan zehir değil sinsilik veriyordu.

**Sabır Taşı** — `sabir_tasi`, RARE, SPECIAL
Zehirli düşman ne kadar uzun zehirli kalırsa zehir hasarı artar (saniyede +%15, max 5 kat). **Ona vurduğun anda sayaç sıfırlanır.**
Zindanın kimliği olan "sabır"ı mekanikleştirir: vur, çekil, izle, dokunma. `gorunmezlik_pelerini` ile birebir. `poison_mastery`nin eksik zirvesi.

**Yankesici** — `yankesici`, RARE, SPECIAL
Zehirli bir düşmanın yanından dodge ile geçtiğinde ondan altın çalarsın; miktar zehir stack'i başına artar.
**Eksi:** çaldığın düşman 3 sn öfkelenir, hasarı artar.
Akrobat hırsız fantezisini doğrudan mekanikleştirir (bkz. bölüm 3).

**Şerbetçi** — `serbetci`, RARE, SPECIAL
Zehirli bir düşman öldüğünde zehir stack'leri en yakın düşmana geçer; her geçişte 1 azalır.
Sönümlü zincir — `patlama_zinciri`nin zehir kardeşi ama daha stratejik: bir hedefte stack biriktirip öldürerek sürüye yayarsın.

### 5.10 Havuz büyüklükleri

Ön koşullu item'lar bedava geldiği için **unlock kararı** sayısı item sayısından az.

| Zindan | Keşif | Boss | **Karar** | Bedava |
|--------|-------|------|-----------|--------|
| 1 Ateş | 9 | 4 | **13** | — |
| 2 Buz | 9 | 6 | **15** | 1 |
| 3 Zehir | 8 | 6 | **14** | 1 |
| 4 Fırtına | 7 | 6 | **13** | 5 |
| 5 Barut | 7 | 8 | **15** | — |
| 6 Gölge | 6 | 5 | **11** | 3 |

Toplam 81 unlock kararı. Aralık 11–15; en ince olan Gölge, ki son zindan olduğu için kabul edilebilir.

---

## 6. UNLOCK TAKVİMİ

`DungeonProgress` her zindanda 3 alıştırma run'ı (1/2/3 bölüm, boss yok) sonra boss run'ı tutuyor. Tetik noktaları hazır: `record_warmup_complete()` ve `record_clear()`.

| Olay | Ödül | Havuz |
|------|------|-------|
| Keşif run 1 (1 bölüm) | 3 seçenek → 1 seç | Zindanın **keşif** havuzu |
| Keşif run 2 (2 bölüm) | 3 seçenek → 1 seç | Zindanın **keşif** havuzu |
| Keşif run 3 (3 bölüm) | 3 seçenek → 1 seç | Zindanın **keşif** havuzu |
| İlk boss clear | 3 seçenek → 1 seç | Zindanın **boss** havuzu |
| 2+ boss clear | 3 seçenek → **2 seç** | Zindanın boss havuzu |
| 3. clear | LEGENDARY ağırlığı artar | Zindanın boss havuzu |

**Neden keşif de temadan veriyor:** ilk tasarımda keşif ödülleri "nötr" bir havuzdan geliyordu. Yanlıştı — o havuz tanım gereği artakalanlardan oluşuyordu, yani oyuncunun hayatındaki ilk üç unlock'ı en sıkıcı item'lar oluyordu. Şimdi ateş zindanındaki ilk unlock `atesli_yumruk`: zindanın kimliğini ilk dakikadan hissediyorsun, boss ödülü de özel kalıyor çünkü derinlik orada.

**Seçilmeyen 2 item yok olmaz** — aday torbasına döner, sonra tekrar çıkabilir. Kalıcı kayıp FOMO ve analiz felci üretir; sıralama kararı zaten yeterince anlamlı.

**Ölümde teselli ödülü yok.** Sonucu: keşif run 1 neredeyse kaybedilemez olmalı. Oyuncu ilk unlock'ını mutlaka görmeli, yoksa sistem daha başlamadan tıkanır. Zorluk 3. keşif run'ından itibaren gelsin.

### Tempo

110 item (101 mevcut − 1 kaldırılan + 10 yeni tasarım), 19'u başlangıçta → 91 kalır. Ön koşullu 10 item ebeveyniyle bedava → **81 unlock kararı**. Garantili olay: 6 zindan × 3 keşif + 6 ilk boss = 24. Gerisini tekrar clear'lar taşır (boss başına 2 seçim).

---

## 7. SERT KISITLAR

### 7.1 Ön koşul zinciri

`item_manager.gd` içindeki `ITEM_REQUIREMENTS` / `ITEM_REQUIREMENTS_ANY`:

```
kum_saati        <- zaman_durdurucu
karagoz_laneti   <- ortaoyunu
hacivat_golgesi  <- ortaoyunu
sadik_golge      <- ruh_avcisi
kan_bedeli       <- cevher_dili | yikim_muhru
yansiyan_ok / ruzgarin_nisani / yanki_oku / kartal_bakisi / gerilmis_yay
                 <- uzun_menzil | ok_yagmuru
```

**Kural:** çocuk item asla ebeveyninden önce teklif edilmez; ebeveyn açılınca çocuk **otomatik açılır**. Aksi halde koleksiyonda ölü ağırlık olur ve tempo matematiği bozulur.

Dikkat: `kan_bedeli`nin ebeveynleri Barut zindanında (`cevher_dili`, `yikim_muhru`) ama kendisi Zehir listesinde. Zehir'i tamamlayan oyuncu Barut'a gitmediyse onu göremez — kasıtlı çapraz bağ.

### 7.2 Setler

`ITEM_SET_DEFINITIONS` (2 parça = bonus). Bir set parçası açıldığında kardeş parçaların teklif ağırlığı artmalı, yoksa setler istatistiksel olarak tamamlanmaz.

| Set | Ana zindan | Not |
|-----|-----------|-----|
| `iron_guard` | 2 (Buz) | `demir_kalkan` başlangıçta, 1 parça eksik |
| `poison_mastery` | 3 (Zehir) | tamamı tek zindanda |
| `sky_strike` | 4 (Fırtına) | parçaları zindanlara yayılmış — çapraz set |
| `tri_element` | 1 / 2 / 4 | 3 elementten 2'si gerek — çapraz set |

`sky_strike` ve `tri_element` bilinçli olarak çapraz: birden fazla zindanı gezen oyunculara ödül.

---

## 8. ZİNDAN İÇİ MARKET

**Altyapı zaten var.** `DungeonEventInteractable.gd` içinde `merchant` event'i yan yollarda/çıkmazlarda spawn oluyor (`level_generator.gd` → `_tag_dungeon_event_side_paths()`), spawn şansı seviyeye göre %14→%32 (`level_config.gd` → `dungeon_event_chance_base`). Şu an erzak/anahtar/kumar satıyor. **Kart satışı buraya eklenecek** — yeni chunk tipi gerekmiyor.

### Market bir KAPI

Yan yol prop'u sandık/varil değil, zindanın kendi kapı sanatı (`assets/objects/dungeon/door_1.png`,
8 kareli sheet, kapalı kare 0). Oyuncu kapıya yaklaşıp yukarı basar, kart arayüzü açılır.
`InteractableVisualHelper.attach_centered_sprite()` bunun için `hframes`/`frame` desteği aldı —
öncesinde 8 kapı yan yana sıkışmış görünürdü.

**Ölçü gerçek kapılarla birebir:** ölçek 1 (kare 192x192), sprite düğümün 97 piksel üstünde —
`CampDoor.tscn` ile aynı. `fit_texture_scale()` artık `max_size` bileşeni 0 ise o eksende sınır
uygulamıyor (eskiden ölçek 0 çıkıp sprite görünmez olurdu).

**Zemine oturma kapının kendi işi.** İlk karede aşağı ışın atıp gerçek zemini bulur ve Y'sini
oraya çeker (`_snap_to_ground`). Yerleştiren tarafın "zemin" referansına güvenilmiyor, çünkü
iki çağıran da yanlış referans veriyordu:

- `level_generator` dekorasyon konvansiyonunu kullanıyor (zemin karosunun üstü −20, +5). Küçük
  merkez pivotlu sandık için doğru ama alt kenarından hizalanan 192 piksellik kapı 16 piksel
  havada kalıyordu.
- Dev konsolu `player.get_foot_position()` kullanıyordu. **O fonksiyonun kendisi hatalı:**
  oyuncu sprite'ının `(1, -48)` yerel ofsetini hesaba katmadan `global_position`'a sprite
  yüksekliğinin yarısını ekliyor, yani ayak hizasının ~53 piksel ALTINI döndürüyor. Kapı bu
  yüzden zemine gömülüyordu.

`get_foot_position()` düzeltilmedi çünkü mevcut çağıranlar (örn. `atesli_kayma`) sapmayı elle
telafi edecek şekilde ayarlanmış; kod içinde "get_foot_position zeminin altında kalabildiği
için yukarıda spawn ediyoruz" notu var. Yeni `lagimci` de aynı telafiyi uyguluyor.

### Arayüz okunabilirliği (playtest düzeltmeleri)

- **Başlık moda göre ve çeviriden.** Sahnede sabit "Choose Your Item" yazıyordu: hem İngilizceydi
  hem dükkânda yanlıştı. Artık `item_selection.title.{draft,unlock,shop}`.
- **Fiyat kartın üst görsel alanında, 34 punto, altın ikonuyla.** Köşede 14 punto rozet
  denendi, okunmuyordu.
- **Kese bakiyesi cümle değil sembol.** Başlığın altında altın ikonu + 44 punto sayı.

### Ne satar

**Run-içi kart, kalıcı unlock DEĞİL.** Sebep: altınla kalıcı unlock alınabilirse altın evrensel çözücü olur, oyuncu en kolay zindanı farmlayıp her şeyi satın alır ve zindan coğrafyası çöker.

Erzak, anahtar ve pazarlık seçenekleri kaldırıldı; market sadece kart satar. Anahtar ekonomisi
etkilenmiyor: segment çıkış anahtarını zaten seviye üreteci yerleştiriyor
(`level_generator.gd` → `Spawner.spawn_dungeon_key`), tüccar tek kaynak değildi.

### Kurallar

1. **3 kart görünür ve fiyat etiketli.** Rastgele çekiliş değil — market'in tüm değeri
   "istediğimi seçebiliyorum". Arayüz `ui/item_selection.tscn`'in üçüncü modu ("dükkân"):
   draft ekranıyla aynı kart görselleri. Parası yetmeyen kart soluk ve kırmızı görünür,
   seçilemez. Escape ile eli boş çıkılır (draft ekranından tek davranış farkı bu).
2. **Alışveriş tek seferlik değil.** Kart alınınca tezgâhtan kalkar, dükkân açık kalır;
   oyuncu parası yettiği sürece devam eder. Ödeme `setup_shop`'a verilen `buy_handler`
   callable'ı üzerinden senkron yapılır (arayüz altın harcamaz, sadece sorar).
   Tezgâh boşalınca kapı kapanır.
2. **Stok build'e ağırlıklı.** `item_manager._get_favored_category()` zaten yazılı (Falcı Kadın item'ı için), aynen yeniden kullanılır.
3. **Stok event başına bir kez belirlenir.** Kapıyı kapatıp açmak vitrini yenilemez.

### Fiyatlar kasıtlı olarak fahiş

| Rarity | Taban | Seviye başına |
|---|---|---|
| COMMON | 45 | +6 |
| UNCOMMON | 70 | +6 |
| RARE | 110 | +6 |
| LEGENDARY | 180 | +6 |

Bir run'ın toplam altını bu ölçekte, yani tek kart ciddi bir feragat.

### Tasarım gerilimi (kasıtlı)

Run altını çıkışta `gold_multiplier_accumulated` ile köye taşınıyor (`DungeonRunState.gd`). Markette kart almak = **köy geliştirmesinden feragat**. Sıfır toplamlı, her seferinde acıtan bir karar. Fiyatlar hissedilir olmalı.

---

## 9. FALCI NPC (sonraki faz)

**İsim çakışması:** `falci_kadin` zaten bir item (`item_manager.gd`, kategori yönlendirme yapıyor). NPC'ye farklı isim verilecek ya da item ona bağlanacak (falcıyla tanışınca açılır).

Yetenekleri, değer sırasına göre:

1. **Silme** — "bu item bir daha teklif edilmesin". Meta-progression'daki en güçlü kaldıraç: gelecekteki *bütün* run'ların kalitesini yükseltir. Ücretli, sınırlı.
2. **Kehanet** — para karşılığı sonraki zindanın unlock teklifini belirli bir kategoriye/elemente yönlendirir. Rastgeleliğe karşı valf.
3. **Takas** — istenmeyen bir açık item'ı aynı rarity'de rastgele başkasıyla değiştirir.

Kervanla birlikte gelir (ticaret sistemi mevcut), her N günde bir 1-2 gün kalır. Kaçırma riski köye dönmeye sebep yaratır.

---

## 10. UI

### Dünya haritası (karar verildi)

Her zindan hex'inin yanında **doluluk göstergesi**: "Zehir Zindanı 7/11". Completionist baskısı, keşif teşvikinin en ucuz ve en etkili hali. `WorldManager` hex tile verisi zaten mevcut.

### Unlock seçim ekranı

`ui/item_selection.tscn` "unlock modu" ile yeniden kullanılır — yeni ekran yazılmaz.

**Ne zaman açılır:** run bitiminde, zindandan çıkarken (boss kapısı / keşif çıkışı). Köye dönünce değil — ödül eylemle aynı anda gelmeli.

---

## 11. UYGULAMA PLANI

### Faz 1 — Unlock çekirdeği ✅ TAMAM

- `ItemManager`'a `unlocked_item_ids: Array[String]` + `STARTER_ITEM_IDS` sabiti
- `ItemManager`'a `DUNGEON_THEME_POOLS: Dictionary` (zindan teması → item id listesi)
- Keşif/boss ayrımı `DUNGEON_THEME_POOLS` içinde açık liste
- `get_random_items()` içine tek satır filtre: `if not is_unlocked(item_id): continue`
- Ön koşul kaskadı: `unlock_item()` ebeveyni açınca çocukları da açar
- `get_save_data()` / `load_save_data()` — `DungeonProgress` deseninin aynısı, `SaveManager.gd` kancası
- `record_warmup_complete()` / `record_clear()` sonrası unlock teklifi tetikle
- `item_selection.tscn` unlock modu

**Havuz durumu neden `ItemManager`'da:** state havuzun yaşadığı yere konur; filtre `get_random_items()` içinde tek satır olur. Tetik `DungeonProgress`'te kalır — orada zaten var ve doğru yerlerden çağrılıyor.

### Faz 2 — Yeni item'lar (10 adet) ✅ TAMAM
Bölüm 5.7 (Ateş: `koz_tutan`, `koruk`, `tavlanmis_celik`, `ocak`), 5.8 (Barut: `falya`, `lagimci`, `tepme`), 5.9 (Zehir: `sabir_tasi`, `yankesici`, `serbetci`).
`miknatis` tamamen silindi (`ITEM_SCENES`, sahne/script dosyaları, çeviri satırları).

Uygulamada iki tasarım sapması oldu:

**Falya şarj değil zamanlama item'ı.** `HeavyAttackState`'te bir şarj seviyesi kavramı yok; onun
yerine 60 ms'lik bir "just" mükemmel zamanlama penceresi var (`JUST_WINDOW_LENGTH`, +%25 hasar).
Falya artık bu pencereyi tutturan heavy'ye patlama ekliyor. Tematik olarak daha isabetli (falya =
ateşleme anı) ve mevcut mekaniği kullanıyor. Gerektirdiği tek ekleme: `player.last_heavy_just_bonus`
bayrağı, `heavy_attack_impact` emit edilmeden hemen önce yazılıyor.

**Yankesici'nin eksisi "öfkelenme" değil, zehir bedeli.** Düşmanlarda hasar çarpanı alanı yok, öfke
sistemi sıfırdan yazılacaktı. Bunun yerine her çalma o düşmandan bir zehir katmanı tüketiyor: hem
soyup hem zehirle öldürmek verimsiz, oyuncu seçim yapıyor. Mevcut state üzerinden çalışan, gerçek
bir takas.

Yeni item'lar mevcut altyapıyı kullanıyor: `ExplosionModifiers` (Barut Zırhı bağışıklığı, Kara
Barut yarıçapı/tepmesi), `add_burn_stack` / `add_poison_stack`, `stamina_bar`, `credit_run_loot_gold`.
Yeni efekt script'leri: `effects/ocak_embers.gd`, `effects/powder_trail.gd`.

### Faz 3 — Market ✅ TAMAM

`DungeonEventInteractable` içindeki mevcut `merchant` event'ine iki seçenek eklendi; yeni chunk
tipi ya da yeni sahne yazılmadı.

Market artık **bir kapı**: prop görseli zindan kapısı, açınca kart arayüzü geliyor. Erzak /
anahtar / pazarlık seçenekleri kaldırıldı, sadece kart satılıyor. Fiyatlar fahiş (bkz. bölüm 8).

Arayüz `ui/item_selection.tscn`'in üçüncü modu: aynı kart görselleri, fiyat rozeti, kese bakiyesi,
Escape ile çıkış. `InteractableVisualHelper` sprite sheet (`hframes`) desteği aldı.

**Ertelenen:** run içi "bu kartı bir daha gösterme" hizmeti. `ItemManager.banish_item_for_run()`
yazıldı ve çalışıyor ama markete bağlanmadı — üç kartlık vitrini kalabalıklaştırıyordu.
Kavramsal yeri zaten falcı (Faz 5), orada açılacak.

**Yan bulgu — mevcut hata düzeltildi:** `item_button.setup()` buton ağaca eklenmeden
`has_node("/root/ItemManager")` çağırıyordu; Godot bunu
"Can't use get_node() with absolute paths from outside the active scene tree" ile reddediyor.
Yani set ipuçları (`get_set_hint_if_selected`) **draft ekranında da hiç görünmüyormuş**.
Autoload erişimi `Engine.get_main_loop().root` üzerinden yapılacak şekilde düzeltildi.

`ItemManager` tarafında eklenenler:
- `get_offer_candidate_ids()` — `get_random_items()` artık bunun üzerine kurulu, tek kaynak
- `pick_merchant_stock(count)` — build'e ağırlıklı vitrin
- `get_item_meta(id)` — ad/açıklama/rarity/kategori; sahne instantiate ettiği için sadece
  vitrinde kullanılır, kart çekiminde değil
- `banish_item_for_run(id)` / `is_banished_for_run(id)` — run'a özgü eleme,
  `clear_all_items()` ile sıfırlanır (kalıcı silme falcının işi, Faz 5)

### Faz 4 — Dünya haritası göstergesi ✅ TAMAM

Zindan hex balonuna tema + doluluk satırı eklendi: **"Zehir zindanı: 7/14 eşya açık"**.
Yeri `WorldMapScene._build_dungeon_hex_tooltip_lines()`, mevcut ad/zorluk satırlarının altında.
Balon zaten "yalnızca o karonun bilgisi" kuralına tabi (CLAUDE.md) ve koleksiyon doluluğu tam
olarak o karonun bilgisi, oynanış talimatı değil.

Tema adları çeviriye taşındı (`dungeon.theme.*.name`) ve tek kaynaktan okunuyor:
`WorldManager.get_dungeon_theme_display_name()`. Kart ekranındaki yerel tema sözlüğü silindi,
o da aynı fonksiyonu çağırıyor. Kart ekranının dükkân/unlock metinleri de `tr()` üzerinden.

Gösterilen sayı **unlock kararı** sayısıdır: ön koşullu item'lar ebeveyniyle bedava geldiği için
toplama dahil değil. Böylece "13/13" gerçekten "bu zindanda verecek kararım kalmadı" demek.

### Faz 5 — Falcı NPC ✅ TAMAM

Üç hizmet, hepsi kalıcı koleksiyon üzerinde çalışıyor ve kayda yazılıyor:

| Hizmet | Ücret | Ne yapar |
|---|---|---|
| **Sil** | 120 | Item bir daha kart olarak teklif edilmez (run draft'ı + unlock teklifleri) |
| **Takas** | 80 | Item aynı rarity'den rastgele başkasıyla değişir |
| **Kehanet** | 60 | Sonraki unlock teklifinde bir slot seçilen kategoriye yönlenir, tek kullanımlık |

**İki koruma var.** Ön koşul **ebeveynleri takas edilemez** — `uzun_menzil` çıkarılsa ona bağlı
5 okçuluk item'ı koleksiyonda ölü ağırlık kalırdı; `ITEM_REQUIREMENTS_ANY` için başka bir
ebeveyn hâlâ açıksa takasa izin verilir. **Başlangıç loadout'u** ne silinebilir ne takas
edilebilir: onlar temel araçlar, falcının işi değil.

**Takvim `ItemManager`'da, tüccar sistemine bağlanmadı.** Tüccar listesi kaynak/ürün satışı
üzerine kurulu; falcının satacak ürünü yok ve ticaret arayüzünde ürünsüz bir satıcı olarak
görünürdü. 6-9 günde bir gelir, 2 gün kalır (`TimeManager.day_changed` ile ilerler).
`VillageManager._sync_falci_npc()` `falci_presence_changed` sinyalini dinleyip sprite'ı
ekliyor / yürüterek çıkarıyor.

**Arayüz** `ui/FalciPopupUI.gd` — tüccar penceresiyle aynı parşömen iskeleti, oyunu durdurmaz.
Üstte kehanet kategorileri, altta koleksiyon listesi (her satırda Sil ve Takas), kart
kenarlığı rarity rengine boyalı.

**GEÇİCİ SANAT:** falcının sprite'ları şimdilik tüccarınkiler, mor tonlamayla ayırt ediliyor
(`FalciVillageNPC.gd` → `_apply_placeholder_tint()`). Kendi sheet'leri gelince
`FalciVillageNPC.tscn` içindeki dört texture yolunu değiştirmek ve o fonksiyonu silmek yeterli.

**İsim çakışması hatırlatması:** `falci_kadin` hâlâ ayrı bir item. NPC ile bağlantısı kurulmadı.

### Faz 6 (koleksiyon ~50'yi geçince) — Heybe/Deste

Koleksiyon büyüdükçe draft tekrar bulanıklaşır (havuz seyrelmesi paradoksu). O noktada sınırlı slotlu bir seçki katmanı gerekir: run içi 3 karttan 2'si heybeden, 1'i koleksiyondan joker. **Şimdi yapmak erken optimizasyon** — havuz 19→40 arası düz havuz olarak sorunsuz çalışır.

---

## 12. AÇIK KONULAR

- `sessiz_ayakkabi` (gürültü −%50) ödül olarak zayıf. Stealth sistemi (stealth chest, stealth exit, `golge_pelerini`) mevcut olduğuna göre ya gerçek bir stealth enabler'a güçlendirilmeli ya da başlangıca alınmalı.
- Boss imza item'ı (her boss'a sabit tematik ödül) ertelendi.
- Item mastery (bir item'ı N kez kullanınca küçük yükseltme) değerlendirilmedi.
