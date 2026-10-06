// A splash ring on the ground (Atmosphere weather "rain"): a flat quad, the ring growing over the particle's life and
// thinning as it goes. Opaque and hard-edged.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 colour : source_color = vec3(0.56, 0.7, 0.81);

varying float age;

void vertex() {
	age = INSTANCE_CUSTOM.y;
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float radius = 0.25 + age * 0.7;
	float width = 0.12 * (1.0 - age) + 0.02;
	if (abs(r - radius) > width || age > 0.95) {
		discard;
	}
	ALBEDO = colour;
}
