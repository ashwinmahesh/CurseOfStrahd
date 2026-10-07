// Character sprites (DirectionalSprite; owner 2026-10-07: "crisp lines, high definition of each character's features").
// At the usual zoom a sheet is drawn at about half its size: plain linear sampling skips texels (jagged, broken lines)
// and mipmaps blur. This shader takes a 4x4 grid of samples across part of each screen pixel's footprint on the
// full-resolution sheet (sharp, without the jaggies), and draws an ink outline of `outline_px` screen pixels round the
// figure so its silhouette stays clear at any zoom. Billboard (Y only) unless `billboard` is off (CombatToken's lying
// view lies flat on the ground), unshaded, modulate through COLOR, alpha-blended (fades work). DirectionalSprite binds the sheet (texture_albedo = the current frame's atlas): the
// sprite's UVs already address the atlas.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_prepass_alpha;

uniform sampler2D texture_albedo : source_color, filter_linear, repeat_disable;
// The share of a screen pixel's footprint the samples cover: 1.0 is a plain box (smooth), lower is sharper.
uniform float footprint = 0.6;
// Outline width in screen pixels, and its colour (the palette's ink).
uniform float outline_px = 1.4;
uniform vec4 ink : source_color = vec4(0.071, 0.055, 0.094, 1.0);
// Off for a sprite that keeps its own orientation (DirectionalSprite.setup_material reads the node's billboard mode).
uniform bool billboard = true;

void vertex() {
	// No early return here: Godot's own vertex code runs after this block.
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		for (int j = 0; j < 4; j++) {
			vec2 o = ((vec2(float(i), float(j)) + 0.5) / 4.0 - 0.5) * footprint;
			vec4 s = texture(texture_albedo, UV + dx * o.x + dy * o.y);
			acc += vec4(s.rgb * s.a, s.a);
		}
	}
	acc /= 16.0;
	vec3 rgb = acc.a > 0.0 ? acc.rgb / acc.a : ink.rgb;
	// The outline: the most covered of eight samples `outline_px` screen pixels away.
	float near = 0.0;
	for (int k = 0; k < 8; k++) {
		float ang = float(k) * 0.785398;
		vec2 o = vec2(cos(ang), sin(ang)) * outline_px;
		near = max(near, texture(texture_albedo, UV + dx * o.x + dy * o.y).a);
	}
	float edge = clamp(near - acc.a, 0.0, 1.0);
	float a = clamp(acc.a + edge, 0.0, 1.0);
	vec3 col = a > 0.0 ? (rgb * acc.a + ink.rgb * edge) / a : ink.rgb;
	ALBEDO = col * COLOR.rgb;
	ALPHA = a * COLOR.a;
}
