shader_type canvas_item;

// Yüzen köylü (ShowSwimVisual): her yüzücünün KENDİ su çizgisi vardır; bu çizginin (dünya y'si) altındaki pikseller atılır.
// Böylece köylü suda aşağı yukarı gezerken figürün görünen kısmı (baş ve göğüs) hep aynı kalır, boyu uzayıp kısalmaz.
// mirrored=true: aynı figürün su çizgisine göre ters çevrilmiş kopyası (yansıma): çizginin ÜSTÜNDE kalan orijinal pikseller
// çizginin altında görünür, aşağı doğru solar ve hafifçe dalgalanır.

uniform float clip_y = 100000.0;
uniform bool mirrored = false;
uniform float alpha_mul : hint_range(0.0, 1.0) = 1.0;
uniform float wobble = 0.02;           // yansıma yatay dalgalanma şiddeti (UV)
uniform float fade_height = 28.0;      // yansıma bu kadar aşağıda tamamen solar (piksel)
uniform vec3 water_tint = vec3(0.05, 0.2, 0.28);

varying float world_y;
varying vec4 vertex_modulate;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
	vertex_modulate = COLOR;
}

void fragment() {
	if (mirrored) {
		if (world_y < clip_y) {
			discard;
		}
	} else {
		if (world_y > clip_y) {
			discard;
		}
	}
	vec2 uv = UV;
	if (mirrored) {
		uv.x += sin(world_y * 0.7 + TIME * 2.5) * wobble;
	}
	vec4 c = texture(TEXTURE, uv) * vertex_modulate;
	float a = c.a * alpha_mul;
	if (mirrored) {
		a *= clamp(1.0 - (world_y - clip_y) / fade_height, 0.0, 1.0);
		c.rgb = mix(c.rgb, water_tint, 0.35);
	}
	COLOR = vec4(c.rgb, a);
}
