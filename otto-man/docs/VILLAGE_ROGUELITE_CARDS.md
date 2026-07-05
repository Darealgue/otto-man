# Köy Roguelite Kart Sistemi — Onaylı Kart Listesi

> Bu dosya, köy ekonomisi roguelite meta-ilerleme sistemi için tasarım sohbetinde
> **onaylanmış** kartları ve draft sistemi kurallarını içerir. Kart havuzu ve
> draft mekanikleri tasarım açısından tamamlandı — bu, uygulamanın (implementasyon)
> dayanacağı SSOT (tek doğru kaynak) listesidir.

## Sistem özeti

- **Nüfus 5:** Mentor önce yol seçimini sunar: **Eşkıya / Paşa / Köylü**.
  Seçim yapılır yapılmaz **aynı anda 1. draft** gerçekleşir — seçilen yoldan
  **3 kart** sunulur. Yol seçimi ile ilk kart draftı aynı adımdır, ayrı değildir.
- **Nüfus 10, 15** (2., 3. draft): Mentor **3 kart** sunar, **hepsi seçilen
  yoldan** (wildcard yok).
- **Nüfus 20'den itibaren** (4. draft ve sonrası): Mentor **3 kendi yol + 1
  wildcard** olmak üzere **4 kart** sunar (wildcard diğer iki yoldan rastgele
  gelir). Bu düzen sonsuza kadar her 5 nüfusta bir tekrarlanır.
- **Görülüp seçilmeyen kartlar o run'da bir daha hiç çıkmaz** — havuzdan kalıcı
  olarak düşer (her draft kararı gerçek bir fırsat maliyeti taşır).
- Kartlar büyük oranda **ikilem (dilemma)** formatında: iki zıt kart aynı anda
  sunulup biri seçilir, ya da kart hem güçlü bir bonus hem gerçek bir bedel taşır.
- **İkilem çiftleri asla tek tek gösterilmez.** Bir draft'ta ikilem çıkarsa, o
  draft'ın **tamamı** ikilemin 2 tarafından ibarettir — sadece 2 seçenek
  görünür, o draft'ın diğer kart yuvaları (3. kart, wildcard dahil 4. kart)
  o turda hiç kullanılmaz. Oyuncu doğrudan "A mı B mi" seçimini yapar.
- Mucit Odası bu sistemden **tamamen ayrı**: artık köy ekonomisi/kaynak
  binası verimiyle **hiç ilgilenmez** (bu alan tümüyle kart sistemine devredildi).
  Mucit Odası'nın tek görevi **oyuncu karakterinin** (saldırı gücü, can) kalıcı
  yükseltmeleridir — village-economy meta-progression değil, character build.

---

## EŞKIYA

