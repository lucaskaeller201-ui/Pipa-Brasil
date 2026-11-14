extends RefCounted
## Base dos testes do PIPA BRASIL.
##
## Cada arquivo de teste estende este script pelo caminho
## (extends "res://tests/test_case.gd") e define métodos que começam com
## "test_". O executor (tests/run_tests.gd) chama cada um e coleta as falhas.

var failures: Array[String] = []
var current_test := ""
## Árvore de cena do executor, para testes que precisam instanciar cenas.
var tree: SceneTree


func assert_true(condicao: bool, mensagem := "") -> void:
	if not condicao:
		_fail("esperava verdadeiro. %s" % mensagem)


func assert_false(condicao: bool, mensagem := "") -> void:
	if condicao:
		_fail("esperava falso. %s" % mensagem)


func assert_eq(obtido: Variant, esperado: Variant, mensagem := "") -> void:
	if typeof(obtido) != typeof(esperado) or obtido != esperado:
		_fail("obtido %s, esperado %s. %s" % [str(obtido), str(esperado), mensagem])


func assert_near(obtido: float, esperado: float, tolerancia: float, mensagem := "") -> void:
	if is_nan(obtido) or absf(obtido - esperado) > tolerancia:
		_fail("obtido %f, esperado %f ± %f. %s" % [obtido, esperado, tolerancia, mensagem])


func assert_vec_near(obtido: Vector3, esperado: Vector3, tolerancia: float, mensagem := "") -> void:
	if not obtido.is_finite() or obtido.distance_to(esperado) > tolerancia:
		_fail("obtido %s, esperado %s ± %f. %s" % [str(obtido), str(esperado), tolerancia, mensagem])


func assert_not_null(valor: Variant, mensagem := "") -> void:
	if valor == null:
		_fail("valor nulo. %s" % mensagem)


func _fail(mensagem: String) -> void:
	failures.append("%s: %s" % [current_test, mensagem])
