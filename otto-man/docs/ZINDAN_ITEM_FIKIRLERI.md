# Zindan Roguelite — Yeni Item Fikirleri (Onaylı Liste)

> Tasarım sohbetinde üretilen ve **kullanıcı tarafından onaylanan 32 yeni item**.
> Görsel/interaktif hali: claude.ai artifact "Zindan Eşya Cönki".
> Mevcut sistem referansı: `autoload/item_manager.gd` (69 item, scene tabanlı,
> `ItemEffect` base class `resources/items/item_effect.gd`, hook'lar `_on_player_*` metodlarıyla
> otomatik bağlanıyor, set bonusları `ITEM_SET_DEFINITIONS`, önkoşullar `ITEM_REQUIREMENTS`).

## Durum: ✅ 32/32 oyuna entegre edildi (2026-07-09) — editörde test bekliyor

Tüm 32 item `autoload/item_manager.gd::ITEM_SCENES`'e kayıtlı, `resources/items/*.gd+.tscn`
olarak yazıldı. **Gerilmiş Yay** en son eklendi: `attack_state.gd`'nin combo mantığına hiç
dokunmadan, item'ın kendi `process()`'inden `Input.is_action_pressed("attack")` izlenerek
uygulandı — tut-bırak, normal saldırı akışının yanında bağımsız çalışır.

> **Tasarım notu (ceset kümesi):** Kullanıcı Leş Gazı ve Ceset Tekmesi'ni seçti ama hub kartı
> Mezar Taşı'nı (kalıcı platform + zıplama bonusu) seçmedi. Karar: "elit düşman cesedi bir süre
> yerde kalır ve etkileşilebilir" minimal altyapısı bu iki itemin ortak parçası olarak yapılır;
> platform/zıplama bonusu (Mezar Taşı'nın kendine has kısmı) YAPILMAZ.

---

## KÜME: Menzilli Vuruş

### 1. Ok Yağmuru (Rare, Kolay)
Ağır saldırı ayrıca ikinci bir mermi fırlatır (menzil 180px, hasar %50).
- **Impl:** `resources/items/uzun_menzil.gd` deseninin kopyası; tetikleyici `_on_heavy_attack_impact`.
  Mermi: `effects/light_attack_projectile.gd` klonu.
- **Sinerji:** Lav Çekici / Gök Gürültüsü / Donma Çekici ile ağır saldırıda iki ayrı mermi/patlama.

### 2. Yansıyan Ok (Rare, Zor)
Mermiler ilk hedeften 1 kez sekip 140px içindeki ikinci düşmana çarpar.
- **Önkoşul:** mermi kaynağı (Uzun Menzil veya Ok Yağmuru) → `ITEM_REQUIREMENTS`.
- **Impl:** projectile script'lerine sekme: ilk çarpışta `queue_free` yerine 140px içindeki
  en yakın ikinci düşmana yön değiştir (1 kez).

### 3. Rüzgârın Nişanı (Uncommon, Orta)
Menzilli vuruşlar aktif melee elementi (frost/burn/poison/lightning) mermiye bulaştırır.
- **Impl:** projectile çarpma anında `ItemManager.has_active_item(...)` → `enemy.add_X_stack`.
  Element tespiti: `hacivat_golgesi.gd`'deki desen.
- **Sinerji:** Elemental Odak ile "büyücü okçu".

## KÜME: Geniş Vuruş / Çoklu Hedef

### 4. Pala Kılıcı (Uncommon, Kolay)
Hafif saldırı aynı vuruşta 2 düşmana temas edebilir.
- **Impl:** Attack hitbox'ında `PlayerHitbox.max_targets_per_attack` 1→2 (desen: `genis_dusus.gd`).

### 5. Cenk Meydanı (Rare, Orta)
Ağır saldırı hitbox genişliği +%40, max hedef 1→3.
- **Impl:** HeavyAttack hitbox scale + `max_targets_per_attack = 3`.

## KÜME: Tuzak Ehli

### 6. Tuzak Fısıldayan (Rare, Orta)
Tüm zindan tuzakları (ateş, diken, ok, gülle, zehir) düşmanlara da hasar verir.
- **Impl:** `traps_v2/` script'lerinde `is_in_group("player")` gate'lerinin yanına
  `is_in_group("enemies")` dalı; enemy'de `take_damage` + `add_burn_stack`/`add_poison_stack`.
  Global flag: `ItemManager.has_active_item("tuzak_fisildayan")`.

## KÜME: Patlayıcı Doğaçlama

### 7. Barut Zırhı (Rare, Kolay)
Patlama kaynaklı TÜM hasara %100 bağışıklık (Patlama Zinciri, Zehir+Ateş patlaması,
Dodge Bombası, Patlama Topuzu, Çift Zıplama patlaması dahil).
- **Impl:** patlama efekt script'leri (`chain_explosion.gd`, `poison_fire_explosion.gd`,
  `heavy_explosion.gd`, dodge bombası, çift zıplama) oyuncuya hasar vermeden önce flag kontrolü.

