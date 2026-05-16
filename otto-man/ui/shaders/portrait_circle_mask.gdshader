shader_type canvas_item;
render_mode blend_mix;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	if (dot(centered, centered) > 0.25) {
		col.a = 0.0;
	}
	COLOR = col;
}
