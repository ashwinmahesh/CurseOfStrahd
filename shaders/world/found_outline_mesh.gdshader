shader_type spatial;
// One pass of the outline round a 3D piece that a Search or a check just found (world/look/found_outline.gd): the piece
// drawn again, shifted `shift` screen pixels one way and brought a little toward the camera (so a wall it's set in
// doesn't hide the line), only where the stencil doesn't mark the piece itself (found_rim.gdshader marks it) or an
// earlier pass of the outline. Eight of these, each shifted another way, make a line round the piece's shape however
// its faces are cut; eight more, further out and fainter, its glow. `glow` as in found_outline_sprite.gdshader: the
// line swells and the glow brightens while it pulses.
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled, blend_mix;
stencil_mode read, write, compare_not_equal, 37;

uniform vec4 color : source_color = vec4(0.95, 0.6, 0.2, 1.0);
uniform vec2 shift = vec2(2.5, 0.0);
uniform float lift = 0.3;
uniform float swell_by = 0.6;
uniform float glow = 1.0;
uniform float bright = 1.0;
uniform float saturate = 1.0;

vec3 tone(vec3 c) {
	float grey = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return max(mix(vec3(grey), c, saturate), vec3(0.0)) * bright;
}

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xyz += normalize(-view_pos.xyz) * lift;
	vec4 clip = PROJECTION_MATRIX * view_pos;
	clip.xy += shift * (1.0 + swell_by * max(glow - 1.0, 0.0)) * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	if (glow <= 0.0) {
		discard;
	}
	float swell = min(max(glow - 1.0, 0.0), 1.0);
	ALBEDO = tone(color.rgb) * mix(1.0, 1.25, swell);
	ALPHA = clamp(color.a * clamp(glow, 0.0, 1.0) * (1.0 + 0.6 * swell), 0.0, 1.0);
}
