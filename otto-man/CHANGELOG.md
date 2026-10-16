# Changelog

Her sürüm için oyuncuya dönük kısa notlar. Biçim `tools/push_itch.ps1` tarafından okunur:

- Sürüm başlığı `## <sürüm> - <tarih>` olmalı ve `project.godot` içindeki `config/version` ile aynı yazılmalı.
- Altında `### TR` ve `### EN` bölümleri, her biri madde işaretli liste.
- Oyuncu metinlerinde tire işaretli cümle kurma, sade yaz.
- En yeni sürüm en üstte.

Bu dosya 0.26.5 ile başladı, öncesi kayıt altında değil.

## 0.47.0 - 2026-10-17

### TR
- Ön çalılar artık zemine göre hizalı: kamera nasıl oynarsa oynasın, zıplayınca ya da binanın üstüne çıkınca yerlerinde kalıyor.
- Komşu köylerin köylüleri artık sebepsiz dükkâna girip çıkmıyor. Çalışanlar işyerinde kalıyor ve ara sıra iş için dışarı çıkıyor: kaynak binalarından ambara, dükkânlardan ambara ya da başka bir dükkâna elinde mal taşıyarak yürüyor, teslim edip boş elle işyerine dönüyor.
- Duran köylüler artık adım atma pozunda donmuyor, bacakları birleşik dik duruyor.

### EN
- The front bushes are now aligned to the ground: however the camera moves, they stay in place when you jump or climb onto a building.
- Villagers of neighboring villages no longer walk in and out of shops for no reason. Workers stay at their workplace and now and then go out on a job: from gathering buildings to the storehouse, from shops to the storehouse or another shop, carrying goods, then they deliver and walk back empty handed.
- Standing villagers no longer freeze in a stride, they stand upright with their legs together.

## 0.46.4 - 2026-10-17

### TR
- Ön çalılar artık ekranın en altına tam oturuyor, altlarında boşluk kalmıyor. Çatıdayken çalılar yine yerlerinde kalıyor.
- Komşu köylerin köylülerinin başındaki boş siyah isim şeridi kaldırıldı.
- Duran köylüler artık yürüme ya da oturma adımının ortasında donup kalmıyor, dik duruşa geçiyorlar.

### EN
- The front bushes now sit exactly at the bottom of the screen, with no gap beneath them. On a roof the bushes still stay in place.
- The empty black name strip above the heads of villagers in neighboring villages is gone.
- Standing villagers no longer freeze mid step or mid sit, they return to an upright pose.

## 0.46.3 - 2026-10-17

### TR
- Komşu köylerde arkadaki ağaç ve tepe katmanlarının uçlarında kesik kalan kısımlar, yatay çevrilmiş komşu parçayla tamamlanıyor.
- Ekranın altındaki ön çalılar oyuncu zıplayınca ya da çatıya çıkınca onunla yükselmiyor, yerinde kalıyor.

### EN
- In neighboring villages, cut-off parts at the ends of the background tree and hill layers are now completed by a horizontally mirrored neighbor piece.
- The front bushes at the bottom of the screen no longer rise with the player when jumping or climbing a roof, they stay in place.

## 0.46.2 - 2026-10-17

### TR
- Komşu köylerde arka plandaki çalı ve çimenler artık binaların önüne geçmiyor, zeminin üstünde ama binaların arkasında duruyor.
- Ekranın altındaki ön çalı şeridinde uçlarda kesik kalan çalı, yatay çevrilmiş komşu şeritle tamamlanıyor.

### EN
- In neighboring villages the background bushes and grass no longer draw in front of buildings, they sit above the ground but behind the buildings.
- In the front bush strip at the bottom of the screen, a bush cut off at the strip's end is now completed by a horizontally mirrored neighbor strip.

## 0.46.1 - 2026-10-16

### TR
- Kıyıda olmayan komşu köyler artık tam çimen zeminle çiziliyor, zeminin altı da çimen rengi. Kıyı köylerinde eski zemin ve su kalıyor.
- Ziyaret ettiğin köylerde ekranın en altına yapışık, kameraya en yakın görünen çalılar var. Çizimin kendi boyutunda durur, oyuncunun önünden geçer ve kamera hareketine göre biraz daha hızlı kayarak derinlik verir.

### EN
- Inland neighboring villages are now drawn with a full grass ground, and the area below the ground is grass colored too. Coastal villages keep the old ground and the water.
- Villages you visit now have bushes pinned to the very bottom of the screen, closest to the camera. They keep the drawing's own size, pass in front of the player and slide a little faster than the camera moves to add depth.

## 0.46.0 - 2026-10-16

### TR
- Köyler arası ittifaklar artık savaşı etkiliyor: bir köy saldırıya uğrayınca müttefikleri ona erzak ve altın yolluyor ve saldırgana kin besliyor. Ordular yine birleşmiyor.
- Kin yeterince büyürse müttefik de saldırgana savaş açıyor, böylece haritada savaşlar birden fazla köyü içine alabiliyor. İki tarafın da müttefiği olan köy tarafsız kalıyor.
- Dostluk ve savaşın üst üste gelmesi seyrek, bu yüzden bunu sık görmeyebilirsin.

### EN
- Alliances between villages now affect wars: when a village is attacked, its allies send it food and gold and grow resentful of the attacker. Armies still do not merge.
- If the resentment grows large enough the ally declares war on the attacker too, so wars on the map can pull in several villages. A village allied to both sides stays neutral.
- Friendships and wars rarely overlap, so you may not see this often.

## 0.45.1 - 2026-10-16

### TR
- Komşu köy ziyareti sırasında oyun kendiliğinden kayıt yapmıyor ve duraklatma menüsündeki Kaydet kapalı. Yarım kalmış bir soygun kayda girmesin diye son kayıt, haritaya girdiğin andaki kalıyor. Haritaya dönünce otomatik kayıt yine çalışır.

### EN
- The game no longer autosaves during a neighboring village visit and Save in the pause menu is disabled. An unfinished heist can't end up in a save, so the last save stays the one from when you entered the map. Autosave resumes when you return to the map.

## 0.45.0 - 2026-10-16

### TR
- Dost köyde gündüz köylülerle konuşabilirsin: dışarıdaki bir köylünün yanına gidince üstünde ok çıkar, etkileşim tuşuyla durup sana bir şey söyler.
- Söyledikleri köyün kişiliğine, zenginliğine, ordusuna, esir tutup tutmadığına ve seninle ilişkisine göre değişir. Gece ve düşman köyde kimse seninle konuşmaz.

### EN
- You can talk to villagers by day in friendly villages: walk up to a villager outside, an arrow appears above them, and the interact key makes them stop and say something.
- What they say depends on the village's personality, wealth, army, whether it holds prisoners and its relation with you. At night and in hostile villages nobody talks to you.

## 0.44.0 - 2026-10-16

### TR
- Komşu köylere gece soygunu: dost köyde gündüz serbestsin, gece nöbetçiler görüş konileriyle devriye geziyor. Düşman köyde gündüz de gizli kalmak zorundasın ve gündüz görüş konileri çok daha geniş.
- Nöbetçiler köyün askerleri gibi giyinir, köye göre hafif renk farkı taşır. Köyün asker sayısı kadar nöbetçi var, bir kısmı hazine binasının çevresinde dolaşır.
- Üç hedef: rastgele bir binanın çatısındaki hazine kapağı (çatıya çıkman gerek), depo kapısı ve savaş esiri tutan köylerde zindan. Hedefin yanında ok çıkar, etkileşim tuşuyla alırsın.
- Ganimet köyün kenarındaki çıkıştan çıkınca senin olur. Alarm çalarsa ganimetin tamamı gider, prestij kaybedersin, köyle ilişkin ağır bozulur, çoğunlukla misilleme gelir ve haritaya dönersin. Sessiz soygunda ilişki az düşer ve haber "gizemli hırsızlık" olarak duyulur.
- Savaşı kazanan köyler artık esir tutuyor, esirler zamanla salınıyor. Kurtardığın esirler köyüne yerleşmeye gelir.

### EN
- Night heists on neighboring villages: by day you roam freely in friendly villages, by night guards patrol with vision cones. In hostile villages you must stay hidden even by day, and the daytime cones are much wider.
- Guards wear the village soldier look with a slight tint per village. There are as many guards as the village has soldiers, some of them loiter around the treasure building.
- Three targets: a treasure hatch on the roof of a random building (you must climb up), the storehouse door, and a prison in villages that hold war prisoners. An arrow appears next to a target and the interact key takes the loot.
- Loot becomes yours when you leave through the village edge exit. If the alarm rings you lose all loot and some prestige, relations with the village drop hard, retaliation is likely and you return to the map. A quiet heist costs little relation and is reported as a mysterious theft.
- Villages that win wars now hold prisoners, and prisoners are released over time. Freed prisoners come to settle in your village.