| Kart | Mekanik |
|------|---------|
| **Maskeli Soyguncular** | Yağma sonrası %50 ihtimalle ilişki düşmez |
| **Gölge Ağı** | Ajan cariyenin işaretlediği hedefte garanti yüksek yağma başarısı (odaklanma cezası: sadece işaretli hedefe) |
| **Baraka Düzeni** | Ev 4 kişi barındırır (2 yerine) |
| **Savaşçı Ruhu** | Kayıp savaş/yağma moral düşürmez; ama 3 gün üst üste saldırı/yağma yapılmazsa moral düşer |
| **Deli Cesaret** | Düşmandan sayıca azsan savaş gücü 2×; eşit/fazlaysan bonus yok |
| **Kesik Kulak** | Kazanılan savaşta düşman askerinden bir kısmı kendi ordun olur; bu askerler moral cezasına daha duyarlı (büyük yenilgide ilk kaçanlar) |
| **Kan Borcu** | Yağma ganimeti 2×; yağmalanan köy rastgele bir gün misilleme baskını gönderebilir |
| **Talan İzni** | Askerler yağmadan otomatik kişisel pay alır → kalıcı moral bonusu, ama köy deposuna giren ganimet azalır |
| **Zafer Rüzgarı** *(eski adı: Panik Yayıcı)* | Başarılı bir yağma sonrası **belirli bir süre** ordunun saldırı gücüne buff (kendi ordunu güçlendirir, düşmanı zayıflatmaz) |
| **Kanun Kaçağı Cenneti** | Diğer köylerden kaçak/mahkûm köylüler sığınır (bedava nüfus); ama her yeni gelen köyün genel moralini düşürür |
| **Kölelik Düzeni** | Savaşta esir alınan düşmanlar ücretsiz işçi olur; moral çok düşükse kaçarlar ve giderken kaynak çalarlar |
| **Silah Kaçakçılığı** | Savaş kazanınca otomatik silah ganimeti gelir; silah üretim binasına ihtiyaç azalır |
| **Kurt Kardeşliği** | Yaralanan askerler ölmez, "emekli" olup köyde üretici işçiye döner — asker kaybı hiç tam kayıp olmaz |
| **Şafak Vakti Kaçışı** | Kaybedilen savaşta ölüm oranı çok düşer (çoğu kaçıp kurtulur), ama moral büyük düşer (utanç) |
| **Ateş ve Kül** | Yağmada hedefi yakma seçeneği: ganimet azalır ama o köy uzun süre çok zayıf kalır (rakip fena hâlde geriler) |
| **Gece Baskını** | Yağmalar sadece gece yapılabilir, başarı şansı çok yüksek; ama kendi köyünün gece savunması da aynı oranda zayıflar |
| **Çapulcu Şöhreti** | Şöhret arttıkça gönüllü eşkıyalar orduna katılır; ama şöhret düşman ittifaklarını da tetikler |
| **Gölgede Saklanma** | Yağmada misilleme riski düşer (temkinli baskın); ama ganimet biraz azalır |

### İkilem — Tek Vuruş / Uzun Kuşatma
| | Tek Vuruş | Uzun Kuşatma |
|---|---|---|
| Süre | Aynı gün biter | Günler sürer, asker o süre meşgul |
| Hedef | Sadece küçük hedefler | Büyük hedeflere de yapılabilir |
| Ganimet | Küçük | Çok büyük |

### İkilem — Midas'ın Eli / Karaborsa
| | Midas'ın Eli | Karaborsa |
|---|---|---|
| Yağma sonucu | Direkt altın | Ham/lüks eşya (zanaata girdi olarak kullanılabilir) |
| Satış | — | Satarsan daha az altın (aracısız pazar cezası) |
| Build yönü | Hızlı likit ekonomi | Yavaş ama zanaat zincirini besler |

### İkilem — Sadık Çete / Paralı Kılıçlar
| | Sadık Çete | Paralı Kılıçlar |
|---|---|---|
| Asker kaynağı | Sadece kendi köylülerin | Altınla anında asker satın alınır (barınak/nüfus şartı yok) |
| Moral | Kayıplarda ceza yok | Kayıplarda ceza yok, ama haftalık maaş ödenmezse asker sayısı azalır |
| Build yönü | Yavaş büyüyen öz ordu | Hızlı ama altına bağımlı ordu |

---

## PAŞA

