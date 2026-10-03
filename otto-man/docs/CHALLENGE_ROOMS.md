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

## Henüz yok
- Otomatik doğma (ömür/sıklık), ozan haberi, giriş kabul ekranı.
- Tuzak Geçidi, Kovalamaca ve diğer türler (bkz. sohbetteki fikir listesi).
