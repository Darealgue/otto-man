shader_type canvas_item;
render_mode blend_mix;

// fill_level: 0 = boş (dip), 1 = tam dolu. VillageManager.get_morale() / 100.0 buraya yazılır.
uniform float fill_level : hint_range(0.0, 1.0) = 1.0;
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.018;
uniform float wave_frequency : hint_range(1.0, 40.0) = 14.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.4;
uniform vec4 low_tint : source_color = vec4(0.85, 0.3, 0.26, 1.0);
uniform vec4 high_tint : source_color = vec4(0.4, 0.82, 0.46, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// İki üst üste sinüs dalgası — düz bir kesim çizgisi yerine canlı bir sıvı yüzeyi.
	float wave = sin(UV.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
	wave += sin(UV.x * wave_frequency * 0.5 - TIME * wave_speed * 0.7) * wave_amplitude * 0.5;

	// UV.y: 0 üst, 1 alt. fill_level arttıkça kesim çizgisi yukarı çıkar.
	float cutoff = (1.0 - fill_level) + wave;
	float mask = step(cutoff, UV.y);

	vec3 tint = mix(low_tint.rgb, high_tint.rgb, fill_level);
	vec3 tinted_color = mix(tex.rgb, tint, tint_amount);

	COLOR = vec4(tinted_color, tex.a * mask);
}
