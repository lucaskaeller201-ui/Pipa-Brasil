shader_type spatial;
// Chão do bairro (D-057): ruas de asfalto com calçada e faixa, e o resto de
// terra e cimento batido com manchas. Coordenadas do mundo (sem textura).

uniform vec4 rua_x1 = vec4(-1000.0, 1000.0, 26.0, 34.0);   // xmin, xmax, zmin, zmax
uniform vec4 rua_x2 = vec4(-1000.0, 1000.0, -62.0, -54.0);
uniform vec4 rua_z1 = vec4(-60.0, -52.0, -1000.0, 1000.0);
uniform vec4 rua_z2 = vec4(62.0, 70.0, -1000.0, 1000.0);

uniform float praia = 0.0;       // 1 = mapa da praia (D-063)
uniform float calcadao_z = -30.0; // começa o calçadão (para o mar é -Z)
uniform float areia_z = -37.0;    // começa a areia

varying vec3 mundo;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0 fora; 1 asfalto; 2 calçada. eixo = coordenada ao longo da rua; meio = distância ao centro
vec3 na_rua(vec4 r, vec2 p, bool ao_longo_x) {
	float cal = 1.6;
	if (p.x < r.x - cal || p.x > r.y + cal || p.y < r.z - cal || p.y > r.w + cal) {
		return vec3(0.0);
	}
	bool asf = p.x >= r.x && p.x <= r.y && p.y >= r.z && p.y <= r.w;
	float meio = ao_longo_x ? abs(p.y - (r.z + r.w) * 0.5) : abs(p.x - (r.x + r.y) * 0.5);
	float eixo = ao_longo_x ? p.x : p.y;
	return vec3(asf ? 1.0 : 2.0, eixo, meio);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = mundo.xz;
	float n = ruido(p * 0.35) * 0.6 + ruido(p * 2.1) * 0.4;
	if (praia > 0.5 && p.y < calcadao_z) {
		if (p.y > areia_z) {
			// calçadão de pedra portuguesa: as ondas pretas e brancas
			float onda = sin(p.x * 0.55) * 1.1;
			float faixa = fract((p.y + onda) / 1.6);
			ALBEDO = faixa < 0.5 ? vec3(0.08, 0.08, 0.09) : vec3(0.92, 0.9, 0.85);
			ROUGHNESS = 0.55;
		} else {
			// areia clara, mais escura e molhada perto do mar
			float molhada = smoothstep(-80.0, -95.0, p.y);
			vec3 seca = mix(vec3(0.93, 0.85, 0.66), vec3(0.97, 0.9, 0.74), n);
			ALBEDO = mix(seca, vec3(0.7, 0.6, 0.45), molhada);
			ROUGHNESS = mix(0.95, 0.35, molhada);
		}
		return;
	}
	// terra batida mais escura, com manchas de mato (de dia não fica branca)
	vec3 terra = mix(vec3(0.3, 0.24, 0.18), vec3(0.4, 0.34, 0.26), n);
	terra = mix(terra, vec3(0.22, 0.34, 0.14), smoothstep(0.55, 0.72, ruido(p * 0.045 + vec2(7.0, 3.0))) * 0.85);
	vec3 cor = terra;
	float rug = 0.95;
	vec3 r = na_rua(rua_x1, p, true);
	vec3 r2 = na_rua(rua_x2, p, true);
	if (r2.x > r.x) { r = r2; }
	vec3 r3 = na_rua(rua_z1, p, false);
	if (r3.x > r.x) { r = r3; }
	vec3 r4 = na_rua(rua_z2, p, false);
	if (r4.x > r.x) { r = r4; }
	if (r.x > 1.5) {
		float lajota = step(0.94, fract(p.x * 0.5)) + step(0.94, fract(p.y * 0.5));
		cor = mix(vec3(0.68, 0.66, 0.62), vec3(0.5, 0.49, 0.47), clamp(lajota, 0.0, 1.0)) * (0.9 + 0.1 * n);
		rug = 0.9;
	} else if (r.x > 0.5) {
		cor = mix(vec3(0.16, 0.16, 0.17), vec3(0.24, 0.23, 0.23), n);
		// faixa amarela tracejada no meio
		if (r.z < 0.08 && fract(r.y * 0.25) < 0.5) {
			cor = vec3(0.85, 0.7, 0.15);
		}
		rug = 0.8;
	}
	ALBEDO = cor;
	ROUGHNESS = rug;
}
