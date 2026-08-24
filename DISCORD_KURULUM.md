# Rogue Harem — Discord Sunucusu Kurulum Rehberi

İki aşamalı plan:
- **Aşama 1 (şimdi):** Arkadaşlarla kapalı playtest, geri bildirim toplama
- **Aşama 2 (Steam sayfası + IG/TikTok sonrası):** Halka açık topluluk

Sunucuyu şimdi Aşama 2'yi düşünerek kur, sonra yeniden yapılandırmakla uğraşma.

---

## AŞAMA 1 — Kapalı Playtest Kurulumu

### 1. Sunucuyu oluştur
- Discord → sol alttaki **+** → "Kendim Oluştur"
- Ad: **Rogue Harem**
- İkon: oyunun logosu, 512x512 PNG

### 2. Topluluk modunu şimdiden aç
Sunucu Ayarları → **Topluluk'u Etkinleştir**

Kurallar ekranı, duyuru kanalları, AutoMod ve Onboarding'i açar. Aşama 2'de zaten lazım olacak, şimdiden açıp alışman daha kolay.

### 3. Roller (Ayarlar → Roller)

| Rol | Renk | Kim | İzin notu |
|---|---|---|---|
| **Geliştirici** | Belirgin (altın/kırmızı) | Sen ve ekip | Yönetici |
| **Playtester** | İkincil renk | Arkadaşlar | Özel test kanallarını görür |
| **Moderatör** | — | Aşama 2'de lazım olacak | Mesaj/üye yönetimi |

