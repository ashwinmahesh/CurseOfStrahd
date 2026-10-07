// The cel lighting of cel.gdshader for 3D pieces painted with their own 2D art (world/look/model_piece.gd, "spr_"
// materials: statues, stuffed animals and wall fittings sculpted from their sprite). The sprite's alpha cuts the
// outline; `tint` darkens an emptied container. The palette pass snaps the result afterwards.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.5;
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.18;
uniform float mid_tone : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * tint;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float lit = ndl * ATTENUATION;
	float band = lit > 0.5 ? 1.0 : (lit > 0.12 ? mid_tone : (lit > 0.02 ? shadow_floor : 0.0));
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
