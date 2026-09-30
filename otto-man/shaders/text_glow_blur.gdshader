// Tek eksende gerçek Gaussian blur. İki kere kullanılır (önce yatay, sonra dikey);
// ayrılabilir (separable) Gaussian olduğu için iki tek eksenli geçiş, tek geçişli
// iki boyutlu blur ile birebir aynı sonucu verir ama kat kat ucuzdur.
//
// StudioSplash'teki oyun adının ışıması için yazıldı. Öncesinde hale, yazının
// outline_size'ı gitgide artan kopyaları üst üste bindirilerek yapılıyordu; her kopya
// keskin kenarlı bir halka bıraktığı için ışıma değil izohips haritası gibi görünüyordu.
// Aynı tespit assets/logo/ blur'ları için de yapılmıştı (bkz. CLAUDE.md, "Açılış").
//
// Toplamalı (additive) karışım shader'ın kendisinde: hale siyah zeminde ışık saçmalı,
// blend_mix'e çevirirsen sadece bulanık bir kopya olur.
shader_type canvas_item;
render_mode blend_add, unshaded;

// Örnek sayısı derleme zamanı sabiti — sürücü döngüyü açabilsin ve her platformda
// kesin derlensin diye uniform değil. 24 ≈ 3 sigma, yani Gaussian'ın pratikte
// tamamı kernel'in içinde kalıyor.
const int RADIUS = 24;

// (1,0) = yatay geçiş, (0,1) = dikey geçiş.
uniform vec2 direction = vec2(1.0, 0.0);
// Küçültülmüş kaynak dokunun pikseli cinsinden standart sapma.
uniform float sigma : hint_range(0.5, 16.0) = 8.0;

// Düğümün modulate'i (üst düğümlerinkiyle çarpılmış hâli) vertex aşamasındaki COLOR'da
// geliyor. Fragment'e vardığında COLOR zaten dokuyla çarpılmış oluyor, o yüzden modulate'i
// bozulmadan buradan taşıyoruz. Godot 4.4'ün MODULATE built-in'i 4.3'te henüz yok.
varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

void fragment() {
	vec2 texel = direction * TEXTURE_PIXEL_SIZE;
	// Gaussian RADIUS'ta kesildiği için orada sıfırdan biraz büyük bir değere sahip;
	// siyah zeminde toplamalı çizince bu, halenin çevresinde silik bir kutu kenarı
	// bırakıyor. Kuyruk değerini her ağırlıktan düşmek kernel'i tam kenarda sıfırlıyor.
	float tail = exp(-0.5 * float(RADIUS) * float(RADIUS) / (sigma * sigma));
	vec3 accumulated = vec3(0.0);
	float weight_sum = 0.0;
	for (int i = -RADIUS; i <= RADIUS; i++) {
		float offset = float(i);
		float weight = max(0.0, exp(-0.5 * offset * offset / (sigma * sigma)) - tail);
		accumulated += texture(TEXTURE, UV + texel * offset).rgb * weight;
		weight_sum += weight;
	}
	// TitleLayer'ın belirme animasyonu ve glow_strength modulate'ten geliyor; toplamalı
	// karışım src.alpha ile çarptığı için halenin parlaklığını taşıyan şey alfa.
	COLOR = vec4(accumulated / weight_sum * node_modulate.rgb, node_modulate.a);
}
