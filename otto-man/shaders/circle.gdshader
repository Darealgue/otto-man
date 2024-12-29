shader_type canvas_item;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    float circle = smoothstep(0.5, 0.48, dist);  // Smooth edge
    COLOR.a *= circle;  // Apply circle mask to alpha
} 