| Kart | Mekanik |
|------|---------|
| **Altın Kalkanı** | Saldırı geldiğinde rüşvet vererek baskını iptal etme seçeneği (maliyet: raid gücüne göre altın) |
| **Pazar Yeri** | Oyuncu kendi pazarını kurar; tüccar ziyaretini beklemeden alım-satım yapılabilir |
| **Harem Siyaseti** | Cariye sayısı arttıkça köy morali ve görev başarı şansı kalıcı artar |
| **Elçilik** | Diplomat cariye görevleri hiç başarısız olmaz; maliyeti 2× lüks kaynak |
| **Altınla Geçiş** | Haftada 1 cariye görev maliyeti, kaynak yerine altınla ödenebilir |
| **Şaşaa Gösterisi** | Saldırı sıklığı azalır; ama gerçek saldırı gelirse hazırlıksız yakalanma cezası |
| **Vergi Muafiyeti** | Seçilen 1 bina bedava kurulur |
| **Sadakat Yemini** | İşçi/asker verimi morale bağımsız sabit yüksek kalır (altınla moral sistemini bypass) |
| **Rehin Diplomasi** | Bir cariyeni komşuya gönder → o yönle sonsuza dek barış; cariye geri gelmez (kalıcı kayıp) |
| **Sahte Skandal** | Rakip köyün ittifakını zayıflat; başarısız olursa kendi ilişkin daha çok düşer |
| **Nüfuz Ağı** | Her ittifak köy sana otomatik istihbarat sağlar (yaklaşan saldırılar önceden görünür) |
| **Hazine Odası** | Altın stoku saldırıda hiç yağmalanamaz; diğer kaynaklar daha savunmasız hâle gelir |
| **Tören Alayı** | Düzenli gösteri: moral yükselir, göçmen akışı hızlanır; her tören altın harcar |
| **Rüşvet Ağı** | Rüşvet maliyeti kalıcı düşer; ama her rüşvette küçük ihtimalle "yolsuzluk skandalı" (moral cezası) |
| **Tefeci Defteri** | Altın borç verdiğin köyler "defterine" yazılır; toplam alacak belli eşiği geçince tek seferlik dev geri ödeme tetiklenir |
| **Loncalar Vergisi** | Zanaat/lüks binalarının ürettiği her birim için küçük otomatik altın (üretim vergisi) — pasif gelir |
| **Sahte Zenginlik** | Köyün gerçek altın stoku haritada olduğundan az görünür; rakip seni zayıf sanıp daha küçük saldırı gönderir |
| **Suikast Parası** | Pahalı, tek seferlik: bir düşman komutanına suikast — başarılıysa o köyün sıradaki saldırısı çok zayıflar, başarısızsa savaş ilanı |
| **Cömert Efendi** | Köylülere/askerlere düzenli hediye dağıt — moral kalıcı yüksek kalır, ama altın sürekli dışarı akar |
| **Vergi Reformu** | Tüm bina yükseltme maliyetleri sadece altına çevrilir (kaynak istemez), ama altın ihtiyacı katlanır |
| **Debbağ Vergisi** | Köye gelen her tüccardan geçiş vergisi alınır — sadece ticaret ağın zaten aktifse anlamlı pasif gelir |
| **Casus Yuvası** | Ajan cariye görevleri daha ucuz ve daha hızlı biter (kendi "casus okulun") |
| **Yabancı Misafir** | Düzenli aralıklarla gelen yabancı zanaatkâr, geçici olarak bir binanın üretimini 2 katına çıkarır, sonra gider |
| **Sırça Köşk** | Gösterişli, üretim vermeyen bina — kalıcı moral/itibar bonusu, ama inşa maliyeti çok yüksek |

### İkilem — Saray Fermanı / Kendi Ordun
| | Saray Fermanı | Kendi Ordun |
|---|---|---|
| Savunma | Otomatik, haftalık vergiyle | Yok — kendi kışlanı kurarsın |
| Bağımlılık | Altın akışına tam bağımlı | Bağımsız, ama ekonomi payı asker giderine gider |
| Risk | Vergi ödenmezse saray'ın kendisi ağır ceza baskını düzenler | Klasik savaş riski |

---

## KÖYLÜ

| Kart | Mekanik |
|------|---------|
| **Kış Ambarı** | Depo kapasitesi +%50 *(nihai hâl — "hiç kayıp yok" versiyonu çok güçlü bulunup nerf edildi)* |
| **Geniş Tarla** | +1 avcı kulübesi slotu veya mevcut kulübeye +2 max işçi |
| **Nadas Bilgisi** | Toplama binaları altınsız, haftada otomatik +1 kapasite kazanır (yavaş, bedava büyüme) |
| **Ortak Ekin** | Bir kaynak biterse diğerinden küçük oranda otomatik "takas" (kıtlık tamponu) |
| **Göçmen Kapısı** | Düzenli aralıklarla yeni köylü gelir; her gelen ilk gün "aç" gelir (küçük yemek şoku) |
| **Bereket Duası** | Her gün küçük şansla bedava 1 ekstra rastgele ham kaynak |
| **Saray Emrinde** | Cariyeler üretim binasına atanabilir; atanan bina +1 üretim kazanır, ama o cariye o süre görev alamaz |
| **Şölen Geleneği** | Haftada 1 şölen günü: üretim durur, tüm köy morali maksimuma çıkar ve birkaç gün yüksek kalır |
| **Herkes İçin Bir Şey** | Moral belli eşiğin üstündeyken tüm üretim binaları +1 verim |
| **Taş Siper** | 1 duvar segmenti + savunmada hafif bonus |
| **Ortak Kader** | Nüfus arttıkça tüm üretim otomatik hafif artar; kıtlık/şortaj cezası tek bina değil tüm köye yayılır |
| **Sıkı Disiplin** | Üretim sabit bonus alır; moral tavanı düşer (asla çok yüksek coşku, ama asla çok dip de yok) |
| **Sağlam Temeller** | Yeni bina inşa/yükseltme maliyeti %50 ucuzlar; inşa süresi %100 uzar |
| **Ortaklaşa İnşaat** | Bina inşası sırasında tüm boşta köylüler yardıma koşar, inşa süresi çok kısalır (boşta işçinin zaten üretime katkısı olmadığı için pratikte neredeyse bedelsiz bir bonus) |
| **Nesil Bilgisi** | Bir bina 10+ gün kesintisiz çalışırsa "gelenek" oluşur, üretimi kalıcı artar — ama işçi değişince bu bonus sıfırlanır |
| **Emeğin Karşılığı** | Köylülere düzenli pay/ücret verilir: moral kalıcı yüksek kalır, ama sürekli küçük altın gideri oluşur |

