// A character's reflection (Visual Polish Plan 1; SpriteReflection): the figure the crisp sprite shader draws, mirrored
// under its feet and shown only where the surface below it is level, at the figure's feet height and glossy: open
// water and rain puddles fully, wet ground, polished marble and tiles faintly and softer, dry ground not at all. The
// surface is read per pixel from the depth and normal-roughness buffers, so anything standing in front of the
// reflection (a wall, a barrel, another figure) hides it, and no world shader has to know about it. On water it
// wavers. Drawn after the screen pass like the figures themselves (SpriteReflection.PRIORITY), never in a shadow.
//
// The motion between frames (squash, lean, lift, push), the billboard and the scene lighting follow
// sprite_crisp.gdshader, so the reflection moves and is lit as its figure is.
shader_type spatial;
render_mode cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D texture_albedo : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D surface_tex : hint_normal_roughness_texture, filter_nearest;
uniform bool billboard = true;
uniform vec3 face = vec3(0.0);
uniform vec2 squash = vec2(1.0);
uniform float lean = 0.0;
uniform float lift = 0.0;
uniform float push = 0.0;
uniform float ghost = 0.0;
uniform vec4 ghost_tint : source_color = vec4(0.741, 0.741, 0.776, 1.0);
uniform bool lit = true;
uniform float light_floor = 0.25;
uniform float glow = 0.0;
uniform float light_cap = 0.85;
// The figure's height (world units): how far below the surface the reflection fades out is a share of it.
uniform float height = 1.5;
// How strongly the reflection shows on still water, and how dark it is (water swallows some of the light).
uniform float strength = 0.9;
uniform float darken = 0.9;
// Roughness at which a surface starts to reflect, and below which it reflects fully (water is about 0.05, a rain
// puddle 0.1, wet ground about 0.3, polished marble 0.3, tiles 0.36, dry cobbles 0.4, earth 0.8).
uniform float gloss_from = 0.45;
uniform float gloss_full = 0.25;
// How much of the figure's height shows on a fully glossy surface before it fades, and on a barely glossy one.
uniform float reach_glossy = 1.6;
uniform float reach_dull = 0.6;
// How far (world units) the surface may be from the figure's feet and still count as the one it stands on.
uniform float level_tolerance = 0.18;
// Water's waver: how far it pulls the reflection sideways (in screen pixels) and how fast.
uniform float waver_px = 2.5;
uniform float waver_speed = 1.6;

varying float feet_y;

void vertex() {
	// The crisp sprite's motion between frames, then the figure turned upside down about its feet.
	VERTEX = vec3(VERTEX.x * squash.x + lean * VERTEX.y + push, -(VERTEX.y * squash.y + lift), VERTEX.z);
	feet_y = MODEL_MATRIX[3].y;
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
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	// Derivatives first (before any discard): a screen pixel's step across the sheet.
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	// The surface already drawn at this pixel: where it is, which way it faces, how glossy it is.
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	vec3 ground = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	vec4 nr = texture(surface_tex, SCREEN_UV);
	// Godot packs roughness into the alpha (halved, flipped for moving objects).
	float rough = nr.a > 0.5 ? 1.0 - nr.a : nr.a;
	rough /= (127.0 / 255.0);
	vec3 n = (INV_VIEW_MATRIX * vec4(normalize(nr.xyz * 2.0 - 1.0), 0.0)).xyz;
	float level = 1.0 - smoothstep(level_tolerance * 0.5, level_tolerance, abs(ground.y - feet_y));
	float up = smoothstep(0.8, 0.95, n.y);
	float gloss = 1.0 - smoothstep(gloss_full, gloss_from, rough);
	float mask = level * up * gloss;
	if (mask < 0.01) {
		discard;
	}
	// How far below the surface this part of the mirrored figure is: it fades out sooner on a duller surface.
	vec3 here = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float below = max(feet_y - here.y, 0.0);
	float reach = mix(reach_dull, reach_glossy, gloss) * height;
	float fade = 1.0 - smoothstep(0.0, reach, below);
	// Water and puddles (roughness 0.1 and under) waver; a duller surface blurs the figure instead.
	float water = 1.0 - smoothstep(0.12, 0.2, rough);
	float wave = sin(ground.z * 11.0 + TIME * waver_speed * 2.3) * 0.6 + sin(ground.x * 7.0 - TIME * waver_speed * 1.7) * 0.4;
	vec2 uv = UV + dx * wave * waver_px * water;
	float spread = 1.0 + (1.0 - gloss) * 3.0;
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		vec2 o = vec2(float(i & 1) - 0.5, float(i >> 1) - 0.5) * spread;
		vec4 s = texture(texture_albedo, uv + dx * o.x + dy * o.y);
		acc += vec4(s.rgb * s.a, s.a);
	}
	acc /= 4.0;
	vec3 col = acc.a > 0.0 ? acc.rgb / acc.a : vec3(0.0);
	if (ghost > 0.0) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, clamp(vec3(lum) * ghost_tint.rgb * 1.35, 0.0, 1.0), ghost);
	}
	col *= darken;
	ALPHA = acc.a * COLOR.a * mask * fade * strength;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (lit) {
		ALBEDO = col * COLOR.rgb;
		EMISSION = ALBEDO * max(light_floor, glow);
	} else {
		ALBEDO = vec3(0.0);
		EMISSION = col * COLOR.rgb;
	}
}

void light() {
	if (lit) {
		// As the figure is lit (sprite_crisp.gdshader), without its rim.
		float gain = LIGHT_IS_DIRECTIONAL ? 1.0 : 1.35;
		float front = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
		vec3 c = LIGHT_COLOR / PI * ATTENUATION * gain;
		float peak = max(c.r, max(c.g, c.b));
		c *= min(1.0, light_cap / max(peak, 0.0001));
		DIFFUSE_LIGHT += c * mix(0.45, 1.0, front);
	}
}
