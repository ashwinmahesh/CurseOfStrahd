// How a seamless world texture lies on a box of any size (docs/art/textures.md), shared by the Modern finish's lit
// world shaders: top faces take x and z, side faces the horizontal axis they run along and the height, so every box
// has one texel density and neighbouring squares line up. Classic's cel_world.gdshader keeps its own copy (frozen).

// The world axes a face's texture runs along, in world units: top faces x and z, side faces the horizontal axis they
// run along and the height (down).
vec2 world_axes(vec3 p, vec3 wn) {
	vec3 n = abs(wn);
	if (n.y >= n.x && n.y >= n.z) {
		return p.xz;
	} else if (n.x >= n.z) {
		return vec2(p.z, -p.y);
	}
	return vec2(p.x, -p.y);
}

// The texture coordinates of a point on a face (world position, world normal), in tiles of `tile_units` squares.
// `wall_band` (wainscot walls, wrapped in x only) maps a side face's v once from `band_top` down `band_height`.
vec2 world_uv(vec3 p, vec3 wn, float tile_units, vec2 offset, bool wall_band, float band_top, float band_height) {
	vec3 n = abs(wn);
	bool top = n.y >= n.x && n.y >= n.z;
	vec2 uv = world_axes(p, wn) / tile_units + offset;
	if (wall_band && !top) {
		uv.y = clamp((band_top - p.y) / band_height, 0.0, 0.999);
	}
	return uv;
}

// Whether a face is a top (floor, roof flat, table top) rather than a side.
bool world_top(vec3 wn) {
	vec3 n = abs(wn);
	return n.y >= n.x && n.y >= n.z;
}

// A tangent-space normal map sample (0..1) laid on the face the texture is projected on, as a world normal. OpenGL
// convention, as Godot's Image.bump_map_to_normal_map makes them: red towards the image's right, green towards its
// top, so `t` runs with u and `b` against v (on a wall, up). The map's z is rebuilt from x and y, so two-channel
// (compressed) normal maps read the same as full ones.
vec3 world_relief(vec3 wn, vec3 map_rgb, float strength) {
	vec3 n = abs(wn);
	vec3 t;
	vec3 b;
	if (n.y >= n.x && n.y >= n.z) {
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 0.0, -1.0);
	} else if (n.x >= n.z) {
		t = vec3(0.0, 0.0, 1.0);
		b = vec3(0.0, 1.0, 0.0);
	} else {
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 1.0, 0.0);
	}
	vec2 xy = map_rgb.xy * 2.0 - 1.0;
	float z = sqrt(max(1.0 - dot(xy, xy), 0.0));
	xy *= strength;
	return normalize(t * xy.x + b * xy.y + normalize(wn) * max(z, 0.05));
}
