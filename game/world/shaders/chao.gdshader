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

// D-067: fotos CC0 (Poly Haven). "m_" = cor média da foto, para repintar.
uniform float texturas = 0.0;
uniform sampler2D t_asfalto : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_asfalto : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_concreto : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_concreto : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_terra : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_terra : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_grama : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_grama : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_areia : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_areia : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 m_asfalto = vec3(0.35);
uniform vec3 m_concreto = vec3(0.45);
uniform vec3 m_terra = vec3(0.4);
uniform vec3 m_grama = vec3(0.4);
uniform vec3 m_areia = vec3(0.5);

// Duas leituras em escalas/ângulos diferentes: esconde a repetição da foto.
vec3 foto(sampler2D t, vec2 p, float metros) {
	vec2 uv = p / metros;
	vec3 a = texture(t, uv).rgb;
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.37 + vec2(0.31, 0.17);
	return mix(a, texture(t, uv2).rgb, 0.35);
}

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
	if (praia > 0.5 && p.y < calcadao_z) {
		if (p.y > areia_z) {
			// calçadão de pedra portuguesa: as ondas pretas e brancas
			float ondinha = sin(p.x * 0.55) * 1.1;
			float faixa = fract((p.y + ondinha) / 1.6);
			cor = faixa < 0.5 ? vec3(0.08, 0.08, 0.09) : vec3(0.92, 0.9, 0.85);
			rug = 0.55;
		} else {
			// areia clara, mais escura e molhada perto do mar
			float molhada = smoothstep(-80.0, -95.0, p.y);
			vec3 seca = mix(vec3(0.86, 0.77, 0.58), vec3(0.92, 0.84, 0.66), n);
			cor = mix(seca, vec3(0.62, 0.52, 0.38), molhada);
			rug = mix(0.95, 0.35, molhada);
		}
	} else if (r.x > 1.5) {
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
	if (texturas > 0.5) {
		// D-067: mesmas áreas, agora com foto de verdade repintada na cor certa
		vec3 nm = vec3(0.5, 0.5, 1.0);
		float macro = 0.85 + 0.3 * ruido(p * 0.02);
		if (praia > 0.5 && p.y < calcadao_z) {
			if (p.y > areia_z) {
				vec3 det = foto(t_concreto, p, 2.0) / m_concreto;
				cor *= mix(vec3(1.0), det, 0.6);
				nm = texture(n_concreto, p / 2.0).rgb;
			} else {
				float molhada = smoothstep(-80.0, -95.0, p.y);
				vec3 det = foto(t_areia, p, 2.5) / m_areia;
				cor = mix(vec3(0.9, 0.82, 0.64), vec3(0.6, 0.5, 0.37), molhada) * det;
				nm = texture(n_areia, p / 2.5).rgb;
			}
		} else if (r.x > 1.5) {
			float lajota = step(0.96, fract(p.x * 0.5)) + step(0.96, fract(p.y * 0.5));
			cor = foto(t_concreto, p, 2.0) / m_concreto * vec3(0.62, 0.6, 0.57) * (1.0 - 0.3 * clamp(lajota, 0.0, 1.0));
			nm = texture(n_concreto, p / 2.0).rgb;
		} else if (r.x > 0.5) {
			cor = foto(t_asfalto, p, 3.0) / m_asfalto * vec3(0.2, 0.2, 0.21) * macro;
			if (r.z < 0.08 && fract(r.y * 0.25) < 0.5) {
				cor = vec3(0.8, 0.66, 0.15) * (0.7 + 0.3 * foto(t_asfalto, p, 3.0) / m_asfalto);
			}
			nm = texture(n_asfalto, p / 3.0).rgb;
		} else {
			float mato = smoothstep(0.5, 0.72, ruido(p * 0.045 + vec2(7.0, 3.0)));
			vec3 chao_terra = foto(t_terra, p, 3.0) / m_terra * vec3(0.34, 0.27, 0.19);
			vec3 chao_grama = foto(t_grama, p, 4.0) / m_grama * vec3(0.24, 0.32, 0.13);
			cor = mix(chao_terra, chao_grama, mato) * macro;
			nm = mix(texture(n_terra, p / 3.0).rgb, texture(n_grama, p / 4.0).rgb, mato);
		}
		NORMAL_MAP = nm;
		NORMAL_MAP_DEPTH = 1.0;
	}
	ALBEDO = cor;
	ROUGHNESS = rug;
}
