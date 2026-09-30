# Boru Hattı Kompozisyonu — Item Sistemi V4 (2026-09-30, düzeltilmiş)

> **Durum: saf tasarım, hiçbir kod değişikliği yapılmadı.** Bu doküman
> `ITEM_SYNERGY_DESIGN.md` §10-11'deki "kaynak/eşik" formülünün YERİNE geçen
> bir yaklaşımı tarif ediyor — o bölümler tarihsel kayıt olarak duruyor, ama
> güncel yön burası. Kullanıcı geri bildirimi netti: sayaç doldurup okumak
> ("toplama sinerjisi") yeterince "deck-builder" hissettirmiyor. Asıl istenen
> **dönüşüm sinerjisi**: bir item'ın eylemin NE OLDUĞUNU değiştirmesi, sadece
> bir sayıyı büyütmesi değil.
>
> **Bu revizyon, ilk taslaktaki 3 hatayı düzeltiyor** (kullanıcı review'ında
> yakalandı): (1) "Mermi" ayrı bir boru hattı değil, Temas Saldırısı'nın bir
> alt-dalı — çünkü menzilli saldırı temel bir fiil değil, bir item'ın (Uzun
> Menzil) dönüştürdüğü bir şey. (2) "Tuzakçı" ayrı bir hat olamaz çünkü
> oyuncunun "tuzak yerleştir" diye bir fiili yok — tuzaklar zindana önceden
> rastgele yerleşiyor, oyuncu sadece onlarla etkileşebiliyor. (3) Element ayrı
> bir kaynak/hat değil, herhangi bir hattın Yük katmanının seçebileceği bir
> **teslimat tipi** — bu da "melee mage / ranged fighter" gibi hibrit
> kimliklerin nasıl ortaya çıkacağını açıklıyor (bkz. §3).

## 0. Neden bu formül — mevcut kodda zaten kanıtlanmış bir emsal var

`resources/items/uzun_menzil.gd` bir "mermi dalı" açıyor (light attack artık
melee değil projectile). Bundan sonra `yansiyan_ok` (sekme), `ruzgarin_nisani`
(element), `yanki_oku` (echo), `kartal_bakisi` (menzil+kritik), `gerilmis_yay`
(şarj) — hepsi AYNI dala birer adım ekliyor (`ITEM_REQUIREMENTS_ANY` ile
önkoşullu, `_apply_projectile_upgrades()` üzerinden). Bu aile muhtemelen
oyundaki en "sinerjik hisseden" item grubu. Bu doküman bu deseni BİLİNÇLİ
olarak 5 boru hattına yayıyor.

## 1. Evrensel boru hattı şekli

Her boru hattı 4 katmandan oluşur, item'lar bu katmanlara "adım ekler" ya da
mevcut bir adımın parametresini değiştirir:

| Katman | Soru | Örnek |
|---|---|---|
| **Tetik** | Ne zaman ateşleniyor? | "light attack basıldığında" |
| **Hedef** | Kimi/neyi etkiliyor? | "tek hedef" → "3'e ayrılan yelpaze" |
| **Yük** | Etkilenene ne oluyor? | "hasar" → "hasar + element" |
| **Son-etki** | Sonra ne doğuyor? | "yok olur" → "2. kez patlar" |

Bir boru hattı **item'sız da temel bir şekilde çalışır** (base davranış) —
item'lar onu zenginleştirir/dönüştürür, var etmez.

---

## 2. Boru Hatları (5 tane)

### 2.1 ⚔️ Temas Saldırısı (light/heavy/fall) — ve onun Mermi alt-dalı

**Temel:** light combo (3-4 vuruş zinciri), heavy (tek, güçlü knockback),
fall (düşüş vuruşu). Hepsi melee — oyuncu itemsiz sadece yumruğuyla dövüşür.

| Katman | Item | Rarity | Etki |
|---|---|---|---|
| Tetik | **Kesintisiz Zincir** *(yeni)* | Rare | Light combo süresi bitmeden basmaya devam edersen zincir hiç kesilmez (her 5 vuruşta hasar biraz düşer — kendi içinde bedel) |
| Hedef | Pala Kılıcı / Cenk Meydanı / Geniş Düşüş *(var)* | Uncommon-Rare | Light/heavy/fall çok-hedefli olur (sabit, her vuruşta aynı) |
| Hedef | **Daire Darbesi** *(yeni)* | Rare | Heavy attack 360° vurur (yönsüz) |
| Hedef | **Sırt Darbesi** *(yeni)* | Rare | Combo'nun 3. vuruşu artık ARKAYA da vurur — çevrelenirsen sırtındaki düşmanı da yakalarsın |
| Hedef | **Kesme Yayı** *(yeni)* | Uncommon | Combo'nun SON vuruşu geniş bir yay çizip 180° kapsar |
| Hedef | **Zincirleme Vuruş** *(yeni)* | Rare | Bir vuruş bir düşmanı öldürürse, aynı vuruşun hitbox'ı anında 60px ileri uzayıp arkasındaki düşmana da değer |
| Yük | Zehirli Tırnak / Ateşli Yumruk / Buzlu Kılıç / Şimşek Parmak *(var)* | Uncommon-Rare | Saldırı tipini element'e çevirir — **bu hattın ana element KAYNAĞI** (diğer hatlar bunu "taşır", kendi üretmez) |
| Yük | **Artan Güç** *(yeni)* | Uncommon | Combo'nun her vuruşu bir öncekinden %10 güçlü (5. vuruşta sıfırlanır) — teslimat mekanizmasından (melee/ranged) bağımsız, sadece combo pozisyonunu okur |
| Son-etki | **Zıplatan Yumruk** *(yeni)* | Rare | Normal heavy attack de Havaya Fırlatma boru hattını tetikler |
| Son-etki | **Güç Devri** *(yeni)* | Rare | Bir vuruş öldürürse, sıradaki vuruşun hasarı +%50 (can çalmıyor — zincirleme öldürme ödülü) |
| Son-etki | **Sarsıcı Darbe** *(yeni)* | Uncommon | Her 3. vuruş küçük bir shockwave (yakın AoE) yayar |

**Mermi alt-dalı** (açıcı gerekir — `uzun_menzil`/`ok_yagmuru` olmadan bu
katman hiç yok): light/heavy attack'in teslimat mekanizmasını melee hitbox'tan
projectile'a çevirir.

