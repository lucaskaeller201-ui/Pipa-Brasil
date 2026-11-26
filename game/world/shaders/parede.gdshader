shader_type spatial;
// Casas do bairro (D-057): parede rebocada e pintada ou tijolo aparente, com
// janelas e portas; o teto é laje de concreto. Coordenadas do mundo.

uniform vec3 cor : source_color = vec3(0.9, 0.8, 0.6);
uniform float tijolo = 0.0;      // 1 = tijolo aparente
uniform float semente = 0.0;
uniform float por_instancia = 0.0;
uniform float janelas = 1.0;   // D-069: 0 = janelas e portas são peças 3D   // D-068: cor vem de cada casinha (MultiMesh)
varying vec3 cor_inst;

varying vec3 mundo;
varying vec3 normal_mundo;

// D-067: fotos CC0 de reboco, tijolo e concreto (laje)
uniform float texturas = 0.0;
uniform sampler2D t_reboco : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_reboco : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_tijolo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_tijolo : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_concreto : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_concreto : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 m_reboco = vec3(0.68);
uniform vec3 m_tijolo = vec3(0.4);
uniform vec3 m_concreto = vec3(0.45);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + semente) * 43758.5453);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cor_inst = COLOR.rgb;
}

void fragment() {
	vec3 n = normal_mundo;
	vec3 c;
	float rug = 0.92;
	vec3 nm = vec3(0.5, 0.5, 1.0);
	vec3 base_cor = por_instancia > 0.5 ? cor_inst : cor;
	if (n.y > 0.5) {
		// laje: concreto com manchas
		float m = hash(floor(mundo.xz * 1.5));
		c = mix(vec3(0.55, 0.54, 0.52), vec3(0.45, 0.44, 0.43), m * 0.6);
		if (texturas > 0.5) {
			c = texture(t_concreto, mundo.xz / 2.0).rgb / m_concreto * vec3(0.52, 0.51, 0.49);
			nm = texture(n_concreto, mundo.xz / 2.0).rgb;
		}
	} else {
		vec2 t2 = normalize(vec2(-n.z, n.x));
		float u = dot(mundo.xz, t2);
		float v = mundo.y;
		if (tijolo > 0.5) {
			float fila = floor(v / 0.2);
			float uu = u / 0.4 + (mod(fila, 2.0) > 0.5 ? 0.5 : 0.0);
			float junta = step(0.9, fract(v / 0.2)) + step(0.92, fract(uu));
			float tom = hash(vec2(floor(uu), fila));
			c = mix(vec3(0.66, 0.3, 0.18), vec3(0.78, 0.4, 0.24), tom);
			c = mix(c, vec3(0.62, 0.58, 0.52), clamp(junta, 0.0, 1.0));
			if (texturas > 0.5) {
				c = texture(t_tijolo, vec2(u, -v) / 1.1).rgb / m_tijolo * vec3(0.55, 0.3, 0.22);
				nm = texture(n_tijolo, vec2(u, -v) / 1.1).rgb;
			}
		} else {
			float sujo = smoothstep(0.0, 1.2, 1.0 - fract(v / 3.0)) * 0.08;
			// reboco com manchas suaves e escorrido de chuva (D-065)
			float mancha = hash(floor(vec2(u * 0.7, v * 0.25))) * 0.08;
			float escorre = smoothstep(0.7, 1.0, hash(vec2(floor(u * 1.3), 3.0))) * smoothstep(0.0, 2.5, fract(-v / 3.0) * 3.0) * 0.12;
			c = base_cor * (0.97 - sujo - mancha - escorre + 0.04 * hash(floor(vec2(u, v) * 6.0)));
			if (texturas > 0.5) {
				vec3 det = texture(t_reboco, vec2(u, -v) / 2.0).rgb / m_reboco;
				c = base_cor * (0.97 - sujo - mancha * 0.5 - escorre) * mix(vec3(1.0), det, 0.85);
				nm = texture(n_reboco, vec2(u, -v) / 2.0).rgb;
			}
		}
		// janelas: uma por módulo de 3 m de largura e 3 m de altura
		vec2 cel = vec2(u / 3.0, v / 3.0);
		vec2 f = fract(cel);
		float andar = floor(cel.y);
		float tem = step(0.35, hash(floor(cel) + vec2(3.0, 7.0)));
		if (janelas > 0.5 && andar >= 0.0 && tem > 0.5 && f.x > 0.3 && f.x < 0.7 && f.y > 0.35 && f.y < 0.75) {
			bool moldura = f.x < 0.33 || f.x > 0.67 || f.y < 0.38 || f.y > 0.72;
			float acesa = step(0.85, hash(floor(cel) + vec2(11.0, 5.0)));
			// vidro reflete o céu (mais na beirada, como de verdade)
			float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
			vec3 vidro = mix(vec3(0.1, 0.14, 0.2), vec3(0.55, 0.68, 0.85), fres * 0.8 + 0.1);
			c = moldura ? vec3(0.85, 0.85, 0.82) : mix(vidro, vec3(1.0, 0.82, 0.5), acesa);
			nm = vec3(0.5, 0.5, 1.0);
			rug = moldura ? 0.6 : 0.08;
		}
		// porta (térreo)
		if (janelas > 0.5 && andar < 0.5 && andar >= 0.0 && f.x > 0.08 && f.x < 0.24 && f.y < 0.7 && hash(floor(cel) + vec2(1.0, 9.0)) > 0.6) {
			c = vec3(0.35, 0.22, 0.12);
		}
	}
	// sombra de contato no pé da parede e na quina com a laje
	c *= mix(0.62, 1.0, smoothstep(0.0, 1.4, mundo.y));
	ALBEDO = c;
	ROUGHNESS = rug;
	if (texturas > 0.5) {
		NORMAL_MAP = nm;
		NORMAL_MAP_DEPTH = 0.8;
	}
}
