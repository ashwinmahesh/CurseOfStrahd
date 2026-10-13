shader_type spatial;
// The outline round a 2D piece that a Search or a check just found, where something stands well in front of it: drawn
// over everything and kept to those pixels by the depth it reads (found_outline_sprite.gdshaderinc, XRAY).
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled, blend_mix;

#define XRAY
#include "res://shaders/world/found_outline_sprite.gdshaderinc"
