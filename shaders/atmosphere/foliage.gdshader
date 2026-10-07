// The leaves of the Modern look's trees and plants (Flora, docs/art/plants.md): cards cut from the painted atlas
// (art/plants/cards.png) with hard edges, so they stay in the opaque pass with a depth prepass (little overdraw) and
// cast shadows through their gaps. Not alpha to coverage: Godot draws that in the transparent pass, after the copy of
// the screen the screen pass works from, which would leave the leaves out of the outlines, mist and grade.
// Each card's normal is bent out from its crown (blender/plants_3d.py), so a tree takes the light as one soft
// volume; its back side keeps that normal, and light coming through from behind tints it (backlight). Vertex alpha is
// how much light reaches that part of the plant (inside and under the crown is darker); the instance colour darkens
// or warms a whole plant (the land darkens the ones further out). It moves in the wind (wind.gdshaderinc).
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
#include "res://shaders/atmosphere/wind.gdshaderinc"

uniform sampler2D cards : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.45;
// How dark the inside of a crown gets (vertex alpha 0), and how much light shows through a leaf lit from behind.
uniform float shade_floor : hint_range(0.0, 1.0) = 0.4;
uniform float backlight : hint_range(0.0, 1.0) = 0.35;
uniform float roughness : hint_range(0.1, 1.0) = 0.8;
// Snow lying on the upward faces (0 none, 1 the tops all white).
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_colour : source_color = vec3(0.82, 0.85, 0.9);
// Leaves this close to the camera thin away (world units), so a camera tilted down near the trees sees past them.
uniform float near_fade = 5.0;

varying float up;
varying vec3 wpos;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX += wind_offset(root, VERTEX - root, UV2.x, UV2.y, TIME);
	up = NORMAL.y;
	wpos = VERTEX;
}

void fragment() {
	vec4 t = texture(cards, UV);
	// Mipmaps average the gaps into the leaves and thin the alpha out; give it back as the texture gets smaller on
	// screen, so far trees keep their mass.
	vec2 px = UV * vec2(textureSize(cards, 0));
	vec2 dx = dFdx(px);
	vec2 dy = dFdy(px);
	float mip = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	ALPHA = clamp(t.a * (1.0 + mip * 0.22), 0.0, 1.0) * smoothstep(near_fade * 0.55, near_fade, distance(wpos, CAMERA_POSITION_WORLD));
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 c = t.rgb * tint * COLOR.rgb * mix(shade_floor, 1.0, COLOR.a);
	if (snow > 0.0) {
		// In patches on the tops of the sprays that face the sky, more on the open outside of the crown.
		float patchy = smoothstep(0.35, 0.65, fract(sin(dot(floor(px / 48.0), vec2(12.9898, 78.233))) * 43758.5453));
		c = mix(c, snow_colour, smoothstep(0.72, 0.95, up) * snow * patchy * COLOR.a);
	}
	ALBEDO = c;
	// The back of a card keeps the crown's outward normal (Godot flips it for back faces).
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// Never below 0.1: the screen pass reads near-zero roughness as water.
	ROUGHNESS = roughness;
	SPECULAR = 0.25;
	BACKLIGHT = c * backlight;
}
