// An aura round a figure (world/look/aura_fx.gd): a quad standing behind the sprite, turned to the camera round the
// up axis like the sprite (billboard fixed Y), drawn just before it so the figure covers its middle and only the edge
// shows. Both burn like fire (owner 2026-10-09: "Does the aura flicker? Like a fire almost. I want that", for Godrick and
// Strahd): flame tongues lick upward round the figure and the whole flame flickers. `style` 0: Strahd's black fire with
// crimson at its tips, mixed over the scene. `style` 1: a paladin's warm flame, added, faint enough that the figure
// still reads. `surge` (0..1) swells it when he acts. Premultiplied blending carries both: the dark fire covers
// (alpha), the warm one adds (no alpha).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int style = 0;
uniform float strength = 1.0;
uniform float surge = 0.0;
uniform float fade = 1.0;
uniform vec3 shadow_col : source_color = vec3(0.05, 0.02, 0.08);
uniform vec3 edge_col : source_color = vec3(0.6, 0.05, 0.1);
uniform vec3 glow_col : source_color = vec3(1.0, 0.75, 0.35);
uniform vec3 fire_col : source_color = vec3(0.95, 0.66, 0.23);
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float seed = 0.0;

void vertex() {
	// Face the camera round the up axis, keeping the quad's own scale.
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	right.y = 0.0;
	right = length(right) > 0.0001 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 fwd = cross(right, up);
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	mat4 world = mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
}

// Flame tongues: noise stretched upward and pulled up fast, warped sideways by slower noise so the tongues sway and
// split; 0..1, higher in the body of a flame.
float flames(vec2 uv, float t, float sd) {
	float sway = texture(noise_tex, vec2(uv.x * 1.6 + sd, uv.y * 0.8 + t * 0.35)).r - 0.5;
	float a = texture(noise_tex, vec2(uv.x * 3.4 + sway * 0.45 + sd, uv.y * 1.1 + t * 1.25)).r;
	float b = texture(noise_tex, vec2(uv.x * 6.5 - sway * 0.6 - sd, uv.y * 1.9 + t * 1.9)).r;
	return a * 0.68 + b * 0.42;
}

// The whole flame's flicker: a quick unsteady brightness, never quite still (several rates beating together).
float flicker(float t, float sd) {
	float n = texture(noise_tex, vec2(sd * 3.1, t * 0.9)).r;
	return 0.82 + 0.1 * sin(t * 11.3 + sd * 6.0) + 0.06 * sin(t * 23.9 + sd * 2.0) + (n - 0.5) * 0.35;
}

void fragment() {
	float x = UV.x - 0.5;
	float v = 1.0 - UV.y;            // 0 at the feet, 1 at the top
	float t = TIME + seed * 17.0;
	float flick = flicker(t, seed);
	float f = flames(UV, t, seed);
	if (style == 0) {
		// Black fire round him: thickest just outside his outline at the hem, its tongues reaching past his shoulders
		// and thinning to nothing at the quad's edges and the top. The quad is wide (AuraFx.HALO_SIZE) so it fades out
		// inside it.
		float half_w = mix(0.3, 0.15, smoothstep(0.0, 0.9, v)) * (1.0 + surge * 0.25);
		float edge = abs(x) + (f - 0.55) * 0.05;
		float env = smoothstep(half_w + 0.17, half_w - 0.05, edge);
		float rise = pow(clamp(1.0 - v * 0.95, 0.0, 1.0), 0.7) * smoothstep(0.0, 0.08, v);
		// The flame's edge climbs with height, so tongues taper to points as they rise.
		float body = env * rise * (1.0 + surge * 0.7) * (0.9 + flick * 0.2);
		float a = smoothstep(0.36 + v * 0.12, 0.8 + v * 0.1, body * f * 1.6);
		// Crimson in the thin parts of the flame, the tips and edges, flickering hotter in a surge.
		float tip = smoothstep(0.05, 0.3, a) * smoothstep(0.75, 0.35, a);
		float ember = tip * (0.45 + surge * 1.2) * flick;
		float alpha = clamp(a * 0.74 * strength * fade, 0.0, 0.8);
		ALBEDO = shadow_col * alpha + edge_col * ember * fade * strength * 0.6;
		ALPHA = alpha;
	} else {
		// A warm flame licking up round the paladin's outline, brightest low and fading by the head, with a soft glow
		// under it; it flickers like a candle in a draught.
		float half_w = mix(0.36, 0.22, smoothstep(0.0, 0.9, v));
		float edge = abs(x) + (f - 0.55) * 0.05;
		float env = smoothstep(half_w + 0.12, half_w - 0.08, edge);
		float rise = pow(clamp(1.0 - v * 0.92, 0.0, 1.0), 0.6) * smoothstep(0.0, 0.06, v);
		float fire = smoothstep(0.42 + v * 0.1, 0.85 + v * 0.08, env * rise * f * 1.7);
		float core = smoothstep(0.55, 1.0, fire);
		float d = length(vec2(x / 0.36, (v - 0.42) / 0.56));
		float glow = smoothstep(1.0, 0.2, d) * 0.2;
		// Orange at the edges, golden in the middle of a tongue; partly laid over the scene (alpha) so it stays warm
		// over cold stone instead of washing pale, partly added so it glows.
		vec3 hot = mix(glow_col, fire_col, core);
		float lit = flick * (1.0 + surge * 1.5) * strength * fade;
		float cover = clamp(fire * 0.32 * lit, 0.0, 0.5);
		ALBEDO = hot * cover + (glow_col * glow + hot * fire * 0.22) * lit;
		ALPHA = cover;
	}
}
