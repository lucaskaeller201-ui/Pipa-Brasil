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
	for (int k = 0; k < 4; k++) {
		v += a * ruido(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
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
		float n = fbm(uv);
		float nuvem = smoothstep(1.0 - cobertura, 1.0 - cobertura + 0.28, n) * smoothstep(0.0, 0.12, h);
		vec3 cor_nuvem = mix(vec3(1.0, 0.62, 0.45), vec3(1.0, 0.93, 0.86), clamp(h * 2.5, 0.0, 1.0));
		cor_nuvem = mix(cor_nuvem, cor_sol * 1.3, pow(sol, 6.0) * 0.6);
		cor = mix(cor, cor_nuvem, nuvem * 0.85);
	} else {
		cor = mix(horizonte * 0.75, baixo, clamp(-h * 5.0, 0.0, 1.0));
	}
	COLOR = cor;
}