`@everyone` rolünden kapat: **Herkesten Bahset**, **Mesajları Yönet**, **Kanalları Yönet**, **Davet Oluştur** (Aşama 1'de davet kontrolü sende kalsın).

### 4. Kanallar

Aşama 1'de az kanal aç. Boş kanal ölü sunucu hissi verir.

```
📢 BİLGİ
  #duyurular          → Duyuru kanalı yap, sadece Geliştirici yazsın
  #kurallar           → Kurallar ekranına da aynısını koy
  #sürüm-notları      → Her build'de ne değişti

🎮 PLAYTEST  (kategori: sadece Playtester + Geliştirici görsün)
  #build-indirme      → Sürüm linkleri
  #hata-bildirimi     → Şablonu pinle
  #geri-bildirim      → Genel izlenim, denge, "şurası sıkıcı"
  #ekran-görüntüleri

💬 SOHBET
  #genel
  🔊 Sesli Sohbet
```

**#hata-bildirimi** kanalında Forum kanalı tipini kullan (normal metin kanalı yerine). Her rapor ayrı başlık olur, çözüleni kapatırsın, aynı hata iki kez bildirilmez. Playtest için farkı büyük.

### 5. Kritik: geri bildirim şablonu
Aşağıdaki şablonu #hata-bildirimi kanalına **pinle**. Şablonsuz rapor gelirse işe yaramaz ("oyun bozuldu" diye mesaj atarlar).

### 6. Davet
Kanala sağ tık → Davet Et → **"Süresi asla dolmasın"** + kullanım sınırı yok.
Aşama 1'de bu linki sadece arkadaşlara özelden gönder, hiçbir yere koyma.

---

## AŞAMA 2 — Halka Açılma (Steam + IG/TikTok)

### Yapılacaklar
1. **PLAYTEST kategorisini gizli tut.** Playtester rolü artık ödül gibi çalışır — "aktif üyelere veriyoruz" dersen topluluk canlanır.
2. **Yeni kanallar aç:** `#öneriler`, `#fan-art`, `#oyun-yardım`, gerekirse `#general-en`
3. **Onboarding'i kur** (Ayarlar → Onboarding): giren kişiye "Türkçe/English?" ve "Bildirim almak ister misin?" diye sorup otomatik rol versin
4. **Güvenlik ayarları:**
   - Doğrulama seviyesi: **Orta** (hesap en az 5 dakikalık olmalı)
   - **AutoMod'u aç:** spam link, mention spam, kaba dil filtreleri hazır geliyor
   - Kendi hesabında **2FA** aç (yönetici olarak zaten zorunlu olacak)
   - Yeni sunucular scam DM botu çeker, bu ayarlar önemli
5. **Steam sayfasına Discord linkini koy** (Steam sayfa yönetiminde ayrı bir alan var)
6. **Oyunun ana menüsüne Discord butonu ekle** — en kaliteli üye buradan gelir

### Hangi platform kaç kişi getirdi, nasıl ölçersin
Discord'un hazır analitiği 500 üyeden önce gelmiyor. Bunun yerine:
**Her platform için ayrı davet linki oluştur** (TikTok bio, IG bio, Steam sayfası, oyun içi buton).
Ayarlar → **Davetler** ekranında her linkin kaç kez kullanıldığını görürsün. Bedava ve yeterli.

### IG/TikTok içerik notu
- Bio'ya direkt `discord.gg/...` linki koy, tek adım olsun
- Videonun sonunda "Discord'da erken erişim veriyoruz" gibi somut bir sebep ver — "bize katıl" tek başına çalışmıyor
- İlk 50 kişi gelene kadar sunucuda **her mesaja cevap ver.** Boş sunucudan gelen kişi 5 dakikada çıkar

---

## Dikkat: İçerik politikaları

Oyunun teması/adı nedeniyle şunları önceden kontrol et — sonradan sunucu kapanması ya da hesap kısıtlanması can sıkar:

- **Discord:** Yetişkin içerik (ekran görüntüsü, sanat) paylaşılacaksa o kanalları **Yaş Kısıtlamalı (18+)** işaretle. Sunucu genelinde yetişkin içerik varsa Discord'un Topluluk/Keşfet özelliklerinde kısıt olabilir. Discord'un güncel "Age-Restricted Content" politikasını kurulumdan önce bir oku, kurallar zaman zaman değişiyor.
- **TikTok/Instagram:** Müstehcen sayılan içerik algoritmada baskılanır, bazen hesap kısıtlanır. Oyunun adı bile erişimi sınırlayabilir. Bu platformlarda **oynanış, pixel art, dövüş sistemi, zindan tasarımı** üzerinden tanıtım yapmak hem daha güvenli hem de daha çok kişiye ulaşır — insanları oradan Discord'a çekip asıl içeriği orada gösterirsin.
- **Steam:** Yetişkin içerik varsa mağaza sayfasında bunu beyan etmen gerekiyor, sonradan eklemek sorun çıkarıyor.

---

# KOPYALA-YAPIŞTIR METİNLER

## #kurallar

```
📜 ROGUE HAREM — SUNUCU KURALLARI

1️⃣ Saygılı ol
Hakaret, taciz, ayrımcılık, nefret söylemi yasak. Tartış, ama kişiselleştirme.

2️⃣ Spam yok
Reklam, davet linki, tekrarlayan mesaj ve zincir DM'ler yasak.
Kendi projeni paylaşmak istiyorsan önce bize sor.

3️⃣ Doğru kanalı kullan
Hata bildirimi #hata-bildirimi kanalına, fikirler #geri-bildirim kanalına.

4️⃣ Spoiler ver
Oyunun hikâyesi/sonuyla ilgili şeyleri spoiler etiketiyle paylaş: ||böyle||

5️⃣ Sızıntı yok
Test sürümleri, build linkleri ve buradaki materyaller sunucu dışına çıkmaz.
Paylaşmak istersen önce sor.

6️⃣ Discord Kullanım Şartları geçerli
13 yaş altı kullanıcı bulunamaz. Yasa dışı içerik anında ban.

⚖️ Kuralları çiğneyen uyarı alır, tekrarında susturulur veya banlanır.
Karar geliştirici ekibindedir.

❓ Sorun mu var? @Geliştirici etiketle veya DM at.
```

## #duyurular — açılış mesajı (Aşama 1)

```
🎮 **Rogue Harem Discord'una hoş geldiniz!**

Burası oyunun geliştirme süreci ve test topluluğu için açıldı.
Şu an kapalı playtest aşamasındayız — buradasınız çünkü oyunu ilk deneyen
ve şekillendiren kişiler sizsiniz.

**Ne yapmanızı istiyoruz:**
🐞 Karşılaştığınız her hatayı #hata-bildirimi kanalına yazın
💭 "Şurası sıkıcıydı", "burayı anlamadım" gibi dürüst yorumları #geri-bildirim kanalına
📸 Güzel bir an yakalarsanız #ekran-görüntüleri kanalına atın

**Önemli:** Övmenize gerek yok. En işe yarar geri bildirim, sizi
sinirlendiren veya kafanızı karıştıran şey. Onu duymak istiyoruz.

Build linkleri #build-indirme kanalında, her güncellemede haber vereceğiz.

İyi oyunlar 🗡️
```

## #hata-bildirimi — pinlenecek şablon

```
🐞 **HATA BİLDİRİM ŞABLONU**

Lütfen her hata için ayrı bir başlık açın ve şu formatı kullanın.
Kopyalayıp doldurmanız yeterli:

**Sürüm:** (ör. v0.3.1 — sürüm no ana menüde yazıyor)
**Ne oldu:** (tek cümle: "Zindan 2'de boss öldükten sonra kapı açılmadı")
**Nasıl tekrarlanır:**
1.
2.
3.
**Beklediğim:** (ne olmalıydı)
**Olan:** (ne oldu)
**Görsel:** (ekran görüntüsü veya video — en değerli kısım burası)
**Sistem:** (Windows sürümü / klavye mi kontrolcü mü)

---
💡 **İpuçları**
• Hata tekrar ediyor mu, yoksa bir kez mi oldu? Yaz.
• Video en iyisi. Windows'ta **Win + Alt + R** ile kayıt alabilirsiniz.
• Aynı hata zaten bildirilmişse yeni başlık açmak yerine altına yorum yapın.
• Emin değilseniz yine de bildirin — fazlası eksiğinden iyidir.
```

## #build-indirme — her sürümde atacağın mesaj şablonu

```
📦 **Rogue Harem — v0.0.0**
🗓️ (tarih)

⬇️ **İndir:** (link)
📄 **Kurulum:** Zip'i çıkart, `otto-man.exe` çalıştır.

🆕 **Bu sürümde yeni:**
•
•

🔧 **Düzeltilenler:**
•

⚠️ **Bilinen sorunlar:** (bunları bildirmenize gerek yok)
•

🎯 **Özellikle şuna bakın:** (o sürümde test edilmesini istediğin şey)

Hatalar → #hata-bildirimi | Yorumlar → #geri-bildirim
```
