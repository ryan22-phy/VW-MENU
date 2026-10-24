# Testes e auditoria — VW MENU

Data: 24/10/2026. Nenhum Roblox Studio estava conectado. Os resultados abaixo não são playtest, avaliação visual, medição real de memória, validação multiplayer ou compatibilidade Xeno.

## Verificações executadas

| Verificação | Resultado e alcance |
| --- | --- |
| Compilador oficial Luau 0.740 | Código próprio, bundle e specs compilados; detalhes e quantidade em `compile-results.txt`. Não verifica propriedades/API da engine. |
| Cleanup e Settings | 43 assertions aprovadas: LIFO, idempotência, conexões simuladas, falhas contidas, tipos/faixas/NaN/infinito, whitelist, cópia, reexecução e ownership. |
| FeatureController | Spec aprovada: recurso repetido não duplica trabalho, desligar/finalizar limpa escopo, erro contido e instância encerrada não reinicia recurso. |
| Notificações | 14 assertions aprovadas com stubs: máximo de três, expiração, 80 pushes sem crescimento do registro de cleanup, duração limitada e callbacks inofensivos após Destroy. |
| Integração Main | 75 assertions aprovadas com cinco módulos reais e adaptadores de UI/notificação: callbacks, cinco abas/dez controles, reset, rerun síncrono, ownership, Destroying, encerramento e falha parcial de inicialização. |
| Empacotamento | Igualdade textual entre fontes, bundle e Source XML; sete módulos e um bootstrap; sem dependência remota/executor nos fontes independentes. Ver `package-results.json`. |
| Evidências REA | Hash, tamanho, metadados HTTP e coordenadas léxicas conferidos. Nenhuma amostra original compilada ou executada. |
| Revisão independente | Defeito de fonte identificado e corrigido; nenhum bloqueador de código conhecido na última revisão. Ver `CODE_REVIEW.md` e seus limites. |

Resultados brutos: `support-results.txt`, `main-integration-results.txt`, `compile-results.txt` e `final-validation.json`. O último arquivo registra a execução da suíte de entrega e seus códigos de saída. A validade desses resultados se limita ao snapshot de fontes/hash registrado.

## Falhas encontradas e corrigidas

- A primeira implementação de notificação usava `GothamSemibold`, ausente no [enum Font oficial](https://create.roblox.com/docs/reference/engine/enums/Font). O stub genérico aceitava qualquer enum e não detectava isso. Foi adicionada uma whitelist de Font: a regressão falhou antes da troca para `GothamMedium` (`font-regression-red.txt`) e passou depois. Outros stubs continuam sem validar toda a API Roblox.
- A revisão estática encontrou ativação possível de foco oculto por teclado e lateral sem rolagem em telas baixas. Corrigidos no código; o comportamento em engine ainda precisa de teste real.
- Uma execução da suíte agregada falhou ao gravar no diretório temporário do sandbox. O orquestrador passou a aceitar `--work-dir` e direcionar TMP/TEMP dos processos filhos a essa pasta. Isso é uma correção do ambiente de testes, não uma falha do menu.

## Reproduzir localmente

Obtenha uma distribuição oficial de Luau nas [releases do projeto](https://github.com/luau-lang/luau/releases). A verificação original usou a versão 0.740; ZIP com SHA-256 `be676d9a1092b3d5ee36be5f5f11e2af1976911c32f5644a052548dc7c66bb9c`. Nenhum runtime foi instalado globalmente ou incluído como dependência do menu.

Nesta pasta, com Python 3.6+ e os executáveis locais disponíveis:

```text
python -B tools/validate.py --luau CAMINHO/luau.exe --compiler CAMINHO/luau-compile.exe --work-dir CAMINHO_GRAVAVEL/work
```

O comando regenera o bundle/modelo, verifica integridade/evidências, executa testes de lógica com stubs e compila somente o código próprio. Não baixa ou executa o Lumin Hub. Os runners individuais também usam a pasta temporária do Python; escolha TMP/TEMP graváveis se rodá-los separadamente.

## O que permanece pendente

Execute [STUDIO_CHECKLIST.md](STUDIO_CHECKLIST.md). Faltam renderização, tamanhos/fontes reais, toques/scroll, Ctrl e TextBox com entrega real de eventos, interação com CoreGui, importação do modelo, respawn/orientação, Output e profiling de memória/desempenho.

Timers de notificações são guardados por token/referência fraca. Seus frames e tweens são removidos imediatamente; closures podem permanecer no scheduler por até 15 segundos. Os testes não provam ausência de vazamentos no Roblox. A limpeza de conexões no teste de integração mede os adaptadores e a propriedade de Main, não o sistema real de sinais da engine.

Luau Language Server e Selene não foram encontrados no PATH desta sessão; não foi realizada análise semântica completa com definições Roblox. Compilação não teria detectado o enum inválido sozinha. Nenhuma API de gameplay ou remotes de servidor existe no pacote, e não houve teste com múltiplos clientes.
