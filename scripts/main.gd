extends Node2D
## Esquiva — jogo arcade em Godot 4 com assets do Kenney (Space Shooter Redux).
## Mova a nave (setas ou toque) e desvie dos meteoros.
## Se os PNGs do Kenney não existirem, o jogo roda igual com retângulos coloridos.

const LARGURA := 720.0
const ALTURA := 1280.0
const TAM_JOGADOR := Vector2(120, 96)
const TAM_OBSTACULO := Vector2(80, 80)
const VELOCIDADE_JOGADOR := 900.0
const INTERVALO_SPAWN := 0.7
const VELOCIDADE_BASE := 350.0
const VIDAS_INICIAIS := 30
const CASCOS_JOGADOR := [
	[
		Vector2(24.0 / 120.0, 18.0 / 96.0),
		Vector2(60.0 / 120.0, 8.0 / 96.0),
		Vector2(96.0 / 120.0, 18.0 / 96.0),
		Vector2(100.0 / 120.0, 54.0 / 96.0),
		Vector2(60.0 / 120.0, 80.0 / 96.0),
		Vector2(20.0 / 120.0, 54.0 / 96.0),
	],
	[
		Vector2(20.0 / 120.0, 46.0 / 96.0),
		Vector2(35.0 / 120.0, 54.0 / 96.0),
		Vector2(20.0 / 120.0, 62.0 / 96.0),
	],
	[
		Vector2(96.0 / 120.0, 46.0 / 96.0),
		Vector2(81.0 / 120.0, 54.0 / 96.0),
		Vector2(100.0 / 120.0, 62.0 / 96.0),
	],
]
const CONTORNO_METEORO := [
	Vector2(12.0 / 80.0, 8.0 / 80.0),
	Vector2(32.0 / 80.0, 0.0),
	Vector2(58.0 / 80.0, 10.0 / 80.0),
	Vector2(74.0 / 80.0, 24.0 / 80.0),
	Vector2(72.0 / 80.0, 56.0 / 80.0),
	Vector2(56.0 / 80.0, 76.0 / 80.0),
	Vector2(18.0 / 80.0, 76.0 / 80.0),
	Vector2(4.0 / 80.0, 48.0 / 80.0),
	Vector2(6.0 / 80.0, 22.0 / 80.0),
]

const TEX_JOGADOR := "res://assets/kenney/playerShip1_blue.png"
const TEX_OBSTACULO := "res://assets/kenney/meteorBrown_big1.png"

var jogando := false
var pontos := 0.0
var vidas := VIDAS_INICIAIS
var dificuldade := 1.0
var tempo_spawn := 0.0
var obstaculos: Array = []
var jogador
var rotulo_pontos: Label
var rotulo_vidas: Label
var rotulo_msg: Label
var sobreposicao_flash: ColorRect
var tween_flash: Tween
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_criar_fundo()
	_criar_jogador()
	_criar_interface()
	_criar_efeitos_colisao()
	_mostrar_mensagem("Setas ou toque para mover\nToque/clique para começar")


func _criar_fundo() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.05, 0.05, 0.12)
	fundo.size = Vector2(LARGURA, ALTURA)
	fundo.z_index = -10
	add_child(fundo)


func _criar_jogador() -> void:
	jogador = _criar_sprite(TEX_JOGADOR, TAM_JOGADOR, Color(0.2, 0.7, 1.0))
	jogador.position = Vector2(LARGURA / 2 - TAM_JOGADOR.x / 2, ALTURA - 180)
	add_child(jogador)


func _criar_sprite(caminho: String, tamanho: Vector2, cor_fallback: Color) -> Node:
	var textura := ResourceLoader.load(caminho) as Texture2D
	if textura != null:
		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.centered = false
		sprite.scale = tamanho / textura.get_size()
		return sprite
	push_warning("Não foi possível carregar a sprite '%s'; usando retângulo de fallback." % caminho)
	var ret := ColorRect.new()
	ret.color = cor_fallback
	ret.size = tamanho
	return ret


func _criar_interface() -> void:
	rotulo_pontos = Label.new()
	rotulo_pontos.position = Vector2(24, 40)
	rotulo_pontos.add_theme_font_size_override("font_size", 48)
	add_child(rotulo_pontos)

	rotulo_vidas = Label.new()
	rotulo_vidas.position = Vector2(420, 40)
	rotulo_vidas.size = Vector2(276, 60)
	rotulo_vidas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rotulo_vidas.add_theme_font_size_override("font_size", 48)
	add_child(rotulo_vidas)
	_atualizar_rotulo_vidas()

	rotulo_msg = Label.new()
	rotulo_msg.position = Vector2(0, ALTURA / 2 - 60)
	rotulo_msg.size = Vector2(LARGURA, 160)
	rotulo_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_msg.add_theme_font_size_override("font_size", 36)
	add_child(rotulo_msg)


