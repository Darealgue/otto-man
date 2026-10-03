# Item Yazım Rehberi — yeni item eklerken önce BUNU oku

> Amaç: kullanıcının (ve yeni oturumdaki ajanın) her seferinde aynı şeyleri baştan anlatmasına
> gerek kalmasın. Bu dosya **kısa, güncel çerçeve**. Ayrıntı ve tarihçe için:
> `docs/ITEM_PIPELINE_DESIGN.md` (hatlar, tam item listesi, kararların günlüğü),
> `docs/ITEM_UNLOCK_SISTEMI.md` (kilit açma). `docs/ITEM_SYSTEM_ARCHITECTURE.md` ve
> `ITEM_SYNERGY_DESIGN.md` eski/kısmen uygulanmamış tasarımlar: `add_modifier`, priority tablosu,
> `conflicts_with` gibi şeyler **kodda yok**, oradan kod kopyalama.
>
> Yeni bir karar çıkarsa en altaki "Alınmış kararlar" bölümüne ekle.

---

## 1. Felsefe (tasarım ilkeleri)

Oyun bir **deck-builder hissi** vermeli: item'lar oyun stilini değiştirir, sayı büyütmez.

1. **Fiil değiştir, stat şişirme.** İyi item: "light attack artık mermi atar", "parry stamina iade
   eder", "Ok Yağmuru top yerine zıplayan bomba atar". Kötü item: "+%20 hasar", "+%50 stamina
   yenileme". Düz stat sopası kullanıcı tarafından açıkça reddedildi (EXCLUDED listesinin sebebi).
   İtemsiz de var olan bir fiile sadece %X eklemek istiyorsan, o item'ı yazma.
2. **Soyut duruma bak, teslimat mekanizmasına değil.** Item "combo kaçıncı vuruş", "aktif element
   var mı", "vuruş indi mi", "parry yapıldı mı" gibi durumları okumalı; vuruşun melee mi mermi mi
   olduğunu umursamamalı. Böylece melee ve ranged iki ayrı evren olmaz, aynı sistemin iki
   kaplaması olur. (Artan Güç buna örnek.)
3. **Her item bir boru hattına ve bir katmana ait olmalı** (bkz. §2). "Hangi hattın hangi
   adımını ekliyor / değiştiriyor?" sorusunun cevabı yoksa item gereksizdir.
4. **Köprü ve sinerji düşün.** İyi item en az bir başka item'la *mekanik olarak gerçek* bir
   etkileşime girer (aynı mermi alanı, aynı element, aynı sinyal). Sinerjiyi sonradan kart
   üzerinde göstermek için `ITEM_SYNERGY_PAIRS` kullanılır (§7). Gerçekte olmayan etkileşimi
   yazma.
5. **Element ayrı bir hat değil, bir "Yük" tipi.** Element KAYNAĞI Temas Saldırısı hattındaki
   (Zehirli Tırnak, Ateşli Yumruk, Buzlu Kılıç, Şimşek Parmak) item'lar. Diğer hatlar kendi
   element item'ını yazmaz, "aktif elementimi taşı" köprüsü yazar (`get_active_elements()`,
   `apply_element_to_enemy()`). Dört element: poison, fire, ice, lightning; 6 çift reaksiyon
   motorda hazır (`ITEM_PIPELINE_DESIGN.md` §3).
6. **Açıklama gerçeği söylemeli.** Kartta yazan ile kodun yaptığı birebir aynı olmalı (bir
   denetimde 30 açıklama yanlış çıktı). Yeni item'dan sonra açıklamayı koda karşı oku.
7. **Zayıf item ödül olamaz.** Zayıf/öğretici item'lar (COMMON, kolay okunur) başlangıç
   havuzuna gider; kilitli havuzlara fiil değiştiren, güçlü item konur.
8. **Görseller placeholder.** Kullanıcı sanatı sonra çizecek. Sadece *doğru yerde ve doğru
   yarıçapta* basit bir şekil (daire, halka, çizgi) çiz. Hazır yardımcılar:
   `effects/aoe_burst_ring.gd` (`setup(pos, radius, color)`), `effects/element_hit_flash.gd`,
   `effects/lightning_bolt_line.gd`. Yarıçap = hasarın gerçek yarıçapı olmalı.
