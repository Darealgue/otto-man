shader_type canvas_item;

uniform sampler2D normal_texture : hint_normal;
uniform bool sprite_flipped;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
	COLOR = texture(TEXTURE, UV);
}

void light() {
	// Normal map lighting
	vec3 normal = texture(normal_texture, UV).rgb;
	normal = normal * 2.0 - 1.0; // Convert from [0,1] to [-1,1]
	
	// Fix Y-axis inversion - normal maps typically have Y pointing down (+Y)
	// but Godot uses Y pointing up (+Y), so we need to flip Y
	normal.y *= -1.0;
	
	// Handle sprite flipping - if sprite is flipped horizontally,
	// we need to flip the normal's X component
	if (sprite_flipped) {
		normal.x *= -1.0;
	}
	
	// Calculate lighting
	float NdotL = dot(normal, LIGHT_DIRECTION);
	float light_intensity = max(0.0, NdotL);
	
	// Apply light color and intensity
	vec3 light_color = LIGHT_COLOR.rgb;
	vec3 final_color = COLOR.rgb * light_color * light_intensity;
	
	// Add ambient lighting
	final_color += COLOR.rgb * 0.3;
	
	LIGHT = vec4(final_color, COLOR.a);
}
