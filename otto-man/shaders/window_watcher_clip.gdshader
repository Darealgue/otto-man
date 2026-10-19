shader_type canvas_item;

// Pencereden bakan köylü (WindowWatcherDirector): köylünün tüm sprite katmanları (parent material ile) pencere kemerinin
// şekline kırpılır. `mask`, pencere dokusundan üretilen kemer maskesidir (kemer içi opak); dünya konumundan maskeye
// bakılarak kemer dışı kalan pikseller atılır. Pencere ayna çevrikse (sağdaki pencere) maske yatayda çevrilir.

uniform sampler2D mask : filter_nearest;
uniform vec2 mask_origin = vec2(0.0);   // maskenin sol üst köşesinin dünya konumu
uniform vec2 mask_size = vec2(85.0, 50.0);
uniform bool mask_flip_h = false;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_pos;
varying vec4 vertex_modulate;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vertex_modulate = COLOR;
}

void fragment() {
	vec2 muv = (world_pos - mask_origin) / mask_size;
	if (mask_flip_h) {
		muv.x = 1.0 - muv.x;
	}
	if (muv.x < 0.0 || muv.x > 1.0 || muv.y < 0.0 || muv.y > 1.0 || texture(mask, muv).a < 0.5) {
		discard;
	}
	vec4 c = texture(TEXTURE, UV) * vertex_modulate;
	COLOR = vec4(c.rgb, c.a * fade);
}
