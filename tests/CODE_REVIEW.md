# Revisão independente do VW MENU

Revisão estática em 24/10/2026. Escopo: os oito arquivos de `src/`, `tools/build.py`, o bundle `VW_MENU.lua` e a estrutura XML de `VW_MENU.rbxmx`. O alvo Lumin foi tratado separadamente e nunca executado. Esta revisão não equivale a playtest do Roblox Studio.

## Achado corrigido

**[P1] Enum de fonte inexistente interrompia a inicialização.** Em `src/NotificationManager.lua:108`, a primeira versão usava `Enum.Font.GothamSemibold`. Esse item não existe no enum [Font da documentação oficial](https://create.roblox.com/docs/reference/engine/enums/Font); a notificação inicial é chamada dentro de `Main.Start()`, portanto o acesso inválido dispararia o tratamento de falha e a limpeza do painel. A versão reinspecionada usa `Enum.Font.GothamMedium`, item existente. Correção confirmada por leitura do arquivo atual e pela inclusão exata desse módulo nos dois artefatos gerados. Nenhum runtime do Roblox foi usado para esta confirmação.

Nenhum bloqueador de código conhecido após a correção. As pendências de runtime abaixo impedem tratar a revisão como aprovação total do comportamento no Studio.

## Contratos e ciclo de vida examinados

- Main utiliza os métodos existentes da UI e dos managers. Os handles implementam `Set` com chamadas tanto por ponto quanto por dois-pontos, compatíveis com a sincronização e a reversão de valor rejeitado.
- As definições do registro utilizam chaves e faixas aceitas pelo SettingsManager. Os valores demonstrativos não alteram personagem, economia, inventário ou servidor.
- A revisão final incluiu `Main.lua:40–41`: as preferências salvas de movimento reduzido e escala são aplicadas antes de criar os controles.
- A revisão final incluiu `UIController.lua:76–88`: cada botão possui UIStroke de hover em `#80CEFF`, com `ApplyStrokeMode.Border`. O stroke pertence ao botão e utiliza os dois listeners de mouse já existentes. Seus tweens passam pelo mesmo registro e cleanup dos demais efeitos; não houve conexão adicional.
- O Ctrl mantém registro das teclas pressionadas, ignora digitação em TextBox e limpa o registro na liberação/fim de foco. O listener pertence ao ciclo da GUI e o launcher permanece fora do CanvasGroup fechado.
- As conexões de arraste, slider e teclado são registradas no CleanupManager. Perda de foco e fechamento apagam o arraste ativo. A animação de fechamento cancela seu timer anterior.
- A troca de aba e o fechamento de dropdown retiram o foco de controles ocultos. A navegação lateral é um ScrollingFrame. As duas correções já estavam presentes e não são tratadas como achados pendentes.
- CleanupManager realiza limpeza LIFO protegida e idempotente. O handshake de rerun solicita encerramento da GUI própria antes de destruí-la. O botão de encerramento aciona o mesmo cleanup; o callback do bootstrap também pertence ao escopo da aplicação.
- FeatureController impede alterações concorrentes por registro, destrói o escopo anterior e sinaliza cancelamento em cleanup. Os callbacks atualmente registrados são locais e síncronos; não existem workers de gameplay para validar.
- As notificações retêm até três frames. Frames e tweens são destruídos ao remover cada toast. Timers curtos restantes guardam referência fraca ao manager e não voltam a operar após Destroy; não há loop permanente.

## Verificações dos artefatos executadas

Uma verificação local com Python e `xml.etree.ElementTree`, sem avaliar Luau, confirmou novamente após os ajustes finais do Main e do hover:

1. Todos os sete módulos atuais de `src/` aparecem exatamente no bundle, após a única transformação prevista de `require(script.Parent.X)` para o resolvedor local.
2. `VW_MENU.rbxmx` é XML analisável e contém sete ModuleScripts e um LocalScript Bootstrap em um Folder. Cada propriedade Source coincide exatamente com seu arquivo de origem atual.
3. Os marcadores `luminon.top`, `lura.ph`, `scriptblox.com` e o encaminhador `loadstring(game:HttpGet` não aparecem no bundle.
4. O build lê uma allowlist fixa de sete módulos próprios e o bootstrap; não lê `analysis/`, os corpos originais ou evidência externa. O .rbxmx preserva os requires entre módulos irmãos.

Esses checks comprovam consistência textual e XML. A importação pelo Studio e o funcionamento em engine permanecem verificações distintas.

Uma verificação intermediária havia identificado o Main anterior no pacote. Após a regeneração, o último check encontrou igualdade de todos os módulos atuais no bundle e no .rbxmx, incluindo as preferências iniciais e o hover final.

## Limites a validar no Studio

- Ajuste de textos e rolagem em viewports estreitos, especialmente descrições de altura fixa; não foi feita medição de fontes ou inspeção visual do painel em engine.
- Interação entre Tab/Return/Space e navegação/CoreGui do jogo, além de mouse e toque reais.
- Repetição de abrir/fechar, reexecução e remoção do bootstrap com o scheduler real, bem como respawn e mudanças de orientação.
- Ausência de erros no Output, comportamento dos CanvasGroups e importação do modelo. Parsing XML e compilação isolada não comprovam esses resultados.

Não houve teste multiplayer, executor Xeno, vazamento medido por profiler ou equivalência com gameplay do Lumin. A revisão não acrescenta esses resultados aos testes do projeto.

## Identidade do snapshot revisado

| Arquivo | SHA-256 |
| --- | --- |
| `src/Main.lua` | `4e5ec648dc3e24e536d35e23d3d0a542c90220bf26da38af0787805adeef1117` |
| `src/UIController.lua` | `71438809215b17b566e31953351958be7848c813c2a27923c3112ebfdd576df3` |
| `src/NotificationManager.lua` | `233301d6fea166cef82dee8b73e33d6d9bc0c95ac7037ac35ba762238fb4c523` |
| `src/FeatureController.lua` | `212a7e5fac46f439dc187c06486bee76f7df85551eac963db641458668f9d3a5` |

Alterações posteriores exigem reavaliação dos pontos afetados. Esta revisão apenas leu `src/` e o build; não os modificou.
