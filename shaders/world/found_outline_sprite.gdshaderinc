// The outline round a 2D piece that a Search or a check just found (world/look/found_outline.gd), shared by its two
// passes: found_outline_sprite.gdshader where the piece can be seen and found_outline_sprite_xray.gdshader (XRAY)
// where something stands in front of it. Laid over the Sprite3D as its overlay, on its own quad grown past the
// picture's edges, so the line can run outside a picture that fills its texture. Outside the picture's shape it
// draws an orange line that hugs it, a dark hairline beyond (so it reads on pale ground too) and a soft orange glow
// beyond that; inside the shape it draws nothing, so the piece looks as it always does. Seen through a wall (XRAY) it
// is a fainter line and a faint orange fill of the shape, so a find behind a cut-away wall still shows where it is.
// Widths are in screen pixels, the same at any zoom. `glow` is 1 for the steady outline, more while it pulses as the
// thing is found, and falls to 0 as it goes.

uniform sampler2D sprite_tex : source_color, filter_linear_mipmap, repeat_disable;
// The picture's part of the texture (a frame or region): x, y, width, height in UV.
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
// The quad's middle in the sprite's own space, and how much bigger it's drawn (across, up).
uniform vec3 quad_center = vec3(0.0);
uniform vec2 grow = vec2(1.0);
// The quad's plane (the sprite's axis): 0 XY (z), 1 XZ (y, lying flat), 2 ZY (x).
uniform int plane = 0;
// The sprite's billboard: 0 none, 1 facing the camera, 2 turning about y.
uniform int billboard = 0;
uniform float alpha_cut = 0.5;
uniform vec4 line_color : source_color = vec4(0.95, 0.6, 0.2, 1.0);
uniform vec4 halo_color : source_color = vec4(0.85, 0.45, 0.12, 1.0);
uniform vec4 edge_color : source_color = vec4(0.05, 0.04, 0.07, 1.0);
uniform float line_px = 2.5;
uniform float edge_px = 1.25;
uniform float halo_px = 10.0;
uniform float halo_alpha = 0.45;
uniform float glow = 1.0;
// Brought this far toward the camera, so a rug or a wall face it lies against doesn't hide the line.
uniform float lift = 0.12;
// The look's colour (FoundOutline.tone): the modern finish's tone mapping washes a full-strength orange toward white,
// so there it's drawn dimmer and more saturated.
uniform float bright = 1.0;
uniform float saturate = 1.0;
#ifdef XRAY
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// Only where what's in front is at least this far in front (world units): not the floor it lies on, a wall it's set in.
uniform float xray_gap = 0.8;
uniform float xray_alpha = 0.35;
#endif

const int DIRS = 12;
const int RINGS = 6;

void vertex() {
	vec3 d = VERTEX - quad_center;
	if (plane == 0) {
		d.x *= grow.x;
		d.y *= grow.y;
	} else if (plane == 1) {
		d.x *= grow.x;
		d.z *= grow.y;
	} else {
		d.z *= grow.x;
		d.y *= grow.y;
	}
	VERTEX = quad_center + d;
	vec2 uc = uv_rect.xy + uv_rect.zw * 0.5;
	UV = uc + (UV - uc) * grow;
	// The sprite's own material turns it to the camera (BaseMaterial3D's billboard, keeping its scale): do the same.
	if (billboard == 1) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(MAIN_CAM_INV_VIEW_MATRIX[0], MAIN_CAM_INV_VIEW_MATRIX[1],
			MAIN_CAM_INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	} else if (billboard == 2) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), MAIN_CAM_INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	}
	if (billboard != 0) {
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xyz += normalize(-view_pos.xyz) * lift;
	POSITION = PROJECTION_MATRIX * view_pos;
}

// How much of the picture covers `uv` (0 outside its part of the texture), read at mip level `lod`.
float cover(vec2 uv, float lod) {
	vec2 lo = uv_rect.xy;
	vec2 hi = uv_rect.xy + uv_rect.zw;
	if (uv.x < lo.x || uv.y < lo.y || uv.x > hi.x || uv.y > hi.y) {
		return 0.0;
	}
	return smoothstep(alpha_cut - 0.2, alpha_cut + 0.2, textureLod(sprite_tex, uv, lod).a);
}

// The most of the picture within `r` screen pixels of `uv` (`px`: UV per pixel), looked for in DIRS directions.
float near(vec2 uv, vec2 px, float r, float lod) {
	float m = 0.0;
	for (int i = 0; i < DIRS; i++) {
		float a = float(i) * (6.2831853 / float(DIRS));
		m = max(m, cover(uv + vec2(cos(a), sin(a)) * px * r, lod));
	}
	return m;
}

vec3 tone(vec3 c) {
	float grey = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return max(mix(vec3(grey), c, saturate), vec3(0.0)) * bright;
}

void fragment() {
	vec2 px = fwidth(UV);
	// The mip level a texel per screen pixel needs (the samples below are taken in loops, so it's worked out here).
	vec2 texels = px * vec2(textureSize(sprite_tex, 0));
	float lod = max(log2(max(texels.x, texels.y)), 0.0);
	if (glow <= 0.0) {
		discard;
	}
	float lit = clamp(glow, 0.0, 1.0);
	float swell = max(glow - 1.0, 0.0);   // while it pulses the line glows brighter and the glow reaches further
	float inside = cover(UV, lod);
	float line = max(near(UV, px, line_px, lod), near(UV, px, line_px * 0.5, lod));
#ifdef XRAY
	// Drawn only where something well in front hides the piece.
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 at = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	if (-at.z / at.w > -VERTEX.z - xray_gap) {
		discard;
	}
	float fill = inside * 0.45;
	float l = line * (1.0 - inside);
	float a = (l + fill) * xray_alpha * lit;
	if (a <= 0.003) {
		discard;
	}
	ALBEDO = tone(line_color.rgb);
	ALPHA = clamp(a, 0.0, 1.0);
#else
	if (inside > 0.99) {
		discard;
	}
	float edge = near(UV, px, line_px + edge_px, lod);
	// How far out the picture is, in steps of the glow's reach: the glow fades with it.
	float reach = halo_px * (1.0 + 0.4 * swell);
	float far = 1.0;
	for (int k = 1; k <= RINGS; k++) {
		float r = line_px + edge_px + (reach - line_px - edge_px) * float(k) / float(RINGS);
		if (near(UV, px, r, lod) > 0.5) {
			far = float(k) / float(RINGS);
			break;
		}
	}
	float halo = (1.0 - smoothstep(0.0, 1.0, far)) * halo_alpha * (1.0 + 0.8 * swell);
	float outside = 1.0 - inside;
	float l = line * outside;
	float e = clamp(edge - line, 0.0, 1.0) * outside;
	float h = clamp(1.0 - edge, 0.0, 1.0) * outside * halo;
	float a = l * lit + e * 0.7 * lit + h * lit;
	if (a <= 0.003) {
		discard;
	}
	vec3 col = (line_color.rgb * mix(1.0, 1.25, min(swell, 1.0)) * l + edge_color.rgb * e * 0.7 + halo_color.rgb * h)
		/ max(l + e * 0.7 + h, 0.0001);
	ALBEDO = tone(col);
	ALPHA = clamp(a, 0.0, 1.0);
#endif
}