## 0.43.1 - 2026-10-16

### TR
- Komşu köyler artık senin köyündeki gerçek binalarla kuruluyor: aynı 22 inşa parseli, odun kampı, taş ocağı, avcı kulübesi, depo, fırın, dokumacı, demirci, kışla gibi dükkânlar ve kat kat evler. Eski şehir evleri kaldırıldı.
- Köyün nüfusu kaç ev ve kaç kat gerektirdiğini belirliyor (kat başına 4 kişi, en çok 4 kat, sığmayan katlar dükkânların üstüne ekleniyor). Zengin ve kalabalık köylerde kaynak binaları yüksek seviyede, görseli ve çatısı seviyeye göre değişiyor.
- Hangi dükkânların olacağı köyün kişiliğine bağlı: savaşçı köyde kışla ve demirci, tüccar köyde çayhane, terzi ve dokumacı daha çok çıkıyor.
- Köylüler artık yaşıyor: sabah evden çıkıp işyerlerine giriyor, ara sıra kapıya çıkıyor, akşam meydanda dolaşıyor, gece evlerine girip uyuyor. Evlerde birileri varken pencereler yanıyor.
- Ziyaret ettiğin köyün binaları senin köyünün üretimine, işçilerine ya da kaynaklarına karışmıyor.

### EN
- Neighboring villages are now built from the real buildings of your own village: the same 22 build plots, woodcutter camp, stone mine, hunter hut, storage, bakery, weaver, blacksmith, barracks and other shops, and multi-floor houses. The old city houses are gone.
- The village's population decides how many houses and floors it needs (4 people per floor, at most 4 floors, floors that do not fit are added on top of shops). Rich and crowded villages have high-level gathering buildings whose look and roof change with level.
- Which shops appear depends on the village's personality: warlike villages get more barracks and smithies, merchant villages more tea houses, tailors and weavers.
- Villagers now live: they leave their homes in the morning and enter their workplaces, step out to the door now and then, wander the square in the evening and go home to sleep at night. Windows light up while someone is home.
- The buildings of a village you visit never touch your own village's production, workers or resources.

## 0.43.0 - 2026-10-16

### TR
- Komşu köyleri ziyaret edebilirsin. Dünya haritasında keşfettiğin bir köyün hex'inde köy menüsünden "Köyü ziyaret et" de.
- Köy sahnesi senin köyünün görünümünde: düz zemin, arka plan, gün ve gece, kıyıdaki köylerde su. Binalar köyün nüfusuna göre, zenginliğine göre fakir, orta ya da zengin evlerden dizilir. Çalılar, çimenler ve çamlar rastgele serpiştirilir. Aynı köy her ziyarette aynı görünür.
- Girişte köyün adı, lideri, kişiliği ve bu saatteki durum yazar: dost köyde gündüz serbestsin, gece ve düşman köyde gizlenmen gerekecek (nöbetçiler ve hedefler sonraki sürümde).
- Köyün iki ucundaki çıkışta yukarı tuşuyla haritaya dönersin.

### EN
- You can visit neighboring villages. On the hex of a village you have discovered on the world map, choose "Visit the village" in the village menu.
- The village scene looks like your own village: flat ground, backdrop, day and night, and water in coastal villages. Buildings are lined up by the village's population, using poor, average or rich houses depending on its wealth. Bushes, grass and pines are scattered at random. The same village looks the same on every visit.
- On entry you see the village name, its leader, personality and the current situation: in a friendly village you move freely by day, at night and in a hostile village you will have to stay hidden (guards and objectives come in a later version).
- Press up at the exit on either end of the village to return to the map.

## 0.42.0 - 2026-10-16

### TR
- Komşu köylerin artık kendi lideri, kişiliği, ordusu ve hazinesi var. Kişilikler: Savaşçı, Tüccar, İhtiyatlı, Hırslı, Dindar. Lider adı ve kişilik köyün bilgi balonunda görünüyor.
- Kişilik davranışı değiştiriyor: savaşçı ve hırslı köyler daha sık çatışır, ihtiyatlılar daha az; tüccar köyler daha çok kervan çıkarır; dindar ve ihtiyatlı köyler daha kolay ittifak kurar.
- Köylerin hazinesi var: halk vergi verir, ordu maaş yer, kervan satışı altın getirir. Hazine boşalınca asker kaçar, dolunca yeni asker alınır.
- Köyler arası savaşta iki ordu da yıpranır, hazine ve erzak erir. Ordusu çöken köy barış ister.
- Savaş haberleri artık nedenini ve savaşı hangi liderin istediğini söylüyor.
- Köyün sana yaptığı baskının gücü artık gerçek ordusundan geliyor, baskında verdiği kayıp ordusundan düşüyor.
- Köyün ordusu ve hazinesi balonda kaba ifadeyle yazıyor (zayıf, orta, güçlü / fakir, orta, zengin). Ajanın bilgi ağındaki köylerde gerçek sayı görünüyor.

### EN
- Neighboring villages now have their own leader, personality, army and treasury. Personalities: Warlike, Merchant, Cautious, Ambitious, Devout. The leader's name and personality show in the village tooltip.
- Personality changes behavior: warlike and ambitious villages clash more often, cautious ones less; merchant villages send more caravans; devout and cautious villages form alliances more easily.
- Villages have a treasury: the people pay taxes, the army draws pay, caravan sales bring gold. When the treasury runs dry soldiers desert, and when it is full new soldiers are recruited.
- In a war between villages both armies wear down and treasury and food drain. A village whose army collapses asks for peace.
- War news now states the cause and which leader wanted the war.
- The strength of a raid on your village now comes from the attacking village's real army, and its losses come off that army.
- A village's army and treasury show as rough terms in the tooltip (weak, average, strong / poor, average, rich). Villages in your agent's intel network show the real numbers.

## 0.41.0 - 2026-10-16

### TR
- Komşu köyler arasında ittifaklar kuruluyor. Birbirine yakın köyler zamanla dostlaşıyor, ortak düşmanı olanlar daha hızlı yakınlaşıyor, ilişkisi yüksek çiftler müttefik oluyor. İttifak bozulabiliyor da.
- Haritada ittifaklar çiziliyor: iki müttefik köyü ya da köyünle müttefik olduğun bir köyü bağlayan düz çizgi ve ortasında küçük bir kalkan (köyler arası mavi, seninle altın).
- Her komşu köyün üstünde seninle ilişkisini gösteren küçük bir bayrak duruyor: müttefik altın, dostane yeşil, gergin turuncu, düşman kırmızı. Nötr köyde bayrak yok.
- Köyün bilgi balonunda müttefikleri ve savaştığı köyler yazıyor.
- İttifak kurulunca ve bozulunca haber çıkıyor.

### EN
- Neighboring villages now form alliances. Villages close to each other grow friendly over time, those sharing an enemy grow closer faster, and pairs with high relations become allies. Alliances can break.
- Alliances are drawn on the map: a solid line with a small shield in the middle connecting two allied villages or your village and an ally (blue between villages, gold with you).
- A small flag above each neighboring village shows its relation with you: gold for allies, green for friendly, orange for tense, red for hostile. Neutral villages have no flag.
- A village's tooltip lists its allies and the villages it is at war with.
- News appears when an alliance forms or breaks.

## 0.40.1 - 2026-10-16

### TR
- Kervan yağması artık iki yüzlü: başarılı yağmada kimse kimin yaptığını öğrenmez, kervan yolda kaybolmuş sayılır ve çıktığı köyde yalnızca ufak bir şüphe kalır.
- Başarısız girişimi herkes bilir. Kervanın çıktığı ve vardığı köyle ilişki ağır bozulur, haberlerde kimin yaptığı yazar ve çıktığı köy büyük olasılıkla köyüne baskın yaparak karşılık verir.
- Kervan cariye varmadan menzile ulaşmışsa başarısız girişim sayılmaz, ceza yok.

### EN
- Caravan raids now have two faces: when a raid succeeds nobody learns who did it, the caravan is simply lost on the road and only a small suspicion lingers in the village it left.
- A failed attempt is known to everyone. Relations with the village the caravan left and the one it was heading to worsen badly, the news names who did it, and the village it left will most likely retaliate with a raid on your village.
- If the caravan reached its destination before the concubine arrived, it does not count as a failed attempt and there is no penalty.

