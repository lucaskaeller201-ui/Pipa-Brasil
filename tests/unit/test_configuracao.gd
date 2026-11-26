extends "res://tests/test_case.gd"
## Garante que configurações importantes do projeto não mudem sem querer.


## D-082: passo fixo de 60 Hz no jogo (com 2 subpassos de 1/120 s).
func test_fisica_em_passo_fixo() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60,
		"o passo fixo da física é a base da física independente do FPS (D-004)")


func test_renderizador_mobile() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile",
		"renderizador base definido em D-005")


func test_compressao_de_textura_para_android() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"), true,
		"o Android exige ETC2/ASTC")


func test_cena_principal_definida() -> void:
	var cena: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_eq(cena, "res://scenes/main/main.tscn")
	assert_true(ResourceLoader.exists(cena), "o arquivo da cena principal precisa existir")


func test_celular_deitado() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4, "paisagem com sensor (D-023)")
	assert_true(ProjectSettings.get_setting("display/window/size/viewport_width") > ProjectSettings.get_setting("display/window/size/viewport_height"))