func _criar_efeitos_colisao() -> void:
	sobreposicao_flash = ColorRect.new()
	sobreposicao_flash.color = Color(0.8, 0.92, 1.0, 0.0)
	sobreposicao_flash.size = Vector2(LARGURA, ALTURA)
	sobreposicao_flash.z_index = 100
	sobreposicao_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sobreposicao_flash)


func _mostrar_mensagem(texto: String) -> void:
	rotulo_msg.text = texto
	rotulo_msg.visible = true


func _process(delta: float) -> void:
	if not jogando:
		return
	pontos += delta
	dificuldade = 1.0 + pontos / 20.0
	rotulo_pontos.text = "Pontos: %d" % int(pontos)
	_mover_jogador(delta)
	tempo_spawn -= delta
	if tempo_spawn <= 0.0:
		_spawn_obstaculo()
		tempo_spawn = INTERVALO_SPAWN / dificuldade
	_mover_obstaculos(delta)
	_verificar_colisao()


func _mover_jogador(delta: float) -> void:
	var direcao := 0.0
	if Input.is_action_pressed("ui_left"):
		direcao -= 1.0
	if Input.is_action_pressed("ui_right"):
		direcao += 1.0
	jogador.position.x += direcao * VELOCIDADE_JOGADOR * delta
	jogador.position.x = clamp(jogador.position.x, 0.0, LARGURA - TAM_JOGADOR.x)


func _unhandled_input(evento: InputEvent) -> void:
	# emulate_touch_from_mouse converte o mouse em toque: um código só
	if evento is InputEventScreenTouch and evento.pressed:
		if not jogando:
			_iniciar()
		_mover_para(evento.position.x)
	elif evento is InputEventScreenDrag:
		_mover_para(evento.position.x)
	elif evento is InputEventKey and evento.pressed and not jogando:
		_iniciar()


func _mover_para(x: float) -> void:
	if jogando:
		jogador.position.x = clamp(x - TAM_JOGADOR.x / 2, 0.0, LARGURA - TAM_JOGADOR.x)


func _iniciar() -> void:
	for obstaculo in obstaculos:
		obstaculo.queue_free()
	obstaculos.clear()
	pontos = 0.0
	vidas = VIDAS_INICIAIS
	_atualizar_rotulo_vidas()
	dificuldade = 1.0
	tempo_spawn = 0.3
	jogando = true
	rotulo_msg.visible = false


func _spawn_obstaculo() -> void:
	var obstaculo := _criar_sprite(TEX_OBSTACULO, TAM_OBSTACULO, Color(1.0, 0.35, 0.3))
	obstaculo.position = Vector2(
		rng.randf_range(0.0, LARGURA - TAM_OBSTACULO.x),
		-TAM_OBSTACULO.y
	)
	add_child(obstaculo)
	obstaculos.append(obstaculo)


func _mover_obstaculos(delta: float) -> void:
	var velocidade := VELOCIDADE_BASE * dificuldade
	for obstaculo in obstaculos:
		obstaculo.position.y += velocidade * delta


func _verificar_colisao() -> void:
	var poligono_meteoro := _criar_poligono_mundo(
		Vector2.ZERO,
		TAM_OBSTACULO,
		CONTORNO_METEORO
	)
	for obstaculo in obstaculos:
		var meteoro := poligono_meteoro.duplicate()
		for i in range(meteoro.size()):
			meteoro[i] += obstaculo.position
		for casco in CASCOS_JOGADOR:
			var jogador_poligono := _criar_poligono_mundo(
				jogador.position,
				TAM_JOGADOR,
				casco
			)
			if not Geometry2D.intersect_polygons(jogador_poligono, meteoro).is_empty():
				_ao_colidir(obstaculo)
				return
	for i in range(obstaculos.size() - 1, -1, -1):
		if obstaculos[i].position.y > ALTURA:
			obstaculos[i].queue_free()
			obstaculos.remove_at(i)


func _criar_poligono_mundo(
	posicao: Vector2,
	tamanho: Vector2,
	contorno: Array
) -> PackedVector2Array:
	var poligono := PackedVector2Array()
	for ponto in contorno:
		poligono.append(posicao + ponto * tamanho)
	return poligono


func _ao_colidir(obstaculo: Node2D) -> void:
	vidas -= 1
	_atualizar_rotulo_vidas()
	_tocar_som_colisao()
	_piscar_tela()
	_dissolver_meteoro(obstaculo.position)
	if obstaculo in obstaculos:
		obstaculos.erase(obstaculo)
		obstaculo.queue_free()
	if vidas <= 0:
		_game_over()
		return
	_afastar_jogador_do_meteoro(obstaculo.position)


