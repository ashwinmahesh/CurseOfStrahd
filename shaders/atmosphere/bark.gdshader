// The trunks and limbs of the Modern look's trees (Flora, docs/art/plants.md): a painted bark of dark furrows between
// lighter ridges running along the wood (the model's UV: u round the trunk, v along it), lit like the leaves above it
// and moving in the same wind (wind.gdshaderinc). Vertex alpha darkens it where the crown shades it; the instance
// colour darkens a whole tree, as the leaves do.
shader_type spatial;
render_mode world_vertex_coords, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/atmosphere/wind.gdshaderinc"

uniform vec3 ridge : source_color = vec3(0.30, 0.27, 0.29);
uniform vec3 furrow : source_color = vec3(0.12, 0.10, 0.12);
// Lichen and moss on the side away from the weather (spruce bark), as a share of the surface.
uniform vec3 lichen : source_color = vec3(0.32, 0.36, 0.30);
uniform float lichen_amount : hint_range(0.0, 1.0) = 0.15;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.5;
// Wood this close to the camera is cut away (world units), with the leaves round it (foliage.gdshader).
uniform float near_fade = 5.0;

varying vec3 world_n;
varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX += wind_offset(root, VERTEX - root, UV2.x, UV2.y, TIME);
	world_n = NORMAL;
	wpos = VERTEX;
}

void fragment() {
	ALPHA = step(near_fade * 0.75, distance(wpos, CAMERA_POSITION_WORLD));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Furrows: stretched noise along the wood, sharpened into ridges.
	vec2 p = vec2(UV.x * 9.0, UV.y * 2.2);
	float n = vnoise(p) * 0.65 + vnoise(p * 2.7 + 3.1) * 0.35;
	float r = smoothstep(0.32, 0.62, n);
	vec3 c = mix(furrow, ridge, r);
	float l = smoothstep(0.55, 0.75, vnoise(vec2(UV.x * 5.0, UV.y * 1.3) + 9.0)) * smoothstep(-0.2, 0.6, world_n.y + world_n.x * 0.4);
	c = mix(c, lichen, l * lichen_amount * 2.0);
	ALBEDO = c * COLOR.rgb * mix(shade_floor, 1.0, COLOR.a);
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