| Katman | Item | Rarity | Etki |
|---|---|---|---|
| Dönüştürücü | Uzun Menzil / Ok Yağmuru *(var)* | Rare | Light/heavy attack artık projectile, %70 hasar |
| Tetik | **Gölge Nişancı** ✅ | Rare | Fall attack, iniş noktasından aşağı yönlü bir mermi fırlatır (AoE patlamıyor, alt katmanlara devam ediyor) — `golge_nisanci.gd`, `fall_attack_impacted` |
| Hedef | Yansıyan Ok *(var)* | Rare | Mermi 1 kez sekip 2. hedefe çarpar |
| Hedef | **Sürü Oku** ✅ | Rare | Mermi 3'e ayrılır (±15° yelpaze), her biri %40 hasar — `ItemManager.spawn_upgraded_projectile()` |
| Hedef | **Peşine Düşen** ✅ | Uncommon | Mermi hafif homing kazanır (220px menzil, saniyede orantılı dönüş) — `light_attack_projectile.gd:homing_strength` |
| Yük | Rüzgârın Nişanı *(var)* | Uncommon | **Element köprüsü**: aktif elementini mermiye bulaştırır (kendi element üretmiyor, Temas Saldırısı'ndan taşıyor) |
| Yük | Kartal Bakışı *(var)* | Uncommon | Menzil sınırı kalkar, 300px+ isabet otomatik kritik |
| Yük | **Ağır Mermi** ✅ | Common | Mermi knockback da verir (Uzun Menzil'in sildiği knockback'i opsiyonel geri getirir) — `light_attack_projectile.gd:knockback_force` |
| Son-etki | Yankı Oku *(var)* | Uncommon | Çarptıktan 1sn sonra aynı noktada 2. patlama |
| Son-etki | Gerilmiş Yay *(var)* | Rare | Tut-bırak şarj, şarj oranlı menzil+hasar |
| Son-etki | **Ruh Mermisi** ✅ | Legendary | Mermi bir düşmanı öldürürse anında en yakın başka düşmana (200px) yönelip devam eder — sınırsız zincir, eşik yok — `light_attack_projectile.gd:soul_chain` |

> **Not (2026-09-30):** Mermi'nin 8 yükseltme item'ı (Yansıyan Ok, Rüzgârın
> Nişanı, Yankı Oku, Kartal Bakışı, Gerilmiş Yay + yeni Sürü Oku/Ağır
> Mermi/Peşine Düşen/Ruh Mermisi) artık TEK bir merkezi fonksiyonda uygulanıyor:
> `ItemManager.spawn_upgraded_projectile()`. Öncesinde `uzun_menzil.gd` ve
> `ok_yagmuru.gd`'de birbirinin birebir kopyası iki `_apply_projectile_upgrades()`
> vardı; Sürü Oku'nun yelpaze-spawn'ı ve Gölge Nişancı'nın üçüncü çağrı noktası
> bunu üçlemek yerine merkezileştirmeyi haklı çıkardı — artık her üç tetikleyici
> (Uzun Menzil, Ok Yağmuru, Gölge Nişancı) aynı fonksiyonu çağırıyor, yeni bir
> mermi yükseltmesi eklemek TEK yerde yapılıyor.

**Örnek yığılma (melee):** Cenk Meydanı + Daire Darbesi + Zıplatan Yumruk +
Sarsıcı Darbe → tek bir heavy attack, etrafındaki herkesi 360° vurup havaya
kaldırıyor ve her 3 vuruşta shockwave yayıyor.

**Örnek yığılma (ranged, "Ranged Fighter"):** Uzun Menzil + Sürü Oku + Ağır
Mermi + Artan Güç → element YOK, saf fiziksel — combo pozisyonu okuyan Artan
Güç, teslimat mekanizması ranged olsa da çalışmaya devam ediyor.

**Örnek yığılma (ranged, "Ranged Mage"):** Uzun Menzil + Rüzgârın Nişanı +
Zehirli Tırnak (Temas Saldırısı'ndaki element kaynağı) → mermiler artık zehir
taşıyor, hiçbiri "birlikte çalışsın" diye tasarlanmadı.

### 2.2 💨 Kaçınma (dodge/dash)

**Temel:** dodge/dash = kısa/uzun mesafe hareket + i-frame (dash için
`ruzgar_hanceri` gerekir, starter havuzunda).

| Katman | Item | Rarity | Etki |
|---|---|---|---|
| Tetik | **Refleks** *(yeni)* | Legendary | Hasar almadan hemen önceki dar pencerede otomatik dodge tetiklenir (rundan 1 kez) |
| Hedef | **Geniş Kavis** *(yeni)* | Uncommon | Dodge'ın temas alanı genişler |
| Yük | Zehirli Sekme *(var, genellenmiş)* | Rare | **Element köprüsü**: içinden geçilen düşmana temas hasarı + aktif element (hangi element olursa) |
| Yük | **Soğuk Temas** *(yeni)* | Common | Temas edilen düşman kısa süre yavaşlar (element'siz de çalışır, öğretmen item) |
| Son-etki | Kesintisiz Akış *(var)* | Legendary | Dodge/dash sırasında öldürme → stamina segmenti iade |
| Son-etki | **İz Bırakan** *(yeni)* | Rare | Geçtiğin yol 1.5sn hasar veren bir çizgi bırakır |
| Son-etki | **Yankı Adım** *(yeni)* | Legendary | Dodge bitince, başlangıç noktasında 0.3sn sonra bir "hayalet dodge" daha oynanır (temas hasarı 2. kez, farklı konumda) |

**Örnek yığılma:** Zehirli Sekme + İz Bırakan + Yankı Adım → dodge artık kaçış
değil, geçtiğin her yeri ateşe verip aynı hareketi iki kez tekrarlayan bir
saldırı aracı.

### 2.3 🛡️ Savunma (block/parry)

**Temel:** block (hasar azaltma), perfect parry (0.2sn pencere, tam iptal +
counter-window açar — motor bunu zaten yapıyor, `player.gd`
`counter_window_timer`).

| Katman | Item | Rarity | Etki |
|---|---|---|---|
| Hedef | **Alan Parry'si** ✅ | Rare | Perfect parry, 100px içindeki HERKESİ (5 hasar + stagger) sersemletir — `alan_parrysi.gd`, `perfect_parry` sinyaline bağlı |
| Yük | Yansıtıcı Kalkan *(var)* | Uncommon | Bloklanan hasarı yansıtır |
| Yük | Tavlanmış Çelik ✅ *(var, genellenmiş — Element Kalkanı köprüsü)* | Uncommon | **Element köprüsü**: kızgın kalkanla blok, aktif elementi(leri) saldırgana bulaştırır — `tavlanmis_celik.gd`, `get_active_elements()` döngüsü |
| Yük | **Emici Kalkan** ✅ | Uncommon | Bloklanan hasarın %40'ı `player_hitbox.pending_flat_damage_bonus`'a birikir, sıradaki vuruşa düz bonus olarak eklenir — `emici_kalkan.gd` |
| Son-etki | Fırlatma Parry *(var)* | Uncommon | Havaya Fırlatma boru hattını tetikler |
| Son-etki | Gölge Adımı *(var)* | Rare | Parrylenen düşmanın arkasına ışınlanır |
| Son-etki | **Karşı Mermi** ✅ | Legendary | Perfect parry, saldırgana otomatik bir mermi fırlatır (Uzun Menzil/Ok Yağmuru gerekir, yoksa etki yok) — `karsi_mermi.gd`, `LightAttackProjectileScript` |

> **Not (2026-09-30):** "Geniş Pencere" (parry penceresi uzatma) planlanmıştı
> ama triage'da iptal edildi — `parry_ustasi` zaten aynı işi yapıyor
> (perfect parry penceresi +%40), ikinci bir item gereksiz tekrar olurdu.

**Örnek yığılma:** Emici Kalkan + Karşı Mermi + (Mermi dalında Sürü Oku varsa)
→ her parry hem yük doldurur hem otomatik 3 parçaya ayrılan bir mermi
fırlatır. Savunma artık saf savunma değil, bir saldırı tetikleyicisi.

### 2.4 🌀 Havaya Fırlatma (juggle) — motorun `air_combo_float` mekaniğinin üstü, tamamen boş bir hat

**Temel:** `up_heavy` düşmanı havaya kaldırır; havadaki pencerede vurmaya
devam edince kısa "hit-freeze" + oyuncunun kendi yerçekimi azalır (asılı
kalma), `up_heavy` isabetinden sonra kısa bir jump-cancel penceresi açılır.
**Mevcut item'lardan hiçbiri bu hatta oturmuyor — tamamen yeni bir alan.**

| Katman | Item | Rarity | Etki |
|---|---|---|---|
| Tetik | Zıplatan Yumruk *(Temas Saldırısı'nda tanımlı)* | Rare | Normal heavy de fırlatıcı olur |
| Tetik | Fırlatma Parry *(var, Savunma'da tanımlı)* | Uncommon | Parry de fırlatıcı olur |
| Hedef | **Toplu Kaldırma** *(yeni)* | Rare | Fırlatma, 80px içindeki TÜM düşmanları da kaldırır (tekli → AoE juggle) |
| Yük | **Ağırlıksız** *(yeni)* | Uncommon | Havadaki düşmana vurunca kendi yerçekimin normalden daha da azalır (motorun `air_combo_gravity_scale`'ini güçlendirir, uzun juggle penceresi) |
| Yük | **Kader Anı** *(yeni, basitleştirildi)* | Legendary | **Element köprüsü**: havadaki (juggle penceresi açıkken) HER vuruş garanti kritik olur + aktif elementini uygular — eşik/sayaç yok, ilk vuruştan itibaren güçlü |

> **Not (2026-09-30):** "Gökten İniş" (juggle bitince otomatik fall-attack)
> kullanıcı geri bildirimiyle tamamen kaldırıldı — otomatik tetiklenen bir
> saldırı güçlendirme değil, oyuncuyu zorlayan/kontrolü elinden alan bir şey
> gibi hissettiriyordu. "Kader Anı" da eskiden "5 vuruşluk zincir tamamla"
> şartına bağlıydı; kullanıcı "gerçekten güçlü upgrade istiyoruz, eşik
> gerekmiyor" dedi — artık havadaki İLK vuruştan itibaren koşulsuz çalışıyor.

**Örnek yığılma:** Zıplatan Yumruk + Toplu Kaldırma + Ağırlıksız + Kader Anı →
tek bir heavy attack odadaki herkesi kaldırır, uzun süre havada kalırsın,
havadayken attığın HER vuruş garanti kritik + element patlaması — sayaç yok,
anında güçlü.

### 2.5 🏃 Hareket/Parkur

**Temel:** çift zıplama (itemsiz var), duvar zıplama, duvarda kayma, kenar
tutunma, slide, crawl.

| Katman | Item | Rarity | Etki |
|---|---|---|---|
| Tetik | Kuş Kanadı ✅ *(var, genellenmiş — Üçüncü Sıçrayış)* | Common | 3. zıplama, artık can bedeli değil 2 stamina hücresi |
| Hedef | **Duvar Kırıcı** ✅ | Common | Duvardan zıplarken 90px içindeki düşmanlara hafif hasar + fırlatma — `duvar_kirici.gd`, `wall_slide_state.gd:_perform_wall_jump()` |
| Yük | Element İzi ✅ *(var, genellenmiş)* | Uncommon | **Element köprüsü**: dodge/dash/zıplama/slide sırasında aktif elementini taşıyan bir iz bırakır |
| Son-etki | **Rüzgâr Toplama** ✅ | Uncommon | Her ayrı parkur eylemi (duvar zıplama, kenar tutunma, slide, çift zıplama) kesirli stamina iade eder — `ruzgar_toplama.gd`, `apply_parkour_momentum_tick()` |
| Son-etki | **Kesintisiz Akrobasi** ✅ | Rare | Kenar tutunmadan çıkarken (tırmanarak veya bırakarak) çift zıplama hakkı otomatik yenilenir — `kesintisiz_akrobasi.gd`, `ledge_grab_state.gd:_apply_kesintisiz_akrobasi()` |

> **Not (2026-09-30):** "Momentum" ayrı bir sayaç/kaynak olarak kurulmadı —
> Rüzgâr Toplama doğrudan stamina ekonomisine bağlandı (`restore_partial_charge`),
> çünkü oyunun asıl kısıtlı kaynağı zaten stamina; ayrı bir "Momentum" barı
> §6'nın uyardığı gereksiz ikinci bir kaynak sistemi olurdu.

**Örnek yığılma:** Rüzgâr Toplama + Element İzi + Duvar Kırıcı → düz bir
parkur koşusu (duvardan duvara, kenardan kenara) artık pasif olarak element
izi bırakan, düşmanlara sürekli hasar veren VE hiç durmadan dodge/dash/parry
basabileceğin (stamina hiç tükenmeyen) bir "koşarken temizleme" build'ine
dönüşür — hiç dövüşmeden, sadece hareket ederek düşman öldürmek mümkün olur.
"Parkur dövüş kadar önemli" ilkesinin doğrudan karşılığı.

---

## 3. Element — ayrı bir hat değil, bir "teslimat tipi"

Element'i ayrı bir boru hattı ya da paylaşılan bir kaynak yapmak yanlıştı
(önceki V3'te öyleydi, dağınık kaldığı için terk edildi). Doğrusu: **element,
herhangi bir hattın "Yük" katmanının seçebileceği bir teslimat tipi**, hasarın
yanında ya da yerine. Zaten kodda böyle çalışıyor:

- Temas Saldırısı'nın Yükü → Zehirli Tırnak/Ateşli Yumruk/Buzlu Kılıç/Şimşek
  Parmak — **bu hattın element KAYNAĞI**, diğerleri üretmiyor, taşıyor.
- Mermi dalının Yükü → Rüzgârın Nişanı (köprü, kaynak değil)
- Kaçınma'nın Yükü → Zehirli Sekme (köprü)
- Savunma'nın Yükü → Element Kalkanı (köprü)
- Havaya Fırlatma'nın son-etkisi → Kader Anı (köprü)
- Hareket'in Yükü → Element İzi (köprü)

**Her hattın kendi element ailesine (4 ayrı zehir/ateş/buz/şimşek item'ına)
ihtiyacı yok — sadece BİR "aktif elementimi taşı" köprüsüne ihtiyacı var.**
Kaynak tek yerde (Temas Saldırısı), köprüler her yerde.

### Bunun "melee mage / ranged fighter" hayalini nasıl çözdüğü

| İstenen kimlik | Nasıl kurulur |
|---|---|
| **Saf Melee Fighter** | Temas Saldırısı'na yığ (Daire Darbesi, Sırt Darbesi, Artan Güç), Yük'e element sokma — ham fiziksel |
| **Saf Ranged** | Uzun Menzil + Sürü Oku + Ağır Mermi — element yok, sadece mesafeden fiziksel |
| **Saf Mage** | Temas Saldırısı'nın Yükünü element'e ayarla (Zehirli Tırnak vb.) + element'i okuyan "usta" item'lar |
| **Ranged Mage** | Uzun Menzil (teslimatı değiştir) + Rüzgârın Nişanı (Mermi'nin Yükünü element'e çevir) |
| **Melee Mage** | Temas Saldırısı + ağır element Yükü + reaksiyon/usta item'ları |
| **Savunmacı Mage** | Element Kalkanı + Emici Kalkan — blok yaparken element yayıyorsun |

Kritik ilke: **item'lar "teslimat mekanizmasına" değil "soyut duruma" (combo
pozisyonu, element aktif mi, vuruş indi mi) bakmalı.** Artan Güç örneğin combo
pozisyonunu okuyor, saldırı melee mi ranged mi umursamıyor — bu yüzden ikisinde
de çalışıyor. Böyle yazılırsa ranged ve melee iki ayrı evren olmaktan çıkıp
aynı sistemin iki farklı "kaplaması" oluyor.

### Element Reaksiyon Matrisi (motor seviyesi) — ✅ 6/6 UYGULANDI (2026-09-30)

4 element = 6 olası çift, hepsi doldu. Hiç yeni item gerekmedi — mevcut/yeni
tüm element-köprü item'ları (Zehirli Tırnak, Rüzgârın Nişanı, Element Kalkanı,
Element İzi, Kader Anı, ...) otomatik olarak bu matrisin parçası.

| Çift | Reaksiyon | Nerede | Etki |
|---|---|---|---|
| Zehir + Ateş | Patlama | `base_enemy.gd add_burn_stack()` | AoE patlama (önceden vardı) |
| Ateş + Buz | Buhar Patlaması | `base_enemy.gd add_burn_stack()` | Don tüketilir, `frost_stacks × 1.5` bonus hasar |
| Zehir + Buz | Bulaşıcı Don | `base_enemy.gd add_frost_stack()` | Zehir en yakın başka düşmana (160px) sıçrar |
| Buz + Şimşek | Kırılma | `item_manager.gd _apply_lightning_reactions()` | Don tüketilir, `frost_stacks × 2.0` bonus hasar (en güçlü ikili) |
| Zehir + Şimşek | Uçucu Zehir | `item_manager.gd _apply_lightning_reactions()` | Zehir stack'leri anında patlar (`× 2.0`), tüketilir |
| Ateş + Şimşek | Aşırı Yükleme | `item_manager.gd _apply_lightning_reactions()` | `burn_remaining_ticks × 0.5` bonus hasar (en zayıf ikili, kasıtlı) |

**Mimari not:** Şimşeğin poison_stacks/frost_stacks/burn_remaining_ticks gibi
kalıcı bir stack'i yok (anlık hasar) — bu yüzden onu içeren 3 çift, kalıcı
stack'ler arasındaki 3 çift gibi `base_enemy.gd`'nin `add_X_stack()`
fonksiyonlarında değil, `item_manager.gd`'nin `apply_element_to_enemy()`'sinde
(şimşek uygulandığı AN) kontrol ediliyor — o an "şimşek şu an uygulanıyor"
bilgisinin var olduğu tek yer. Zehir+Ateş ile aynı sırayla ilgili kısıt burada
da geçerli: reaksiyon sadece BELİRLİ bir sırayla tetiklenir (ör. önce buz
sonra şimşek gelirse Kırılma tetiklenir, ama önce şimşek sonra buz gelirse
tetiklenmez çünkü şimşeğin kalıcı bir izi yok) — bu, mevcut Zehir+Ateş
reaksiyonunun da zaten sahip olduğu, bilinçli olarak korunan bir sınırlama.

---

## 4. Tuzaklar — küçük tutulan bir kategori, ayrı bir hat DEĞİL

Oyuncunun **"tuzak yerleştir" diye bir fiili yok** — tuzaklar (`traps_v2/`:
tavan zehiri, yer ateşi/diken, duvar topu/oku) zindana önceden rastgele
yerleşiyor. Bu yüzden "Tuzakçı" ayrı bir boru hattı olamaz (4 katmanlı bir
şekli dolduracak bir "tetik" fiili yok). İki gerçek seçenek kaldı:

- **Var olan tuzaklarla etkileşim** (küçük kategori, hat değil):
  `tuzak_fisildayan` zaten bunu yapıyor ("tüm zindan tuzakları düşmanlara da
  hasar verir"). Genişletilebilir (ör. "tuzaklar artık element de uyguluyor")
  ama bu tek bir açma-kapama item'ı, 4 katmanlı bir hat değil.
- **Kaçınma'nın son-etkisi olarak mayın bırakma** (`dodge_bombasi` zaten bu —
  Kaçınma hattının bir son-etki adımı, ayrı bir "Tuzakçı" hattı değil).

Oyuncuya gerçek bir "tuzak yerleştir" fiili kazandırmak (yeni input/buton)
ayrı, daha büyük bir karar — bu dokümanın kapsamı dışında, istenirse ayrıca
değerlendirilir.

---

## 5. Köprü (bridge) item'ları — asıl kaos buradan çıkıyor

| Item | Bağlantı |
|---|---|
| Zıplatan Yumruk, Fırlatma Parry | → Havaya Fırlatma |
| Kader Anı | Havaya Fırlatma → Element (Temas Saldırısı'ndaki kaynağı okur) |
| Karşı Mermi | Savunma → Mermi |
| Rüzgârın Nişanı, Element Kalkanı, Element İzi, Zehirli Sekme | → Element (hepsi Temas Saldırısı'ndaki kaynağı taşır) |
| Rüzgâr Toplama | Hareket → Momentum |

Bir hattın **son-etki** katmanı neredeyse her zaman ya "kendi hattında tekrar"
ya da "başka bir hattı tetikleme" seçeneği sunmalı — tasarım kuralı bu olmalı,
çünkü köprüler olmadan 5 boru hattı 5 ayrı ada olur.

## 6. Kaynaklar hâlâ var, ama artık ikincil

Momentum/Karşılık gibi kaynaklar silinmedi — ama artık boru hatlarının
**son-etki katmanına içkin** hale geldi (bağımsız bir sistem değil, hatların
doğal çıktısı). Element artık bir kaynak bile değil, bir Yük tipi (§3).

## 7. Çeşitlilik ödülleri (Joker/Wildcard)

| Item | Rarity | Etki |
|---|---|---|
| **Usta İşçi** ✅ | Legendary | Kaç FARKLI boru hattına item eklediğine göre periyodik stamina iade eder (3-4 hat küçük puls, 5 hat/hepsi büyük puls) — jenerali ödüllendirir |
| **Tek Sanat** ✅ | Legendary | SADECE bir boru hattına (5+ item, başka hiçbirinde yok) odaklanırsan, o hattın numeric çıktısı (hasar/iade) 1.5x güçlenir — uzmanı ödüllendirir |

İkisi zıt stratejiler, ikisi de eşit güçte tasarlanmalı.

> **Not (2026-09-30) — "tetiklenme sıklığı"/"retrigger" nasıl somutlaştırıldı:**
> Her iki tasarım da orijinal haliyle soyuttu ("tetiklenme sıklığı artar",
> "son-etki katmanı 2 kez tetiklenir") ve doğrudan uygulanamazdı — motor
> genel bir "pipeline step" listesi tutmuyor (§8.2 madde 9'un kararı:
> step-engine inşa edilmedi), bu yüzden literal bir "olayı 2 kez tetikle"
> mekanizması yok. İkisi de aynı ruhu koruyan, güvenle uygulanabilir somut
> bir mekanizmaya çevrildi:
> - **Usta İşçi** → periyodik stamina puls'u (zaten kanıtlanmış
>   `restore_partial_charge` API'si, Refleks/Kesintisiz Akış/Rüzgâr
>   Toplama/Cellat Nefesi'yle aynı desen). Daha fazla hatta yayılmak =
>   daha sık stamina-gated eylem (dodge/dash/parry) basabilmek — "tetiklenme
>   sıklığı artar" fikrinin dolaylı ama gerçek bir karşılığı.
> - **Tek Sanat** → literal retrigger yerine düz 1.5x çarpan. Motorda
>   ZATEN 5 boru hattının hepsinin numeric çıktısı ya `player_hitbox.gd`'de
>   (Temas+Havaya Fırlatma) ya da `item_manager.gd`'nin merkezi Kaçınma/
>   Hareket/Mermi fonksiyonlarında tek bir hesaplama noktasından geçiyor
>   (bu oturumun kurduğu mimari) — bu yüzden "pipeline'ın gücü artar" tek
>   bir çarpanla, 8 dosyaya (player_hitbox.gd, 3 merkezi fonksiyon, 3
>   Savunma item dosyası) minimal dokunuşla, hiçbir sinyali ikinci kez
>   ateşlemeden uygulanabildi.
> - Hat sınıflandırması item dosyalarına yeni bir alan eklemedi — her
>   item'ın zaten taşıdığı `category` (ItemCategory enum) `_CATEGORY_PIPELINE_MAP`
>   ile hatta eşleniyor; bu eşleme aslında `docs/ITEM_SYNERGY_DESIGN.md`
>   §10'daki "category_family" gruplarıyla (movement/combat) aynı fikrin
>   genişletilmiş hali.

---

## 8. Mevcut 114 item'ın triyajı (2026-09-30)

Tüm mevcut item dosyaları tek tek okunup yukarıdaki modele göre sınıflandırıldı.
Aşağıdaki sonuçlar kesin karar değil — çözülmesi gereken çakışmalar var (§8.3),
onlar netleşmeden hiçbir kod değişikliği yapılmayacak.

### 8.1 Hatlara taşınan item'lar (Taşınır / Hafif Revizyon)

**Temas Saldırısı** — Zehirli Tırnak, Ateşli Yumruk, Buzlu Kılıç, Şimşek
Parmak, Zehirli Dev, Lav Çekici*, Donma Çekici, Gök Gürültüsü, Zehirli Düşüş,
Ateş Topu Düşüşü, Buz Çağı, Yıldırım Düşüşü, Pala Kılıcı, Cenk Meydanı, Geniş
Düşüş, Çift Vuruş, Sekme Tabanlığı, Patlama Topuzu, Koruk, Cevher Dili, Yıkım
Mührü, Falya, Element Değişimi, Koz Tutan, Ocak*, Şerbetçi, Olümcül Sükût
(→Savunma köprüsü), Topuk Kırıcı (→Hareket köprüsü), Tepme (→Hareket köprüsü).
*Lav Çekici kendi fireball'unu Uzun Menzil OLMADAN spawn ediyor — §8.2'de not.

**Mermi alt-dalı** — Uzun Menzil, Ok Yağmuru, Yansıyan Ok, Rüzgârın Nişanı,
Yankı Oku, Kartal Bakışı, Gerilmiş Yay.

**Kaçınma** — Ruzgar Hançeri (açıcı), Zehirli Sekme, Kesintisiz Akış, Dodge
Bombası, Görünmezlik Pelerini, Ortaoyunu, Dodge Zehiri*, Element İzi*
(*mevcut, aşağıda çakışma notu var).

**Savunma** — Yansıtıcı Kalkan, Parry Ustası, Ters Darbe, Parry Ruhu, Zaman
Durdurucu, Kum Saati, Gölge Adımı, Fırlatma Parry, Son Kale, Sanşlı Nal,
Nazar Boncuğu*, Tavlanmış Çelik* (*aşağıda çakışma notu var).

**Hareket/Parkur** — Çift Zıplama (Üçüncü Sıçrayış'ın kaynağı), Kuş Kanadı*,
Duvar Ustası, Havada Kal, Ateşli Kayma*, Buzlu Kayma*, Ziplama Zehiri*,
Slide Şimşeği*, Lağımcı* (*hepsi §8.2'de konsolide edilecek).

**Kendi başına tutarlı, hiçbir hatta girmeyen küçük yan-sistemler:**
- **Ceset Ekonomisi**: Leş Gazı, Ceset Tekmesi, Kan Bedeli, Sabır Taşı,
  Yankesici — Tuzaklar gibi (§4) ayrı bir küçük kategori, hat değil.
- **Gölge İkiz**: Ortaoyunu + Karagöz Laneti + Hacivat Gölgesi — decoy
  spawn + fiziksel/elemental taklit, kendi içinde tutarlı ama 5 hattın
  hiçbirine girmiyor.
- **Ekonomi/Meta**: Falcı Kadın (dokümanın zaten verdiği örnek).

### 8.2 Çözülmesi gereken çakışmalar — kullanıcı kararı gerekiyor

1. **✅ UYGULANDI — element trail ailesi konsolide edildi.** `element_izi.gd`
   pasif işarete çevrildi; gerçek mantık tek bir merkezi fonksiyonda
   (`ItemManager.spawn_element_trail_if_active(pos)`, poison/fire/ice kalıcı
   yer efekti, lightning anlık zap+AoE). Bu fonksiyon artık `dodge_state.gd`,
   `dash_state.gd`, `jump_state.gd` (yer/duvar zıplaması) ve `slide_state.gd`
   (slide bitişi) içinden çağrılıyor — yani element_izi artık dodge/dash/
   zıplama/slide'ın HEPSİNDE çalışıyor, tek bir fiile sabit değil.
   `dodge_zehiri`, `ziplama_zehiri`, `slide_simsegi` silindi (.gd+.tscn+.uid),
   `ITEM_SCENES`/`DUNGEON_THEME_POOLS`/`poison_mastery` setinden çıkarıldı,
   localization satırları temizlendi.
2. **🔴 `parry_ustasi` zaten "Geniş Pencere"** — parry penceresini %40 uzatıyor,
   önerdiğim yeni item birebir aynı şeyi tekrar öneriyor. **Geniş Pencere
   fikri iptal, parry_ustasi olduğu gibi kalıyor.**
3. **🟡 `tavlanmis_celik` ↔ "Element Kalkanı"** — tavlanmış_çelik zaten "blok
   → saldırganı yak" yapıyor (ateşe sabit). Önerdiğim Element Kalkanı bunun
   genellenmiş hali olmalı — **tavlanmiş_çelik'i Element Kalkanı'na
   dönüştürmek** (yeni bir item eklemek yerine) daha temiz.
4. **✅ ÇÖZÜLDÜ — `dikenli_kalkan` ↔ `yansitici_kalkan`** — kod incelendi,
   gerçek bir çakışma yokmuş: `yansitici_kalkan` `player_blocked`'a bağlı
   (sadece başarılı blokta, bloklanan hasarın %50'si — beceri gerektiren
   araç), `dikenli_kalkan` `player_took_damage`'a bağlı (blok olsun olmasın
   HER hasarda, tam hasarın %100'ü — pasif, her zaman açık diken zırhı).
   Kullanıcının istediği "farklılaştır" yönü zaten koddaymış, değişiklik
   yapılmadı. **Denge notu (ayrı konu):** Dikenli Kalkan koşulsuz %100
   yansıtıyor, Yansıtıcı Kalkan blok+%50 — Dikenli Kalkan göreceli güçlü
   duruyor, istenirse ayrıca ele alınabilir.
5. **🟡 `hayalet_adim` ↔ "Yankı Adım"** — ikisi de "dodge + fantom kopya"
   fikrini taşıyor. Yankı Adım fikri hayalet_adim'in üstüne mi kurulmalı,
   yoksa tamamen ayrı mı kalmalı?
6. **🟡 `lagimci` ↔ "Element İzi"** — lağımcı zaten "slide → iz bırak → patla"
   yapıyor (barut/patlama temalı). Element İzi tam bu yuvaya oturuyor,
   ikisinin aynı Yük/Son-etki slotunu paylaşıp paylaşmayacağı netleşmeli.
7. **🟢 `genis_darbe`'nin flavor text'i "Geniş kavis"** — önerdiğim yeni
   "Geniş Kavis" (Kaçınma/Hedef) ile sadece İSİM çakışıyor, işlev tamamen
   farklı (biri light attack cleave, diğeri dodge hitbox'ı). Kozmetik, yeni
   item'a farklı bir isim vermek yeterli.
8. **🟢 Mermi'nin "açıcı gerekir" kuralı tam doğru değil** — §2.1'de "Mermi
   dalı `uzun_menzil`/`ok_yagmuru` olmadan hiç yok" deniyor ama `lav_cekici`
   zaten kendi fireball'unu bağımsız spawn ediyor. Kural şu şekilde
   düzeltilmeli: "Mermi dalının YÜKSELTME item'ları (Sürü Oku, Yankı Oku vb.)
   uzun_menzil/ok_yagmuru gerektirir, ama bağımsız tek-seferlik mermi
   üreten item'lar (lav_cekici gibi) bu kısıtın dışında."
9. **✅ ÇÖZÜLDÜ — `kus_kanadi` ↔ `cift_ziplama`** — kod incelendi
   (`player/states/air/jump_state.gd`, `resources/items/cift_ziplama.gd`):
   gerçek bir çakışma YOK, ikisi tamamen ayrı meta anahtarları kullanıyor
   (`kus_kanadi_active`/`kus_kanadi_jump_count` vs `cift_ziplama_active`/
   `cift_ziplama_available`) ve `cift_ziplama`'nın 3. zıplaması `fall_state.gd`
   üzerinden ayrı bir mekanizmayla veriliyor — `jump_state.gd`'deki triple-jump
   sayaç sistemine hiç dokunmuyor. Bu arada `kus_kanadi` yeniden tasarlandı:
   eski "air control %75 azalır" bedeli kaldırıldı, yerine **bonus (3.)
   zıplama artık 2 stamina hücresi harcıyor** (ilk hava zıplaması — herkesin
   sahip olduğu bedava çift zıplama — bedelsiz kaldı). Uygulandı:
   `resources/items/kus_kanadi.gd`,
   `player/states/air/jump_state.gd:_consume_kus_kanadi_bonus_jump_stamina()`.

### 8.3 Atılacak adaylar (Atılır) — düz stat sopası, hiçbir hatta "adım" değil

`hizlanan_yumruk, ruh_avcisi, ikinci_nefes, berserker_ruhu, kan_tadi,
tas_yurek, sessiz_ayakkabi, golge_pelerini, sadik_golge, barut_zirhi,
kara_barut, panzehir_derisi, kaygan_yag, keskin_nazar`

> **✅ UYGULANDI (2026-09-30).** Bu 14 item aylardır burada "Atılır" olarak
> işaretliydi ama havuzlardan hiç çıkarılmamıştı — kullanıcı birkaç run
> denedikten sonra "hep eski itemler geldi, bunları istemiyorum, oyun tarzını
> değiştiren itemler olsun" diye bildirdi. Artık gerçekten `EXCLUDED_ITEM_IDS`'e
> alındı, `DUNGEON_THEME_POOLS`'dan çıkarıldı — bir daha hiç teklif edilmiyorlar.
> Item dosyaları silinmedi (geri getirmek istenirse tek satır).

**Starter havuzundaki flat item'lar** — kullanıcı geri bildirimiyle **kısmen
uygulandı (2026-09-30)**: `ayran, zeytinyagi, gokten_dusus, guc_kayasi,
hizli_charge, tunel_ustasi` (itemsiz de var olan bir fiile düz %X bonusu
ekleyen 6 item) STARTER_ITEM_IDS'ten çıkarılıp kesif havuzlarına (occasional
variety olarak) taşındı; yerlerine önkoşulsuz, gerçekten fiil değiştiren 6
COMMON/UNCOMMON boru hattı item'ı (`duvar_kirici, soguk_temas, sarsici_darbe,
kesme_yayi, artan_guc, emici_kalkan`) kondu. `baklava, simit, hizli_el,
combo_ustasi, demir_kalkan, kalkan_ustasi, parry_ruhu, topuk_kirici` starter'da
kalmaya devam ediyor — bunlar blok/parry/stamina gibi gerçek temelleri
öğretiyor, "Atılır" listesindeki gibi zaten-var-olan-bir-fiile-düz-bonus değil.
Starter artık 19 item'ın ~9'u flat-stat (%47), önceki 14/19'dan (%74) düşüş.

> **✅ UYGULANDI (2026-09-30, aynı gün ikinci geri bildirim).** Kullanıcı
> ranged item'ları (Mermi alt-dalı) firtina zindanı boss'u temizlenene kadar
> beklemeden direkt denemek istedi. `uzun_menzil`/`ok_yagmuru` (Mermi'nin
> açıcıları, `firtina.boss`'tan) STARTER_ITEM_IDS'e taşındı. Bunun tek satırlık
> bir etkisi yok — `ITEM_REQUIREMENTS_ANY`'nin 10 bağımlısı (yansiyan_ok,
> ruzgarin_nisani, yanki_oku, kartal_bakisi, gerilmis_yay, golge_nisanci,
> suru_oku, pesine_dusen, agir_mermi, ruh_mermisi) `_cascade_unlocks()`
> sayesinde oyunun BAŞINDAN itibaren otomatik açılıyor — yani artık run 1'de
> hem açıcılar hem TÜM Mermi yükseltmeleri teklif edilebilir. Simülasyonla
> doğrulandı (starter + cascade zinciri manuel yürütülüp 10 item'ın da
> `unlocked` çıktığı görüldü). Starter artık 21 item.

## 9. Sonraki adımlar

- **✅ TAMAMLANDI — §8.2'deki 9 çakışmanın hepsi çözüldü** (element trail
  konsolidasyonu, dikenli_kalkan/yansitici_kalkan farklılaşması dahil).
- **✅ TAMAMLANDI — Element Reaksiyon Matrisi 6/6** (§3'e taşındı, tam detay
  orada).
- **✅ ÇÖZÜLDÜ — Boru hatlarının teknik mimarisi.** Genel bir "adım listesi
  yürüten" soyutlama (`Array[Callable]` vb.) KURULMADI — bunun yerine bu
  oturumda uygulanan her şey (element trail konsolidasyonu, element
  reaksiyon matrisi, kus_kanadi stamina bedeli, geçen oturumların
  `apply_movement_contact_tick`/`apply_element_to_enemy` desenleri) mevcut
  sinyal-bazlı mimariyi kullandı: item pasif bir işarettir, gerçek mantık ya
  ilgili state dosyasında (`ItemManager.has_active_item("id")` kontrolüyle)
  ya da `ItemManager`'da merkezi, tekrar kullanılabilir bir fonksiyonda
  yaşar. Bu desen ~10 farklı yerde kanıtlandı, sıfır gerçek hataya (sadece
  kendi hatalarım, hepsi headless taramayla yakalandı) yol açtı. Genel bir
  "adım motoru" inşa etmenin somut bir faydası görülmedi — mevcut desen
  zaten "boru hattı" hissini veriyor, sadece daha az soyutlama katmanıyla.
  **Karar: mevcut mimari korunuyor, yeni bir "step engine" inşa edilmeyecek.**
- **✅ TAMAMLANDI — Havaya Fırlatma hattı dolduruldu (2026-09-30).**
  `ziplatan_yumruk`/`toplu_kaldirma`/`agirliksiz`/`kader_ani` koda döküldü
  (Fırlatma Parry zaten vardı). Gerçek hook noktaları:
  - **Zıplatan Yumruk**: `components/player_hitbox.gd`'ye `force_heavy_launch`
    bayrağı eklendi; `enable_combo()` içinde `heavy_neutral` artık `up_heavy`
    ile aynı fırlatma kuvvetini (160/190) kullanıyor.
  - **Toplu Kaldırma**: `enemy/base_enemy.gd`'nin `take_damage()`'ına
    `knockback_up_force >= 150.0` (gerçek fırlatma eşiği) kontrolü eklendi;
    `_try_group_launch_nearby_enemies()` 80px içindeki diğer düşmanlara AYNI
    kuvveti uyguluyor, ekstra hasar vermiyor.
  - **Ağırlıksız**: `player.gd`'nin zaten var olan `@export`'ları
    (`air_combo_gravity_scale`, `air_combo_float_duration`) doğrudan item
    tarafından ölçeklendiriliyor — yeni bir mekanizma gerekmedi.
  - **Kader Anı**: `player_hitbox.gd`'ye `force_air_crit_multiplier` eklendi
    (owner `is_on_floor()==false` iken `enable_combo()` hasarı çarpıyor) +
    `player_attack_landed` dinleyip havadayken `ItemManager.get_active_elements()`'i
    okuyup hedeflere uyguluyor. **Kullanıcı geri bildirimiyle basitleştirildi:**
    "5 vuruşluk zincir" şartı kaldırıldı, artık havadaki İLK vuruştan itibaren
    koşulsuz çalışıyor; "Gökten İniş" (otomatik fall-attack) tamamen iptal
    edildi çünkü oyuncuyu güçlendirmek yerine kontrolü elinden alıyordu.
  Doğrulama: tam proje `--quit` + her dokunulan dosyada ayrı `Parse Error`
  taraması + kayıt bütünlüğü kontrolü (115 item, sıfır ulaşılamaz) — hepsi
  temiz. Artık 5 boru hattının hepsi (Temas Saldırısı+Mermi, Kaçınma, Savunma,
  Havaya Fırlatma, Hareket/Parkur) en az bir item'a sahip.
- **✅ TAMAMLANDI — Savunma hattı dolduruldu (2026-09-30).**
  `alan_parrysi`/`emici_kalkan`/`karsi_mermi` koda döküldü (Yansıtıcı Kalkan,
  Tavlanmış Çelik, Fırlatma Parry, Gölge Adımı zaten vardı). Gerçek hook
  noktaları:
  - **Alan Parry'si**: `perfect_parry` sinyaline bağlı, 100px içindeki tüm
    `"enemies"` grubu üyelerine 5 hasar + stagger uyguluyor.
  - **Emici Kalkan**: `player_hitbox.gd`'ye `pending_flat_damage_bonus`
    eklendi; `player_blocked` sinyalinde bloklanan hasarın %40'ı birikiyor,
    `enable_combo()`'nun başında tek seferlik düz bonus olarak tüketiliyor.
  - **Karşı Mermi**: `perfect_parry`'de `uzun_menzil`/`ok_yagmuru` varlığı
    kontrol edilip (`ITEM_REQUIREMENTS_ANY` yok, runtime guard) saldırgana
    `LightAttackProjectileScript` ile mermi fırlatılıyor; saldırgan
    `block_state.gd`'nin `_last_parried_attacker`'ından okunuyor (player'da
    değil, `StateMachine/Block` node'unda).
  - "Geniş Pencere" iptal edildi — `parry_ustasi` zaten aynı işi yapıyordu.
  Doğrulama: tam proje `--quit` + 5 dosyada ayrı `Parse Error` taraması +
  kayıt bütünlüğü kontrolü (127 item, sıfır ulaşılamaz/kırık referans) +
  localization (TR/EN, 3 item × 2 satır) eklenip headless reimport edildi —
  hepsi temiz.
- **✅ TAMAMLANDI — Hareket/Parkur hattı dolduruldu (2026-09-30).**
  `duvar_kirici`/`ruzgar_toplama`/`kesintisiz_akrobasi` koda döküldü (Kuş
  Kanadı ve Element İzi zaten vardı, bu oturumun erken fazında genellenmişti).
  Gerçek hook noktaları:
  - **Duvar Kırıcı**: `item_manager.gd`'ye `apply_wall_jump_burst()` eklendi;
    `wall_slide_state.gd:_perform_wall_jump()`'tan çağrılıyor, 90px içindeki
    düşmanlara 6 hasar + fırlatma.
  - **Rüzgâr Toplama**: `item_manager.gd`'ye `apply_parkour_momentum_tick()`
    eklendi (stamina_bar'ın var olan `restore_partial_charge()`'ını 0.1
    kesirle çağırıyor); 4 ayrı çağrı noktası —
    `wall_slide_state.gd:_perform_wall_jump()`,
    `ledge_grab_state.gd:enter()` (başarılı kenar yakalama),
    `slide_state.gd:enter()`, `jump_state.gd` çift zıplama bloğu.
  - **Kesintisiz Akrobasi**: `ledge_grab_state.gd`'ye `_apply_kesintisiz_akrobasi()`
    eklendi, hem tırmanarak hem bırakarak kenar çıkışında `player.enable_double_jump()`
    çağırıyor (var olan, `has_double_jumped`'ı sıfırlayan fonksiyon).
  Doğrulama: tam proje `--quit` + 8 dosyada ayrı `Parse Error` taraması +
  kayıt bütünlüğü kontrolü (130 item, sıfır ulaşılamaz/kırık referans) +
  localization (TR/EN, 3 item × 2 satır) eklenip headless reimport edildi —
  hepsi temiz.
- **✅ TAMAMLANDI — Mermi alt-dalı dolduruldu (2026-09-30).**
  `golge_nisanci`/`suru_oku`/`pesine_dusen`/`agir_mermi`/`ruh_mermisi` koda
  döküldü (Yansıyan Ok, Rüzgârın Nişanı, Yankı Oku, Kartal Bakışı, Gerilmiş
  Yay zaten vardı). Gerçek hook noktaları:
  - `item_manager.gd`'ye `spawn_upgraded_projectile()` +
    `_apply_projectile_item_upgrades()` eklendi; `uzun_menzil.gd` ve
    `ok_yagmuru.gd`'nin birbirinin kopyası olan eski
    `_apply_projectile_upgrades()`'leri silinip bu merkezi fonksiyona
    yönlendirildi (davranış değişmedi, tek nokta hâline geldi).
  - `effects/light_attack_projectile.gd`'ye `knockback_force`/
    `knockback_up_force` (Ağır Mermi), `homing_strength` (Peşine Düşen,
    `_physics_process`'te `lerp` ile yön bükme), `soul_chain` (Ruh Mermisi)
    eklendi; eski `_find_bounce_target()` parametrik `_find_nearest_enemy()`'e
    genellendi (bounce/soul_chain/homing üçü de paylaşıyor).
  - **Gölge Nişancı**: `fall_attack_impacted` sinyaline bağlı, kardeşlerinin
    (Ateş Topu Düşüşü vb.) aksine AoE patlamıyor — `spawn_upgraded_projectile`
    ile aşağı yönlü bir mermi fırlatıp diğer mermi yükseltmelerinden de
    (Sürü Oku dahil) otomatik yararlanıyor. Kardeşleriyle aynı stamina
    bedeli konvansiyonunu koruyor (`stamina_bar.use_charge()`).
  - 5 item de `ITEM_REQUIREMENTS_ANY: ["uzun_menzil", "ok_yagmuru"]` —
    havuzlara girmiyor, sadece açıcılarla cascade geliyor (proje kuralı).
  Doğrulama: tam proje `--quit` + 9 dosyada ayrı `Parse Error` taraması
  (bu sırada `light_attack_projectile.gd`'de gerçek bir hata yakalandı:
  `var desired := (Node.global_position - ...)` statik tipi çıkaramıyordu,
  `Vector2` tip belirtimiyle düzeltildi) + kayıt bütünlüğü kontrolü (135
  item, sıfır ulaşılamaz/kırık referans) + localization (TR/EN, 5 item × 2
  satır) eklenip headless reimport edildi — hepsi temiz. Artık 5/5 boru
  hattı (Temas Saldırısı+Mermi, Kaçınma, Savunma, Havaya Fırlatma,
  Hareket/Parkur) tamamen dolu.
- **✅ TAMAMLANDI — Wildcard/Joker item'ları dolduruldu (2026-09-30). Bu,
  bu oturumdaki ~26 item'lık planlanmış-ama-kodlanmamış listenin SON
  ikilisiydi — tüm boru hatları + jeneralist/uzman ödülleri artık kodda.**
  `usta_isci`/`tek_sanat` koda döküldü. Gerçek hook noktaları:
  - `item_manager.gd`'ye `_get_item_pipeline()`/`get_pipeline_item_counts()`/
    `count_active_pipelines()`/`get_specialist_multiplier()` eklendi —
    her item'ın var olan `category` alanını 5 hatta eşleyen küçük bir
    statik tablo (+ 3 istisna override: toplu_kaldirma/agirliksiz/kader_ani).
  - **Usta İşçi**: `process()` override, 4 saniyede bir
    `count_active_pipelines()` okuyup 3+ hatta küçük, 5 hatta büyük
    `restore_partial_charge()` puls'u veriyor.
  - **Tek Sanat**: pasif işaret; `get_specialist_multiplier(pipeline)`
    (SADECE 1 hatta 5+ item varsa 1.5x, aksi 1.0 no-op) 8 dosyaya işlendi:
    `player_hitbox.gd` (temas + havaya), `item_manager.gd`'nin
    `apply_movement_contact_tick`/`apply_movement_trail_if_active` (kaçınma),
    `apply_wall_jump_burst`/`apply_parkour_momentum_tick` (hareket),
    `spawn_upgraded_projectile` (temas/mermi), ve `alan_parrysi.gd`/
    `emici_kalkan.gd`/`karsi_mermi.gd` (savunma).
  Doğrulama: tam proje `--quit` + 7 dosyada ayrı `Parse Error` taraması +
  kayıt bütünlüğü kontrolü (137 item, sıfır ulaşılamaz/kırık referans) +
  localization (TR/EN, 2 item × 2 satır) eklenip headless reimport edildi —
  hepsi temiz.
- **✅ SÜPÜRME TAMAMLANDI (2026-09-30).** 140 item, 5/5 boru hattı dolu,
  Wildcard'lar dahil. Son doğrulama turunda yeni bir kontrol yöntemi
  eklendi — sadece `--check-only`/`--quit` değil, TÜM 140 item scene'i tek
  tek `instantiate()` edilip `item_id` özelliğinin dictionary anahtarıyla
  eştiği doğrulandı (`--check-only`'nin göremediği, script'in TAMAMI
  derlenemediğinde sessizce oluşan bir sınıfı yakalar). Bu tarama, bu
  oturumda hiç dokunulmamış eski bir item'da (`zaman_durdurucu.gd`) gerçek
  bir hata buldu: `ItemManager` bare identifier olarak kullanılıyordu
  (CLAUDE.md'nin "yeni kodda get_node_or_null('/root/X') tercih et" kuralının
  ihlali) — normal oyun akışında zararsız (autoload boot'ta zaten hazır)
  ama herhangi bir `--script`/dış araç bağlamında script'in TAMAMININ
  derlenmesini engelliyordu. `get_node_or_null("/root/ItemManager")`'a
  çevrilip düzeltildi, fix sonrası 140/140 item hatasız instantiate oluyor.
- **✅ DÜZELTİLDİ — havuz dağılımı, "hep eski itemler geldi" geri bildirimi
  üzerine (2026-09-30).** Kod tamamlanmış olması yetmiyordu: kullanıcı birkaç
  run denedi, hep §8.3'te aylardır "Atılır" işaretli düz stat item'ları
  gördü — çünkü o işaretleme hiç uygulanmamıştı, item'lar hâlâ havuzlardaydı.
  Araştırma (bir Explore agent'la starter havuzunun 19 item'ının header
  yorumları okunup FLAT_STAT/VERB sınıflandırıldı) şunu doğruladı: starter
  havuzunun **%74'ü** (14/19) hiçbir fiil eklemeyen, sadece zaten var olan
  bir fiile düz %X bonusu veren item'dı — kullanıcının şikayet ettiği "yüzde
  elli daha hızlı stamina doldurma" (ayran) ve "gökten düşüş %30 hasar"
  (gokten_dusus) tam olarak bunlardı. İki değişiklik yapıldı (bkz. §8.3):
  14 "Atılır" item `EXCLUDED_ITEM_IDS`'e alınıp tüm havuzlardan çıkarıldı;
  starter'daki 6 en düz item (ayran/zeytinyagi/gokten_dusus/guc_kayasi/
  hizli_charge/tunel_ustasi) çıkarılıp yerine 6 önkoşulsuz boru hattı item'ı
  (duvar_kirici/soguk_temas/sarsici_darbe/kesme_yayi/artan_guc/emici_kalkan)
  kondu. Doğrulama: tam proje `--quit` (dupe/unassigned uyarıları için
  `_validate_unlock_pools()` zaten debug build'de otomatik çalışıyor, temiz
  çıktı) + özel bir script'le starter/pool/excluded arasında çakışma
  olmadığı ve 140 item'ın hepsinin bir yere atandığı doğrulandı.
