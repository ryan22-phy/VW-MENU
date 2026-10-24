# VW MENU

Interface independente em Luau para o cliente de uma experiência Roblox autorizada. Inicia aberta, sem key, usando somente APIs Roblox e código local. A análise do Lumin Hub está separada em [REA_REPORT.md](analysis/REA_REPORT.md) e [FUNCTION_INVENTORY.md](analysis/FUNCTION_INVENTORY.md).

**Não há equivalência comprovada de gameplay com o Lumin Hub.** O raw é um encaminhador e o loader obtido está ofuscado. As funções anunciadas na página pública não foram observadas em execução. O visual VW MENU segue o brief fornecido nesta conversa. Nenhum trecho do payload original foi incluído na implementação.

## Executar no Studio

Escolha uma das opções; instalar ambas cria inicializações desnecessárias.

### Arquivo único

1. Abra uma experiência própria ou autorizada no Roblox Studio.
2. Em `StarterPlayer > StarterPlayerScripts`, crie um **LocalScript** chamado `VW_MENU`.
3. Cole todo o conteúdo de [VW_MENU.lua](VW_MENU.lua) nesse LocalScript.
4. Inicie **Play**. O painel abre no cliente.
5. Use Ctrl esquerdo/direito para alternar, o X para ocultar e o botão VW para reabrir por toque/mouse. Arraste o cabeçalho para mover.

Não use Script do servidor ou Command Bar de edição para executar a UI. `HttpService`, `LoadStringEnabled`, plugins e APIs de executor não são necessários.

### Projeto modular

Insira o modelo local [VW_MENU.rbxmx](VW_MENU.rbxmx) e mova a pasta `VWMenu` para `StarterPlayerScripts`. O modelo é gerado com os mesmos fontes; sua importação visual ainda precisa ser confirmada no Studio.

Alternativamente, crie essa pasta manualmente. Coloque `Bootstrap.client.lua` como **LocalScript** chamado `Bootstrap`; cada outro arquivo em `src/` é um **ModuleScript** com o nome sem `.lua`. Todos são irmãos. Inicie Play.

## O que está implementado

| Recurso | Comportamento |
| --- | --- |
| Janela e abas | Janela de referência 610 × 390, cabeçalho arrastável, paleta solicitada, Main/Player/Visual/Teleport/Settings, conteúdo e navegação roláveis. |
| Ctrl | LeftControl e RightControl; latch evita alternância repetida; foco em TextBox bloqueia o atalho; continua conectado quando apenas oculto. |
| Teclado/toque | Launcher VW, controles por Activated, navegação Tab/Shift+Tab, Enter/Espaço e setas em sliders. Precisa de validação de entrada real nos dispositivos. |
| Toggle | Estado, cor e callback. |
| Slider | Mouse/toque, valor, limites, passo e callback. |
| Dropdown | Seleção, lista expansível, fechamento e callback. |
| Botão | Feedback, hover e callback protegido. |
| Preferências reais | Escala de 80% a 110% limitada ao espaço útil, redução das transições do painel, restauração. |
| Notificações | Até três toasts locais, duração limitada e remoção. |
| Ciclo de vida | Substituição da instância anterior com ownership, cleanup idempotente de conexões/instâncias/escopos, encerramento explícito. |
| Demonstrações | Toggle, valor, perfil e destino; somente estado da UI. A confirmação de destino exibe mensagem. |

As preferências são atributos em uma pasta criada **localmente** sob `Players.LocalPlayer`, com `Owner=VWMenu` e `Version=1`. Sobrevivem à reinicialização do menu no mesmo cliente. Não há gravação em disco, DataStore ou garantia entre sessões/servidores; não são dados autoritativos de gameplay.

“Reduzir movimento” atua nas transições do painel; a breve entrada dos toasts permanece independente. Encerrar remove os eventos do painel. Ctrl não reabre um painel encerrado; execute o script novamente. Apenas ocultar mantém Ctrl e o launcher.

## Integrar funções próprias

O `FeatureRegistry` define cada controle; `FeatureController` executa callbacks e gerencia seu escopo. Exemplo em um registro próprio:

```lua
{
    Id = "localOverlay", Tab = "Visual", Kind = "Toggle",
    Key = "myOverlaySetting", -- acrescente uma chave validada no SettingsManager
    Title = "Overlay proprio", Description = "Somente informacoes autorizadas.",
    Apply = function(enabled, scope, context, token)
        if not enabled then return end
        -- Registrar aqui objetos/conexoes de uma implementacao sua:
        -- scope:Add(connection)
        -- scope:Add(function() ... restaurar estado ... end)
        -- Trabalho assincrono deve verificar token.Cancelled apos cada yield.
    end,
}
```

`Apply(value, scope, context, token)` é síncrono para alterações de UI. Não faça yield direto nele. Para trabalho assíncrono, agende uma tarefa que consulte o token após cada yield, registre a restauração no escopo e finalize ao cancelamento. Trocar valor destrói o escopo anterior; repetir o mesmo valor não duplica trabalho. Falha de toggle deixa o recurso desligado e notifica o erro.

Botões usam `Run(context)`. Context contém `UI`, `Settings`, `Notify`, `Reset` e `Destroy`. Handles de controles têm `Get()` e `Set(value, fireCallback)`; o padrão de `fireCallback` é falso. Botões retornam `Activate()` e `Instance`. Alterações diretas em Settings não atualizam automaticamente todos os controles; use o fluxo de controller/handle ou `app.Reset()`.

Qualquer ação valiosa de um jogo próprio deve ser solicitada por remote e validada no servidor. Este pacote não cria remotes, altera personagem, concede moedas, teleporta, automatiza terceiros ou contorna anticheat.

## Estrutura

```text
VW_MENU/
  VW_MENU.lua                 arquivo unico gerado
  VW_MENU.rbxmx               pasta modular importavel
  README.md
  IMPLEMENTATION_PLAN.md
  src/
    Main.lua                  inicializacao e integracao
    UIController.lua          construcao e interacao visual
    FeatureRegistry.lua       cadastro de controles e callbacks
    FeatureController.lua     estados e escopos por recurso
    SettingsManager.lua       schema e preferencias de sessao
    NotificationManager.lua   toasts locais
    CleanupManager.lua        ownership e limpeza
    Bootstrap.client.lua      entrada modular
  tests/                      testes isolados, specs Studio e resultados
  tools/build.py              empacotador local sem dependencias
  analysis/                   relatorio, inventario e evidencias inertes
  design/                     transcricao do brief fornecido
```

Os corpos originais em `analysis/evidence/` são dados para auditoria. Não devem ser colocados em Script, LocalScript ou ModuleScript. O empacotador lê somente a lista explícita de módulos em `src/`.

## Regerar os entregáveis

Com Python 3.6+ disponível, execute `python tools/build.py` nesta pasta. Ele gera `VW_MENU.lua` e `VW_MENU.rbxmx` sem rede ou dependências. Após editar módulos, regenere antes de usar o arquivo único.

## Verificação e limites

Leia [TEST_RESULTS.md](tests/TEST_RESULTS.md) para comandos, resultados e escopo. Não havia Studio conectado nesta sessão. Compilação Luau e testes com stubs não substituem renderização, entrada real, perfis de memória, latência, multiplayer ou compatibilidade de executor. Xeno não foi testado.

Não implementados: gameplay anunciado do Lumin Hub, layout original não observado e autenticação/licenciamento do original. Faltam semântica legível do payload e contratos do jogo autorizado. O painel novo inicia sem chave porque sua implementação é independente.
