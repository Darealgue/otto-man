# Challenge Odaları (geçici zindanlar)

Haritada geçici olarak çıkan, tek odalık etkinlikler. Tür ve mekân ayrıdır: aynı challenge orman
chunk'ında da kapalı zindan chunk'ında da oynanabilir (kamera chunk'a kilitli).

## Kurallar (kullanıcı kararları)
- Ödül challenge'ın temasına göre değişir: Koruma → kurtarılan köylüler, Tuzak Geçidi → altın/hammadde,
  Asansör Arenası → rastgele item, Dalga Arenası → koleksiyona unlock kartı.
- Giriş ücretsiz. Başarısızlık = oyuncunun ölümü (normal ölüm akışı: 1 canla köyde doğar). Koruma'da
  bütün köylüler ölürse ödül yok, haritaya dönülür.
- Arena itemleri oyuncunun açtığı item havuzundan gelir (başlangıç item'ları + açtıkları; falcı ile
  pasife alınanlar hariç). Girişte 3 seçim (build kurma). Dalga arenasında her dalgadan sonra +1 seçim.
- Challenge bitince harita sahnesine dönülür; sonra köye dönmek ya da başka zindan aramak oyuncunun seçimi.

## Kod haritası (`scenes/challenge/`)
| Dosya | Görevi |
|---|---|
| `challenge_room.tscn/.gd` | Tek sahne. Payload `{kind, biome, difficulty}` ile kendini kurar, akışı yönetir |
| `challenge_arena_builder.gd` | Orman/zindan arenasını kodla kurar (dungeon_master_tileset terrain'leri) |
| `challenge_wave_spawner.gd` | Dalga bileşimi + doğurma (zorluğa göre dalga sayısı ve düşman karışımı) |
| `ward_target.gd`, `ward_hurtbox.gd` | Korunan köylü: düşmanlar onu da hedef alır ve ona gerçek hasar verir |
| `challenge_room_registry.gd` | Tür/mekân listesi, sahne yolu |

- **Düşman → köylü:** `BaseEnemy.get_nearest_player()` artık "ward_targets" grubundaki hedefleri de
  hesaba katar (en yakın olan seçilir). Köylünün `WardHurtbox`'ı PLAYER_HURTBOX katmanındadır, düşmanların
  `EnemyHitbox`'ı onu yakalar. Meta `always_aggro` olan düşmanlar menzile bakmadan hedefe yürür.
  Menzilli düşman mermileri (ateş büyücüsü vb.) köylüye vurmaz; challenge dalgalarında yalnız yakın dövüş
  ve uçan düşmanlar kullanılır.
- **SceneManager:** `change_to_challenge_room(payload)`. Yol kontrolü `ChallengeRoomRegistry.is_challenge_room_path`.
- **Dev komutu:** `challenge [koruma|dalga] [orman|zindan] [zorluk 1-9]`.

## Haritada görünüm (geçici)
- Karo `poi_type = "challenge"` (+ kind/biome/difficulty/expires_day). Altın "!" işaretçisi koda çiziliyor,
  üstüne gelince balonda tür, açıklama, mekân + zorluk ve kalan gün yazıyor. Üstüne gidip onaylayınca
  odaya girilir ve karo kalkar (tek kullanımlık); süresi dolanlar harita açılınca silinir.
- Dev komutu: `challenge_poi [tür] [mekân] [zorluk]` köye 2-10 hex yakın keşfedilmiş bir karoya koyar.
- Köylü görünümü: Worker "dungeon prisoner" kipi (AppearanceDB ile rastgele köylü, oturma pozu); ödülde
  aynı görünüm/ad köye gelir.

## Asansör Arenası (`asansor`)
- Uzun dikey kuyu (`SHAFT_FLOOR_ROW`); kuyunun iç genişliğini kaplayan `AnimatableBody2D` asansör zemini
  (kenardan düşme yok). Kamera asansörü izler. Yer düşmanları ekranın üstünden asansöre düşer
  (layout `drop_y`), uçanlar yanlardan girer. Dalga sürerken zemin yavaş yükselir (hız zorlukla artar),
  dalgalar arasında 420 px'lik "kat" yükselmesi olur. Kuyu duvarlarında wall slide/jump yapılabilir.
- Ödül: rastgele bir temadan, henüz açılmamış rastgele bir item doğrudan koleksiyona açılır.
- Zindan arenaları her girişte rastgele dekor ve renk paleti (6 palet) alır; karolar ekran dışına taşar.
- Koruma'da dalga sayısı köylü sayısına bağlı (1-4); payload `wards` ile köylü sayısı verilebilir.

## Kovalamaca (`kovalamaca`)
- `chase_corridor_builder.gd`: ~9-14 bin px uzunluğunda yatay koridor (orman veya zindan). Engeller şablonlardan
  rastgele dizilir (`TEMPLATES`, her birinin maliyeti var; biçimleri `_piece_ops` içinde karo dikdörtgenleri),
  koridor boyunca izin verilen maliyet yükselir; aynı şablon üst üste gelmez.
  - Basit: alçak/yüksek engel, 3 çukur boyu, duvar, çift engel.
  - Tavandan sarkanlar: `low_ceiling` (2 karo boşluk, zıplama yok), `slide_gap` (1 karo, kayarak geç),
    `stalactites` (sarkıt + alt engeller).
  - Karmaşık: `hill` (merdiven + tavanlı plato), `bridge_pit` (çukurda taş basamaklar), `chicane` (zıpla-kay-zıpla),
    iki yollu `fork_block` (bloğun üstü zıplayarak / altı kayarak) ve `fork_trench` (üstte boşluklu platformlar,
    altta derin hendeğin engelli dibi, sağda merdivenle çıkış).
  - Oyuncu ~44 px (çömelince ~22): 1 karo aralık yalnız çömelerek/kayarak, 2 karo ayakta geçilir. Kayma ~400 px sürer,
    tüneller bundan kısa tutuldu. Havada yüzen tek satırlık karo şeritleri terrain'de tile üretmez: platformlar 2 satır.
  - Test kancası: `ChaseCorridorBuilder.dev_force_template = "fork_trench"` tek şablonu art arda dizer.
- `chase_swarm.gd`: soldan gelen kuş sürüsü (uçan düşmanın sprite'ları). Oyuncu ~560 px/s koşar; sürü
  430 + 12*zorluk px/s, 1000 px'ten fazla açılırsa 1.35x hızlanır. Yetişirse yakalar: 20 hasar, oyuncu sekip
  yavaşlar, sürü 420 px geri çekilir (2 sn bekleme). 3 yakalanma = ölüm. Sol kenarda yakınlıkla kızaran uyarı.
- Kamera oyuncuyu yatayda izler. Çıkış kapısına ulaşan kazanır. Ödül: 1 unlock teklifi, hiç yakalanmadan
  bitirirse 2 teklif.
- Başlangıç kart seçimi (3) diğer türlerle aynı.

## Tuzak Geçidi (`tuzak`)
- Yalnız zindan. Tek ekrana dikey olarak sığan gerçek bir **ızgara labirenti**: `trap_maze_builder.gd`. Kamera yalnız
  yatayda kayar. Genişlik zorlukla artar (4*zorluk hücre, zorluk 1-9; hücre 8 kolon, 5 satır yükseklik; tuzak sıklığı da zorlukla artar ama düşük tutuldu).
- Üretim: 5 katlı ızgarada rastgele DFS "mükemmel labirent" (başlangıç sol alt, çıkış sağ alt) + ~%12 ekstra açıklık
  (döngüler). Her hücrenin 2 satırlık zemini var; dikey geçitler zeminde 4 kolonluk delik (çift zıplama ile çıkılır/inilir),
  yatay geçitler duvar sütunlarında 3 satırlık açıklık. Hücre içinde %40 ihtimalle 2x2 blok. Çıkmaz sokaklar doğal olarak
  oluşur; doğru yolu gözle bulmak gerekir (BFS ile çözüm `route` hesaplanır, süre ve güvenli noktalar buna göre).
- Tuzaklar (`populate`): gerçek zindan tuzak sistemi (`TileTrapSpawner`, `TrapConfigV2`, tema ağırlıkları/grup boyları).
  Blokların ve zemin/tavanın her açık yüzüne konur: zemin yüzeyleri (1-5'li gruplar), tavan yüzeyleri, duvar yüzleri
  (ok/top). Rotanın her ikinci duruş noktası (+komşuları) zemin tuzağından muaf: oyuncunun nefes aldığı yerler.
  Sıklık zorlukla artar. Tema `DungeonThemeStyle`'dan (ates/zehir/buz/firtina/barut/golge); payload `theme` veya rastgele.
- Tema kuralları oyuncuya uygulanır: kaygan zemin (buz), sabit durana yıldırım (fırtına), karanlık + fener (gölge).
- Süre: 25 + çözüm uzunluğu/7 * 3.5 sn. Tuzağa çarpmak (oyuncu hasar alınca) -4 sn. Süre biterse başarısızlık = ölüm;
  çıkış kapısına ulaşırsan kazanırsın. Ödül: altın (30 + 25*zorluk + kalan sn) ve birkaç taş/odun.
- Giriş kart seçimi yok (yalnız hareket ve zamanlama).
- Not: `trap_corridor_traps.gd` yalnız ortak yardımcılar (grup boyu, spawner kurma); `ChaseCorridorBuilder`'ın `trap_mode`
  parametresi artık kullanılmıyor.
## Zirve Tırmanışı (`tirmanis`)
- Yalnız orman (gökyüzü + dağ arka planı); `ChallengeRoomRegistry.biome_for` her zaman "orman" verir. Düşman/kart seçimi yok.
- `summit_tower_builder.gd` (düzen + çizim), `summit_climb_controller.gd` (kamera, altın, düşme/zirve, gökyüzü, bulutlar).
- **Başlangıç:** zemin engebeli (sinüs toplamı, komşu sütunlar en çok 1 satır farklı; doğma noktası ve ağaç öbeği düz). Alçak platform yok:
  sahnedeki hazır `tree1` + `tree3` (dalları tek yönlü çarpışma) bir öbek kurar, dalları ilk platforma giden basamaktır
  (zemin -> tree1 sağ dal 5.2 satır -> tree3 alt sol -> sağ -> orta sol dal ~15 satır -> ilk platform). Yarısında ayna çevrilir.
  Dal koordinatları tree1/tree3 tscn'lerinden (sprite merkezi orijinli); ağaç tabanı zemin yüzeyine oturur.
- Platform sayısı `14 + 5*zorluk` (zorluk 1 ~20, zorluk 9 ~64; ~49 m / ~145 m). Zorluk düşükse kulenin en sert kısmına ulaşılmaz
  (`te = t * lerp(0.55, 1.0, ...)`). Yükseldikçe platformlar küçülür; basamak 3-4 -> 5-6 satır, açıklık 1-3 -> 3-9 karo.
- Platform türleri: `wall` (orman zemin karosu; altı pürüzlü ada gibi 2-5 satır, uçlar ince, en az 2 sütunluk parçalar, altından
  zıplanamaz), `oneway` (dungeon tileset "walls2", 1 satır, 1-7 karo, `OnewayTiles` katmanında kahverengiye boyanır), `branch`
  (ağaç dalı, düzen verisi), `summit` (aşağıda). Katı platform, altındaki platformun zıplama alanını (11 satır) kapatamaz.
- **Zirve:** ekranın bir yanındaki dağdan çıkıntı yapan kaya sırtı: serbest uçta 3 satır, duvara doğru 11 satıra kalınlaşır, ekran dışına
  uzanır; bayrak serbest uçtan 5 karo içeride. Oyuncu yerde durarak çıkıntıya varınca kazanır.
- Ölçüm (headless, gerçek oyuncu): tek zıplama 5.0 satır, çift zıplama 7.7 satır, koşarak çift zıplama ~18 karo yatay. `MAX_STEP_ROWS = 6`.
  Rota botu (kaba; ağaç dalları ve zeminden ilk dal dahil) zorluk 9'da 128 sıçramanın 126'sını, zorluk 1'de 48'in 48'ini geçti.
- **Altın:** oyunun normal madeni parası (`coin_small.png`, 8 kare) ve altın kesesi (`pouch.png`), 1.5x. Seyrek: ana yolda platform başına
  ~%28 tek altın, ~%12 havada tek altın (zıplamak gerekir), ~%6 kese, ~%12 boşlukta yay; yol dışı yan çıkıntılarda (1-2 sıçrama) kese
  (değer yükseklik ve zorlukla artar). Toplanan altın düşünce de kalır (zirve bonusu verilmez).
- Düşme: en son durulan en yüksek noktadan 448 px (14 karo) aşağı inilirse = ölüm (alttaki platforma düşmek sayılmaz).
- Ödül: `40 + 30*zorluk` altın + toplanan altın, birkaç taş/odun.
- **Görünüm:** ForestArenaDecorator `decor_biome = "mountain"` (dağ parallax'ı, dikey kayma artırıldı), hep gündüz (DayNightController kapatılır),
  yükseldikçe koyulaşan gökyüzü örtüsü, dünya uzayında akan bulutlar. Zemine rastgele orman dekoru (ağaç, çiçek, çalı, kütük, kaya,
  kelebek): `TileMapLayer` yalnız zemini taşır (dekor bu adı arar), platformlar `PlatformTiles`/`OnewayTiles` katmanlarındadır ve dekorlanmaz
  (platformdaki dekor ağaçları ek basamak olurdu). Ağaç öbeğinin üstüne rastgele ağaç düşmesin diye `_forest_tree_reserve_px` ile rezerve edilir.
- Yan duvarlar görünmez ve `no_wall_slide` (duvar zıplamasıyla kenardan tırmanmak platformları atlatırdı).
## Haritada doğma, ozan, kabul ekranı
- **Otomatik doğma:** `WorldManager.maybe_spawn_challenge()` harita her açıldığında çalışır: en çok 2 aktif,
  son doğmadan en az 2 gün sonra, %60 şansla; ömür 5 gün; tür koruma/dalga/asansör/kovalamaca/tuzak/tırmanış rastgele (asansör ve tuzak hep zindan, tırmanış hep orman);
  zorluk gün sayısına göre. Son doğma günü köy karosunda (`challenge_last_spawn_day`) saklanır. Zindan
  rehberi sürerken doğmaz.
- **Ozan:** `OzanSongs.pick_clue()` haritada aktif etkinlik varsa (%65) onu söyler: yön + uzaklık + türün türküsü
  (`ozan.song.challenge.<tür>`). Aynı etkinlik oturum içinde tekrar söylenmez (kayda yazılmaz).
- **Kabul ekranı:** POI'ye girince `ConfirmationDialog`: tür, açıklama, mekân/zorluk, kalan gün, ölüm uyarısı;
  "Gir" onaylarsa oda açılır ve karo kalkar, "Vazgeç" hiçbir şeyi tüketmez.

## Henüz yok
- Diğer türler (bkz. sohbetteki fikir listesi). Not: otomatik doğma şu an yalnız koruma/dalga/asansör/kovalamaca/tuzak/tırmanış
  türlerinden seçer; zorluk gün sayısına göre en fazla 7.
