// A painted landmark far past the map's edge (Vista, Improvement Ideas W13): Castle Ravenloft on its crag. An
// upright card that turns about its foot to face the camera, painted art fading into the haze the screen pass gives
// the far land (`haze`, matched each frame) by how far off it stands, its foot sinking into the mist, its lit windows
// staying warm. Drawn after the screen pass like the mountains (vista.gdshader); nearer land and trees hide it.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 haze : source_color = vec3(0.4, 0.4, 0.46);
// How far into the haze the whole card is (0 as painted, 1 gone), and the share of its height, from the foot, that
// sinks into it.
uniform float hazing : hint_range(0.0, 1.0) = 0.45;
uniform float foot : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	to_cam.y = 0.0;
	vec3 back = normalize(to_cam + vec3(1e-4, 0.0, 0.0));
	vec3 right = normalize(cross(up, back));
	mat4 world = mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec4 t = texture(art, UV);
	if (t.a < 0.02) {
		discard;
	}
	float up_share = 1.0 - UV.y;
	float h = hazing + (1.0 - hazing) * (1.0 - smoothstep(0.0, foot, up_share)) * 0.7;
	// Nearer than the mountains, so darker against the haze: a silhouette with its rock still showing.
	vec3 c = mix(t.rgb * 0.3, haze, h);
	// Lit windows: warm, bright pixels keep their glow through the haze.
	float warm = smoothstep(0.15, 0.45, t.r - t.b) * smoothstep(0.35, 0.7, t.r);
	c = mix(c, t.rgb * 1.8, warm * (1.0 - h * 0.4));
	ALBEDO = c;
	ALPHA = t.a;
}
