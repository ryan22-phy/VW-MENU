# Inventário com nível de evidência

Nenhuma função de gameplay foi verificada em runtime. “Comprovado estaticamente” abaixo significa que a operação está expressa no texto do arquivo; não significa execução bem-sucedida. Identificadores E01–E05 e hashes estão em `REA_REPORT.md`.

## Operações verificadas

| Nome e categoria | Finalidade e comportamento expresso | Parâmetros | Ativação | Dependências | Estados/eventos/resultados | Implementação independente | Evidência |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Busca do loader; inicialização | Solicita a string do endereço remoto | URL HTTP literal | Avaliação do encaminhador; controle visual desconhecido | `game:HttpGet`, rede, host remoto | Retorno esperado: texto; tratamento de falha não aparece | Tecnicamente possível, mas não necessário nem adotado para o menu local | E01 linha 1 |
| Compilação dinâmica; inicialização | Entrega o retorno anterior ao compilador dinâmico | String retornada pela busca | Imediata, na mesma expressão | `loadstring` oferecido pelo ambiente | Função retornada em caso de compilação; nenhuma proteção explícita na expressão | Substituída por módulos locais próprios no projeto | E01 linha 1 |
| Invocação imediata; inicialização | Chama sem argumentos explícitos o retorno de `loadstring` | Nenhum argumento explícito | Imediata, na mesma expressão | Sucesso das duas operações anteriores | O resultado do payload não foi observado | Inicialização própria diretamente pelo código local | E01 linha 1 |
| Invólucro protegido; estrutura | Retorna expressão encadeada a partir de tabela com funções e dados | Varargs repassados na expressão final; contratos desconhecidos | Após invocação anterior | Ambiente e bibliotecas referenciadas; demais requisitos desconhecidos | Funções do payload, eventos e resultados não determinados | Sem reuso ou reconstrução da proteção; camada própria criada do zero | E02 linha 3; E05 |

## Recursos anunciados, sem comprovação comportamental

A [descrição pública ScriptBlox](https://scriptblox.com/script/Steal-An-Egg-Lumin-Hub-223771), seção Description, linha 66 do texto normalizado, anuncia estas famílias. O resumo agrupa a lista publicada; não é inventário de implementação recuperada:

| Família anunciada | Resumo da declaração |
| --- | --- |
| Coleta e deslocamento | Roubo automático, seleção de zonas, retorno e viagens à base/lobby, gestão de ovos carregados e uso de esteira. |
| Eventos e combate | Rifts, ingredientes, trocas, recompensas, chefe, cristais, ataques, consumíveis, loja, árvores e evento de cerejeira. |
| Incubação e progressão | Incubadora, mutações, abertura e colocação de ovos, equipamentos, favoritos, renascimento, melhorias, trilhas, índice, códigos e recompensas. |
| Inventário | Venda, fusão, filtros de preservação, revelação e remoção de pets próprios. |
| Observação e alertas | Busca e previsão de ovos, ESP por entidades, radar, informações do servidor, raridade, desconexão e resumos. |
| Jogador | Proteções declaradas, animações, reset, salto, colisão e voo. |
| Sessão e apresentação | Servidores, reconexão, desempenho, renderização, atalhos, execução, watermark, erros, depuração, cursor, arquivos e encerramento. |

Para todas essas famílias, parâmetros, tipos de controles, dependências, eventos, frequência, estados internos, falhas e resultados são **desconhecidos**. A viabilidade de uma versão autorizada depende dos contratos do jogo próprio e de validação pelo servidor. Os rótulos não justificam implementar funcionalidades fictícias, explorar o jogo de terceiros ou remover proteção de licença.

A página também identifica sistema de key; a [página oficial](https://www.luminon.top/) descreve acesso gratuito com chave e Lifetime. Isso confirma a descrição de acesso publicada; nenhum fluxo de autenticação foi aberto ou testado. A nova implementação inicia diretamente porque é código independente.

## Relação com VW MENU

As abas Main, Player, Visual, Teleport e Settings, sua paleta, Ctrl, controles, animações e dimensão aproximada vêm do brief do usuário. Não foram atribuídos ao Lumin Hub. Controles de demonstração devem permanecer marcados como demonstração, com callbacks locais e sem prometer alteração de gameplay.

Persistência só deve existir no escopo permitido pelo projeto: estado durante a sessão ou integração explícita de configurações próprias. Não se presume acesso a arquivos de executor ou DataStore no cliente. Os recursos efetivamente implementados e os testes do novo código constam da documentação do projeto, separadamente deste inventário do alvo.
