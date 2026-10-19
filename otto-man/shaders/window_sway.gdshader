shader_type canvas_item;

// Pencerede asılı kumaş, perde ve halının rüzgârda sallanması. Sprite'ın üst kenarı sabit kalır, alt kısmı yana kayar.
// Kayma tam piksele yuvarlanır (piksel sanatı kıyılmadan, basamaklı sallanır). top_v / bottom_v, çizimin dokudaki
// dikey sınırlarıdır (0..1) ve betik tarafından dokudan hesaplanır.

uniform float top_v = 0.3;
uniform float bottom_v = 0.7;
uniform float amplitude_px = 1.0;
uniform float speed = 1.6;
uniform vec2 tex_size = vec2(85.0, 150.0);

varying vec4 vertex_modulate;
varying float phase;

void vertex() {
	vertex_modulate = COLOR;
	// Her sprite dünyadaki konumuna göre farklı fazda sallanır, hepsi aynı anda oynamaz.
	phase = MODEL_MATRIX[3].x * 0.05 + MODEL_MATRIX[3].y * 0.03;
}

void fragment() {
	float t = clamp((UV.y - top_v) / max(bottom_v - top_v, 0.001), 0.0, 1.0);
	float shift_px = floor(sin(TIME * speed + phase) * amplitude_px * t * t + 0.5);
	vec4 c = texture(TEXTURE, vec2(UV.x - shift_px / tex_size.x, UV.y));
	COLOR = c * vertex_modulate;
}
