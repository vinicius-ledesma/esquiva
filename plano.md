IA: Uma observação rápida antes do plano: a plataforma não gera `.md` como arquivo baixável (o gerador de documentos só produz `.docx`/`.pdf`, e um `.docx` atrapalharia sua execução com copiar/colar de código). Entreguei o plano completo abaixo em **markdown puro** — basta copiar todo o conteúdo do documento e salvar como `plano.md` na pasta do projeto. Nada ficou de fora: ambiente, assets do Kenney, código do jogo já convertido para sprites, workflow completo do GitHub Actions e publicação.

---

# Plano de Execução Completo — Jogo "Esquiva"

> Stack: **Godot 4.x (Linux) + Kenney (assets) + GitHub Actions (iOS) + Stable Diffusion (arte própria, opcional)**
> Objetivo: jogo arcade 2D rodando no desktop, empacotado para Android e iOS a partir do mesmo código-fonte.

## Índice

1. Fase 0 — Preparar o ambiente Linux
2. Fase 1 — Criar o projeto (todos os arquivos)
3. Fase 2 — Instalar os assets do Kenney
4. Fase 3 — Rodar e validar no desktop
5. Fase 4 — Export para Android
6. Fase 5 — GitHub Actions (build Android + iOS sem Mac)
7. Fase 6 — Publicação (Play Store, App Store, itch.io)
8. Fase 7 (opcional) — Arte própria com Stable Diffusion e Mixamo
9. Checklist final de execução

---

## Fase 0 — Preparar o ambiente Linux

### 0.1 Instalar o Godot 4.x

```bash
# Opção recomendada: binário oficial (sem dependências)
# Baixe em https://godotengine.org/download → "Godot Engine → Linux"
mkdir -p ~/tools && cd ~/tools
# exemplo (ajuste a versão para a mais recente do site):
wget https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip
unzip Godot_v4.6.3-stable_linux.x86_64.zip
sudo ln -s ~/tools/Godot_v4.6.3-stable_linux.x86_64 /usr/local/bin/godot
godot --version   # deve imprimir 4.6.3
```

Alternativa: `flatpak install flathub org.godotengine.Godot`.

### 0.2 Instalar os templates de export (necessário para Android/iOS)

1. Abra o Godot.
2. Menu **Editor → Manage Export Templates**.
3. Clique em **Download and Install** (baixa ~1 GB).

### 0.3 Preparar Java e Android SDK (pode adiar até a Fase 4)

```bash
sudo apt install openjdk-17-jdk
java -version   # deve mostrar 17.x
```

