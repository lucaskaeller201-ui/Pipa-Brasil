extends SceneTree
## Executor de testes do PIPA BRASIL, sem dependências externas.
##
## Uso:
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Procura arquivos test_*.gd nas pastas abaixo, executa todos os métodos que
## começam com "test_" e termina com código 1 se algum falhar.
## O CI também reprova a execução se aparecer "SCRIPT ERROR" na saída, porque
## um erro de execução no GDScript não interrompe o processo sozinho.

const PASTAS_DE_TESTE: Array[String] = [
	"res://tests/unit",
	"res://tests/scenarios",
	"res://tests/benchmarks",
]

var _aprovados := 0
var _reprovados := 0
var _mensagens: Array[String] = []


func _initialize() -> void:
	# Durante _initialize a raiz ainda não está pronta para receber cenas
	# (_ready não seria chamado). Os testes rodam no primeiro quadro.
	process_frame.connect(_rodar_tudo, CONNECT_ONE_SHOT)


func _rodar_tudo() -> void:
	print("PIPA BRASIL — testes automáticos")
	var arquivos: Array[String] = []
	for pasta in PASTAS_DE_TESTE:
		_coletar(pasta, arquivos)
	arquivos.sort()

	if arquivos.is_empty():
		push_error("Nenhum arquivo de teste encontrado.")
		quit(1)
		return

	for caminho in arquivos:
		_executar_arquivo(caminho)

	print("")
	for mensagem in _mensagens:
		print("  FALHA  ", mensagem)
	print("RESULTADO: %d aprovados, %d reprovados" % [_aprovados, _reprovados])
	quit(1 if _reprovados > 0 else 0)


func _coletar(pasta: String, saida: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(pasta):
		return
	for nome in DirAccess.get_files_at(pasta):
		if nome.begins_with("test_") and nome.ends_with(".gd"):
			saida.append(pasta.path_join(nome))
	for sub in DirAccess.get_directories_at(pasta):
		_coletar(pasta.path_join(sub), saida)


func _executar_arquivo(caminho: String) -> void:
	print("")
	print("» ", caminho)
	var script: GDScript = load(caminho)
	if script == null or not script.can_instantiate():
		_reprovados += 1
		_mensagens.append("%s: não foi possível carregar o script" % caminho)
		return

	var caso: Object = script.new()
	caso.set("tree", self)
	for metodo in script.get_script_method_list():
		var nome: String = metodo["name"]
		if not nome.begins_with("test_"):
			continue
		caso.set("current_test", "%s::%s" % [caminho.get_file(), nome])
		var falhas: Array = caso.get("failures")
		var antes := falhas.size()
		caso.call(nome)
		falhas = caso.get("failures")
		if falhas.size() == antes:
			_aprovados += 1
			print("  ok     ", nome)
		else:
			_reprovados += 1
			print("  FALHOU ", nome)
			for i in range(antes, falhas.size()):
				_mensagens.append(str(falhas[i]))
