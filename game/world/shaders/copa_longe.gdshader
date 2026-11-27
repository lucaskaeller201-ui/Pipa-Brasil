shader_type spatial;
// Copas de árvore da mata da serra, vistas de longe (D-085): sólidas (sem
// furos), com a variação de verde calculada nos vértices — muito mais leve que
// a folhagem de perto.

uniform vec3 verde_escuro : source_color = vec3(0.1, 0.24, 0.08);
uniform vec3 verde_claro : source_color = vec3(0.3, 0.46, 0.16);
varying vec3 tom;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	vec3 m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = hash3(floor(m * 1.7));
	VERTEX += NORMAL * (n - 0.5) * 0.18;   // copa irregular, sem ser bola lisa
	tom = mix(verde_escuro, verde_claro, clamp(n * 0.8 + NORMAL.y * 0.35, 0.0, 1.0));
}

void fragment() {
	ALBEDO = tom;
	ROUGHNESS = 0.9;
}
