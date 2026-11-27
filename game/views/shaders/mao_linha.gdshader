shader_type spatial;
render_mode unshaded, cull_disabled;
// Linha entre as mãos (D-089), com a mesma projeção das mãos.

uniform mat4 proj_mao;
uniform bool usar_proj = false;

void vertex() {
	if (usar_proj) {
		PROJECTION_MATRIX = proj_mao;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
