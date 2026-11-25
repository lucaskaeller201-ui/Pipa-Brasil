shader_type spatial;
render_mode cull_disabled;
// Copa de árvore (D-065): bolas de folhagem "furadas" por ruído (vira um monte
// de folhas, não uma bola lisa), cores variadas, topo mais claro, balanço com
// o vento. Leve: sem textura.

uniform vec3 verde_escuro : source_color = vec3(0.1, 0.25, 0.07);
uniform vec3 verde_claro : source_color = vec3(0.35, 0.55, 0.16);
uniform float furos = 0.47;
uniform float escala_folha = 5.0;

varying vec3 mundo;
varying vec3 local_n;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float ruido3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_n = NORMAL;
	float balanco = sin(TIME * 1.4 + mundo.x * 0.35 + mundo.z * 0.21) * 0.06;
	VERTEX += vec3(balanco, 0.0, balanco * 0.6) * (0.6 + 0.4 * NORMAL.y);
}

void fragment() {
	float n = ruido3(mundo * escala_folha) * 0.65 + ruido3(mundo * escala_folha * 2.3) * 0.35;
	// mais furos na borda (silhueta recortada) e menos no miolo
	float borda = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	if (n < furos + borda * 0.25) {
		discard;
	}
	float tom = ruido3(mundo * 1.3);
	vec3 c = mix(verde_escuro, verde_claro, clamp(n * 1.2 - 0.2 + local_n.y * 0.25 + (tom - 0.5) * 0.4, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
