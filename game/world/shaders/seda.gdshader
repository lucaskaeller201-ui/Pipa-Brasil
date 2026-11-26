shader_type spatial;
render_mode cull_disabled;
// Papel de seda da pipa (D-075): fibra do papel, leve amassado (relevo), um
// pouco de brilho e, principalmente, a luz ATRAVESSANDO o papel: contra o
// sol a pipa acende na cor dela e as varetas aparecem como sombra por dentro.
// Só desenho: a forma e o movimento vêm da física.

uniform float vareta_sup_y = 0.1;
uniform float vareta_inf_y = -0.1;
uniform float vareta_larg = 0.006;
uniform float transmissao = 0.85;

varying vec3 local;
varying float vareta;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local.xy;
	// fibra fina do papel + manchas largas (seda não é uniforme)
	float fibra = ruido(p * vec2(420.0, 160.0)) * 0.5 + ruido(p * 90.0) * 0.5;
	float mancha = ruido(p * 9.0);
	ALBEDO = COLOR.rgb * (0.93 + 0.07 * fibra) * (0.96 + 0.08 * mancha);
	// amassado: relevo suave de dobras
	float a = ruido(p * 28.0 + vec2(3.1, 7.7));
	float b = ruido(p * 28.0 + vec2(9.2, 1.4));
	NORMAL_MAP = normalize(vec3(0.5 + (a - 0.5) * 0.35, 0.5 + (b - 0.5) * 0.35, 1.0));
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
	// onde passam as varetas (a central e as duas atravessadas, que vergam)
	float bojo = local.x * local.x * 0.25;
	float v = 1.0 - smoothstep(0.0, vareta_larg, abs(local.x));
	v = max(v, 1.0 - smoothstep(0.0, vareta_larg, abs(local.y - vareta_sup_y - bojo)));
	v = max(v, 1.0 - smoothstep(0.0, vareta_larg, abs(local.y - vareta_inf_y - bojo)));
	vareta = v;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float frente = max(ndl, 0.0);
	float tras = max(-ndl, 0.0);
	// luz que atravessa o papel, mais forte olhando contra o sol
	float contra = pow(max(dot(-VIEW, LIGHT), 0.0), 2.0) * 0.6 + 0.4;
	float passa = tras * transmissao * contra * (1.0 - 0.75 * vareta);
	DIFFUSE_LIGHT += (frente + passa) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 40.0) * 0.25 * frente * ATTENUATION * LIGHT_COLOR / PI;
}
