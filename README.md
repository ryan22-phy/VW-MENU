# VW MENU

Roblox Luau UI, Aim Controller and ESP System para experiências e sessões de teste autorizadas.
UI nativa, sem bibliotecas externas, sem remotes, sem alterações em sistemas de segurança.

## Instalação e execução

1. Copie **todo** o conteúdo de [`dist/VW-MENU.lua`](dist/VW-MENU.lua) para um **LocalScript** em `StarterPlayer > StarterPlayerScripts` da sua experiência.
2. Inicie Play. A janela abre com AIM e ESP desligados; o FOV começa visível.
3. Habilite os recursos desejados. Use uma sessão de Studio com pelo menos dois clientes para testar alvos reais.

O arquivo integrado não faz HTTP, não exige Drawing, não carrega módulos externos e não requer habilitar `LoadStringEnabled`.
Também é possível importar os sete arquivos de `src/v2` como ModuleScripts irmãos e iniciar `require(pasta.main).start()` por um LocalScript.
O retorno de `start()` contém `Config`, `UI`, `Aim`, `ESP`, `Tracker`, `Cleanup` e `:Destroy()`.

### Loader Raw opcional

[`loader.lua`](loader.lua) usa o [Raw integrado](https://raw.githubusercontent.com/ryan22-phy/VW-MENU/main/dist/VW-MENU.lua).
Ele se destina somente a um host cliente de testes que **já exponha HTTP e loadstring autorizados**.
Não funciona como loader HTTP em um LocalScript padrão: o Roblox restringe `loadstring` ao servidor.
Para o Studio padrão, use a instalação acima; o runtime precisa executar no cliente.
Consulte as [capacidades oficiais de scripts](https://create.roblox.com/docs/scripting/capabilities).

```lua
local source = game:HttpGet("https://raw.githubusercontent.com/ryan22-phy/VW-MENU/main/dist/VW-MENU.lua")
local run, problem = loadstring(source, "@VW-MENU")
assert(run, problem)
return run()
```

## Controles

| Controle | Ação |
| --- | --- |
| Ctrl esquerdo/direito | Abre/fecha o menu; ignorado durante edição de texto |
| Arrastar o cabeçalho | Move a janela dentro da área útil |
| `−` / `+` no cabeçalho | Minimiza/restaura |
| `×` | Fecha a janela; Ctrl ou botão VW reabre |
| RMB / MouseButton2 | Ativa a mira enquanto Aim Assist está habilitado |
| SETTINGS → Unload | Encerra recursos e remove todas as instâncias próprias |
| SETTINGS → Reset Defaults | Restaura configurações e desliga AIM/ESP |

Perder foco da janela, editar texto ou abrir o menu Roblox solta a mira.
Fechar a janela VW mantém os recursos configurados; Unload encerra a sessão inteira.
Os sliders aceitam mouse/toque e setas quando selecionados. As cores são confirmadas ao sair do campo `#RRGGBB`.

## Recursos reais

- **AIM:** Smooth Speed 1–30 (6), FOV 30–400 px (100), Show FOV, Wall Check, Team Check, Target Lock, Head/HRP.
  Alvos vivos, replicados, na tela e dentro do FOV; neutros não são aliados.
  Com Wall Check, raycast usa a parte selecionada e ignora o personagem local e a câmera.
  `CFrame:Lerp` usa `1 - exp(-speed * deltaTime)`; não depende do FPS.
  O binding é `Camera + 1`, somente enquanto a mira pode atuar; Scriptable e VR suspendem sua atuação.
  Não altera CameraType/CameraSubject. Experiências com controladores próprios podem precisar integrar a prioridade escolhida.
- **ESP:** Highlight, caixa 3D por personagem com BoxHandleAdornment alinhado ao HRP, nomes, vida e distância em studs.
  Nomes, vida e distância são controles independentes; desativar Name Tags pode deixar vida/distância visíveis.
  Suporte estrutural R6/R15 por Humanoid, Head e HRP; sem aguardar partes em loops.
  Morte, troca de equipe, respawn, streaming e saída invalidam referências e overlays via eventos.
  Atualização de limites e distância a 10 Hz somente quando existem overlays; desligar remove os objetos.
- **VISUAL:** FOV sincronizado com AIM, cor, espessura e transparência; amostras de todas as cores.
  Cada componente ESP oferece `Team / Relation` ou `Custom`.
  No primeiro modo, Team Colors usa a equipe atribuída; sem equipe ou com Team Colors desligado, usa Friend/Enemy.
  No segundo, aplica Name Color, Box Color ou Highlight Color individualmente.
  Transparência usa sempre 0 = opaco e 1 = invisível, inclusive na adaptação opcional de Drawing.
- **SETTINGS:** estado real da mira/ESP/FOV, número de overlays, conexões gerenciadas, binding e último erro interno capturado.
  Reduce Motion altera as transições; o tema usa a paleta especificada #0B0E14 / #102441 / #42ADFF.

O caminho padrão do círculo é ScreenGui + UICorner + UIStroke. Quando um host disponibiliza Drawing compatível, existe um adaptador opcional.
Reexecutar a v2 invoca um handshake local síncrono e descarrega a instância anterior. Não usa `_G`, CoreGui ou RobloxLocked.
Uma instância identificada como VW MENU sem endpoint válido causa recusa de inicialização, evitando somar listeners desconhecidos.

## Organização e preservação do repositório existente

O repositório já continha uma UI demonstrativa e arquivos `src/Main.lua`, `VW_MENU.lua` e `VW_MENU.rbxmx`.
Esses arquivos foram preservados. As fontes novas ficam em **`src/v2/`** para evitar sobrescrita e a colisão `Main.lua`/`main.lua` em sistemas Windows.
O README anterior estava vazio. Os testes e ferramentas da versão anterior continuam separados pelos nomes existentes.

```text
README.md
.gitignore
loader.lua
src/v2/
  main.lua       # composição e handshake de reexecução
  config.lua     # valores, validação e notificações
  aim.lua        # mira e círculo FOV
  esp.lua        # overlays e cores
  ui.lua         # componentes nativos reaproveitados e integrados
  tracker.lua    # jogadores, personagens e partes
  cleanup.lua    # propriedade central dos recursos
dist/VW-MENU.lua  # script integrado executável
tools/build-v2.mjs
tools/verify-v2.mjs
tests/core.spec.luau
tests/controllers.spec.luau
tests/signal.luau
tests/v2-local-results.json
docs/V2_ANALYSIS.md
docs/V2_TESTS.md
```

Os seis módulos de suporte não importam uns aos outros; `main` os compõe. O build rejeita imports desconhecidos e ciclos.
Conexões pertencem a escopos de UI, câmera, jogador, personagem e recurso; remover um escopo libera suas referências.
Os ScreenGuis persistentes são filhos diretos de PlayerGui para sobreviver ao respawn local.

## Build e verificação

Node.js é necessário somente para as ferramentas locais; o runtime Roblox não depende dele.
Com `luau` e `luau-compile` disponíveis no PATH:

```text
node tools/build-v2.mjs
node tools/verify-v2.mjs luau luau-compile
```

Também é possível passar os dois caminhos absolutos dos executáveis ao comando de verificação.
O verificador compila fontes, testes, loader e bundle; executa as duas suítes e confere build determinístico.
Resultados e limitações estão em [`docs/V2_TESTS.md`](docs/V2_TESTS.md).
**Nenhum teste Roblox/Studio, multiplayer, captura da UI ou medição de FPS foi executado nesta entrega.**

## Referências técnicas

[RenderPriority e BindToRenderStep](https://create.roblox.com/docs/reference/engine/classes/RunService/BindToRenderStep),
[ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui),
[BoxHandleAdornment](https://create.roblox.com/docs/reference/engine/classes/BoxHandleAdornment),
[Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight).