Instale o Android Studio (https://developer.android.com/studio) ou apenas as *cmdline-tools*; ao abrir o Android Studio, use o **SDK Manager** para instalar:
- Android SDK Platform (API 34 ou superior)
- Android SDK Build-Tools
- Android SDK Command-line Tools
- Android SDK Platform-Tools

Anote o caminho do SDK (padrão: `~/Android/Sdk`).

---

## Fase 1 — Criar o projeto

### 1.1 Estrutura de pastas

```text
esquiva/
├── project.godot
├── export_presets.cfg        (criado na Fase 4, pelo editor)
├── scenes/
│   └── main.tscn
├── scripts/
│   └── main.gd
└── assets/
    └── kenney/               (preenchido na Fase 2)
```

```bash
mkdir -p esquiva/scenes esquiva/scripts esquiva/assets/kenney
cd esquiva
```

### 1.2 Arquivo `project.godot`

```ini
; Engine configuration file — Godot 4.x
config_version=5

[application]
config/name="Esquiva"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.4")

[display]
window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/handheld/orientation=1

[input_devices]
pointing/emulate_touch_from_mouse=true

[rendering]
renderer/rendering_method="mobile"
```

### 1.3 Arquivo `scenes/main.tscn`

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

### 1.4 Arquivo `scripts/main.gd` (versão final, já com suporte a Kenney)

```gdscript
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

const TEX_JOGADOR := "res://assets/kenney/playerShip1_blue.png"
const TEX_OBSTACULO := "res://assets/kenney/meteorBrown_big1.png"

var jogando := false
var pontos := 0.0
var dificuldade := 1.0
var tempo_spawn := 0.0
var obstaculos: Array = []
var jogador: Node2D
var rotulo_pontos: Label
var rotulo_msg: Label
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_criar_fundo()
	_criar_jogador()
	_criar_interface()
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


func _criar_sprite(caminho: String, tamanho: Vector2, cor_fallback: Color) -> Node2D:
	# Usa o PNG do Kenney se existir; senão desenha um retângulo colorido.
	if ResourceLoader.exists(caminho):
		var sprite := Sprite2D.new()
		sprite.texture = load(caminho)
		sprite.centered = false
		sprite.scale = tamanho / sprite.texture.get_size()
		return sprite
	var ret := ColorRect.new()
	ret.color = cor_fallback
	ret.size = tamanho
	return ret


func _criar_interface() -> void:
	rotulo_pontos = Label.new()
	rotulo_pontos.position = Vector2(24, 40)
	rotulo_pontos.add_theme_font_size_override("font_size", 48)
	add_child(rotulo_pontos)

	rotulo_msg = Label.new()
	rotulo_msg.position = Vector2(0, ALTURA / 2 - 60)
	rotulo_msg.size = Vector2(LARGURA, 160)
	rotulo_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_msg.add_theme_font_size_override("font_size", 36)
	add_child(rotulo_msg)


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
	var rect_jogador := Rect2(jogador.position, TAM_JOGADOR)
	for obstaculo in obstaculos:
		if Rect2(obstaculo.position, TAM_OBSTACULO).intersects(rect_jogador):
			_game_over()
			return
	for i in range(obstaculos.size() - 1, -1, -1):
		if obstaculos[i].position.y > ALTURA:
			obstaculos[i].queue_free()
			obstaculos.remove_at(i)


func _game_over() -> void:
	jogando = false
	_mostrar_mensagem("Fim de jogo! Pontos: %d\nToque/clique para jogar de novo" % int(pontos))
```

> 💡 Como os sprites usam `centered = false` e escala proporcional, a lógica de colisão por `Rect2` funciona idêntica com PNG ou com retângulo.

---

## Fase 2 — Instalar os assets do Kenney

### 2.1 Baixar o pacote

1. Acesse **https://kenney.nl/assets/space-shooter-redux**.
2. Clique em **Download** (zip gratuito, licença CC0 — uso comercial liberado).
3. Extraia o zip em qualquer pasta temporária.

### 2.2 Copiar os arquivos usados pelo jogo

```bash
# Ajuste os caminhos de origem conforme a extração (a pasta PNG/ fica dentro do zip)
cp /PNG/Players/playerShip1_blue.png   esquiva/assets/kenney/
cp /PNG/Meteors/meteorBrown_big1.png   esquiva/assets/kenney/
```

Os dois nomes precisam ficar exatamente assim (o código procura por eles):
- `assets/kenney/playerShip1_blue.png` — nave do jogador
- `assets/kenney/meteorBrown_big1.png` — obstáculo

### 2.3 (Opcional) Variar os meteoros

Copie também `meteorBrown_big2.png`, `meteorBrown_med1.png` e `meteorGrey_big1.png` para a mesma pasta. Para usar variedade, troque a linha do `_spawn_obstaculo` por:

```gdscript
	var texturas := [
		"res://assets/kenney/meteorBrown_big1.png",
		"res://assets/kenney/meteorBrown_big2.png",
		"res://assets/kenney/meteorBrown_med1.png",
		"res://assets/kenney/meteorGrey_big1.png",
	]
	var obstaculo := _criar_sprite(texturas[rng.randi() % texturas.size()], TAM_OBSTACULO, Color(1.0, 0.35, 0.3))
```

### 2.4 Outros pacotes Kenney úteis para os próximos jogos

- **Simplified Platformer** — plataforma 2D
- **Pixel Platformer** — pixel art
- **UI Pack** — botões e HUD
- **Kenney Game Assets All-in-1** — acervo completo (pago, barato)

---

## Fase 3 — Rodar e validar no desktop

1. Abra o Godot → **Import** → selecione `esquiva/project.godot` → **Import & Edit**.
2. Se aparecer aviso sobre a versão das features, confirme e prossiga.
3. Aperte **F5** (ou o botão ▶). Se pedir cena principal, escolha `scenes/main.tscn`.
4. Valide cada item:
   - [ ] Nave aparece na base da tela (sprite do Kenney ou retângulo azul)
   - [ ] Setas ← → movem a nave; ela não sai da tela
   - [ ] Clique/touch inicia o jogo e move a nave para o dedo/mouse
   - [ ] Meteoros caem e aceleram com o tempo
   - [ ] Colisão encerra e mostra os pontos; clique reinicia
   - [ ] Placar sobe no canto superior esquerdo

---

## Fase 4 — Export para Android

### 4.1 Configurar o Godot para Android

1. **Editor → Editor Settings → Export → Android**:
   - **Android SDK Path**: `~/Android/Sdk`
   - **Debug Keystore**: aponte para o keystore criado abaixo (user `androiddebugkey`, senha `android`).
2. Gere o keystore de debug (se ainda não existir em `~/.android/debug.keystore`):

```bash
keytool -keyalg RSA -genkeypair -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
  -keypass android -storepass android -validity 9999
```

3. **Project → Export → Add… → Android**. Em **Package → Unique Name**, troque para algo como `br.seunome.esquiva`.
4. **Export Project** (com "Export With Debug" ligado para teste) gera o `Esquiva.apk`.

### 4.2 Instalar no celular

```bash
sudo apt install adb
adb devices          # celular com "Depuração USB" ativada
adb install Esquiva.apk
```

### 4.3 Preparar o AAB para a Play Store

1. Crie um **keystore de release** (guarde senha e backup — sem ele você não atualiza o app):

```bash
keytool -keyalg RSA -genkeypair -v -keystore release.keystore \
  -alias esquiva -dname "CN=Seu Nome" -keypass SUA_SENHA -storepass SUA_SENHA -validity 10000
```

2. No preset Android do Godot, em **Keystore**, aponte para o `release.keystore` (alias `esquiva`).
3. Marque **Export As AAB** e exporte → `Esquiva.aab`.

---

## Fase 5 — GitHub Actions (build Android + iOS sem Mac)

### 5.1 Subir o projeto para o GitHub

```bash
cd esquiva
git init && git add . && git commit -m "Esquiva v1"
# crie o repositório no github.com e então:
git remote add origin git@github.com:SEU_USUARIO/esquiva.git
git push -u origin main
```

⚠️ Confirme que `export_presets.cfg` foi commitado (o CI precisa dele) e que `.gitignore` **não** exclui a pasta `assets/`.

### 5.2 Criar o workflow

Crie o arquivo `.github/workflows/build.yml`:

```yaml
name: Build Esquiva

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  GODOT_VERSION: 4.6.3

jobs:
  android:
    name: Build Android (APK)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - uses: android-actions/setup-android@v3

      - name: Instalar Godot
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip
          unzip -q Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip
          sudo mv Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot

      - name: Instalar templates de export
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz
          unzip -q Godot_v${GODOT_VERSION}-stable_export_templates.tpz
          mkdir -p ~/.local/share/godot/export_templates
          mv templates ~/.local/share/godot/export_templates/${GODOT_VERSION}.stable

      - name: Gerar keystore de debug
        run: |
          keytool -keyalg RSA -genkeypair -v -keystore debug.keystore \
            -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
            -keypass android -storepass android -validity 9999

      - name: Exportar APK
        run: |
          godot --headless --import
          godot --headless --export-release "Android" Esquiva.apk

      - uses: actions/upload-artifact@v4
        with:
          name: esquiva-android
          path: Esquiva.apk

  ios:
    name: Build iOS
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Instalar Godot
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_macos.universal.zip
          unzip -q Godot_v${GODOT_VERSION}-stable_macos.universal.zip
          sudo cp Godot_v${GODOT_VERSION}-stable_macos.universal/Godot.app/Contents/MacOS/Godot /usr/local/bin/godot

      - name: Instalar templates de export
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz
          unzip -q Godot_v${GODOT_VERSION}-stable_export_templates.tpz
          mkdir -p "$HOME/Library/Application Support/Godot/export_templates"
          mv templates "$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable"

      # CAMINHO A (recomendado): assina e envia para o TestFlight.
      # Requer conta Apple Developer (US$ 99/ano) e os segredos abaixo.
      # Descomente este bloco e comente o Caminho B quando tiver as credenciais.
      # - name: Exportar e enviar para TestFlight
      #   uses: dulvui/godot-ios-upload@v4
      #   with:
      #     godot-version: ${{ env.GODOT_VERSION }}
      #     apple-cert-p12-base64: ${{ secrets.APPLE_CERT_P12 }}
      #     apple-cert-password: ${{ secrets.APPLE_CERT_PASSWORD }}
      #     apple-provisioning-profile-base64: ${{ secrets.APPLE_PROVISIONING_PROFILE }}
      #     apple-issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
      #     apple-key-id: ${{ secrets.APPSTORE_KEY_ID }}
      #     apple-key-content: ${{ secrets.APPSTORE_PRIVATE_KEY }}

      # CAMINHO B: IPA não assinado (teste local via AltStore/Sideloadly).
      - name: Exportar projeto iOS
        run: |
          godot --headless --import
          godot --headless --export-release "iOS" build/ios/Esquiva.xcodeproj.zip

      - uses: actions/upload-artifact@v4
        with:
          name: esquiva-ios
          path: build/ios/
```

### 5.3 Criar os presets de export exigidos pelo CI

O CI chama os presets pelo nome — eles precisam existir com exatamente esses nomes:

1. No Godot: **Project → Export → Add… → Android** → nome do preset: `Android` → Unique Name `br.seunome.esquiva`.
2. **Project → Export → Add… → iOS** → nome do preset: `iOS` (deixe os campos de assinatura em branco para o Caminho B).
3. Salve o projeto e faça `git add export_presets.cfg && git commit && git push`.

### 5.4 Rodar e pegar os resultados

1. Cada `git push` na `main` dispara o build (aba **Actions** no GitHub).
2. Ao terminar, entre no run → seção **Artifacts** → baixe `esquiva-android` (APK) e `esquiva-ios`.
3. Para o Caminho A (TestFlight), configure em **Settings → Secrets and variables → Actions** os segredos listados no workflow: certificado `.p12` em base64, senha, provisioning profile em base64, e as chaves da App Store Connect (Issuer ID, Key ID, chave .p8 em base64). O guia oficial está na página da action: https://github.com/marketplace/actions/godot-ios-upload

> 💡 Em repositórios públicos, runners macOS são gratuitos (com cota de minutos generosa). Em privados, os minutos macOS consomem a cota 10× mais rápido — para builds pequenos como este, o nível gratuito costuma bastar.

---

## Fase 6 — Publicação

### 6.1 Google Play (taxa única de `US$ 25`)

1. Crie a conta em https://play.google.com/console (pagamento único).
2. **Criar app** → preencha ficha da loja (título, descrição, screenshots — capture do celular com `adb`), política de privacidade e classificação de conteúdo.
3. **Testes → Interno** → upload do `Esquiva.aab` → teste com até 100 testadores.
4. Após validar, promova para **Produção** e envie para revisão (prazo típico: dias).

### 6.2 App Store (anuidade de `US$ 99`)

1. Assine o **Apple Developer Program** em https://developer.apple.com.
2. No App Store Connect, crie o app (SKU, Bundle ID `br.seunome.esquiva`).
3. Configure o Caminho A da Fase 5 → o build aparece no TestFlight → teste em aparelhos.
4. Preencha a ficha da App Store e envie para revisão da Apple.

### 6.3 itch.io (grátis, publique hoje)

1. Crie conta em https://itch.io → **Upload new project**.
2. Marque **Kind of project: HTML** e faça upload da exportação **Web** do Godot (Project → Export → Add → Web).
3. Configure "Viewport dimensions" para 720×1280 e marque "Mobile friendly".
4. Compartilhe o link — nenhuma taxa, nenhuma revisão.

---

## Fase 7 (opcional) — Arte própria com Stable Diffusion e Mixamo

### 7.1 Stable Diffusion local (Linux, grátis e ilimitado)

```bash
sudo apt install git python3-venv
git clone https://github.com/comfyanonymous/ComfyUI ~/ComfyUI
cd ~/ComfyUI
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
# baixe um checkpoint (ex.: SDXL ou um modelo de pixel art do Civitai) em models/checkpoints/
python main.py   # abre em http://127.0.0.1:8188
```

Prompt de exemplo para sprite consistente: `game sprite, pixel art, blue spaceship, side view, transparent background, 16-bit style`. Gere em fundo transparente (ou remova o fundo com um editor) e salve em `assets/kenney/` substituindo os PNGs — o código não muda.

### 7.2 Mixamo (só quando o jogo virar 3D)

1. Acesse https://www.mixamo.com (grátis, conta Adobe).
2. Suba um modelo humanoide (pode virar do Meshy/Tripo) → auto-rig automático.
3. Escolha animações prontas (correr, pular, atacar) → baixe em FBX → importe no Godot.

---

## Checklist final de execução

- [ ] Fase 0: Godot instalado e `godot --version` responde
- [ ] Fase 0: templates de export instalados
- [ ] Fase 1: 3 arquivos criados (`project.godot`, `main.tscn`, `main.gd`)
- [ ] Fase 2: 2 PNGs do Kenney em `assets/kenney/`
- [ ] Fase 3: jogo roda no desktop com F5 e todos os itens validados
- [ ] Fase 4: APK instalado no celular via `adb`
- [ ] Fase 4: keystore de release criado e AAB exportado
- [ ] Fase 5: repo no GitHub, `build.yml` commitado, presets `Android` e `iOS` criados
- [ ] Fase 5: artifacts `esquiva-android` e `esquiva-ios` baixados do Actions
- [ ] Fase 6: jogo publicado no itch.io (versão web)
- [ ] Fase 6: conta Play criada, AAB em testes internos
- [ ] Fase 6 (opcional): conta Apple, TestFlight com Caminho A
- [ ] Fase 7 (opcional): ComfyUI rodando e sprites próprios gerados

---

Resumindo
- O plano está 100% fechado: ambiente, código do jogo já convertido para sprites do Kenney (com fallback se os PNGs faltarem), workflow completo do GitHub Actions para Android e iOS, e os três canais de publicação.
- O jogo funciona mesmo antes da Fase 2 — os assets do Kenney são uma melhoria visual plug-and-play, sem mudar a lógica.
- O único ponto que depende de credenciais suas é o TestFlight (conta Apple + segredos no GitHub); todo o resto executa com o que está no documento.

Se quiser, posso:
- Gerar o `export_presets.cfg` comentado para você já commitar pronto
- Detalhar a captura dos screenshots exigidos pela ficha da Play Store
- Criar uma segunda mecânica para o jogo (power-ups ou inimigos que atiram) para evoluir o exemplo