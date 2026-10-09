// An aura round a figure (world/look/aura_fx.gd): a quad standing behind the sprite, turned to the camera round the
// up axis like the sprite (billboard fixed Y), drawn just before it so the figure covers its middle and only the edge
// shows. `style` 0: Strahd's dark aura, smoke and shadow curling up round him with a crimson edge, mixed over the scene.
// `style` 1: a paladin's faint warm glow, added. `surge` (0..1) swells it when he acts. Premultiplied blending carries
// both: the dark smoke covers (alpha), the glow adds (no alpha).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int style = 0;
uniform float strength = 1.0;
uniform float surge = 0.0;
uniform float fade = 1.0;
uniform vec3 shadow_col : source_color = vec3(0.05, 0.02, 0.08);
uniform vec3 edge_col : source_color = vec3(0.6, 0.05, 0.1);
uniform vec3 glow_col : source_color = vec3(1.0, 0.75, 0.35);
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

void fragment() {
	float x = UV.x - 0.5;
	float v = 1.0 - UV.y;            // 0 at the feet, 1 at the top
	float t = TIME + seed * 17.0;
	if (style == 0) {
		// Dark flames of smoke licking up round him: soft noise stretched upward and warped sideways, thickest just
		// outside his outline at the hem and thinning to nothing at the quad's edges and toward the top, so it reads as
		// wisps rather than a box behind him. The quad is wide (AuraFx.HALO_SIZE) so the smoke can fade out inside it.
		float half_w = mix(0.3, 0.15, smoothstep(0.0, 0.9, v)) * (1.0 + surge * 0.25);
		float warp = texture(noise_tex, vec2(UV.x * 1.3 + seed, UV.y * 0.7 + t * 0.12)).r - 0.5;
		float n1 = texture(noise_tex, vec2(UV.x * 2.0 + warp * 0.4 + seed, UV.y * 0.6 + t * 0.32)).r;
		float n2 = texture(noise_tex, vec2(UV.x * 3.6 - warp * 0.3 - seed, UV.y * 1.0 + t * 0.55)).r;
		float flame = n1 * 0.75 + n2 * 0.4;
		float edge = abs(x) + warp * 0.06;
		float env = smoothstep(half_w + 0.17, half_w - 0.05, edge);
		float rise = pow(clamp(1.0 - v * 0.95, 0.0, 1.0), 0.7) * smoothstep(0.0, 0.08, v);
		float body = env * rise * (1.0 + surge * 0.7);
		float a = smoothstep(0.38, 0.85, body * flame * 1.55);
		// A smoky crimson glow inside the wisps (not at their edge, which glitters), stronger in a surge.
		float ember = smoothstep(0.2, 0.5, a) * smoothstep(0.85, 0.5, a) * (0.3 + surge * 1.1);
		float alpha = clamp(a * 0.72 * strength * fade, 0.0, 0.78);
		ALBEDO = shadow_col * alpha + edge_col * ember * fade * strength * 0.55;
		ALPHA = alpha;
	} else {
		// A soft oval of warm light round the figure, breathing slowly, with a few motes drifting up through it.
		float d = length(vec2(x / 0.36, (v - 0.46) / 0.56));
		float glow = smoothstep(1.0, 0.15, d) * (0.85 + 0.15 * sin(t * 1.3));
		float m = texture(noise_tex, vec2(UV.x * 4.0 + seed, UV.y * 3.0 + t * 0.12)).r;
		float motes = smoothstep(0.78, 0.86, m) * smoothstep(1.0, 0.5, d);
		ALBEDO = glow_col * (glow * 0.5 + motes * 0.45) * (1.0 + surge * 1.5) * strength * fade;
		ALPHA = 0.0;
	}
}
