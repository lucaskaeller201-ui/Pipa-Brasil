extends RefCounted
## Texturas fotográficas CC0 do Poly Haven (D-067), baixadas pelo GitHub
## Actions (tools/baixar_texturas.py). Se faltarem (ex.: cópia sem as
## imagens), os shaders continuam com o desenho feito por código.

const PASTA := "res://assets/texturas/"

## Cor média de cada foto (medida ao baixar): os shaders "repintam" a foto
## para a cor desejada mantendo o detalhe — assim a cena não fica escura nem
## com cor estranha.
const MEDIA := {
	"areia": Color(0.51, 0.45, 0.36), "asfalto": Color(0.35, 0.35, 0.33),
	"casca": Color(0.26, 0.21, 0.16), "concreto": Color(0.47, 0.43, 0.35),
	"grama": Color(0.45, 0.38, 0.14), "reboco": Color(0.69, 0.66, 0.61),
	"telha": Color(0.36, 0.31, 0.23), "terra": Color(0.4, 0.33, 0.2),
	"tijolo": Color(0.42, 0.33, 0.29),
	"piso": Color(0.48, 0.44, 0.42), "tecido": Color(0.76, 0.67, 0.62),
}


static func existe(vaga: String) -> bool:
	return ResourceLoader.exists(PASTA + vaga + "_cor.jpg")


static func cor(vaga: String) -> Texture2D:
	return load(PASTA + vaga + "_cor.jpg") if existe(vaga) else null


static func relevo(vaga: String) -> Texture2D:
	var p := PASTA + vaga + "_normal.jpg"
	return load(p) if ResourceLoader.exists(p) else null


## D-080: material comum (StandardMaterial3D) com a foto projetada nos três
## eixos (para peças sem UV), repintada para a cor `cor`. `metros` = tamanho
## de uma repetição da foto. `mistura` 0..1 = quanto da cor da foto entra.
static func material(vaga: String, tinta: Color, metros := 2.0, mundo := true, mistura := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tinta
	if not existe(vaga):
		return m
	var media: Color = MEDIA[vaga]
	var lum := (media.r + media.g + media.b) / 3.0
	var alvo := tinta.lerp(media, mistura)
	m.albedo_color = Color(alvo.r / lum, alvo.g / lum, alvo.b / lum) if mistura > 0.0 else Color(tinta.r / media.r, tinta.g / media.g, tinta.b / media.b)
	m.albedo_texture = cor(vaga)
	var n := relevo(vaga)
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
	m.uv1_triplanar = true
	m.uv1_world_triplanar = mundo
	m.uv1_scale = Vector3.ONE / metros
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Liga as texturas num ShaderMaterial: parâmetros t_<vaga>, n_<vaga> e
## m_<vaga> (cor média); "texturas" = 1 só se todas existirem.
static func aplicar(mat: ShaderMaterial, vagas: Array) -> bool:
	for v in vagas:
		if not existe(String(v)):
			mat.set_shader_parameter("texturas", 0.0)
			return false
	for v in vagas:
		mat.set_shader_parameter("t_" + String(v), cor(String(v)))
		mat.set_shader_parameter("n_" + String(v), relevo(String(v)))
		var m: Color = MEDIA[String(v)]
		mat.set_shader_parameter("m_" + String(v), Vector3(m.r, m.g, m.b))
	mat.set_shader_parameter("texturas", 1.0)
	return true