## 0.40.0 - 2026-10-16

### TR
- Komutan cariye artık yolda yürüyen ticaret kervanlarını yağmalayabiliyor. Cariyeyi göreve yollarken haritada kervanın üstündeki hex'i seç.
- Yağmada kervanın yükü (yiyecek, odun ya da taş) ve biraz altın köye gelir. Kervan cariye varmadan menzile ulaşırsa yağma boşa gider.
- Kervanın çıktığı köyle ilişki ciddi, vardığı köyle hafif bozulur. Çıktığı köy birkaç gün sonra köyüne baskın yaparak karşılık verebilir.
- Yağmalanan kervanın izi haritada birkaç gün kırmızı çarpı olarak kalır.

### EN
- The commander concubine can now raid trade caravans walking the road. When sending a concubine on a mission, pick the hex the caravan is on.
- A raid brings the caravan's cargo (food, wood or stone) and some gold to the village. If the caravan reaches its destination before the concubine arrives, the raid comes to nothing.
- Relations worsen badly with the village the caravan left and slightly with the one it was heading to. The village it left may retaliate with a raid on your village a few days later.
- A raided caravan leaves a red cross on the map for a few days.

## 0.39.0 - 2026-10-16

### TR
- Komşu köyler arasındaki gerginlik ve savaşlar dünya haritasında çiziliyor: iki köyü bağlayan renkli kesik çizgi (savaş kırmızı, soğuk savaş turuncu, gerginlik sarı, ateşkes mavi).
- Savaşan iki köyün arasındaki bir hex'te cephe işareti duruyor. İmleci üstüne getirince hangi köyler arasında olduğu ve kaç gündür sürdüğü yazıyor.
- Baskına uğrayan köyün üstünde alev beliriyor.
- Komşu köyler artık kendi aralarında da kavga ediyor: sınır çatışmaları ilişkiyi bozuyor, aç köy tok komşusuna kızıyor, bazı gerginlikler savaşa dönüp ateşkesle bitiyor. Eskiden köyler arasında kendiliğinden hiç savaş çıkmıyordu.
- Kervan balonlarında köy adları artık doğru yazılıyor.
- Yalnızca keşfettiğin iki köy arasındaki gerginlik görünür.

### EN
- Tension and wars between neighboring villages are now drawn on the world map: a colored dashed line connecting the two villages (war red, cold war orange, tension yellow, ceasefire blue).
- A front marker sits on a hex between two villages at war. Hover it to see which villages are involved and how many days it has lasted.
- A flame appears above a village that has been raided.
- Neighboring villages now fight among themselves too: border clashes sour relations, a hungry village resents a well-fed neighbor, and some tensions grow into wars that end in a ceasefire. Before, wars between villages never started on their own.
- Village names in the caravan tooltip are now written correctly.
- You only see tension between two villages you have both discovered.

## 0.38.0 - 2026-10-16

### TR
- Komşu köyler arasındaki ticaret kervanları artık dünya haritasında görünüyor. Kervan yolda her gün birkaç hex ilerliyor, yolu soluk noktalarla çiziliyor.
- İmleci kervanın üstüne getirince nereden çıktığı, nereye gittiği, ne taşıdığı ve kaç gün sonra varacağı yazıyor.
- Yolda yağmalanan kervanın izi birkaç gün haritada kırmızı çarpı olarak kalıyor.
- Yalnızca keşfettiğin yerlerdeki kervanları görürsün. Kervan yolu keşfetmediğin bir köyün yerini ele vermez.

### EN
- Trade caravans between neighboring villages are now visible on the world map. A caravan moves a few hexes each day and its route is drawn with faint dots.
- Hover a caravan to see where it set out from, where it is going, what it carries and how many days until it arrives.
- A caravan plundered on the road leaves a red cross on the map for a few days.
- You only see caravans on ground you have discovered. A caravan route never reveals the location of a village you have not found.

## 0.37.18 - 2026-10-15

### TR
- Dünya haritasında yürürken oluşan takılmalar giderildi.
- Dünya haritası açıkken köy konuşma balonları artık haritanın üstünde görünmüyor.
- Zindan seviyesi yeniden üretilirken önceki denemeden kalan hayalet dekor ve altınlar temizleniyor.
- Düşmanlardan düşen paralar daha geniş bir alana saçılıyor ve havada hız kaybetmiyor.
- Köyde gelen cariyeler ve askerler daha doğal giriyor, cariyeler görev yolunda biraz daha hızlı yürüyor.
- Askerler yalnızca saldırıya giderken koşuyor; normal düşmanlar eski rengine döndü.

### EN
- Fixed stutter while walking on the world map.
- Village speech bubbles no longer show over the world map.
- Leftover ghost decor and gold from a failed dungeon generation attempt are now cleaned up.
- Coins dropped by enemies scatter wider and keep their speed in the air.
- Returning concubines and soldiers enter more naturally; concubines walk slightly faster on missions.
- Soldiers only run when responding to an attack; regular enemies are back to their original colors.

## 0.37.17 - 2026-10-15

### TR
- Düşmanlardan düşen paralar artık top gibi sekiyor, yere yapışmıyor.
- Kuş Kanadı: havada sınırsız zıplama hatası düzeltildi; 3. zıplama doğru şekilde 2 stamina harcıyor, zıplama animasyonu takılı kalmıyor.
- Baklava (+1 stamina) kalıcı olarak birikmiyor; stamina barı artık gerçek stamina kadar hücre gösteriyor (üst sınır yok).
- Duraklatma menüsünden dönünce zindan haritasını büyütme tuşu (Enter) tekrar çalışıyor.
- Paslı kılıç, şifalı bitki ve tüy toplanınca oyuncunun üstünde +1 ikonu beliriyor.
- Haritada uzun yolda "riske girecek misin" sorusu kaldırıldı.
- Köyde Alt ve Win tuşları artık işçi çıkarma/ekleme yapmıyor (Q ve E kaldı).

### EN
- Coins dropped by enemies now bounce like balls instead of sticking to the ground.
- Bird Wing: fixed unlimited air jumps; the 3rd jump now correctly costs 2 stamina and the jump animation no longer freezes on a frame.
- Baklava (+1 stamina) no longer stacks permanently; the stamina bar now shows as many cells as the real stamina (no cap).
- The dungeon map zoom key (Enter) works again after returning from the pause menu.
- Collecting rusty swords, herbs and feathers shows a +1 icon above the player.
- Removed the "will you risk it" prompt for long routes on the world map.
- In the village, Alt and Win keys no longer add/remove workers (Q and E remain).

## 0.37.16 - 2026-10-15

### TR
- Görevden ya da savaştan dönen cariyeler ve askerler artık köyün ortasında aniden belirmiyor; ekranın dışından yürüyerek giriyorlar.
- Cariyeler göreve giderken ve dönerken normalden hızlı yürüyor.

### EN
- Concubines and soldiers returning from missions or battles no longer pop into existence at the village center; they now walk in from offscreen.
- Concubines walk faster than usual when leaving for and returning from missions.

## 0.37.15 - 2026-10-15

### TR
- Gece nöbeti: askerlerin yaklaşık 5te 2'si gece uyumuyor, kasabaya dağılıp dolaşıyor. Nöbetçiler her gece değişiyor.

### EN
- Night watch: about 2 out of every 5 soldiers stay awake at night and spread out to patrol the town. The watch rotates every night.

## 0.37.14 - 2026-10-15

### TR
- Askerler orijinal boyutuna döndü. Kavuk beyaz kaldı, kuşak kırmızı, kıyafet kahverengi (önceki renk filtresi kavuğun yarısını kırmızı yapıyordu, yerine yeniden boyanmış sprite sayfaları geldi).

### EN
- Soldiers are back to their original size. The headgear stays white, the sash is red and the clothes are brown (the previous color filter turned half of the headgear red, so it was replaced by recolored sprite sheets).

## 0.37.13 - 2026-10-15

### TR
- Askerlerin kıyafeti kırmızı, kavukları beyaz oldu (renk filtresi). Asker sprite'ının ayakları köylüyle aynı hizaya alındı, böylece komşu köylülerle üst üste binme sırası doğru çıkıyor.

### EN
- Soldiers now wear red clothing and white headgear (color filter). The soldier sprite's feet were aligned with the villager's, so the draw order against neighbouring villagers is correct.

## 0.37.12 - 2026-10-15