### İkilem — Kutsal Toprak / Açık Pazar
| | Kutsal Toprak | Açık Pazar |
|---|---|---|
| Kısıt | Seçilen 1 ham kaynağı asla satamaz/dışarıdan alamazsın | Kısıt yok |
| Bonus | O kaynağın üretimi kalıcı yüksek | — |
| Not | Tüccar/eşkıya kartlarıyla çelişebilir (o kaynağı satamazsın) | Nötr, esnek |

---

## Karara bağlanan tasarım kuralları

- ✅ Draft ritmi: nüfus 5 = yol seçimi + **aynı anda 1. draft** (3 kart);
  nüfus 10/15 = 2./3. draft, tamamı kendi yoldan; nüfus 20+ = 3 kendi yol + 1
  wildcard, sonsuza kadar tekrarlanır.
- ✅ Görülüp seçilmeyen kart o run'da havuzdan kalıcı olarak düşer, bir daha
  çıkmaz.
- ✅ Nüfus 5'te ayrı bir "tanıtım kartı" yok — yol seçimiyle birlikte gelen
  ilk draft tanıtımı zaten sağlıyor.
- ✅ İkilem çiftleri draft'ta tek başına çıkar (2 seçenek, biri seçilir);
  tekli kartlarla aynı draft'ta karıştırılmaz.
- ✅ Mucit Odası vs. draft kartı ayrımı: **köy ekonomisi/kaynak verimi artık
  tamamen kart sistemine ait** — Mucit Odası bu alana hiç dokunmaz. Mucit
  Odası'nın kapsamı sadece **oyuncu karakterinin saldırı/can** gibi kalıcı
  yükseltmeleridir (village economy'den bağımsız character build sistemi).
- ✅ Her kart run başına **tek seferlik**: bir kez alınan kart havuzdan düşer,
  aynı kart run içinde tekrar çıkıp stack olamaz.
- ✅ Kart gücü/karmaşıklığı nüfus eşiğine göre **kademelenmez** — havuz her
  eşikte (kendi yol kısıtı dışında) tamamen rastgele karışık kalır; basit ve
  karmaşık kartlar en baştan itibaren birbirine karışabilir.

- ✅ Wildcard havuzu ayrımı: yol-tanımlayıcı **ikilem çiftleri** (Saray
  Fermanı/Kendi Ordun, Kutsal Toprak/Açık Pazar, Sadık Çete/Paralı Kılıçlar,
  Tek Vuruş/Uzun Kuşatma, Midas'ın Eli/Karaborsa) **sadece kendi yolunda**
  çıkar, wildcard havuzuna hiç girmez. Tekli kartların tamamı wildcard'a açık.

## Açık tasarım soruları

Şu an için hepsi karara bağlandı — sistem tasarımı draft/wildcard/tekrar
kuralları açısından uygulamaya hazır. Uygulama (implementasyon) sırasında
çıkabilecek yeni edge-case'ler burada eklenecek.