9. **Ranged'e hitstop ekleme** (kullanıcı kararı). Menzilli isabette ekran donması yok.

## 2. Beş boru hattı + wildcard

Her hat 4 katmanlı: **Tetik → Hedef → Yük → Son-etki**. Hat itemsiz de çalışır; item
zenginleştirir/dönüştürür.

| Hat | Temel | Item kategorisi (`ItemCategory`) |
|---|---|---|
| ⚔️ Temas Saldırısı (+ Mermi alt-dalı) | light combo, heavy, fall (melee) | LIGHT/HEAVY/FALL_ATTACK |
| 💨 Kaçınma | dodge / dash + i-frame | DODGE |
| 🛡️ Savunma | block, perfect parry + counter window | BLOCK, PARRY |
| 🌀 Havaya Fırlatma | `up_heavy` ile havaya kaldırma, `air_combo_float` | (HEAVY_ATTACK ama `_PIPELINE_OVERRIDES` ile "havaya") |
| 🏃 Hareket/Parkur | çift zıplama, duvar, kenar, slide, crawl | WALL_SLIDE, SLIDE, CROUCH, JUMP |
| Wildcard | hangi hatta kaç item'ın olduğuna bakar | Usta İşçi (çeşitlilik), Tek Sanat (uzmanlık) |

- Hat, item'ın `category` alanından otomatik türer (`ItemManager._CATEGORY_PIPELINE_MAP`);
  istisnalar `_PIPELINE_OVERRIDES`'a yazılır. STAMINA/SPECIAL/SYNERGY kategorisi hiçbir hatta
  sayılmaz — yani bir item'ı bilerek SPECIAL yaparsan Usta İşçi / Tek Sanat onu görmez.
- **Mermi alt-dalı** (`uzun_menzil` / `ok_yagmuru` açıcı): aşağıda §4'te.
- Tuzaklar ayrı hat değil (oyuncunun "tuzak koy" fiili yok). Mayın = Kaçınma son-etkisi.

## 3. Item'ın kod yapısı

