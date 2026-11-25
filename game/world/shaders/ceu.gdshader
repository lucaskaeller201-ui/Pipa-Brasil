shader_type sky;
// Céu de fim de tarde (D-057): degradê, sol com brilho e nuvens que andam.
// Tudo por código (sem textura), roda no navegador (Compatibility).

uniform vec3 topo : source_color = vec3(0.13, 0.24, 0.52);
uniform vec3 horizonte : source_color = vec3(1.0, 0.58, 0.28);
uniform vec3 baixo : source_color = vec3(0.32, 0.22, 0.16);
uniform float cobertura = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * ruido(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Densidade das nuvens (D-065): ruído "dobrado" (domain warp) dá formas de
// cúmulo, com bordas fofas, em vez de manchas.
float densidade(vec2 uv, float cob) {
	vec2 w = vec2(fbm(uv * 0.7 + vec2(TIME * 0.004, 0.0)), fbm(uv * 0.7 + vec2(5.2, 1.3)));
	float n = fbm(uv + w * 1.4);
	return smoothstep(1.0 - cob, 1.0 - cob + 0.32, n);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 cor;
	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 0.42);
		cor = mix(horizonte, topo, t);
		float sol = 0.0;
		vec3 cor_sol = vec3(1.0, 0.8, 0.55);
		if (LIGHT0_ENABLED) {
			sol = max(dot(d, LIGHT0_DIRECTION), 0.0);
			cor_sol = LIGHT0_COLOR;
			cor += cor_sol * (pow(sol, 900.0) * 6.0 + pow(sol, 18.0) * 0.45 + pow(sol, 3.0) * 0.12);
		}
		vec2 uv = d.xz / max(h, 0.06) * 0.55 + vec2(TIME * 0.008, TIME * 0.003);
		float nuvem = densidade(uv, cobertura) * smoothstep(0.0, 0.12, h);
		// luz na nuvem: um passo na direção do sol — onde há mais nuvem entre
		// o ponto e o sol, a nuvem fica mais escura (barriga cinza, topo claro)
		vec2 para_sol = normalize(LIGHT0_DIRECTION.xz + vec2(0.0001)) * 0.18;
		float sombra = densidade(uv + para_sol, cobertura);
		vec3 claro = mix(vec3(1.0, 0.7, 0.52), vec3(1.0, 0.98, 0.95), clamp(h * 2.5, 0.0, 1.0));
		vec3 escuro = mix(horizonte * 0.55, topo * 0.6 + vec3(0.25), 0.5);
		vec3 cor_nuvem = mix(claro, escuro, clamp(sombra * 0.75 - nuvem * 0.15, 0.0, 1.0));
		// borda prateada perto do sol
		cor_nuvem += cor_sol * pow(sol, 8.0) * (1.0 - nuvem) * 1.2;
		cor = mix(cor, cor_nuvem, nuvem * 0.92);
	} else {
		cor = mix(horizonte * 0.75, baixo, clamp(-h * 5.0, 0.0, 1.0));
	}
	COLOR = cor;
}
