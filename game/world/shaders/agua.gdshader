shader_type spatial;
// Mar da praia (D-063): ondinhas por código, brilho do sol na água e espuma
// perto da areia. Leve: sem textura e sem reflexo em tempo real.

uniform vec3 fundo : source_color = vec3(0.02, 0.22, 0.32);
uniform vec3 raso : source_color = vec3(0.1, 0.55, 0.6);
uniform float beira = -95.0;     // z da beira da areia

varying vec3 mundo;

float onda(vec2 p, vec2 d, float freq, float vel) {
	return sin(dot(p, d) * freq + TIME * vel);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = mundo.xz;
	// inclinação das ondas (derivadas de três senos)
	float dx = cos(p.x * 0.35 + TIME * 1.1) * 0.35 * 0.18 + cos((p.x + p.y) * 0.9 + TIME * 1.7) * 0.9 * 0.06;
	float dz = cos(p.y * 0.42 + TIME * 1.3) * 0.42 * 0.2 + cos((p.x + p.y) * 0.9 + TIME * 1.7) * 0.9 * 0.06;
	vec3 n_mundo = normalize(vec3(-dx, 1.0, -dz));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_mundo, 0.0)).xyz);
	float dist_beira = clamp((beira - p.y) / 60.0, 0.0, 1.0);
	vec3 c = mix(raso, fundo, dist_beira);
	// espuma na beira, indo e voltando
	float vai_vem = sin(TIME * 0.6) * 2.0;
	float espuma = smoothstep(4.0, 0.0, (beira - p.y) + vai_vem) * (0.6 + 0.4 * onda(p, vec2(1.0, 0.2), 1.7, 2.0));
	c = mix(c, vec3(0.95, 0.97, 0.98), clamp(espuma, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = mix(0.06, 0.9, clamp(espuma, 0.0, 1.0));
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