`resources/items/<id>.gd` (`extends ItemEffect`) + `<id>.tscn` (7 satır, hazır bir item'ın
`.tscn`'ini kopyala, örn. `ates_bombasi.tscn`; kökü `Node`, script `ext_resource`).

```gdscript
extends ItemEffect

func _init():
	item_id = "ornek_item"                       # dosya adıyla aynı, ITEM_SCENES anahtarıyla aynı
	item_name = tr("item.ornek_item.name")
	description = tr("item.ornek_item.description")
	flavor_text = "Kısa, tek cümlelik İngilizce/Türkçe tat"   # çevrilmiyor
	rarity = ItemRarity.RARE                     # COMMON / UNCOMMON / RARE / LEGENDARY
	category = ItemCategory.HEAVY_ATTACK         # hattı belirler (§2)
	affected_stats = ["ornek_marker"]            # sadece etiket; kullanılmıyorsa serbest
	tags = ["elemental_fire"]                    # sadece element KAYNAĞI item'lar (§1.5)

func activate(player: CharacterBody2D):
	super.activate(player)
	# durumu kur, gerekiyorsa player'ı sakla

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# activate()'te yapılan HER ŞEYİ geri al
```

### Dinleyebileceğin hook'lar (ItemEffect taban sınıfı)

Metodu override etmen yeterli; `ItemManager._initialize_item` oyuncunun ilgili sinyaline
**otomatik** bağlar (elle `connect` gerekmez, yaparsan `is_connected` kontrolü koy):

| Override | Ne zaman |
|---|---|
| `_on_player_attack_landed(attack_type, damage, targets, position, effect_filter)` | Her isabet. `attack_type`: `"normal"` (light melee), `"heavy"`, `"fall"`, **`"ranged"`** (mermi isabeti ve Top/Bomba alan hasarı) |
| `_on_player_light_attack_performed(direction, position, damage)` | Light saldırı yapıldığında (Uzun Menzil'de mermi çıkış anı) |
| `_on_heavy_attack_performed` / `_on_heavy_attack_hit` / `_on_heavy_attack_impact(name)` | Ağır saldırı |
| `_on_fall_attack_impacted(pos)`, `apply_fall_attack_effect_at(pos, is_decoy)` | Düşüş vuruşu yere değdi |
| `_on_perfect_parry()`, `_on_player_blocked(dmg, attacker)` | Savunma |
| `_on_player_dodged(dir, start, end)`, `_on_player_slid(dist, dur)` | Kaçınma / slide |
| `_on_player_took_damage(...)` | Hasar alındı |
| `on_enemy_killed(enemy)` | Her öldürmede ItemManager çağırır (sinyal değil) |
| `process(player, delta)` | Her kare (ItemManager `_process`'inden) |

Dikkat edilecekler:
- **`attack_type != "normal"` filtresi mermiyi de içerir.** Bir item "sadece melee"
  istiyorsa `"ranged"`'i açıkça dışla; "isabete bağlı" istiyorsa `"ranged"`'i kabul et. Ranged
  oynayan oyuncuda item sessizce ölü kalmasın (geçmişte element item'ları, Koruk, Cevher Dili
  gibi isabete bağlı item'lar ranged'de ölüydü).
- `effect_filter == "physical_only"` olan olaylarda ikincil/element efekt item'ları
  tetiklenmemeli (döngü önleme); örnek `sarsici_darbe.gd`.
- Yeni bir **oyuncu sinyali** için otomatik bağlantı gerekiyorsa üç yeri birlikte güncelle:
  `_initialize_item`, `deactivate_item`, `AUTO_SIGNAL_HOOKS` (sahne değişiminde yeniden
  bağlama bu tabloyu kullanır; unutulursa item ikinci bölümde ölür — 2026-10-02 hatası).
- Item sahne değişiminde yeni Player'a taşınır: `register_player` her item'ı yeniden bağlar ve
  `activate(newPlayer)` çağırır. Bu yüzden `activate()` **tekrar çağrılabilir** olmalı
  (sayaçları sıfırla, çift bağlantı yapma, çift çarpan uygulama).
- **Paylaşılan alana atama yapma, çarpan/ekle yap.** `light_attack_damage_multiplier`,
  `stealth_enemy_vision_mult` gibi birden çok item'ın yazdığı alanlara `=` ile yazmak başka
  item'ı siler (Combo Ustası ↔ Çift Vuruş hatası). Çarpımsal uygula, uygulandığını işaretle,
  `deactivate`'te tam geri al.
- Deactivate'te: bağlantıları kes, spawn ettiğin node'ları `queue_free`, çarpanları geri al.

### Hasar nereden geçer
- Melee: `PlayerHitbox.get_damage_for_target()` → `DamageModifiers.apply_player_modifiers()`
  (flank/stealth vb.). Çarpan eklemek istiyorsan `player_hitbox.gd`
  (`combo_multiplier`, `next_attack_bonus_multiplier`, `pending_flat_damage_bonus`,
  `air_target_damage_multiplier`…) ya da `player.gd` (`light_attack_damage_multiplier`,
  `heavy_attack_damage_multiplier`) zaten uygulanan noktalardır.
- Mermi: `light_attack_projectile.gd:_on_hit` `DamageModifiers`'ı elle çağırır.
- Alan hasarı veren item'lar çoğunlukla `enemy.take_damage(amount, kb, kb_up, stun)`'u doğrudan
  çağırır, `DamageModifiers`'ı atlar (kabul edilmiş durum).
- **Tek Sanat çarpanı hitbox'ta zaten uygulanır**; mermi/başka yerde tekrar çarpma
  (mermide 2.25x olmuştu).
- Overheal (Taşan Kaynak): `player.add_overheal(x)`; `Player.take_damage` önce bunu tüketir.
- Stamina iadesi: `stamina_bar.restore_partial_charge(kesir)` (1.0 = tam segment).

## 4. Mermi sistemi (Uzun Menzil / Ok Yağmuru ailesi)

Tek giriş noktası: **`ItemManager.spawn_upgraded_projectile(scene_root, origin, dir, damage,
max_distance_override, kind, double_strike)`**. Mermi yükseltmesi eklemek = bu fonksiyonun
`_apply_projectile_item_upgrades()` kısmına bir satır + mermi script'ine bir alan. Yeni
tetikleyici (örn. başka bir item'ın mermi atması) da bu fonksiyonu çağırır; kendi mermisini
yazmaz.

| `kind` | Script | Kim atar | Özellik |
|---|---|---|---|
| `ok` | `effects/light_attack_projectile.gd` | Uzun Menzil (light) | hızlı, hafif, x1.0 |
| `top` | `effects/cannon_projectile.gd` | Ok Yağmuru (heavy, **varsayılan**) | yavaş, iri, knockback, 70px alan hasarı %50, x1.6 |
| `bomb` | `effects/player_fire_bomb_projectile.gd` | Ok Yağmuru + **Ateş Bombası** | yerçekimli, düşmana değince patlar, 2-3 sekme / 3 sn fünye, 90px alan %80 + yanma, x1.3 |

Yükseltme item'ları (türden bağımsız çalışır): Sürü Oku (3'lü yelpaze, her biri %40), Yansıyan Ok,
Ruh Mermisi (öldürünce sıradaki düşmana), Yankı Oku, Rüzgârın Nişanı (aktif elementi mermiye
bulaştırır), Kartal Bakışı, Ağır Mermi, Peşine Düşen (bombada uygulanmaz), Gerilmiş Yay, Çift
Vuruş (**yalnızca** Uzun Menzil'in light atışını ikiye katlar; `double_strike=true`).
Hepsi `ITEM_REQUIREMENTS_ANY`'de `uzun_menzil`/`ok_yagmuru`'ya bağlı; açıcılar starter'da.

Yeni mermi türü = `light_attack_projectile.gd`'den türet (`setup()`'ta `_speed/_hit_radius/
_ball_radius/_ball_color` ayarla), `_PROJECTILE_KIND_DAMAGE_MULT`'a çarpan, `match kind`'a
satır, smoke test'e tür ekle. Mermi isabeti her zaman `player_attack_landed("ranged", ...)`
yayınlamalı (isabete bağlı item'lar çalışsın).

## 5. Yeni item ekleme kontrol listesi (sırayla)

1. **Tasarım testi (§1):** fiili değiştiriyor mu? Hangi hat/katman? Hangi item'larla gerçek
   sinerjisi var? Zayıfsa starter, güçlüyse kilitli havuz.
2. `resources/items/<id>.gd` + `.tscn` yaz (§3).
3. `autoload/item_manager.gd` içinde **kayıt**:
   - `ITEM_SCENES["<id>"] = preload(".../<id>.tscn")` (her zaman)
   - Ve **tam olarak biri**:
     - `STARTER_ITEM_IDS` (oyun başında açık), **veya**
     - `DUNGEON_THEME_POOLS[tema]["kesif" | "boss"]` (zindan ödülü), **veya**
     - `ITEM_REQUIREMENTS` / `ITEM_REQUIREMENTS_ANY` (önkoşullu; ebeveyni açılınca ebeveynin
       zindan havuzuna aday olur, havuza YAZILMAZ; ebeveyn başlangıç item'ıysa
       `CHILD_HOME_BY_PARENT`'e ekle), **veya**
     - `EXCLUDED_ITEM_IDS` (havuza girmez)
   - Smoke test "hiçbir yere atanmamış" ve "birden fazla yerde" durumlarını hata sayar.
   - İki önkoşul türü: `ITEM_REQUIREMENTS` = hepsi aktif olmalı (VE); `_ANY` = en az biri (VEYA).
4. **Zindan teması seçimi** (genel eğilim, zorunlu değil): ateş = temas/ağır, buz =
   savunma/parry, zehir = kaçınma/gizlilik, fırtına = şimşek/hareket, barut = patlama/alan/
   stamina, gölge = parkur/wildcard. `kesif` = giriş item'ları, `boss` = derinlik/güçlü ödüller.
5. **Çeviri** (§6): `item.<id>.name`, `item.<id>.description` (TR + EN).
6. **Sinerji ipucu** (opsiyonel ama önerilir): `ITEM_SYNERGY_PAIRS`'e `[a, b, "synergy.x"]` +
   çeviri satırı. Sadece mekanik olarak gerçek etkileşimleri yaz.
7. **Doğrulama (§8)** → `--check-only`, `--import`, `--quit`, smoke test.
8. **Mermi/hasar item'ıysa** smoke test'e kapsam ekle (§8).
9. **Sürüm yükselt** (yeni item içeriği = MINOR, düzeltme = PATCH): `project.godot` +
   `export_presets.cfg` (2 alan), **Edit aracıyla**, PowerShell'le değil.
10. `docs/ITEM_PIPELINE_DESIGN.md` §9'a kısa giriş (ne, neden, hangi dosya, denge notu).

Rarity eğilimi: COMMON = öğretici/basit fiil (starter), UNCOMMON = tek adımlık bridge/yük,
RARE = hattı dönüştüren, LEGENDARY = build tanımlayan (Ruh Mermisi, Kesintisiz Akış…).

## 6. Çeviri kuralları (strings.csv)

- **`strings.csv`'yi elle düzenleme.** Geçici bir Godot script (`extends SceneTree`) ile satır
  ekle/güncelle (`FileAccess`; virgül/tırnak içeren alanları `"` ile sar, `"` → `""`), çalıştır
  (`--headless --path . --script <yol>`), sonra **`--headless --path . --import`** (yoksa
  `tr()` anahtarın kendisini döndürür). Script'i sil. `strings.{tr,en}.translation` dosyaları da
  commit'e girer.
- Format: `anahtar,tr,en`. TR+EN ikisi de eksiksiz ve doğal çeviri olmalı (makine çevirisi
  tonu yok). Türkçe ek uyumuna dikkat; dinamik `{isim}`'e ek getirme.
- Oyuncuya görünen metinde tire (`-`, `—`) kullanma. Kısa, tek cümle, sayıları doğru yaz.
- Bir önceki oturumlarda PowerShell `Get-Content` ile CSV okununca Türkçe bozuk görünür;
  `-Encoding UTF8` ile oku. `Set-Content` ile **asla** proje dosyası yazma (BOM/© bozuluyor).

## 7. Kartta görünen yardımcılar

- `ItemManager.get_synergy_hint(item_id)` → kartta "🔗 <item>: <etki>" satırı
  (`ui/item_button.gd`). Çift yönlü; elde olan item'la eşleşen ilk çift gösterilir.
- Set bonusları: `ITEM_SET_DEFINITIONS` (zehir, kalkan, gökyüzü, 3 element, hareket ailesi,
  dövüş ailesi). Yeni elemental item yazarsan `tags = ["elemental_<element>"]` koy; set otomatik
  sayar, listeye elle eklenmez.
- Kilit açma akışı: kesif katmanı = her warmup run'da 1 seçim (zindan başına 3 warmup);
  boss katmanı = ilk clear 1, sonra her clear 2 seçim. Ön koşullu item'lar buna girmez.

## 8. Doğrulama (her item işinden sonra)

Godot console exe yolu ve komutlar `CLAUDE.md` "Verification discipline" bölümünde (bu makinede
`C:\Users\darea\Godot\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe`).

1. `--check-only --script res://resources/items/<id>.gd` (+ değiştirdiğin her dosya).
   `Identifier not found: <Autoload>` yanlış-pozitif; autoload'a `get_node_or_null("/root/X")`
   ile eriş ki dosya tek başına doğrulansın.
2. CSV değiştiyse `--import`.
3. Tam proje: `--headless --path . --quit` → `Parse Error`/`Compile Error`/`SCRIPT ERROR`
   ara (`EnemyStats`, `.wav`, `InputManager`, RID uyarıları bilinen gürültü).
4. **Smoke test:** `powershell -File tools/run_item_smoke_test.ps1` → `SMOKE OK` beklenir.
   Kayıt bütünlüğü, çeviriler, her item'ın activate/sinyal/deactivate'i, sahne değişimi sonrası
   bağlantılar ve mermi türleri (sahte düşmanlarla) kontrol edilir.
   - Smoke test ipuçları: ObjectPool'daki düşmanlar (0,0)'da "enemies" grubunda bekler, test
     mermilerini uzağa (100000,100000) koy; önceki aşama ağacı duraklatmış olabilir
     (`paused=false`); script modunda `current_scene` yok, test kendisi kurar.
   - Yeni mermi/hasar davranışı eklediysen `_run_projectile_kind_checks` benzeri bir kapsam yaz.
5. Oynanış testi kullanıcıda: dev console (backtick) → `levelup [n]` n kez sırayla item seçimi
   açar, `overheal` kalkan verir. Denge sayıları kullanıcı oynayana kadar **tahmindir**; raporda
   "denge oynanmadı" diye belirt.

## 9. Bilinen tuzaklar (hepsi gerçekten yaşandı)

- Item sahne değişiminde ölüyordu → `AUTO_SIGNAL_HOOKS` yeniden bağlama (§3).
- `=` ile paylaşılan çarpan ezmesi (Combo Ustası/Çift Vuruş, Sessiz Adım) → çarpımsal + işaret.
- Rastgele seçilen saldırı animasyonuna (attack_1.1–1.4) bağlı tetik güvenilmez → sayaçla
  (ardışık N. vuruş) yap (Kesme Yayı/Sırt Darbesi).
- Mermi sekme/zincir sonrası aynı düşmana kare içinde tekrar çarpıyordu → `_recent_hit_id`.
- `attack_state.gd`: Uzun Menzil aktifken light saldırıda melee hitbox hiç açılmaz; hasar
  çarpanları `enable_combo()` ile hitbox.damage'e önceden işlenir, mermi bu değerden türer.
- Önkoşullu item'ı havuza yazma (ev tema ebeveyninden otomatik türer); `_validate_unlock_pools` uyarır.
- PowerShell ile proje dosyası düzenleme (BOM, `Â©`) → Edit/Write araçlarını kullan.
- `FileAccess.file_exists("res://x.tscn")` export'ta hep false; `load()` ile kontrol et.
- Kaynak yolları export'ta büyük/küçük harf duyarlı.

## 10. Alınmış kararlar (kullanıcı onaylı, tekrar tartışma)

- Ranged/menzilli isabete **hitstop yok**.
- Ok Yağmuru varsayılan olarak **Top** atar; **Ateş Bombası** ayrı bir item'dır ve heavy mermiyi
  bombaya çevirir (tuşla geçiş yok). Bomba düşmana değince patlar, değmezse birkaç kez sekip
  patlar.
- Çift Vuruş yalnızca Uzun Menzil'in light atışını ikiye katlar (ağır/fall mermisini değil).
- Rüzgârın Nişanı mermiye bilinçli olarak +1 ekstra element stack bulaştırır.
- Taşan Kaynak: mavi kalkan barı, 150/100 gösterimi, max can değişmez.
- Rüzgâr Toplama için görsel geri bildirim: ertelendi ("düşünürüz").
- Mevcut unlock temposu (kesif = warmup başına 1 seçim) ölçüldü, değiştirilmedi.

## 11. Kullanıcı için kısa istek şablonu

Yeni item isterken şunları söylemen yeter (eksik olanı ben sorarım):

```
Ad / fikir:            (ne yapıyor, hangi fiili değiştiriyor)
Hat ve katman:         (Temas/Mermi, Kaçınma, Savunma, Havaya Fırlatma, Hareket, Wildcard; Tetik/Hedef/Yük/Son-etki)
Rarity ve nerede:      (starter mı, hangi zindan teması ve kesif/boss mu, önkoşulu var mı)
Sinerji:               (hangi item'larla birleşmeli)
Görsel:                (placeholder, nerede / hangi yarıçapta)
```
