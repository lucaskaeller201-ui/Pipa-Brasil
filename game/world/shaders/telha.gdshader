shader_type spatial;
// Telhado de telha de barro (D-065): fileiras de telhas com sombra entre
// elas, tons variados e um pouco de sujeira. Coordenadas do mundo.

varying vec3 mundo;
varying vec3 nm;

uniform float texturas = 0.0;   // D-067
uniform sampler2D t_telha : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_telha : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 m_telha = vec3(0.36);
uniform vec3 tom_barro : source_color = vec3(0.62, 0.3, 0.17);

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
	if (texturas > 0.5) {
		// foto de telhado: mantém o desenho das telhas, repintado de barro
		vec2 uvt = vec2(u, -v) / 3.0;
		vec3 det = texture(t_telha, uvt).rgb / m_telha;
		float l = dot(det, vec3(0.33));
		barro = tom_barro * mix(0.85, 1.15, tom) * mix(vec3(l), det, 0.25);
		NORMAL_MAP = texture(n_telha, uvt).rgb;
		NORMAL_MAP_DEPTH = 1.0;
	}
	ALBEDO = barro;
	ROUGHNESS = 0.8;
}
