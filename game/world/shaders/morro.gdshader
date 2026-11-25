shader_type spatial;
// Morro ao fundo (D-057): casinhas coladas umas nas outras subindo o morro,
// com mato verde no alto. Visto de longe, por código.

varying vec3 mundo;
uniform float topo_verde = 60.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cel = vec2(mundo.x / 4.0, mundo.y / 3.2 + floor(mundo.z / 9.0) * 0.37);
	vec2 i = floor(cel);
	vec2 f = fract(cel);
	float h = hash(i);
	vec3 c;
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
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
