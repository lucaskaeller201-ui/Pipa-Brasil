shader_type spatial;
// Morro ao fundo (D-057): casinhas coladas umas nas outras subindo o morro,
// com mato verde no alto. Visto de longe, por código.

varying vec3 mundo;
uniform float topo_verde = 38.0;
uniform bool so_mata = false;   // D-065: morro só de mata (praia), sem casinhas

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(12.9898, 78.233))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1, 0), vec2(12.9898, 78.233))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0, 1), vec2(12.9898, 78.233))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1, 1), vec2(12.9898, 78.233))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c;
	if (so_mata) {
		// mata atlântica: copas em tons misturados, mais clara no alto
		vec2 q = mundo.xz * 0.12 + vec2(mundo.y * 0.05);
		float n = ruido(q) * 0.5 + ruido(q * 2.7) * 0.3 + ruido(q * 7.0) * 0.2;
		c = mix(vec3(0.07, 0.2, 0.08), vec3(0.24, 0.4, 0.14), n);
		c *= 0.85 + 0.25 * clamp(mundo.y / 120.0, 0.0, 1.0);
	} else {
		vec2 cel = vec2(mundo.x / 6.0, mundo.y / 4.5 + floor(mundo.z / 12.0) * 0.37);
		vec2 i = floor(cel);
		vec2 f = fract(cel);
		float h = hash(i);
		if (h < 0.2) c = vec3(0.86, 0.82, 0.72);
		else if (h < 0.4) c = vec3(0.7, 0.38, 0.25);
		else if (h < 0.55) c = vec3(0.92, 0.72, 0.45);
		else if (h < 0.7) c = vec3(0.6, 0.66, 0.72);
		else if (h < 0.85) c = vec3(0.78, 0.5, 0.42);
		else c = vec3(0.95, 0.93, 0.88);
		if (f.y > 0.82) c *= 0.55;                      // laje/sombra
		if (f.x > 0.35 && f.x < 0.6 && f.y > 0.3 && f.y < 0.6) c *= 0.35;  // janela
		float verde = smoothstep(topo_verde - 12.0, topo_verde + 6.0, mundo.y + hash(i * 0.37) * 10.0);
		c = mix(c, mix(vec3(0.16, 0.32, 0.14), vec3(0.24, 0.42, 0.18), hash(i * 1.7)), verde);
		c *= 0.8;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
