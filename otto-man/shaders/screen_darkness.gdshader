shader_type canvas_item;

// Shader parametreleri
uniform float max_darkness : hint_range(0.0, 1.0) = 0.8;
uniform float light_radius : hint_range(50.0, 500.0) = 200.0;
uniform vec2 player_screen_position;
uniform float ambient_light : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	// Screen koordinatlarını hesapla
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 screen_pos = UV * screen_size;
	
	// Oyuncuya olan mesafeyi hesapla
	float distance_to_player = distance(screen_pos, player_screen_position);
	
	// Karanlık faktörü hesapla (oyuncuya yakın = aydınlık, uzak = karanlık)
	float darkness_factor = smoothstep(0.0, light_radius, distance_to_player);
	darkness_factor = clamp(darkness_factor, 0.0, max_darkness);
	
	// Ambient light ekle (minimum aydınlık)
	float final_darkness = darkness_factor - ambient_light;
	final_darkness = clamp(final_darkness, 0.0, 1.0);
	
	// Karanlık rengi oluştur
	vec4 dark_color = vec4(0.0, 0.0, 0.0, final_darkness);
	
	COLOR = dark_color;
}