### TR
- Asker olarak atanan köylüler artık asker (basic düşman) sprite'ıyla görünüyor. Ayakta bekleme, kılıç antrenmanı ve üç farklı oturuş arasında dönüyorlar, savaşa giderken koşuyorlar. İsimleri üstlerinde yazmaya devam ediyor.

### EN
- Villagers assigned as soldiers now use the soldier (basic enemy) sprite. They cycle between standing idle, sword practice and three sitting poses, and run when heading to war. Their names still show above them.

## 0.37.11 - 2026-10-15

### TR
- Komşu köylerin adları artık hep "Köy" ile bitiyor ve esprili: "Tembel Köy", "Pilav Köy", "Dedikodulu Köy", "Eşek Köy". Eski kayıtlardaki Obası/Mezrası/Beldesi/Köylüsü ekleri de "Köy" olarak görünüyor.
- Köy adları ekranda artık doğru Türkçe karakterlerle yazılıyor (Küçük, Çayır, Soğan).

### EN
- Neighbor village names now always end in "Village" and are playful: "Lazy Village", "Pilaf Village", "Gossipy Village", "Donkey Village". Old suffixes (Tribe/Hamlet/Town) in older saves also show as "Village".
- Village names in Turkish now use the proper characters (Küçük, Çayır, Soğan).

## 0.37.10 - 2026-10-15

### TR
- Tüccarların ve mentorun (Rehber) isimleri etkileşim oku görünürken artık okun altında görünüyor. Falcıyla aynı plaka düzeni.

### EN
- The names of traders and the mentor (Guide) now appear under the interaction arrow whenever it is shown, using the same plate layout as the fortune teller.

## 0.37.9 - 2026-10-15

### TR
- Kamp ateşinde zaman ilerletince tüccar, falcı, ozan ve cariyeler de zamana uygun konuma geçiyor. Eskiden yalnızca köylüler geçiyordu, gece köye giren gezgin NPC'ler saatler geçse de giriş noktasında kalıyordu.

### EN
- When time is advanced at the campfire, the traders, fortune teller, bard and concubines now also settle into positions that match the time. Previously only villagers did, and visitors who arrived at night stayed at the entry point even hours later.

## 0.37.8 - 2026-10-15

### TR
- Tüccar penceresi artık tam ekran ve falcıyla aynı örtü animasyonuyla açılıyor (tüccarın el çiziminin dosyası eklenince; o zamana kadar animasyonsuz açılır).
- Falcı ve tüccar kapanırken açılış animasyonu tersine, hızlıca oynuyor: örtü sağa çekiliyor ve köy görünüyor.
- Silah kademeleri ortak silah ikonunun köşesinde Roma rakamıyla (I, II, III) gösteriliyor.

