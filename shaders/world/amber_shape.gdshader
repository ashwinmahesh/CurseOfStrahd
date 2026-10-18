// The shape held in a block of amber (Amber Temple Look Plan §3.2, AmberGlow): a vestige's silhouette (a game-icons
// picture the build tool composed, art/amber_shapes.json) hung dark in the middle of its block, softened by depth so it
// reads as inside the glass and not on it, always turned to the camera along the ground as a figure's sprite is, with
// the block's own touch drawn on it or round it: gold flecks, rising bubbles, a twitch, hairline cracks, glints, stars
// drifting down, a shape that fades out and comes back, sparks, a ring of glow, a lightless core. Drawn between the far
// inside of the glass and its near face (render priority 1). One material per block, no instance uniforms.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D shape : source_color, filter_linear_mipmap, repeat_disable;
// The colour the shape is drawn in: dark, a palette colour.
uniform vec3 tint : source_color = vec3(0.12, 0.06, 0.03);
// The colour of what the touch draws (flecks, bubbles, sparks, glints).
uniform vec3 speck_col : source_color = vec3(1.0, 0.85, 0.4);
// How far down the picture's mip levels it is read: more is softer, as if the glass were thicker.
uniform float softness : hint_range(0.0, 5.0) = 1.6;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
// How much of it shows now (a block that is sated shows it sharper, a sealed one fainter), and a state's extra.
uniform float shown : hint_range(0.0, 2.0) = 1.0;
// The touch: 0 none, 1 flecks, 2 bubbles, 3 twitch, 4 cracks, 5 glints, 6 stars_down, 7 fade, 8 sparks_up, 9 ring,
// 10 orbit (the picture turns about its middle), 11 void (no shape: a black middle the light bends round).
uniform int touch = 0;
uniform float spin = 0.0;
// Where this block is in its own time, so no two do the same thing together.
uniform float clock = 0.0;

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Points on a grid of `n` cells, a few of them lit, each twinkling on its own beat and drifting by `drift`; 1 at a
// point's middle, falling to 0 at `r` cells' width.
float points(vec2 uv, float n, vec2 drift, float t, float density, float r) {
	vec2 g = (uv + drift * t) * n;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash12(id);
	vec2 jitter = (vec2(hash12(id + 1.7), hash12(id + 3.1)) - 0.5) * 0.6;
	float on = step(1.0 - density, h);
	float twinkle = 0.5 + 0.5 * sin(t * (1.0 + h * 3.0) + h * 40.0);
	return on * twinkle * smoothstep(r, 0.0, length(f - jitter));
}

void vertex() {
	// Turned to the camera about the vertical, as a billboard that stays upright.
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
	float t = TIME + clock;
	vec2 uv = UV;
	if (touch == 3) {
		// The heads twitch apart and back: a quick shudder now and then.
		float k = smoothstep(0.75, 1.0, sin(t * 1.3));
		uv = (uv - 0.5) * (1.0 - 0.05 * k) + 0.5 + 0.018 * vec2(sin(t * 9.0), cos(t * 7.0)) * k;
	}
	if (touch == 10) {
		float a = t * spin;
		vec2 c = uv - 0.5;
		uv = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * c + 0.5;
	}
	float a = 0.0;
	if (touch != 11) {
		a = textureLod(shape, uv, softness).a;
	}
	float alpha = a * opacity;
	float add = 0.0;
	if (touch == 1) {
		add = points(UV, 9.0, vec2(0.0, 0.01), t, 0.22, 0.2) * 0.95;                // gold flecks hung in it
	} else if (touch == 2) {
		vec2 g = (UV + vec2(0.0, t * 0.045)) * 7.0;                                  // bubbles rising
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5 + (vec2(hash12(id + 2.2), hash12(id + 5.5)) - 0.5) * 0.4;
		float ring = smoothstep(0.17, 0.13, length(f)) - smoothstep(0.12, 0.08, length(f));
		add = step(0.7, hash12(id)) * max(ring, 0.0) * 0.8;
	} else if (touch == 4) {
		float n = sin(UV.x * 17.0 + UV.y * 5.0) * sin(UV.y * 13.0 - UV.x * 7.0);   // hairline cracks that never spread
		alpha = max(alpha, smoothstep(0.018, 0.0, abs(n - 0.35)) * 0.55 * a);
	} else if (touch == 5) {
		float lit = step(0.45, textureLod(shape, UV, 0.0).a);                         // pinpoints that glint on it
		add = points(UV, 8.0, vec2(0.0), t * 1.4, 0.3, 0.16) * lit * 1.4;
	} else if (touch == 6) {
		add = points(UV, 10.0, vec2(0.0, -0.035), t, 0.18, 0.12);                    // tiny stars drifting down
	} else if (touch == 7) {
		alpha *= 0.12 + 0.88 * pow(0.5 + 0.5 * sin(t * 0.45), 2.0);                   // rubbed out, and back
	} else if (touch == 8) {
		add = points(UV, 11.0, vec2(0.0, 0.07), t, 0.16, 0.14);                      // sparks drifting up
	} else if (touch == 9) {
		float r = length(UV - 0.5);
		add = smoothstep(0.035, 0.0, abs(r - 0.36)) * (0.35 + 0.15 * sin(t * 0.8));  // a ring of glow, an empty middle
	} else if (touch == 11) {
		float r = length(UV - 0.5) * 2.0;
		alpha = (1.0 - smoothstep(0.3, 0.95, r)) * 0.95;                              // a lightless core
		add = smoothstep(0.55, 0.75, r) * smoothstep(1.0, 0.75, r) * 0.3;            // the glow bending round it
	}
	vec3 col = mix(tint, speck_col, clamp(add, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(max(alpha, add * 0.9) * shown, 0.0, 1.0);
}