### 8. Kara Barut (Uncommon, Kolay)
Tüm patlama yarıçapları +%30; her patlama oyuncuya max canın %3'ü tepme hasarı.
- **Sinerji:** Barut Zırhı tepme bedelini de sıfırlar.

## KÜME: Kritik Vuruş

### 9. Keskin Nazar (Common, Kolay)
%15 kritik şansı, kritikler %75 fazla hasar.
- **Impl:** `AttackManager.enable_critical_strike(player, 0.15, 1.75)` — sistem hazır, boşta.

### 10. Şanslı Nal (Uncommon, Kolay)
Perfect parry karşı saldırısı ve Görünmezlik Pelerini'nin ilk vuruşu her zaman kritik.

## KÜME: Çağırma

### 11. Sadık Gölge (Rare, Orta)
Ruh Avcısı'nın hayaletleri kalıcı dolaşır (max 2 aktif), her öldürmede yenilenir.
- **Önkoşul:** Ruh Avcısı → `ITEM_REQUIREMENTS`.
- **Impl:** hayalet script'inde tek-kullanım yerine hedef arama döngüsü + aktif sayaç.

## KÜME: Meta-Sinerji

### 12. Falcı Kadın (Rare, Zor)
Sonraki 3 item seçeneğinden en az biri, aktif itemlerle aynı kategoriden gelir
(2+ aynı kategorili item varsa %60 ihtimal).
- **Impl:** `ItemManager.get_random_items()` düz shuffle → kategori-ağırlıklı seçim.
  `ItemEffect.category` alanı zaten var, hiç kullanılmıyor.

## KÜME: Ceset Ekonomisi

