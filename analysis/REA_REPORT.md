# REA — Lumin Hub e limites da reconstrução

Data da coleta: 24/10/2026, America/Sao_Paulo. Análise de arquivos como dados; nenhuma amostra foi executada.

O raw ScriptBlox é somente um encaminhador de 59 bytes. O destino forneceu 291.684 bytes de Lua/Luau protegido. É possível comprovar a cadeia de inicialização e a estrutura externa ofuscada. Não foi possível comprovar funcionalidades de gameplay, parâmetros, organização da interface original ou resultado de execução. O VW MENU deve, portanto, ser tratado como implementação independente do brief do usuário, sem alegação de equivalência ao Lumin Hub.

## Identidade e cadeia de evidências

| ID | Alvo | Resultado coletado | SHA-256 |
| --- | --- | --- | --- |
| E01 | [Raw ScriptBlox](https://scriptblox.com/raw/Steal-An-Egg-Lumin-Hub-223771) | HTTP 200; 59 bytes; 1 linha | `da0393d9129e697ede95a56103d2e30bc329c499ef9e9e87396c2af2b5752970` |
| E02 | [Loader fornecido](http://luminon.top/loader.lua) | HTTP 200; 291.684 bytes; 3 linhas | `aecbc6c2561acd12bb37ca5692ff42c39b65e603d73c9019746d1d4611ebc402` |
| E03 | [Anúncio ScriptBlox](https://scriptblox.com/script/Steal-An-Egg-Lumin-Hub-223771) | Texto público; referência a sistema de key; descrição promocional | Sem hash do HTML; observações normalizadas em `evidence/web-observations.json` |
| E04 | [Página pública Lumin](https://www.luminon.top/) | Confirma o endereço do loader e descreve acesso por key | Sem hash do HTML; observações normalizadas em `evidence/web-observations.json` |
| E05 | `evidence/static-lexical-summary.json` | Scanner estático próprio: strings, aliases, posições e URL literal | Vinculado ao hash E02 |

Os metadados HTTP com horários UTC, cabeçalhos e resultados estão em `evidence/*metadata.json`. O download E02 ocorreu em 24/10/2026 às 10:59:50 no fuso do usuário. Seu cabeçalho Last-Modified informou 19/10/2026 16:06:58 UTC; o cache HTTP indicou HIT e Age 4220. Esses valores descrevem a resposta recebida, não uma garantia de versão atual do produto. A API utilizada não expôs a URL final no campo consultado; ela permanece nula nos metadados, sem presumir a cadeia de redirecionamentos.

As tentativas iniciais no sandbox falharam por DNS. O leitor web não aceitou o MIME `application/octet-stream` do loader. A coleta posterior com permissão de rede ampliada foi bem-sucedida, usando apenas GET e gravação de dados. Não houve rejeição automática pendente nem exigência de contornar acesso.

## Método e cobertura

1. Leitura dos alvos fornecidos e das páginas públicas relacionadas.
2. GET dos dois corpos, hash SHA-256, contagem de bytes e linhas.
3. Inspeção textual e scanner léxico próprio, sem `loadstring`, compilação, importação ou execução do alvo.
4. Reconhecimento de comentários, strings entre aspas, blocos longos e tokens visíveis; tradução apenas de escapes literais conhecidos para apoiar a leitura. Escapes desconhecidos permanecem sinalizados.
5. Separação entre comportamento expresso no encaminhador, estrutura visível do protetor e anúncios externos.

O scanner não é parser Luau, decompilador ou decodificador de VM. Seus resultados não comprovam validade de APIs, alcance de chamadas ou comportamento do payload. A análise cobriu integralmente os bytes dos dois arquivos para hash e busca léxica; não cobriu semanticamente o programa virtualizado.

## Fluxo comprovado no raw

Na linha 1 de E01, o programa solicita texto por `game:HttpGet` usando o endereço HTTP do loader, entrega o texto a `loadstring` e chama o valor resultante. A ordem é observável estaticamente; nenhuma requisição originada pelo próprio script foi executada. Não há tratamento explícito de erro nessa expressão. Seu funcionamento depende do ambiente disponibilizar essas chamadas e permitir a execução obtida.

Esse padrão de inicialização não é usado na reconstrução. No Studio, o novo menu utiliza código local desenvolvido para o projeto. Não depende de permissões, APIs de executor, servidor de autenticação ou disponibilidade dos hosts originais.

## Estrutura do loader e ofuscação

E02 declara no comentário da linha 1 o uso de Luraph Obfuscator v14.9. Isso é autodeclaração do artefato; o produto e a versão não foram autenticados por engine externa. A linha 2 está vazia. A linha 3 contém a tabela de funções, constantes, operações e a chamada final encadeada.

Observam-se identificadores curtos, constantes numéricas em formatos mistos, escapes de strings, operações bit a bit, ramificações de estados e um bloco longo de dados. A combinação é compatível com um invólucro virtualizado; a semântica do conteúdo protegido não foi recuperada. O nome do protetor, sozinho, não permite concluir comportamento malicioso.

E05 registrou 26 strings léxicas, incluindo um bloco longo, e 27 aliases diretos de bibliotecas/funções. Referências visíveis incluem `bit32`, `string`, `table`, `buffer`, `coroutine`, `debug`, `task`, `getfenv`, `setfenv`, `unpack` e `select`. Isso documenta a superfície textual, não uma lista completa de requisitos runtime. Os nomes de serviços VirtualInputManager e VirtualUser aparecem em strings escapadas na linha 3, colunas 43805 e 43876; sua presença não prova anti-AFK, automação ou uso efetivo desses serviços.

Exemplos de localização reproduzível em E02:

| Evidência | Localização, base 1 | Interpretação permitida |
| --- | --- | --- |
| Alias `m` para `string.match` | linha 3, coluna 347 | Ligação textual visível |
| Alias `Uw` para `bit32.rrotate` | linha 3, coluna 891 | Ligação textual visível |
| Token `getfenv` | linha 3, coluna 32604 | Referência visível ao ambiente |
| Alias `o` para `setfenv` | linha 3, coluna 288788 | Ligação textual visível |
| URL do protetor | linha 1, coluna 59 | Proveniência declarada no comentário |

## URLs, módulos e dependências

| Origem | Destino ou referência | Estado |
| --- | --- | --- |
| E01 linha 1 | `http://luminon.top/loader.lua` | Dependência de código remoto explícita; coletada como dados |
| E02 linha 1 | `https://lura.ph/` | URL de comentário; sem chamada de rede comprovada |
| E02 linha 3 | Bibliotecas e ambientes listados acima | Referências léxicas visíveis |
| Payload protegido | Outras URLs, ModuleScripts, remotes, autenticação, assets e bibliotecas de UI | Não determinados |

A busca por URLs literais em E02 encontrou apenas o endereço do protetor no comentário. Isso não comprova ausência de URLs codificadas, construídas em runtime ou mantidas no payload. Nenhuma URL de key, checkpoint, compra ou Discord foi visitada para acionar acesso. Não houve tentativa de falsificar ambiente, key ou resposta de licença.

## Funcionalidades e reconstrução

O inventário técnico está em `FUNCTION_INVENTORY.md`. Ele distingue três operações verificadas no encaminhador e uma superfície protegida sem semântica recuperada. As páginas públicas anunciam recursos adicionais; anúncio não comprova que um recurso esteja implementado, alcançável ou funcionando.

A cobertura reconstruível com evidência e autorização presentes é a infraestrutura própria solicitada: janela e navegação, controles demonstrativos, callbacks locais, notificações, preferências locais permitidas e limpeza. Nenhum recurso de gameplay do Lumin Hub foi demonstrado pelos dados disponíveis. Não há base para afirmar equivalência total ou parcial de gameplay.

## Não implementado e justificativas

- Gameplay de coleta, roubo, incubação, venda, fusão, combate ou progressão: faltam implementação legível, contratos de estado, remotes e projeto do jogo autorizado para integração.
- ESP, invulnerabilidade, voo, noclip, automação de servidores e ações similares do anúncio: comportamento não verificado; o brief atual pede controles demonstrativos e exclui exploração e bypass de anticheat.
- Autenticação original, key, checkpoints e licenciamento: fora da reconstrução; nenhum mecanismo foi alterado ou contornado.
- Layout original: imagem pública de prévia falhou no leitor; não se observou a interface em execução. O novo visual segue a paleta e o layout fornecidos pelo usuário.
- Compatibilidade Xeno: não foi testada. APIs de executor não são requisito da implementação para Studio.

## Resultados reais da análise

Passaram: obtenção dos dois corpos como dados, registro de hashes, inspeção textual do raw, inventário léxico completo do invólucro e rastreabilidade de posições. Não executados: runtime do original, desbloqueio por key, teste de gameplay, avaliação de desempenho do original, teste em executor ou validação multiplayer. Os testes do projeto independente devem ser registrados separadamente, com seu escopo real.

Para reproduzir somente a leitura estática, execute `tools/static_scan.py` com Python sobre o corpo já salvo. O utilitário lê bytes e grava JSON; não inicia Roblox, não acessa rede e não avalia Lua. Os corpos originais são evidência inerte, não parte do código independente e não devem ser colocados em Script, LocalScript ou ModuleScript.
