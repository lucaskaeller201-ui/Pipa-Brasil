shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Mãos em primeira pessoa (D-089). Pele realista (mistura de duas fotos de
// pele CC0, para o tom do pipeiro), relevo e oclusão. A projeção própria
// (proj_mao) deixa as mãos com um campo de visão fixo mesmo quando a câmera
// dá zoom na pipa — é o "modelo de visão" dos jogos em primeira pessoa.

uniform sampler2D pele_clara : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D pele_escura : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D relevo : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D orm : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float tom : hint_range(0.0, 1.0) = 0.45;   // 0 = pele clara, 1 = escura
uniform vec3 tinta : source_color = vec3(1.0);
uniform mat4 proj_mao;
uniform bool usar_proj = false;
// braço: sem textura (cor média da pele), com um leve sombreado
uniform bool braco = false;
uniform vec3 cor_braco : source_color = vec3(0.62, 0.42, 0.3);

void vertex() {
	if (usar_proj) {
		PROJECTION_MATRIX = proj_mao;
	}
}

void fragment() {
	if (braco) {
		ALBEDO = cor_braco;
		ROUGHNESS = 0.6;
		BACKLIGHT = cor_braco * 0.25;
	} else {
		vec3 c = mix(texture(pele_clara, UV).rgb, texture(pele_escura, UV).rgb, tom) * tinta;
		vec3 o = texture(orm, UV).rgb;
		ALBEDO = c;
		AO = o.r;
		AO_LIGHT_AFFECT = 0.6;
		ROUGHNESS = clamp(o.g, 0.35, 0.9);
		METALLIC = 0.0;
		NORMAL_MAP = texture(relevo, UV).rgb;
		NORMAL_MAP_DEPTH = 0.35;
		// pele deixa passar um pouco de luz (orelha, dedos contra o sol)
		BACKLIGHT = c * vec3(0.35, 0.12, 0.08);
	}
	// luz de contorno do céu, para a mão não sumir contra o fundo
	float aro = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.55, 0.65, 0.8) * aro * 0.12;
}
