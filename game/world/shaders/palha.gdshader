shader_type spatial;
render_mode cull_disabled;
// Folha de coqueiro (D-065): uma tira que verga com o peso e se divide em
// folíolos (os "dentes" da palha), balançando com o vento.

uniform vec3 cor : source_color = vec3(0.22, 0.45, 0.14);
uniform float comprimento = 3.0;
varying float ao_longo;

void vertex() {
	// a tira vai de z=-comprimento/2 a +comprimento/2; verga para baixo na ponta
	float t = clamp((VERTEX.z + comprimento * 0.5) / comprimento, 0.0, 1.0);
	ao_longo = t;
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y -= t * t * comprimento * 0.45;
	VERTEX.y += sin(TIME * 2.0 + mundo.x * 0.5 + t * 2.0) * 0.08 * t;
}

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;           // 0 no talo, 1 na borda
	float largura = sin(ao_longo * 3.14159) * 0.95 + 0.05;
	float foliolo = fract(ao_longo * 34.0);
	bool talo = x < 0.06;
	if (!talo && (x > largura || foliolo > 0.55 + 0.4 * (1.0 - x))) {
		discard;
	}
	vec3 c = talo ? cor * 0.7 + vec3(0.1, 0.08, 0.0) : cor * (0.85 + 0.3 * x);
	ALBEDO = c;
	ROUGHNESS = 0.7;
}
