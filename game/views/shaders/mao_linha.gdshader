shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
// Linha entre as mãos (D-089), com a mesma projeção das mãos.

// campo de visão próprio: encolhe/estica x e y no espaço da câmera, para a
// mão aparecer como se a câmera tivesse o campo de visão das mãos
uniform float escala_vm = 1.0;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.xy *= escala_vm;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	TANGENT = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
	BINORMAL = normalize((MODELVIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
