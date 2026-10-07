// The cel lighting of cel.gdshader for pieces drawn many times from one mesh (the land's 3D trees in a MultiMesh,
// world/look/model_piece.gd tree_mesh): each surface keeps its palette colour, and each instance's COLOR darkens it
// (the trees further out). The palette pass snaps the result afterwards.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/cel_light.gdshaderinc"

uniform vec3 albedo : source_color = vec3(0.36, 0.36, 0.41);
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.18;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	ALBEDO = albedo * COLOR.rgb;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndl * ATTENUATION;
	float band = cel_band(lit, mid_tone, shadow_floor);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
