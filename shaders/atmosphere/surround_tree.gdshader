// Trees of the land around a map (Atmosphere, docs/art/atmosphere.md): one MultiMesh of upright billboards that
// turn about their trunk to face the camera like the board's own trees, with hard alpha edges so they stay in the
// opaque pass (outlined and palette-snapped). COLOR darkens the ones further out.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.5;

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	mat4 world = mat4(vec4(normalize(cross(up, INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(up, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, up)), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * COLOR.rgb;
}