### 13. Leş Gazı (Uncommon)
Elit düşman cesedi ~20sn yerde kalır; cesede darbe vurunca 100px zehirli gaz bulutu patlar
(4s süre, poison cloud deseni), ceset tükenir.
- **Impl:** minimal ceset altyapısı (elit ölümünde ceset node'u bırak) + vuruş algılama.

### 14. Ceset Tekmesi (Uncommon)
Dodge ile cesedin içinden geçince ceset baktığın yöne fırlar — çarptığı ilk düşmana
12 hasar + knockback, sonra yere düşer (tekrar tekmelenebilir).
- **Sinerji:** Tuzak Fısıldayan aktifse fırlayan ceset tuzağa düşerse tuzağı da tetikler.

## KÜME: Bağışıklık Ekolü

### 15. Panzehir Derisi (Rare, Kolay)
Zehir tuzakları (havuz, tavan damlası) ve TÜM zehir bulutlarına (kendi bulutların dahil) %100 bağışıklık.
- **Impl:** `StatusEffectManager.apply_poison` çağrılarının önünde flag kontrolü + zehir bulutu
  script'lerinde oyuncu istisnası.

## KÜME: Parry Repertuvarı

### 16. Gölge Adımı (Rare, Orta)
Perfect parry sonrası EĞİLME tuşu → parrylenen düşmanın arkasına ışınlan (0.15s), ona dönük dur.
Menzilli düşmanlarla mesafe kapatma aracı.
- **Impl:** BlockState perfect parry penceresinde input dinleme; düşman pozisyonu + facing'den
  arka nokta hesabı. Ters Darbe ile aynı anı paylaşır → input önceliği: eğilme > otomatik saldırı.
- **Sinerji:** Flank Avantajı → ışınlanma sonrası garanti sırt bonusu.

### 17. Fırlatma Parry (Uncommon, Orta)
Perfect parry sonrası ZIPLAMA tuşu → düşmanı havaya fırlat (juggle), düşüş saldırısı bağlanabilir.
- **Sinerji:** Sky Strike set'i → parry'den başlayan aerial combo.

## KÜME: Menzilli Vuruş II

### 18. Gerilmiş Yay (Rare, Zor)
Hafif saldırı tuşu basılı tutulursa (max 0.6s şarj), bırakınca şarj oranlı menzil+hasarla tek mermi.
- **Önkoşul:** mermi kaynağı.
- **Impl:** yeni input katmanı (tut-bırak); AttackState'e şarj alt-durumu.

### 19. Yankı Oku (Uncommon, Kolay)
Mermi çarptıktan 1sn sonra aynı noktada %60 hasarlık ikinci patlama.

### 20. Kartal Bakışı (Uncommon, Kolay)
Menzil sınırı kalkar; 300px+ mesafeden çarpan mermiler otomatik kritik.
- **Sinerji:** Keskin Nazar ile uzak isabet = garanti kritik.

## KÜME: Element Ustalığı II

### 21. Element Değişimi (Legendary, Zor)
Art arda 3 FARKLI element vuruşu → 4. vuruş son elementin 3 katı gücünde patlama.
- **Önkoşul:** 3+ farklı element item.
- **Impl:** oyuncuda element vuruş geçmişi (son 3), `_on_player_attack_landed` hook'u.

### 22. Cüppe Değil Zırh (Rare, Orta)
Element hasarı verdikçe kalkan birikir (vuruş başına %2 hasar-emme, max %30; 3sn hasarsızlıkta sıfırlanır).
- **Sinerji:** Elemental Odak'ın fizik zayıflığını telafi eden "battlemage" can simidi.

### 23. Element İzi (Uncommon, Orta)
Dodge/dash, son kullanılan elementin zemin izini bırakır (Ateşli/Buzlu Kayma deseni, dodge'a bağlı).

## KÜME: Parkur / Mobilite

### 24. Duvar Ustası (Rare, Zor)
Duvara doğru dodge/dash → 0.8sn duvar koşusu. Yeni hareket durumu (wall-run state) gerektirir.
- **Sinerji:** Kuş Kanadı'nın hava kontrolü cezasını telafi eder.

### 25. Hayalet Adım (Rare, Orta)
Dodge sırasında eğilme → dodge iptal, 0.4s sahte kopya bırak, 60px geriye/yana ışınlan;
düşmanlar kopyaya kilitlenir.
- **Impl:** `player_decoy.gd`'nin hafif versiyonu; Gölge Adımı ile aynı "eğilme = özel hamle" dili.

### 26. Sekme Tabanlık (Uncommon, Orta)
Düşüş saldırısı yere çarpınca otomatik pogo zıplaması; her sekişte düşüş hasarı yeniden tetiklenir.

## KÜME: Stamina Büyüsü

> Stamina barı block + dodge'un paylaştığı kaynak (`PlayerStats.block_charges`, UI: stamina_bar).
> Besleyenler var (Baklava +1 max, Ayran +%50 regen, Simit boşalınca 2x regen, Parry Ruhu parry'de +1)
> ama hiçbir item HARCAMIYOR — bu küme onları "mana havuzu"na çeviriyor.

### 27. Cevher Dili (Legendary, Zor)
Hafif saldırılar güçlü elemental patlamalara dönüşür (×2.5 hasar + küçük AoE, aktif elementle);
her saldırı yarım stamina hücresi yer. Stamina boşsa saldırı sıradan çıkar. Mage build temeli.

### 28. Yıkım Mührü (Rare, Orta)
Ağır saldırı şarjında +1 stamina hücresi yakılabilir (tuşu basılı tutmaya devam):
×2 hasar + %50 geniş hitbox. İsteğe bağlı overcharge.

### 29. Son Kale (Rare, Orta)
Blok sırasında stamina biterse gard kırılması yerine 120px şok dalgası: 10 hasar + güçlü savurma,
oyuncu 1sn sersemlemez.
- **Sinerji:** Simit ile ritim (patla → hızlı dolum); Barut Zırhı varsa şok dalgası patlama sayılır.

### 30. Taşkın Güç (Uncommon, Kolay)
Stamina tamamen doluyken tüm saldırılar +%30 hasar. Cevher Dili'nin zıt teklifi (harca vs biriktir).

### 31. Ruh Akışı (Uncommon, Kolay)
Her öldürmede yarım stamina hücresi geri gelir. Mage döngüsünün motoru.

### 32. Kan Bedeli (Rare, Orta)
Stamina harcayan hamle yapılırken stamina boşsa bedel max canın %5'i olarak kesilir.
- **Önkoşul:** Cevher Dili veya Yıkım Mührü.
- **Sinerji:** Berserker Ruhu + Taş Yürek düşük-can build'iyle doğal köprü.

---

## Implementasyon başvuru notları (kod araştırmasından)

- Çoklu hedef altyapısı hazır: `components/player_hitbox.gd` → `max_targets_per_attack`
  (tek kullanan: `genis_dusus.gd`).
- Kritik altyapısı hazır ve boş: `AttackManager.enable_critical_strike/apply_critical_strike`
  (çoklu kaynak destekli, hiçbir zindan item'ı kullanmıyor).
- Tek mevcut element kombosu: `enemy/base_enemy.gd::add_burn_stack()` içinde poison varsa
  `poison_fire_explosion.tscn` (10 hasar, 90px, oyuncuya da vurur).
- Tuzaklar yalnız oyuncuyu vurur: tüm `traps_v2/` script'leri `is_in_group("player")` gate'li.
- Oyuncuya durum efekti: `player/status_effects/status_effect_manager.gd`
  (sadece tuzaklar kullanıyor; Panzehir Derisi'nin kancası burası).
- Item önkoşul sistemi: `ItemManager.ITEM_REQUIREMENTS` (örnek: kum_saati ← zaman_durdurucu).
- Set bonusları: `ItemManager.ITEM_SET_DEFINITIONS` + `_recalculate_item_sets()`.
- Rarity seçim havuzunda ağırlıksız (düz shuffle) — Falcı Kadın bu boşluğu dolduracak.
- Item ekleme reçetesi: (1) `resources/items/<id>.gd` (`extends ItemEffect`) + `<id>.tscn`,
  (2) `ItemManager.ITEM_SCENES`'e preload kaydı, (3) gerekirse `ITEM_REQUIREMENTS`/set tanımı.
