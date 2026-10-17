// Single-sample character art for Apple's CPU-only iOS simulator. Device and desktop use sprite_crisp.
// Keep the same billboard, atlas UV, ghost tint and motion contract as DirectionalSprite.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_prepass_alpha;
uniform sampler2D texture_albedo : source_color, filter_linear, repeat_disable;
uniform bool billboard = true;
uniform vec3 face = vec3(0.0);
uniform vec2 squash = vec2(1.0);
uniform float lean = 0.0;
uniform float lift = 0.0;
uniform float push = 0.0;
uniform float depth_nudge = 0.0;
uniform float ghost = 0.0;
uniform vec4 ghost_tint : source_color = vec4(0.741, 0.741, 0.776, 1.0);

void vertex() {
	// No early return here: Godot's own vertex code runs after this block.
	VERTEX = vec3(VERTEX.x * squash.x + lean * VERTEX.y + push, VERTEX.y * squash.y + lift, VERTEX.z);
	if (billboard) {
		vec3 z = length(face) > 0.5 ? normalize(vec3(face.x, 0.0, face.z))
				: normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), z)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(z, 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX[3].z += depth_nudge;   // view space: +z is toward the camera
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
    vec4 art = texture(texture_albedo, UV);
    vec3 col = art.rgb;
    if (ghost > 0.0) {
        float lum = dot(col, vec3(0.299, 0.587, 0.114));
        col = mix(col, clamp(vec3(lum) * ghost_tint.rgb * 1.35, 0.0, 1.0), ghost);
    }
    ALBEDO = col * COLOR.rgb;
    ALPHA = art.a * COLOR.a;
}
