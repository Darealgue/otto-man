shader_type canvas_item;

// Shader parametreleri
uniform float max_darkness : hint_range(0.0, 1.0) = 0.8;
uniform float light_radius : hint_range(50.0, 500.0) = 200.0;
uniform vec2 player_position;
uniform float ambient_light : hint_range(0.0, 1.0) = 0.2;
uniform float torch_boost : hint_range(0.0, 1.0) = 0.3;
uniform float wall_shadow : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Screen koordinatlarını hesapla - SCREEN_UV kullan
    vec2 screen_pos = SCREEN_UV * SCREEN_PIXEL_SIZE;
    float distance_to_player = distance(screen_pos, player_position);
    
    // Karanlık faktörü hesapla
    float darkness_factor = smoothstep(0.0, light_radius, distance_to_player);
    darkness_factor = clamp(darkness_factor, 0.0, max_darkness);
    
    // Ambient light ekle
    float final_darkness = darkness_factor - ambient_light;
    final_darkness = clamp(final_darkness, 0.0, 1.0);
    
    // Meşale yakınında ekstra parlaklık
    float torch_distance = distance(screen_pos, player_position);
    float torch_effect = 1.0 - smoothstep(0.0, light_radius * 0.5, torch_distance);
    final_darkness -= torch_effect * torch_boost;
    final_darkness = clamp(final_darkness, 0.0, 1.0);
    
    // Duvarların arkasında gölge efekti
    float wall_shadow_effect = wall_shadow * (1.0 - color.a);
    final_darkness += wall_shadow_effect;
    final_darkness = clamp(final_darkness, 0.0, 1.0);
    
    // Rengi karanlıkla karıştır
    color.rgb = mix(color.rgb, color.rgb * 0.1, final_darkness);
    
    COLOR = color;
}
