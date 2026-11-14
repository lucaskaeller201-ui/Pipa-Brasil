class_name KiteDefinition
extends Resource
## Parâmetros de um modelo de pipa.
##
## Coordenadas locais com origem no centro de massa:
##   X = envergadura (direita), Y = espinha (bico para cima),
##   Z = frente (lado do cabresto, voltado para o pipeiro).
## Cada modelo de pipa da Fase 6 será um arquivo .tres com estes campos.

@export var model_name := "Raia de laboratório"
@export var mass := 0.025                              ## kg
@export var inertia := Vector3(3.75e-4, 2.6e-4, 6.35e-4)  ## kg·m², momentos principais (X, Y, Z locais)
@export var reference_chord := 0.6                     ## m: escala do deslocamento do centro de pressão
@export var tow_point := Vector3(0.0, 0.12, 0.28)      ## cabresto: onde a linha prende
@export var tail_attach := Vector3(0.0, -0.35, 0.0)    ## onde a rabiola prende
@export var triangles := PackedVector3Array()          ## painéis: 3 vértices por triângulo
@export var corners := PackedVector3Array()            ## pontos de contato com o chão

@export_group("Rabiola")
@export var tail_enabled := true
@export var tail_length := 2.0     ## m
@export var tail_mass := 0.006     ## kg
@export var tail_segments := 10
@export var tail_width := 0.025    ## m: largura efetiva para o arrasto
@export var tail_drag_coefficient := 0.6

# Calculados por rebuild() a partir dos triângulos.
var panel_centers := PackedVector3Array()
var panel_normals := PackedVector3Array()
var panel_areas := PackedFloat64Array()
var total_area := 0.0


## Recalcula centros, normais e áreas dos painéis. Chame após mudar triangles.
func rebuild() -> void:
	panel_centers.clear()
	panel_normals.clear()
	panel_areas.clear()
	total_area = 0.0
	for i in range(0, triangles.size(), 3):
		var a := triangles[i]
		var b := triangles[i + 1]
		var c := triangles[i + 2]
		var cr := (b - a).cross(c - a)
		var area := 0.5 * cr.length()
		var n := cr.normalized()
		if n.z < 0.0:
			n = -n  # normal sempre para a frente (lado do cabresto)
		panel_centers.append((a + b + c) / 3.0)
		panel_normals.append(n)
		panel_areas.append(area)
		total_area += area


## Raia em losango de 0,60 m × 0,50 m, 25 g, com vareta transversal envergada
## (diedro) e rabiola de 2 m. Parâmetros calibrados no protótipo
## (tools/prototipo/sim_prototipo.py).
static func raia_laboratorio(dihedral_deg := 12.0) -> KiteDefinition:
	var d := KiteDefinition.new()
	var dh := deg_to_rad(dihedral_deg)
	var top := Vector3(0.0, 0.25, 0.0)
	var bottom := Vector3(0.0, -0.35, 0.0)
	var left := Vector3(-0.25 * cos(dh), 0.05, -0.25 * sin(dh))
	var right := Vector3(0.25 * cos(dh), 0.05, -0.25 * sin(dh))
	var center := Vector3(0.0, 0.05, 0.0)
	d.triangles = PackedVector3Array([
		center, top, left,
		center, right, top,
		center, left, bottom,
		center, bottom, right,
	])
	d.corners = PackedVector3Array([top, bottom, left, right])
	d.rebuild()
	return d
