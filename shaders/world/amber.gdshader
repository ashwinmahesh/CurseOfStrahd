// The Amber Temple's amber (Amber Temple Look Plan §3, AmberGlow): backlit honey, never the white-hot box it was. A block
// is lit from inside: bright honey in the middle of every face, falling to deep ember toward its edges and its foot, as
// amber held up to a candle does, with a hard glassy highlight where the room's lights catch it, a few specks held
// in it and, when it is dead (the hollow, the cracked one, the whole temple once it is sealed), a murky brown glass
// with no light of its own. Its breath comes from the light inside (AmberGlow.Case sets `glow` from it each frame), so
// block and light swell together.
//
// One material per block, never an instance uniform: those take a block of the global buffer for every mesh drawn
// with the shader, and a big place's floors, props and walls overflowed it (memory: walls-look).
shader_type spatial;
// (cull_back: the face seen from outside; AmberGlow makes a copy of this shader with cull_front for the far inside of the
// glass, drawn first, so a block reads as thick glass with its back showing through its front.)
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/world/see_through.gdshaderinc"

// The honey of the glowing middle and the ember of the edges (palette colours, set from AmberGlow).
uniform vec3 core : source_color = vec3(0.98, 0.88, 0.54);
uniform vec3 edge : source_color = vec3(0.54, 0.23, 0.07);
// The murk a dead block is made of.
uniform vec3 dead_tint : source_color = vec3(0.17, 0.1, 0.06);
// How brightly it glows (1 is the breath's own middle: the light inside, as a share of its own energy, times the state's).
uniform float glow : hint_range(0.0, 2.0) = 1.0;
// 0 alive, 1 dead: the glow is gone and the glass is murky brown.
uniform float dead : hint_range(0.0, 1.0) = 0.0;
// Clouding through the amber (a sick block's, a dead one's), 0 clear.
uniform float cloud : hint_range(0.0, 1.0) = 0.15;
// What the clouding is made of (a sick block's bile): multiplied into the murk, white leaves it plain.
uniform vec3 cloud_tint : source_color = vec3(1.0);
// How see-through the glass is at its middle and at its edges.
uniform float alpha_core : hint_range(0.0, 1.0) = 0.52;
uniform float alpha_edge : hint_range(0.0, 1.0) = 0.86;
// The block's height, for the glow rising from its foot (local units).
uniform float body_height = 2.0;
// A block broken open (the Eye's egg of amber): the way the break faces on the ground (x, z), how wide it opens (the
// cosine of its half angle: 1 closed) and the height of the foot of the break. Off at cut_open 1.
uniform vec2 cut_dir = vec2(0.0, 1.0);
uniform float cut_open : hint_range(-1.0, 1.0) = 1.0;
uniform float cut_foot = 0.2;

varying vec3 lp;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (see_cut(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, CAMERA_POSITION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	if (cut_open < 0.999) {
		// Broken open on one side: the shell is gone there, from the foot of the break up.
		vec2 radial = normalize(lp.xz + vec2(1e-4));
		// A ragged edge: the shell broke where it was thinnest, not along a line.
		float jag = 0.09 * sin(lp.y * 31.0 + lp.x * 19.0) * sin(lp.z * 23.0 - lp.y * 13.0) + 0.05 * sin(lp.x * 47.0 + lp.z * 29.0);
		if (dot(radial, cut_dir) > cut_open + jag && lp.y > cut_foot + jag * 0.8) {
			discard;
		}
	}
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) {
		n = -n;   // the inside of a broken block: a smooth hollow, darker than its face
	}
	float facing = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	float t = clamp(lp.y / max(body_height, 0.01), 0.0, 1.0);
	float shade = mix(0.5, 1.0, smoothstep(0.0, 0.75, t));
	if (!FRONT_FACING) {
		shade *= 0.55;
	}
	// Honey where the glass is thin, toward the middle of a face and up the block, ember where it thickens.
	vec3 col = mix(edge, core, pow(facing, 1.35) * shade);
	// Murk: slow clouds through the glass, thicker the deader it is.
	float murk = 0.5 + 0.5 * sin(lp.x * 5.3 + lp.y * 3.1) * sin(lp.z * 4.7 - lp.y * 2.3 + 1.7);
	col = mix(col, col * 0.55 * cloud_tint, cloud * murk);
	// Specks and bubbles held still in it: a few bright points.
	vec3 cell = lp * 13.0;
	float speck = step(0.988, hash13(floor(cell))) * smoothstep(0.34, 0.1, length(fract(cell) - 0.5)) * (1.0 - dead);   // round, not a square cell
	col += core * speck * 0.5;
	col = mix(col, dead_tint * (0.8 + 0.5 * murk), dead);
	float lit = glow * (1.0 - dead);
	ALBEDO = col * 0.3;
	EMISSION = col * lit * 0.6;
	ALPHA = clamp(mix(alpha_core, alpha_edge, 1.0 - facing) + dead * 0.1, 0.0, 1.0);
	ROUGHNESS = 0.5;
	SPECULAR = 0.12;
}
