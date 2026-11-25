shader_type spatial;
// Telhado de telha de barro (D-065): fileiras de telhas com sombra entre
// elas, tons variados e um pouco de sujeira. Coordenadas do mundo.

varying vec3 mundo;
varying vec3 nm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 t2 = normalize(vec2(-nm.z, nm.x) + vec2(0.0001));
	float u = dot(mundo.xz, t2);
	float v = mundo.y + dot(mundo.xz, normalize(nm.xz + vec2(0.0001))) * 0.6;
	float fila = floor(v / 0.28);
	float desloca = mod(fila, 2.0) * 0.5;
	float onda = sin((u / 0.22 + desloca) * 6.2832) * 0.5 + 0.5;   // canal da telha
	float sombra = smoothstep(0.0, 0.25, fract(v / 0.28));
	float tom = hash(vec2(floor(u / 0.22 + desloca), fila));
	vec3 barro = mix(vec3(0.6, 0.24, 0.12), vec3(0.78, 0.38, 0.2), tom);
	barro *= 0.75 + 0.25 * onda;
	barro *= 0.65 + 0.35 * sombra;
	barro = mix(barro, vec3(0.3, 0.28, 0.25), hash(floor(mundo.xz * 0.7)) * 0.15);
	ALBEDO = barro;
	ROUGHNESS = 0.8;
}