func _afastar_jogador_do_meteoro(posicao_meteoro: Vector2) -> void:
	var x_esquerda := posicao_meteoro.x - TAM_JOGADOR.x - 1.0
	var x_direita := posicao_meteoro.x + TAM_OBSTACULO.x + 1.0
	var max_x := LARGURA - TAM_JOGADOR.x
	var esquerda_valida := x_esquerda >= 0.0
	var direita_valida := x_direita <= max_x

	if esquerda_valida and direita_valida:
		if absf(jogador.position.x - x_esquerda) <= absf(jogador.position.x - x_direita):
			jogador.position.x = x_esquerda
		else:
			jogador.position.x = x_direita
	elif esquerda_valida:
		jogador.position.x = x_esquerda
	elif direita_valida:
		jogador.position.x = x_direita
	else:
		var x_esquerda_limitada := clampf(x_esquerda, 0.0, max_x)
		var x_direita_limitada := clampf(x_direita, 0.0, max_x)
		if absf(jogador.position.x - x_esquerda_limitada) <= absf(jogador.position.x - x_direita_limitada):
			jogador.position.x = x_esquerda_limitada
		else:
			jogador.position.x = x_direita_limitada


func _piscar_tela() -> void:
	if tween_flash and tween_flash.is_running():
		tween_flash.kill()
	sobreposicao_flash.color.a = 0.0
	tween_flash = create_tween()
	tween_flash.tween_property(sobreposicao_flash, "color:a", 0.35, 0.04)
	tween_flash.tween_property(sobreposicao_flash, "color:a", 0.0, 0.24)


func _tocar_som_colisao() -> void:
	const TAXA_AMOSTRAGEM := 22050
	const DURACAO := 0.32
	var quantidade_amostras := int(TAXA_AMOSTRAGEM * DURACAO)
	var dados := PackedByteArray()
	dados.resize(quantidade_amostras * 2)

	for i in range(quantidade_amostras):
		var tempo := float(i) / TAXA_AMOSTRAGEM
		var envelope := exp(-tempo * 15.0)
		var fase := TAU * (190.0 * tempo - 210.0 * tempo * tempo)
		var impacto := sin(fase) * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45
		var valor := clampf(impacto * envelope, -1.0, 1.0)
		dados.encode_s16(i * 2, int(valor * 32767.0))

	var som := AudioStreamWAV.new()
	som.format = AudioStreamWAV.FORMAT_16_BITS
	som.mix_rate = TAXA_AMOSTRAGEM
	som.stereo = false
	som.data = dados

	var tocador := AudioStreamPlayer.new()
	tocador.stream = som
	add_child(tocador)
	tocador.finished.connect(tocador.queue_free)
	tocador.play()


func _dissolver_meteoro(posicao: Vector2) -> void:
	var centro := TAM_OBSTACULO / 2.0
	var tons := [
		Color(0.65, 0.38, 0.25),
		Color(0.78, 0.49, 0.31),
		Color(0.48, 0.28, 0.20),
	]

	for i in range(CONTORNO_METEORO.size()):
		var ponto_a: Vector2 = CONTORNO_METEORO[i] * TAM_OBSTACULO - centro
		var ponto_b: Vector2 = CONTORNO_METEORO[(i + 1) % CONTORNO_METEORO.size()] * TAM_OBSTACULO - centro
		var fragmento := Polygon2D.new()
		fragmento.polygon = PackedVector2Array([Vector2.ZERO, ponto_a, ponto_b])
		fragmento.color = tons[i % tons.size()]
		fragmento.position = posicao + centro
		fragmento.z_index = 10
		add_child(fragmento)

		var direcao := (ponto_a + ponto_b).normalized()
		if direcao.is_zero_approx():
			direcao = Vector2.UP
		var duracao := rng.randf_range(0.24, 0.42)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(
			fragmento,
			"position",
			fragmento.position + direcao * rng.randf_range(35.0, 85.0),
			duracao
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(
			fragmento,
			"rotation",
			rng.randf_range(-PI, PI),
			duracao
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragmento, "modulate:a", 0.0, duracao)
		tween.finished.connect(fragmento.queue_free)


func _atualizar_rotulo_vidas() -> void:
	rotulo_vidas.text = "Vidas: %d" % vidas


func _game_over() -> void:
	jogando = false
	_mostrar_mensagem("Fim de jogo man! Pontos: %d\nToque/clique para jogar de novo" % int(pontos))
