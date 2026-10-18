// The thread out of the hollow sarcophagus (Amber Temple Look Plan step 10, AmberGlow): a very thin crimson line rising
// out of the dead amber into the dark toward the valley, where what it was tied to still lives. Faint always, bright once
// someone has seen it (the party's Arcana read of the hollow, flag amber_thread_seen). It sways a little as it climbs and
// a bead of light runs up it now and then. Drawn added over the scene, never lit. One material per hollow.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.78, 0.07, 0.1);
// How bright it burns now: AmberGlow eases it between faint and bright.
uniform float strength : hint_range(0.0, 3.0) = 0.4;
// How tall the cylinder is (local units), so the foot and the top can be told apart.
uniform float thread_length = 10.0;

varying float along;   // 0 at the foot, 1 at the top

void vertex() {
	along = clamp(VERTEX.y / max(thread_length, 0.01) + 0.5, 0.0, 1.0);
	VERTEX.x += sin(VERTEX.y * 1.3 + TIME * 0.8) * 0.07 * along;
	VERTEX.z += cos(VERTEX.y * 0.9 + TIME * 0.6) * 0.05 * along;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 1.6);
	float beads = pow(0.5 + 0.5 * sin(along * thread_length * 1.7 - TIME * 1.4), 7.0);
	float ends = smoothstep(0.0, 0.05, along) * (1.0 - smoothstep(0.55, 1.0, along));
	ALBEDO = colour * strength * core * (0.6 + 1.4 * beads) * ends;
}
