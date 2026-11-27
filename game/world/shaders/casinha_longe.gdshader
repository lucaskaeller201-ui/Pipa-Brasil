shader_type spatial;
// Casinhas da serra, vistas de longe (D-085): leve para a placa de vídeo —
// sem fotos e sem ruído por ponto. Cor de cada casa (MultiMesh), janelas
// escuras numa grade de 3 m, laje cinza em cima e sombra no pé.

varying vec3 mundo;
varying vec3 nm;
varying vec3 cor;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cor = COLOR.rgb;
}

void fragment() {
	vec3 c = cor;
	if (nm.y > 0.5) {
		c = vec3(0.55, 0.54, 0.52);
	} else {
		float u = abs(nm.x) > 0.5 ? mundo.z : mundo.x;
		vec2 f = fract(vec2(u / 2.6, mundo.y / 2.9));
		float janela = step(0.35, f.x) * step(f.x, 0.7) * step(0.35, f.y) * step(f.y, 0.75);
		c = mix(c, vec3(0.08, 0.09, 0.11), janela * 0.85);
		c *= mix(0.7, 1.0, clamp(f.y * 3.0, 0.0, 1.0));
	}
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