### EN
- The trader window is now full screen and opens with the same cloth animation as the fortune teller (once the trader's hand drawing file is added; until then it opens without animation).
- When the fortune teller and the trader close, the opening animation plays in reverse, quickly: the cloth is pulled back to the right and the village is revealed.
- Weapon tiers are shown with Roman numerals (I, II, III) on the corner of the shared weapon icon.

## 0.37.7 - 2026-10-15

### TR
- Tüccarla artık konuşulabiliyor: tüccar otururken etkileşim kapanıyordu ve vaktinin çoğunu oturarak geçirdiği için neredeyse hiç konuşulamıyordu.
- Tüccarların sattıkları çeşitlendi: fakir tüccar yalnızca temel kaynak (yiyecek, odun, taş) satıyor. Diğerleri işlenmiş (kereste, tuğla, ekmek, parfüm, kahve), el işi (metal, kumaş, ilaç, giysi) ve silah satıyor, çok daha pahalıya.
- Tüccar penceresi yenilendi: kademe renkli büyük kartlar, köydeki mevcut stok, düğmelerde toplam bedel, kaynağın geldiği köy.

### EN
- You can now talk to traders: interaction was disabled while the trader was sitting, and they spend most of their time sitting, so it almost never worked.
- Trader stock is more varied: the poor trader only sells basic resources (food, wood, stone). The others sell processed goods (lumber, brick, bread, perfume, coffee), crafted goods (metal, cloth, medicine, garments) and weapons, at much higher prices.
- The trader window was redesigned: large tier-colored cards, current village stock, total cost on the buttons, and the village the trader comes from.

## 0.37.6 - 2026-10-15

### TR
- Dünya haritası açılırken bulutlar ekranı kaplıyor, iki yana açılırken kamera haritadaki oyuncuya yaklaşıyor. Haritadan çıkarken tersi: kamera uzaklaşıyor, bulutlar kapanıyor, yeni sahne bulutların arkasından açılıyor. Bulutlar belirirken ve kaybolurken solarak giriyor, arkadaki bulutlar daha koyu ve yavaş.

### EN
- When the world map opens, clouds cover the screen and part to both sides while the camera moves in on the player. Leaving the map does the reverse: the camera pulls back, the clouds close, and the new scene is revealed from behind them.

## 0.37.5 - 2026-10-15

### TR
- Falcı: fare üstüne gelince kartlar artık vurgulanmıyor, yalnızca tıklanan ya da odaklanan kart vurgulanıyor.
- Falcı: sağ üstteki X kaldırıldı. Sayfa ve kapatma ipuçları kullandığın cihaza göre (klavye ya da gamepad) değişiyor.
- Falcı: kart isimleri kartın altına indi, üst bölge çizimlere ayrıldı.
- Falcı: seçili kartın adı ve açıklaması ortalandı.

### EN
- Fortune teller: cards are no longer highlighted when the mouse hovers over them, only the clicked or focused card is.
- Fortune teller: the X in the top right was removed. The page and close hints change depending on the device you use (keyboard or gamepad).
- Fortune teller: card names moved to the bottom of the card, the top area is reserved for artwork.
- Fortune teller: the selected card's name and description are centered.

## 0.37.4 - 2026-10-15

### TR
- Falcı açılırken bir el siyah örtüyü ekranın sağından soluna doğru sererek arayüzün zeminini oluşturuyor.

### EN
- When the fortune teller opens, a hand spreads a black cloth across the screen from right to left, forming the background of the interface.

## 0.37.3 - 2026-10-15

### TR
- Falcı takası: feda edilen üç kart ortada birleşir, parlama olur ve yeni kart adıyla, açıklamasıyla ekranda çıkar. Bir tuşa basınca kapanır.

### EN
- Fortune teller trade: the three sacrificed cards merge in the middle, a flash plays, and the new card appears with its name and description. Press any key to close.

## 0.37.2 - 2026-10-15

### TR
- Falcı: boş bir sekmeye (arşiv gibi) geçince odak kaybolup ekran takılı kalmıyor; her açılışta Tümü sekmesiyle başlıyor.
- Falcı: sayfa okları kaldırıldı, sayfa Q/E ve fare tekerleğiyle çevriliyor.
- Falcı: Güçlendir, Arşivle ve Takas düğmeleri artık karta tıklayınca açılıyor ve her zaman en üstte çiziliyor.

### EN
- Fortune teller: switching to an empty tab (like the archive) no longer loses focus and freezes the screen; it always opens on the All tab.
- Fortune teller: the page arrows were removed, pages turn with Q/E and the mouse wheel.
- Fortune teller: the Boost, Archive and Trade buttons now open when you click a card and are always drawn on top.

## 0.37.1 - 2026-10-15

### TR
- Falcı arayüzü yeniden düzenlendi: solda element şeridi, ortada sayfa sayfa 5x2 büyük kart, sağda satış, takas sepeti ve falcı yükseltme.
- Güçlendir, Arşivle ve Takas düğmeleri artık seçili kartın üstünde çıkıyor. Seçili kartın açıklaması her zaman altta okunuyor.
- Sayfa değiştirmek için oklar, fare tekerleği ya da Q/E (gamepad omuz tuşları) kullanılır.

### EN
- The fortune teller screen was reorganized: an element rail on the left, 5x2 large cards per page in the middle, and the sale, trade basket and seer upgrade on the right.
- The Boost, Archive and Trade buttons now appear on top of the selected card. The description of the selected card is always readable at the bottom.
- Change pages with the arrows, the mouse wheel, or Q/E (gamepad shoulder buttons).

## 0.37.0 - 2026-10-15

### TR
- Falcı yenilendi: tam ekran bir kart koleksiyonu. Kartlar element rengine göre dizilir; tema sekmeleri, arşiv ve sıralama (son açılan, element, kategori) var.
- Güçlendir: seçtiğin kartlar zindan ödüllerinde üç kat şansla çıkar. Kalıcıdır. Slot sayısı falcının seviyesine bağlı, falcıyı altınla yükseltebilirsin.
- Arşivle: kart desteden çıkar ama silinmez, ücret karşılığı geri alınabilir. Deste belli bir sayının altına inemez.
- Takas: üç kartı feda edersin, feda ettiklerinin elementlerinden biri rastgele açılır. Pahalıdır.
- Her falcı ziyaretinde henüz açmadığın havuzdan üç eşya satılır, birini alınca diğerleri gider.
- Rarity (yaygın, nadir...) tamamen kaldırıldı. Kartlar eşit, rengi element belirler. Pazar kartları tek fiyattan.
- Falcı Kadın eşyası kaldırıldı, işini güçlendirme sistemi alıyor.

### EN
- The fortune teller was rebuilt: a full screen card collection. Cards are laid out by element color, with theme tabs, an archive and sorting (newest, element, category).
- Boost: cards you pick appear at three times the chance in dungeon rewards. It is permanent. The number of slots depends on the seer's level, which you can upgrade with gold.
- Archive: a card leaves the deck but is not deleted, and can be restored for a fee. The deck cannot shrink below a minimum size.
- Trade: you sacrifice three cards and one of their elements is chosen at random to unlock a new card. It is expensive.
- On every visit the seer sells three items from your locked pool, and buying one removes the rest.
- Rarity (common, rare...) was removed completely. All cards are equal and the element decides the color. Market cards share a single price.
- The Fortune Teller item was removed, its job is taken over by the boost system.

## 0.36.1 - 2026-10-15

### TR
- Zindan üretiminde tünel kapatma artık gerçek bir geçidi kapatmıyor: bir tüneli doldurmak seviyeyi ikiye bölecekse tünel açık bırakılır. Geçilemeyen zindanlar düzeldi.
- Duvar Kırıcı itemi kaldırıldı.
- Kalkan Kırığı artık düşmanı gerçekten sersemletiyor (yaklaşık 1,2 saniye); hemen saldırıya dönmüyor.
- Görevden dönen cariyenin haritadaki dönüş işareti, zaman atlandığında artık görev hexinden yeni çıkıyormuş gibi görünmüyor.
- Asansör meydan okumasında zemin artık sabit, yükselme hissini arka plan veriyor. Son dalgadaki düşmanlar tavanın üstünde doğup takılmıyor.
- Zindanda sonraki seviyeye geçerken verilen item artık deneyim çubuğunu sıfırlamıyor.

### EN
- Tunnel sealing in dungeon generation no longer closes a real passage: if filling a tunnel would split the level in two, it is left open. Impassable dungeons are fixed.
- The Wall Breaker item was removed.
- Shield Breaker now really stuns the enemy (about 1.2 seconds) instead of letting it attack again right away.
- The returning marker of a concubine coming back from a mission no longer looks like she just left the mission hex after time was skipped.
- In the elevator challenge the floor is now fixed and the background scrolls to give the rising feel. Enemies of the last wave no longer spawn above the ceiling and get stuck.
- The item given when moving to the next dungeon level no longer resets the experience bar.

## 0.36.0 - 2026-10-15

### TR
- Cariyelerde sağlık ve moral tek değere indi: Dinçlik. Her görev biraz düşürür (başarı 10, başarısızlık 25), 30'un altındaki cariye göreve çıkamaz.
- Dinçlik yemekle dolar: 5 meyve ya da 2 ekmek tam doldurur. Cariye köydeyken günde en çok 40 puan yer, önce meyve sonra ekmek. Yemek yoksa toparlanmaz.
- Köyde hiç meyve ya da ekmek yoksa cariyeler açlıktan günde 10 dinçlik kaybeder. Dinçliği 0'a düşen cariye köyü terk eder.
- Yaralanma ayrı kalır, o hâlâ gün sayarak iyileşir. Eski kayıtlar sağlık ve moralin düşüğünden dinçliğe çevrilir.
- Özellikler başlığı geri geldi.

### EN
- Concubine health and morale were merged into one value: Stamina. Every mission lowers it a little (success 10, failure 25), and a concubine below 30 cannot go on missions.
- Stamina refills by eating: 5 fruit or 2 bread fills it completely. A concubine in the village eats up to 40 points a day, fruit first, then bread. Without food she does not recover.
- If the village has no fruit or bread, concubines lose 10 stamina a day to hunger. A concubine whose stamina reaches 0 leaves the village.
- Injury stays separate and still heals by counting days. Old saves convert the lower of health and morale to stamina.
- The Traits heading is back.

## 0.35.4 - 2026-10-15

### TR
- Cariye penceresinin sol tarafı sadeleştirildi: ad, rol ve seviye önem sırasına göre büyükten küçüğe. HP ve moral satırları kaldırıldı, özellikler daha küçük ve renkli. Portre çerçevesi ve ortalaması düzeldi.

### EN
- The left side of the concubine window was simplified: name, role and level from largest to smallest by importance. HP and morale lines were removed, traits are smaller and color coded. Portrait frame and centering were fixed.

## 0.35.3 - 2026-10-15

### TR
- Cariye penceresi artık ekranın tam ortasında, sabit boyutta ve daha geniş. Uzun yazılar (özellikler, rol bilgisi) kendi kaydırma alanında kalıyor; pencere aşağı uzayıp kaynak çubuğunu kapatmıyor.

### EN
- The concubine window is now exactly centered, fixed in size and wider. Long text (traits, role info) stays in its own scroll area, so the window no longer stretches down over the resource bar.

## 0.35.2 - 2026-10-15

### TR
- Haydut kampları çevrelerindeki yolları tehlikeli yapıyor: 3 hex içinde yolculukta olay şansı artar. Komutan cariye varsa etki azalır, kamp temizlenince tehdit kalkar. Rota önizlemesi de bunu hesaba katar.
- Komutan cariye bir meydan okuma (challenge) odasını çözebilir: harita noktası kalkar, toplama engeli ise bağlı köy olayı biter. Eşya açma ödülü oyuncunun kendi oynayışına ait kalır, cariye yalnız görev ödülünü (altın) getirir.

### EN
- Bandit camps make the roads around them dangerous: more travel incidents within 3 hexes. A commander concubine reduces the effect, and clearing the camp removes it. The route preview accounts for it.
- A commander concubine can resolve a challenge room: the map point disappears, and a gather blockade ends its linked village event. Item unlock rewards stay with the player's own runs, the concubine only brings the mission reward (gold).

## 0.35.1 - 2026-10-15

### TR
- Rol değiştirince açılan "imza görevleri" kaldırıldı. Rol artık anında değiştiği için her cariye ve rol çifti için 100-200 altınlık görev zinciri üretmek altın kazandırıyordu (rol değiştirmek 100 altın).
- Cariye penceresinden eski görev listesi, asker adımlayıcıları ve rol eğitimi kodu temizlendi. Görünüş ve davranış aynı.

### EN
- The "signature missions" that appeared when changing role were removed. Since roles now change instantly, each concubine and role pair produced a 100-200 gold mission chain, which was a gold exploit (a role change costs 100 gold).
- The old mission list, soldier steppers and role training code were cleaned out of the concubine window. Look and behavior are unchanged.

## 0.35.0 - 2026-10-15

### TR
- Cariye penceresine "Cariyeler" sekmesi eklendi: köydeki tüm cariyeler rolleri, puanları ve durumlarıyla (müsait, görevde ve hangi görevde, yaralı ve kaç gün, esir) tek listede. Birine basınca pencere o cariyeye geçer, köyde aramana gerek kalmaz.
- Esir cariyenin kurtarma görevi kayıt dosyasına yazılmıyordu: kaydedip yükleyince cariye sonsuza dek esir kalırdı. Düzeltildi.
- Görev hedefi keşfedilmemiş bir hex'e düşerse artık o hex haritada açılıyor. Aksi halde ilk cariye zincirinin görevi gibi görevler haritada hiç görünmeyebiliyordu.
- Eski "Görevler sekmesinden ata" yazan öğretici ve haber metinleri yeni "Göreve Yolla" akışına göre yenilendi.

### EN
- A "Concubines" tab was added to the concubine window: everyone in the village with role, points and status (available, on which mission, injured and for how long, captive) in one list. Pressing one switches the window to her, so you do not have to find her in the village.
- A captive concubine's rescue mission was not written to the save file: after saving and loading she would stay captive forever. Fixed.
- When a mission target lands on an undiscovered hex, that hex is now revealed on the map. Otherwise missions like the first concubine chain could be invisible.
- Tutorial and news texts that said "assign from the Missions tab" were rewritten for the new "Send on Mission" flow.

## 0.34.3 - 2026-10-15

### TR
- Diplomatın ilişki koruması artık haritadaki doğrudan eylemleri de kapsıyor: baskın emri, baskının sonucu, taraf tutma ve ittifak bozma. Kayıplar etkin puan başına yüzde 10 azalır.

### EN
- The diplomat's relation protection now also covers direct map actions: raid orders, raid results, taking sides and breaking alliances. Losses shrink by 10 percent per effective point.

## 0.34.2 - 2026-10-15

### TR
- Diplomatın krizleri kısaltan etkisi kaldırıldı. Yeni pasifi: görevlerden doğan köy ilişkisi kayıpları (yağma, devşirme) etkin puan başına yüzde 10 azalır, en çok yüzde 50.

### EN
- The diplomat's crisis-shortening effect was removed. New passive: relation losses from missions (plundering, recruiting) shrink by 10 percent per effective point, up to 50 percent.

## 0.34.1 - 2026-10-15

### TR
- Roller sekmesinde her rol için "Aktif yetenekler" (görevde yaptıkları) ve "Pasif yetenekler" (köyde olduğu sürece geçerli etkileri) ayrı gösteriliyor, güncel sayılarla.
- Komutanın pasifi: köyde boştayken orduya saldırı ve savunma bonusu ile askerlere önderlik kapasitesi.

### EN
- The Roles tab now shows "Active abilities" (what she does on missions) and "Passive abilities" (effects while she is in the village) for each role, with live numbers.
- Commander passive: attack and defense bonus for the army while idle in the village, plus soldier leadership capacity.

## 0.34.0 - 2026-10-15

### TR
- Cariye rolleri artık köyün yetenekleri. Aynı roldeki cariyelerden en iyisi belirler, her yardımcı +1 etkin puan ekler (en çok 5). Esir cariye sayılmaz.
- Tıbbiyeci yoksa asker kayıpları yüzde 25, iyileşme süreleri (cariye yaraları ve oyuncunun ölüm sonrası zayıflığı) yüzde 50 artar. Tıbbiyeciyle kayıp en çok yüzde 30, süre en çok yüzde 40 azalır.
- Ajan yoksa komşu köylerden yalnız en yakınının krizi ve baskını görünür. Ajanla 2 artı etkin puan kadar köy görünür. Görünmeyen köylerin yardım görevleri de görünmez.
- Komutanlar önderlik eder: her komutan 5 artı puanının iki katı kadar askeri aynı anda görevde tutabilir. Komutan yoksa yalnız 3 asker.
- Diplomat komşu köylerden köylü devşirebilir: kişi başı 30 altın ve köyle ilişkiden 3 puan harcar, köyle ilişki en az 20 olmalı, aynı köyden 7 günde bir alınır, köyde barınak gerekir.
- Tüccar varsa köye tüccar gelme şansı etkin puan başına yüzde 10 artar.
- Roller sekmesinde köyün bu roldeki toplam gücü ve cariye sayısı görünür.

### EN
- Concubine roles are now village capabilities. The best concubine of a role sets the strength and each helper adds +1 effective point (max 5). Captive concubines do not count.
- Without a physician soldier losses rise 25 percent and healing takes 50 percent longer (concubine wounds and the player's post-death debuff). With one, losses drop up to 30 percent and healing up to 40 percent.
- Without an agent you only see the nearest neighbor village's crisis and raids. With one you see 2 plus effective points villages. Relief missions in unseen villages are hidden too.
- Commanders lead: each commander can keep 5 plus twice her points in soldiers on missions at once. With no commander only 3 soldiers.
- A diplomat can recruit villagers from neighbors: each costs 30 gold and 3 relation points, relations must be at least 20, the same village can be tapped every 7 days, and housing is required.
- With a trader, the chance of a trader visiting the village rises 10 percent per effective point.
- The Roles tab shows the village's total strength in that role and how many concubines hold it.

## 0.33.0 - 2026-10-15

### TR
- Cariye özellikleri yenilendi: tamamen şansa bağlı, 0 ile 3 arası özellik, birbirinin tersi olan özellik yok. Bir cariye hiç iyi özellik almayabilir ya da hepsi kötü olabilir.
- Yeni özellikler: Tatlı Dilli, Açgözlü, Atılgan. Demir İrade, Tembel, Kibirli ve Savurgan kaldırıldı.
- Beğenmediğin cariyeyi Roller sekmesindeki "Köyden yolla" ile gönderebilirsin (iki basışla onay).
- Zindanda bir cariye kurtarınca özelliklerini gösteren bir pencere açılır: köye alabilir ya da yoluna gönderebilirsin. Yoluna gönderirsen teşekkür eder ve 20 altın bırakır.
- Cariye penceresinde Roller sekmesi artık ızgara gibi gezilir: sol sağ aynı satırda, yukarı aşağı satırlar arasında. "+" düğmesiyle puan vermek kolaylaştı.
- Rol düğmelerinde puan noktaları görünür, özellikler renkli ve daha okunaklı.

### EN
- Concubine traits were reworked: fully random, 0 to 3 traits, and no trait is the opposite of another. A concubine may get no good trait at all, or only bad ones.
- New traits: Silver Tongue, Greedy, Reckless. Iron Will, Lazy, Arrogant and Wasteful were removed.
- You can send away a concubine you do not like with "Send away" in the Roles tab (two presses to confirm).
- Rescuing a concubine in a dungeon opens a window showing her traits: take her to the village or let her go. Letting her go earns a thank you and 20 gold.
- The Roles tab now navigates like a grid: left and right within a row, up and down between rows. Giving points with "+" is easier.
- Role buttons show point dots, and traits are colored and easier to read.

## 0.32.0 - 2026-10-14

### TR
- Cariye istatistikleri (savaş, diplomasi, ticaret, bürokrasi, keşif) kaldırıldı. Yerine gelişim puanı geldi: her seviye atlayışta 1 puan kazanılır, Roller sekmesinde istediğin role verilir.
- Bir role en çok 5 puan verilebilir. Puan geri alınamaz. Yalnız aktif rolün puanı sayılır, her puan görev başarı şansına yüzde 4 ekler (5 puanda yüzde 20).
- Seviyenin kendisi artık başarı şansı vermiyor, yalnız puan kazandırıyor.
- Rol puanı pasif etkileri (komutanın ordu bonusu, köy olay etkileri) ve tüccarın satış kârını da güçlendirir.
- Eski kayıtlarda her cariye (seviye eksi bir) boş puanla yüklenir.

### EN
- Concubine stats (combat, diplomacy, trade, bureaucracy, exploration) are gone. A development point replaces them: each level-up grants 1 point to spend on any role in the Roles tab.
- A role takes at most 5 points. Points cannot be taken back. Only the active role's points count, and each point adds 4 percent to mission success chance (20 percent at 5 points).
- The level itself no longer adds success chance, it only grants points.
- Role points also strengthen passive effects (commander army bonus, village event effects) and the trader's sale profit.
- Old saves load each concubine with (level minus one) free points.

## 0.31.5 - 2026-10-14

### TR
- Alım cariye rolü oyundan kaldırıldı. Bu rolde olan cariyeler rolsüz kalır.
- Mal satın alma seçenekleri (odun, taş) Tüccar cariyeye geçti.

### EN
- The Scholar concubine role was removed. Concubines holding it become roleless.
- Buying goods (wood, stone) moved to the Trader concubine.

## 0.31.4 - 2026-10-14

### TR
- Komutan cariye artık boş arazide asker gönderip kaynak toplayamıyor. Kaynak için yağma yapması gerekir.
- Komutan bir komşu köyün yakınındaki orman, dağ ya da ovayı yağmalayabilir: kaynak getirir, köyle ilişki bozulur, asker kaybı ve yaralanma riski var. Götürdüğü asker sayısı ganimeti etkiler.
- Komutan komşu köye baskın da yapabilir: altın ve kaynak getirir, ilişki ciddi bozulur.

### EN
- A commander concubine can no longer gather resources with soldiers in empty land. She has to plunder for them.
- A commander can plunder the forests, mountains or fields near a neighbor village: it brings resources but worsens relations, with soldier loss and injury risks. The number of soldiers affects the loot.
- A commander can also raid a neighbor village: it brings gold and resources, and relations worsen badly.

## 0.31.3 - 2026-10-14

### TR
- Cariye görevlerinin getirdiği odun, taş ve yiyecek belirgin şekilde azaltıldı. Görevler artık binaların yerini tutmuyor, yalnız destek oluyor.
- Mesafe bonusu azaldı (en çok yüzde 60).
- Tüccarın sattığı malın altın karşılığı düşürüldü: odun 1, taş 1.5, yiyecek 0.5 altın civarı.
- Alım cariye artık altın verip mal satın alıyor (odun, taş). Satın alma fiyatı satış fiyatından yüksek, al-sat ile altın çıkmaz.

### EN
- Wood, stone and food rewards from concubine missions are much smaller. Missions now support buildings instead of replacing them.
- The distance bonus is smaller (at most 60 percent).
- Gold paid for goods sold by traders was lowered: about 1 per wood, 1.5 per stone, 0.5 per food.
- Scholar concubines now buy goods with gold (wood, stone). Buying costs more than selling, so buy-and-sell cannot make gold.

## 0.31.2 - 2026-10-14

### TR
- Göreve yollama ekranı tek küçük panele indi: görev, asker ve mal miktarı satırları var. Yukarı aşağı satır seçer, sol sağ değeri değiştirir (basılı tutunca hızlanır), onay direkt yollar.
- Açılışta asker ve mal miktarı makul bir değerle gelir, çoğu zaman yalnız onaylamak yeter.
- Hex üstündeki bilgi balonu kısaldı: yalnız yapılabilecek işlerin adları.

### EN
- The send screen is now one small panel with task, soldier and goods rows. Up Down picks a row, Left Right changes the value (hold to repeat), Confirm sends right away.
- Soldier and goods amounts start at sensible values, so often you only need to confirm.
- The hex tooltip is shorter: just the names of the available jobs.

## 0.31.1 - 2026-10-14

### TR
- Tüccar cariye artık altınla altın kazanmıyor: köyün odununu, taşını ya da yiyeceğini komşu köye satıp altın getiriyor. Kâr köyün ilişkisine ve cariyenin ticaret yeteneğine göre artar.
- Eski ticaret rotası sistemi ve ayrı ticaret görevi penceresi tamamen kaldırıldı.

### EN
- Traders no longer turn gold into gold: a trader concubine sells the village's wood, stone or food to a neighbor village for gold. Profit grows with relations and her trade skill.
- The old trade route system and the separate trade mission window are completely removed.

## 0.31.0 - 2026-10-14

### TR
- Cariyenin rolü artık anında değişiyor: eğitim görevi ve malzeme şartı kalktı, yalnız 100 altın ödenir. Rolü bırakmak bedava.
- Ticaret görevi haritaya taşındı. Tüccar cariye komşu köye "Ticaret anlaşması" ile gönderilir; götürdüğü altın başarıda yüzde 40 kârla geri döner.
- Cariye penceresindeki ayrı ticaret görevi düğmesi kaldırıldı.

### EN
- A concubine's role now changes instantly: the training mission and material costs are gone, you only pay 100 gold. Dropping a role is free.
- The trade mission moved to the map. A trader concubine is sent to a neighbor village with "Trade deal"; the gold she carries returns with a 40 percent profit on success.
- The separate trade mission button in the concubine window is gone.

## 0.30.1 - 2026-10-14

### TR
- Cariye penceresindeki eski görev listesi kaldırıldı. Tüm görevler artık yalnız "Göreve Yolla" ile haritadan veriliyor.
- Haritada bekleyen rol eğitimi ve olay yardımı görevleri, o görevin hex'ine gelince seçenek olarak çıkıyor.
- Cariyeyi göreve yollayınca harita kapanırken oluşan hata düzeltildi.

### EN
- The old mission list in the concubine window is gone. All missions are now given from the map with "Send on Mission".
- Role training and event relief missions waiting on the map show up as options when you pick their hex.
- Fixed an error when the map closed after sending a concubine on a mission.

## 0.30.0 - 2026-10-13

### TR
- Haritadan gönderilen görevlerin sonucu artık beş kademeli: büyük başarı, başarı, kıl payı, başarısızlık ve felaket.
- Başarısız görevlerde cariye yaralanır ve morali düşer. Yaralı cariye birkaç gün görev alamaz, sonra iyileşir. Boştaki cariyeler zamanla toparlanır.
- Tehlikeli görevlerde felaket olursa cariye esir düşer. Haritada kurtarma görevi çıkar: baskınla, fidyeyle ya da bir komutan cariye göndererek kurtarılır.
- Her cariyenin doğuştan bir artı, bir eksi özelliği var. Cariye penceresinde görünür.
- Ajanın zindana sızması sonraki zindan girişinde garanti kurtarma odası verir (10 gün).
- Komutanın zindan girişini temizlemesi sonraki girişte düşman sayısını azaltır (10 gün).
- Tüccarın ticaret anlaşması köye tüccar gelme şansını ikiye katlar (10 gün).
- Zindan balonunda süren etkilerin kalan günü yazar.

### EN
- Missions sent from the map now end in five tiers: great success, success, narrow miss, failure and disaster.
- A failed mission hurts the concubine and lowers her morale. An injured concubine cannot take missions for a few days, then heals. Idle concubines recover over time.
- A disaster on a dangerous mission gets the concubine captured. A rescue mission appears on the map: free her by raid, by ransom, or by sending a commander concubine.
- Every concubine now has one inborn upside and one downside, shown in the concubine window.
- An agent infiltrating a dungeon grants a guaranteed rescue room on the next entry (10 days).
- A commander clearing a dungeon entrance reduces the enemy count on the next entry (10 days).
- A trader's deal doubles the chance of a trader visiting the village (10 days).
- The dungeon tooltip shows the remaining days of active effects.

## 0.29.0 - 2026-10-13

### TR
- Haritada görevdeki cariyelerin yolu artık noktalarla gösteriliyor ve her rolün kendi rengi var. Gittiği kısım soluk, kalan kısım dolu; dönüş yolu daha silik.
- Hedef seçerken rota önizlemesi cariyenin rol renginde çiziliyor.
- Haritada haydut kampları çıktı. Komutan cariye kampa saldırıp temizleyebilir ve ganimet alır.

### EN
- Concubines on missions now show their route as dots in the role color. The walked part is faded, the rest is solid, and the way back is dimmer.
- The route preview while choosing a target uses the concubine's role color.
- Bandit camps now appear on the map. A commander concubine can attack and clear a camp for loot.

## 0.28.0 - 2026-10-13

### TR
- Cariyeleri artık haritadan göreve yolluyoruz: cariye penceresinde "Göreve Yolla"ya basınca harita açılır, hedef hex'i seçersin, cariyenin rolüne göre yapabileceği işler listelenir.
- Göreve çıkmadan önce asker ve hediye miktarını seçiyor, süreyi ve başarı şansını görüyorsun.
- Bilinmeyen bölgelere yalnız Ajan gönderilebilir.
- Rastgele çıkan görev panosu kaldırıldı. Ajan, diplomat, tüccar, alım ve şifacı işlerini artık oyuncu haritada kendisi yapamaz, bunlar cariyelere ait.

### EN
- Concubines are now sent on missions from the map: press "Send on Mission" in the concubine window, pick a target hex and choose from the jobs her role can do there.
- Before departure you pick soldiers and a gift amount and see the duration and success chance.
- Only an Agent can be sent into unexplored areas.
- The random mission board is gone. Agent, diplomat, trader, scholar and medic jobs can no longer be done by the player on the map, they belong to concubines.

## 0.27.5 - 2026-10-12

### TR
- Köydeki pencerelerde küçük yazılar büyütüldü: falcı, tüccar, kamp ateşi, kışla silah seçimi, cariye ve ticaret görevi pencereleri, mucit odası, köy kartı seçimi, ozan ve zindan raporu.
- Dünya haritasındaki alt ipucu çubuğu ve saldırı uyarı kutusu büyütüldü.

### EN
- Small text in the village windows is larger: fortune teller, trader, campfire, barracks weapons, concubine and trade mission windows, inventor workshop, village card draft, bard and dungeon report.
- The bottom hint bar and the attack warning box on the world map are larger.

## 0.27.4 - 2026-10-12

### TR
- İnşa ekranında her bina için ne işe yaradığı, ne ürettiği, ne istediği ve önce hangi binanın gerektiği yazıyor. Sıradaki önerilen bina yıldızlı, kurulu olanlar işaretli.
- İnşa ekranındaki yazılar ve düğmeler büyütüldü, panel genişletildi. Yetmeyen kaynaklar kırmızı neden olarak gösteriliyor.

### EN
- The build screen now tells what each building is for, what it produces, what it needs and which buildings come first. The recommended next building is starred and built ones are marked.
- Text and buttons on the build screen are larger and the panel is wider. Missing resources are shown as a red reason.

## 0.27.3 - 2026-10-12

### TR
- Rehber (mentor) penceresindeki yazılar belirgin şekilde büyütüldü ve kartlardaki boşluklar azaldı: zaman başlığın yanına geçti, pencere içeriğe göre kısalıyor.
- Haber satırlarına yeni bilgiler eklendi: tüccar gelişi, yeni köylü, yiyecek yetmemesi, moral düşüşü ve toparlanması.
- Tüccar geldi haberindeki bozuk "%s köyünüze geldi" yazısı düzeltildi.
- Üst haber satırlarında artık yalnız köyde olup bitenler var, dünya haberleri çıkarıldı (baskın uyarısı hariç). Yeni: köylüler yemek bulamadı, oduncular ve taşçılar eli boş döndü, cariyeler aç kaldı.
- Haber satırlarına daha fazla köy olayı eklendi: köylüler hastalandı ve iyileşti, misafir köylü barınak bulamayıp ayrıldı, depo doldu, cariye göreve çıktı, seviye atladı, yaralandı, yeni cariye katıldı, binalar hasar gördü, bina yükseltmeleri tamamlandı, savaşta düşen köylüler ve askerler adlarıyla, silahı sayesinde sağ kalanlar.

### EN
- Text in the Guide (mentor) window is much larger and cards waste less space: the time sits next to the title and the window shortens to fit its content.
- New items in the news lines: trader arrivals, new villagers, food shortages, morale dropping and recovering.
- Fixed the broken "%s has arrived" text in the trader arrival news.
- The top news lines now show only what happens in the village, world news is gone (except raid warnings). New: villagers could not find food, woodcutters and stone gatherers came back empty handed, concubines went without.
- More village happenings in the news lines: villagers fell sick and recovered, a guest villager left for lack of shelter, storage filled up, a concubine set out on a mission, leveled up, got injured, a new concubine joined, buildings were damaged, building upgrades finished, villagers and soldiers who fell in battle by name, and those who survived thanks to their weapons.

## 0.27.2 - 2026-10-12

### TR
- Haber satırları daha uzun kalıyor (8 saniyeden başlar, satır çoğaldıkça uzar). Satırlarda yalnız başlık var: çarpan ve ayrıntı yazıları kalktı, sadece tehlikeli haberlerde kısa açıklama kalıyor.
- Haber satırları artık ekranın üst ortasında. Oyunda çıkan her haber (köy, dünya, görev, olay) son dakika gibi anında satır olarak düşüyor.
- Köye dönünce kaçırdığın her şey bir anda alt alta diziliyor, önemliler en üstte. Satır sayısı arttıkça okuma süresi uzuyor.
- Haberdeki sayılar renkli: artılar yeşil, eksiler kırmızı, diğerleri sarı.

### EN
- The news lines now sit at the top center of the screen. Every piece of news in the game (village, world, missions, events) drops in as a line the moment it happens.
- When you return to the village, everything you missed stacks up at once with the important items on top. The more lines, the longer you get to read.
- Numbers in the news are colored: gains green, losses red, the rest yellow.

## 0.27.1 - 2026-10-12

### TR
- Köye girince ne olduğunu artık ekranın sol üstünden akan kısa renkli satırlar anlatıyor: baskın sonucu (kayıplar dahil), biten görevler, yokluğunda üretilenler, tamamlanan inşaatlar, başlayan ve biten olaylar.
- Satırlar birkaç saniye kalıp kayboluyor, önemli olanlar (kırmızı ve sarı) önce geliyor. Köyün ortasındaki eski özet kutusu kaldırıldı.

### EN
- Coming back to the village, short color coded lines now flow down from the top left to tell you what happened: raid results (with losses), finished missions, what was produced while you were away, completed buildings, and events that began or ended.
- Lines stay a few seconds and fade, important ones (red and yellow) come first. The old summary box in the middle of the screen is gone.

## 0.27.0 - 2026-10-12

### TR
- Yeni köy olayları: Haydut Pususu ve Kuş Sürüsü. Köylülerin bir kaynağı topladığı alan tutulur ve o kaynağın seferleri eli boş döner.
- Üç çözüm var: görev merkezinden cariye ve asker göndermek, haritada işaretlenen alana kendin gidip haydutları temizlemek ya da kuşları kovalamacaya çekmek, ya da olayın bitmesini beklemek.
- Haritadaki engel etkinliği tek kullanımlık değil: kaybedersen yerinde kalır, kazanırsan toplama yeniden başlar ve biraz altın alırsın.

### EN
- New village events: Bandit Ambush and Bird Flock. The area where villagers gather a resource is held and trips for that resource come back empty handed.
- Three ways to solve it: send a concubine and soldiers from the mission center, go to the marked area on the map and clear the bandits or lead the birds on a chase yourself, or wait the event out.
- The blockade on the map is not single use: if you lose it stays, if you win gathering resumes and you earn some gold.

## 0.26.9 - 2026-10-12

### TR
- Haritadaki etkinlik, görev, yol olayı ve onay kutuları yenilendi: büyük yazı, altın başlık, ödül ve bilgi çipleri, net butonlar.
- Etkinlik kutusu sadeleşti: mekân, zorluk ve kalan süre ayrı etiketlerde, uyarı tek satıra indi.

### EN
- Map event, mission, travel event and confirmation boxes were redesigned: larger text, gold title, reward line and info chips, clear buttons.
- The event box is simpler: place, difficulty and time left sit in separate tags and the warning is a single line.

## 0.26.8 - 2026-10-12

### TR
- Düşen odun, taş ve meyve parçaları büyütüldü, artık kolay fark ediliyor.
- Kaynak toplayınca oyuncunun başında kaynağın ikonuyla "+N" çıkıyor. Kısa sürede toplananlar tek bir sayıda birikiyor.
- Hasar alınca düşen kaynakları ve altını geri toplarken de aynı yazı görünüyor.

### EN
- Dropped wood, stone and berry pieces are larger and easier to spot.
- Collecting a resource shows the resource icon and a "+N" above the player. Pickups made in quick succession add up into one number.
- The same popup shows when you pick your resources and gold back up after taking damage.

## 0.26.7 - 2026-10-12

### TR
- Her ağaç, çalı ve kaya iki parça verip bitiyor: ağaç devriliyor ve rengi soluyor, çalı meyvesiz görünüme geçiyor, kaya kırılıyor.
- Çalılar artık ağaçların odununu bitirmiyor, her kaynak kendi payını veriyor.
- Düşen parçalar minigame'lerdeki gerçek parça çizimlerini kullanıyor, meyveler artık dev gibi görünmüyor.

### EN
- Each tree, bush and rock gives two pieces and then finishes: trees fall over and fade, bushes switch to their berry-less look, rocks break.
- Bushes no longer use up the wood of trees, every resource gives its own share.
- Dropped pieces use the real piece art from the minigames, berries no longer look gigantic.

## 0.26.6 - 2026-10-12

### TR
- Ağaç, meyve çalısı ve taşlar artık minigame yerine vurarak sökülüyor. Hafif, ağır ve düşme saldırısı hepsi işe yarıyor.
- Her 3 ila 4 vuruşta yere bir parça düşüyor ve toplayana kadar kaybolmuyor.

### EN
- Trees, berry bushes and rocks are now harvested by hitting them instead of a minigame. Light, heavy and fall attacks all work.
- Every 3 to 4 hits a piece drops to the ground and stays there until you pick it up.

## 0.26.5 - 2026-10-12

### TR
- Orman, dağ ve akarsu bölgeleri artık sonsuz değil: girişten sağa doğru sınırlı bir yol var ve sonunda ikinci bir çıkış portalı bulunuyor.
- Bölgenin iki ucunda harita kenarı koyulaşarak bitiyor, kamera kenarı göstermiyor ve kenardaki duvarlara tutunulamıyor.
- Her bölgenin hammaddesi sınırlı. Biten stok yaklaşık 3 oyun günü içinde yavaş yavaş yeniden doluyor. Dünya haritasında bölgenin üstüne gelince stok durumu görünüyor.

### EN
- Forest, mountain and river regions are no longer endless: there is a limited path from the entrance to the right, with a second exit portal at the end.
- The edge of the map fades to dark at both ends, the camera never shows the border and the boundary walls cannot be climbed.
- Each region has a limited amount of resources. Depleted stock slowly refills over about 3 game days. Hover a region on the world map to see its stock.
