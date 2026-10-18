// The window walls open round the party (owner 2026-10-17: walls in the way never drop down or go see-through
// whole): what stands nearer the camera than the party, inside an oval round it on screen, isn't drawn, its rim
// dithered; the rest of every wall stands solid. Only pieces SeeThrough.mark gave a copy of their material with
// `see_through` on open (walls, houses, Castle Ravenloft, town walls, pillars); floors, props and figures never do.
// SeeThrough puts the window where the view's camera sees the party just before each frame is drawn; any other
// camera (a lamp's or the moon's shadow, a second view) cuts nothing, so walls keep their whole shadows.
//
// In a shader's fragment():
//     if (see_cut(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, CAMERA_POSITION_WORLD, FRAGCOORD.xy)) { discard; }

// The party's feet (xyz, world) and the window's half-width at the party (w, world units; 0 = no window).
global uniform vec4 see_window;
// The camera the window is for (xyz, world) and how much nearer it a piece must be than the party to open (w).
global uniform vec4 see_window_eye;
// On in the copies of the materials the pieces that open are drawn with (SeeThrough.mark). A material's own uniform,
// not an instance uniform: those take a block of the global buffer for every mesh drawn with the shader, and a big
// place's floors, props and walls overflowed it.
uniform bool see_through = false;

// The window's middle over the party's feet (about a figure's middle), its height over its width (a standing party is
// taller than it is wide), and its dithered rim's share.
const float SEE_LIFT = 0.8;
const float SEE_TALL = 1.2;
const float SEE_RIM = 0.2;

bool see_cut(vec3 vertex, mat4 view_matrix, mat4 inv_view, vec3 eye, vec2 frag) {
	if (!see_through || see_window.w <= 0.0 || distance(eye, see_window_eye.xyz) > 0.02) {
		return false;
	}
	// Nothing below the party's feet opens: from above it can't hide the party or the ground round it, and opening it
	// showed down into a hollow tower rising out of a drop (Castle Ravenloft's roofs).
	if ((inv_view * vec4(vertex, 1.0)).y < see_window.y - 0.1) {
		return false;
	}
	vec3 party = (view_matrix * vec4(see_window.xyz + vec3(0.0, SEE_LIFT, 0.0), 1.0)).xyz;
	// Nearer the camera than the party (view space looks down -z): what stands beside or behind it stays.
	if (vertex.z < party.z + see_window_eye.w) {
		return false;
	}
	// Where the fragment falls on screen, measured at the party's distance.
	vec2 off = vertex.xy * (party.z / vertex.z) - party.xy;
	float r = length(off / vec2(see_window.w, see_window.w * SEE_TALL));
	// Interleaved gradient noise: a fine, even dither across the rim.
	float n = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
	return r < 1.0 - SEE_RIM * n;
}
