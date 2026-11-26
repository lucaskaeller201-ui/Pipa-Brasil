shader_type sky;
// Céu de foto (HDRI CC0 do Poly Haven, D-075). A foto gira para o sol dela
// ficar exatamente onde está a luz do sol do jogo (a luz e as sombras batem
// com o céu). Abaixo do horizonte, um degradê para a cor da névoa.

uniform sampler2D foto : filter_linear, repeat_enable;
uniform float foto_sol_u = 0.5;      // onde (0..1, da esquerda) está o sol na foto
uniform float energia = 1.0;
uniform vec3 cor_baixo : source_color = vec3(0.5, 0.55, 0.6);

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 L = normalize(LIGHT0_DIRECTION);
	float az_sol = atan(L.x, -L.z);
	float az = atan(d.x, -d.z);
	float u = fract((az - az_sol) / (2.0 * PI) + foto_sol_u);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float v = 0.5 - el / PI;
	vec3 c = texture(foto, vec2(u, clamp(v, 0.0, 0.5))).rgb * energia;
	// abaixo do horizonte: a foto "inventa" um chão espelhado; usamos a cor
	// do horizonte esmaecendo para a cor da névoa (o chão do jogo cobre)
	if (d.y < 0.0) {
		c = mix(c, cor_baixo, smoothstep(0.0, -0.08, d.y));
	}
	COLOR = c;
}
