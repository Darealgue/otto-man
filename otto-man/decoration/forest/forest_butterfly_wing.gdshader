shader_type canvas_item;
render_mode blend_mix;

uniform vec4 wing_tint : source_color = vec4(0.5, 0.7, 1.0, 1.0);

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.a < 0.02) {
		COLOR = col;
		return;
	}
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	// Açık kanat / gövde pikselleri doğrudan renklendir (gri-beyaz çizimler için)
	if (lum >= 0.32) {
		COLOR = vec4(wing_tint.rgb * clamp(lum * 1.15, 0.45, 1.0), col.a);
	} else {
		COLOR = col;
	}
}
