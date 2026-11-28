shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
// Árvore de verdade vista de longe (D-100): a árvore do Poly Haven foi
// fotografada de 4 lados no Blender (tools/recursos/converter.py) e aqui vira
// um cartão que sempre olha para a câmera, mostrando o lado certo. Um cartão
// tem 2 triângulos (a árvore original tem 1,6 a 3,9 milhões).

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tom : source_color = vec3(1.0);
uniform float brilho = 1.35;
varying vec2 uv_atlas;
varying float altura;

void vertex() {
	vec3 centro = MODEL_MATRIX[3].xyz;
	float esc = length(MODEL_MATRIX[0].xyz);
	vec3 para = CAMERA_POSITION_WORLD - centro;
	vec3 dir = normalize(vec3(para.x, 0.0, para.z) + vec3(1e-4, 0.0, 0.0));
	vec3 direita = normalize(cross(vec3(0.0, 1.0, 0.0), dir));
	float giro = atan(MODEL_MATRIX[2].x, MODEL_MATRIX[2].z);
	float rel = atan(dir.x, dir.z) - giro;
	float lado = mod(floor(rel / (TAU * 0.25) + 0.5), 4.0);
	vec2 q = vec2(UV.x - 0.5, 0.5 - UV.y);
	VERTEX = centro + (direita * q.x + vec3(0.0, 1.0, 0.0) * q.y) * esc;
	NORMAL = dir;
	uv_atlas = vec2((lado + UV.x) * 0.25, UV.y);
	altura = UV.y;
}

void fragment() {
	vec4 c = texture(atlas, uv_atlas);
	ALBEDO = c.rgb * tom * brilho * mix(1.0, 0.75, altura);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
