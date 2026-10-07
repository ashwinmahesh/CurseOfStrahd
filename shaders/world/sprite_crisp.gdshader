// Character sprites (DirectionalSprite; owner 2026-10-07: "crisp lines, high definition of each character's features").
// At the usual zoom a sheet is drawn at about half its size: plain linear sampling skips texels (jagged, broken lines)
// and mipmaps blur. This shader takes a 4x4 grid of samples across part of each screen pixel's footprint on the
// full-resolution sheet (sharp, without the jaggies), and draws an ink outline of `outline_px` screen pixels round the
// figure so its silhouette stays clear at any zoom. Billboard (Y only) unless `billboard` is off (CombatToken's lying
// view lies flat on the ground), modulate through COLOR, alpha-blended (fades work). DirectionalSprite binds the sheet
// (texture_albedo = the current frame's atlas): the sprite's UVs already address the atlas.
//
// Lit by the scene in the Modern finish (Improvement Ideas W6, `lit`): a figure takes the colour and strength of the
// lamps near it, the sun or moon and the sky (so the time of day and a storm's lightning reach it too), a light behind
// it draws a thin rim along the edge it shines past, and it casts its shadow on the ground. A painted figure isn't
// shaded across its body: every lamp lights it evenly, a little less when behind it. `light_floor` keeps a figure
// readable in the dark; `glow` is for figures that are their own light (fire, wisps). Classic draws it as it always
// has, at its own colours (emission only, no light), frozen with that finish.
//
// Motion between frames (G12): DirectionalSprite feeds `squash`, `lean`, `lift` and `push` every frame (breathing, a
// lean into turns, a bob in the walk, squash and stretch, a recoil when struck), applied to the flat figure with its
// feet as the pivot, so its shadow moves with it.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, depth_prepass_alpha;

uniform sampler2D texture_albedo : source_color, filter_linear, repeat_disable;
// The share of a screen pixel's footprint the samples cover: 1.0 is a plain box (smooth), lower is sharper.
uniform float footprint = 0.6;
// Outline width in screen pixels, and its colour (the palette's ink).
uniform float outline_px = 1.4;
uniform vec4 ink : source_color = vec4(0.071, 0.055, 0.094, 1.0);
// Local contrast (unsharp mask in screen space): lines and features drawn thinner than a screen pixel at the usual zoom
// keep their darkness instead of averaging into the colours round them (owner 2026-10-07: "even more sharp"). 0 is off.
uniform float sharpen = 0.9;
// Off for a sprite that keeps its own orientation (DirectionalSprite.setup_material reads the node's billboard mode).
uniform bool billboard = true;
// A ghostly image (an Echo Knight's echo, CombatToken): 0 is the figure as drawn, 1 is its colours washed to gray
// and tinted with `ghost_tint` (the token's modulate makes it translucent).
uniform float ghost = 0.0;
uniform vec4 ghost_tint : source_color = vec4(0.741, 0.741, 0.776, 1.0);
// Scene lighting (the Modern finish) and its floor, a figure's own glow, and the rim from lights behind it.
uniform bool lit = false;
uniform float light_floor = 0.25;
uniform float glow = 0.0;
uniform float rim_strength = 1.6;
// The most one light adds (its brightest channel), so no light washes a figure out.
uniform float light_cap = 0.85;
// How far inside the edge the rim reaches, in screen pixels.
uniform float rim_px = 2.5;
// The ground direction towards the camera (DirectionalSprite, every frame): the figure faces the camera in every pass,
// so its shadow is the figure the player sees. Zero: face whichever view is rendering (the earlier billboard).
uniform vec3 face = vec3(0.0);
// Motion between frames, in the figure's plane, feet as the pivot: scale (x, y), shear (top over bottom), and offsets
// up and sideways in world units.
uniform vec2 squash = vec2(1.0);
uniform float lean = 0.0;
uniform float lift = 0.0;
uniform float push = 0.0;

// From the fragment to each light: the edge's outward direction (view space) and how close the pixel is to it.
varying vec3 rim_n;

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
	if (sharpen > 0.0) {
		// The same footprint's surroundings: eight samples a screen pixel out. Pushing the pixel away from them
		// restores the contrast the averaging took (colour only; the figure's edge stays as it is).
		vec4 ring = vec4(0.0);
		for (int k = 0; k < 8; k++) {
			float ang = float(k) * 0.785398 + 0.3927;
			vec4 s = texture(texture_albedo, UV + dx * cos(ang) + dy * sin(ang));
			ring += vec4(s.rgb * s.a, s.a);
		}
		ring /= 8.0;
		vec3 here = acc.a > 0.0 ? acc.rgb / acc.a : vec3(0.0);
		vec3 round_ = ring.a > 0.0 ? ring.rgb / ring.a : here;
		acc.rgb = clamp(here + sharpen * (here - round_), 0.0, 1.0) * acc.a;
	}
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
	if (ghost > 0.0) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, clamp(vec3(lum) * ghost_tint.rgb * 1.35, 0.0, 1.0), ghost);
	}
	ALPHA = a * COLOR.a;
	// No sheen from the sky or reflections: a painted figure only takes light (and its rim) from light().
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	rim_n = vec3(0.0);
	if (lit) {
		ALBEDO = col * COLOR.rgb;
		EMISSION = ALBEDO * max(light_floor, glow);
		// The rim: where the figure's alpha falls off within rim_px, the direction it falls off in (view space).
		float gx = texture(texture_albedo, UV + dx * rim_px).a - texture(texture_albedo, UV - dx * rim_px).a;
		float gy = texture(texture_albedo, UV + dy * rim_px).a - texture(texture_albedo, UV - dy * rim_px).a;
		vec3 out_dir = -(gx * normalize(dFdx(VERTEX)) + gy * normalize(dFdy(VERTEX)));
		float l = length(out_dir.xy);
		if (l > 0.05) {
			rim_n = vec3(out_dir.xy / l, clamp(l, 0.0, 1.0) * acc.a);
		}
	} else {
		// Classic: the figure at its own colours, as when it was drawn unshaded.
		ALBEDO = vec3(0.0);
		EMISSION = col * COLOR.rgb;
	}
}

void light() {
	if (lit) {
		// Lamps light a third more than their energy says, as the world's Modern shaders do (lit_light.gdshaderinc).
		float gain = LIGHT_IS_DIRECTIONAL ? 1.0 : 1.35;
		// Evenly across the painted figure; a light behind it lights it a little less (the side it sees is in shade).
		float front = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
		// No more than `light_cap` from one light, keeping its colour: a lantern carried by the figure (or a lamp it
		// stands under) lights it warmly instead of washing it out to white.
		vec3 c = LIGHT_COLOR / PI * ATTENUATION * gain;
		float peak = max(c.r, max(c.g, c.b));
		c *= min(1.0, light_cap / max(peak, 0.0001));
		DIFFUSE_LIGHT += c * mix(0.45, 1.0, front);
		// The rim: on the edge facing the light (on screen), strongest when the light is behind the figure.
		float ll = length(LIGHT.xy);
		if (rim_n.z > 0.0 && ll > 0.001) {
			float side = clamp(dot(rim_n.xy, LIGHT.xy / ll), 0.0, 1.0);
			float behind = clamp(0.4 - LIGHT.z, 0.0, 1.0);
			SPECULAR_LIGHT += c * rim_n.z * side * behind * rim_strength;
		}
	}
}
