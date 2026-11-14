extends "res://tests/test_case.gd"
## Regressão: compara trajetórias com referências gravadas em tests/golden/.
##
## Se uma mudança alterar o voo sem querer, estes testes acusam. Mudança
## intencional: apague o .csv correspondente, deixe o CI gerar a referência
## nova (publicada no ramo "referencias-novas"), revise e guarde no
## repositório, explicando o motivo em docs/decisoes.md.

const DT := 1.0 / 120.0
const PASTA := "res://tests/golden"
const AMOSTRA := 60  ## passos entre amostras (0,5 s)


func _amostra(w: SimWorld) -> String:
	var p := w.kite.position
	return "%.2f,%.4f,%.4f,%.4f,%.4f,%.4f" % [w.time, p.x, p.y, p.z, w.tension, w.line_length()]


func _gravar_ou_comparar(nome: String, linhas: PackedStringArray, tol_pos: float, tol_tensao: float) -> void:
	var caminho := PASTA.path_join(nome + ".csv")
	if not FileAccess.file_exists(caminho):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
		var f := FileAccess.open(caminho, FileAccess.WRITE)
		f.store_string("t,x,y,z,tensao,linha\n" + "\n".join(linhas) + "\n")
		f.close()
		print("      [regressão] REFERÊNCIA NOVA criada: %s" % caminho)
		return
	var ref := FileAccess.get_file_as_string(caminho).strip_edges().split("\n")
	ref.remove_at(0)  # cabeçalho
	assert_eq(ref.size(), linhas.size(), "%s: número de amostras" % nome)
	var pior_pos := 0.0
	var pior_tensao := 0.0
	for i in mini(ref.size(), linhas.size()):
		var a := ref[i].split(",")
		var b := linhas[i].split(",")
		var pa := Vector3(a[1].to_float(), a[2].to_float(), a[3].to_float())
		var pb := Vector3(b[1].to_float(), b[2].to_float(), b[3].to_float())
		pior_pos = maxf(pior_pos, pa.distance_to(pb))
		pior_tensao = maxf(pior_tensao, absf(a[4].to_float() - b[4].to_float()) / (1.0 + a[4].to_float()))
		assert_near(b[5].to_float(), a[5].to_float(), 0.05, "%s: linha em t = %s" % [nome, a[0]])
	print("      [regressão %s] maior diferença: posição %.4f m, tensão %.2f%%" % [nome, pior_pos, pior_tensao * 100.0])
	assert_true(pior_pos <= tol_pos, "%s: posição da pipa mudou %.4f m" % [nome, pior_pos])
	assert_true(pior_tensao <= tol_tensao, "%s: tensão mudou %.2f%%" % [nome, pior_tensao * 100.0])


func test_regressao_voo_da_raia_com_turbulencia() -> void:
	var w := SimWorld.create_flight(WindField.new(5.0, 0.15, 4), KiteDefinition.raia_laboratorio(), 30.0)
	var linhas := PackedStringArray()
	for i in 2400:  # 20 s
		w.step(DT)
		if i % AMOSTRA == AMOSTRA - 1:
			linhas.append(_amostra(w))
	_gravar_ou_comparar("voo_raia_turbulencia", linhas, 0.02, 0.02)


func test_regressao_sequencia_de_comandos() -> void:
	var w := SimWorld.create_flight(WindField.new(5.0), KiteDefinition.raia_laboratorio(), 30.0, 30.0, 0.0, 4, true)
	var linhas := PackedStringArray()
	for i in 2400:  # 20 s
		var t := i * DT
		w.input.clear()
		if i == 360:
			w.trigger(Pilot.Impulse.PUXAO)
		elif i == 600:
			w.trigger(Pilot.Impulse.ARRANCAO)
		elif i == 1920:
			w.trigger(Pilot.Impulse.DESBICAR)
		w.input.pay_out = t >= 7.0 and t < 9.0
		w.input.free_spool = t >= 10.0 and t < 11.0
		w.input.reel_in = t >= 12.0 and t < 15.0
		w.input.slack = 1.0 if t >= 18.0 and t < 19.0 else 0.0
		w.step(DT)
		if i % AMOSTRA == AMOSTRA - 1:
			linhas.append(_amostra(w))
	_gravar_ou_comparar("sequencia_de_comandos", linhas, 0.02, 0.02)


func test_regressao_raia_sem_rabiola() -> void:
	var w := SimWorld.create_flight(WindField.new(5.0, 0.15, 1), KiteDefinition.raia_sem_rabiola(),
		30.0, 30.0, 0.0, 4, true, 3.0)
	var linhas := PackedStringArray()
	for i in 960:  # 8 s (voo caótico: trecho curto)
		w.step(DT)
		if i % AMOSTRA == AMOSTRA - 1:
			linhas.append(_amostra(w))
	_gravar_ou_comparar("raia_sem_rabiola", linhas, 0.05, 0.05)
