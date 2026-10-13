shader_type spatial;
// The first pass over a 3D piece that a Search or a check just found (world/look/found_outline.gd): a faint orange rim,
// brightest at its silhouette and stronger while it pulses, and it marks the piece's own pixels in the stencil buffer
// so the outline's passes after it (found_outline_mesh.gdshader) draw only round it, never over it. `glow` as in
// found_outline_sprite.gdshader; `bright` and `saturate` tone the colour for the look
// (FoundOutline._tone).
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
stencil_mode write, compare_always, 37;

uniform vec3 tint : source_color = vec3(0.85, 0.45, 0.12);
uniform float strength = 0.35;
uniform float glow = 1.0;
uniform float bright = 1.0;
uniform float saturate = 1.0;

vec3 tone(vec3 c) {
	float grey = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return max(mix(vec3(grey), c, saturate), vec3(0.0)) * bright;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float swell = max(glow - 1.0, 0.0);
	ALBEDO = tone(tint) * rim * strength * (clamp(glow, 0.0, 1.0) + 1.5 * swell);
}
