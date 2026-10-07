// A spell's beam, ray or lightning arc (world/combat/fx/fx_kit.gd): a ribbon from `p0` to `p1` in world space that
// always turns its face to the camera. The mesh is a quad subdivided along its length and its instance sits at the
// origin, so the vertex shader places every vertex itself. `jag` throws the ribbon into lightning's zigzag; `flow`
// runs energy along it; `reach` (0 to 1) grows it from the caster; `fade` dims all of it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 p0 = vec3(0.0);
uniform vec3 p1 = vec3(0.0, 0.0, 1.0);
uniform float width = 0.3;
uniform float reach = 1.0;
uniform float fade = 1.0;
uniform float jag = 0.0;
uniform float jag_rate = 18.0;
uniform float flow = 6.0;
uniform float energy = 2.5;
uniform float seed = 0.0;
// 1 thins the ribbon to nothing at p0 (a comet's tail behind a missile), 0 keeps it even.
uniform float taper = 0.0;
uniform vec3 core : source_color = vec3(1.0);
uniform vec3 glow : source_color = vec3(0.8, 0.6, 1.0);
uniform vec3 edge : source_color = vec3(0.4, 0.2, 0.6);
uniform sampler2D noise_tex : repeat_enable, filter_linear;

varying float along;
varying float across;

void vertex() {
	along = UV.x;
	across = UV.y * 2.0 - 1.0;
	float t = UV.x * reach;
	vec3 axis = p1 - p0;
	float len = max(length(axis), 0.001);
	vec3 dir = axis / len;
	vec3 pos = p0 + axis * t;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 side = normalize(cross(dir, cam - pos));
	vec3 lift = normalize(cross(side, dir));
	if (jag > 0.0) {
		// Lightning: the path breaks into a new zigzag several times a second, pinned at both ends.
		float tick = floor(TIME * jag_rate) * 0.137 + seed;
		float k = sin(t * 3.14159);
		float j1 = texture(noise_tex, vec2(t * len * 0.35, tick)).r - 0.5;
		float j2 = texture(noise_tex, vec2(t * len * 0.35 + 0.5, tick + 0.31)).r - 0.5;
		pos += (side * j1 + lift * j2) * jag * k * 2.0;
	}
	pos += side * across * width * 0.5 * mix(1.0 - taper, 1.0, UV.x);
	VERTEX = pos;
}

void fragment() {
	float d = abs(across);
	float len = length(p1 - p0) * reach;
	float n = texture(noise_tex, vec2(along * len * 0.4 - TIME * flow * 0.15, across * 0.5 + seed)).r;
	float n2 = texture(noise_tex, vec2(along * len * 0.9 - TIME * flow * 0.35, across * 0.8 + seed + 0.4)).r;
	float hot = pow(clamp(1.0 - d * 2.2, 0.0, 1.0), 2.0);
	float body = pow(clamp(1.0 - d, 0.0, 1.0), 1.4) * (0.55 + n * 0.9);
	float rim = pow(clamp(1.0 - d, 0.0, 1.0), 0.8) * n2 * 0.5;
	// Soft ends: it grows out of the hand and fades into the target.
	float ends = smoothstep(0.0, 0.04 + taper * 0.5, along) * smoothstep(1.0, 0.94, along);
	vec3 col = core * hot * 1.6 + glow * body + edge * rim;
	ALBEDO = col * energy;
	ALPHA = clamp((hot + body * 0.8 + rim) * ends * fade, 0.0, 1.0);
}
