# Validação VW MENU v2 — 30/10/2026

Ambiente: Windows, compilador e runtime Luau CLI locais. Studio MCP retornou zero instâncias; Ropilot informou ausência de conexão.
Não houve instalação global de runtime nem execução no Roblox.

## Executado localmente

- 10 testes de Config, Cleanup, matemática de suavização/FOV, equipes neutras e seleção exata de Head.
- 7 testes de políticas dos controladores e eventos com doubles mínimos de API: criação tardia de partes, 20 gerações de personagem com contagem estável, saída, morte/stream-out, nearest target, target lock, wall check e precedência de cores do ESP.
- Compilação real dos sete módulos, bundle, loader e três arquivos de teste.
- Build repetido com igualdade byte a byte; imports locais conhecidos resolvidos sem dependência circular.
- Revisão independente de código: corrigida a raiz de UI vulnerável ao reset de PlayerGui. Sem P1/P2 confirmado pendente na revisão.

O teste de resiliência de Cleanup injeta um erro proposital, que aparece no log. A suíte verifica que os demais recursos continuam sendo liberados.
Os resultados completos ficam em [`tests/v2-local-results.json`](../tests/v2-local-results.json).
Os doubles exercitam políticas e propriedade de conexões; **não executam o engine, renderização ou a UI completa**.

## Checklist de playtest pendente

| Pedido | Resultado nesta entrega | Procedimento no Studio |
| --- | --- | --- |
| 1. Ctrl abre/fecha | Não executado no Roblox | Alternar ambos Ctrl, texto focado, minimizar, fechar e reabrir pelo VW |
| 2. Recursos independentes | Políticas Config/ESP testadas localmente; UI pendente | Acionar cada controle e verificar seu overlay/câmera, incluindo HP/distância sem nomes |
| 3. Sliders ao vivo | Validação e limites testados localmente; arraste pendente | Mudar todos os sliders enquanto os recursos estão ativos |
| 4. Equipes diferentes | Relações e cores testadas com doubles | Dois ou mais clientes, equipe igual/diferente, neutros e mudanças de equipe |
| 5. Paredes | Política Raycast testada com double | Obstáculos reais e partes CanQuery; Wall Check ligado/desligado |
| 6. Morte/respawn/saída | Tracker testado com sinais simulados | Morrer, reaparecer e desconectar clientes; confirmar config/UI persistentes |
| 7. R6 e R15 | Uso de partes comuns revisado; rigs não executados | Jogar com ambos os rigs e escalas; conferir limites das caixas |
| 8. Reexecutar duas vezes | Escopos testados; handshake real pendente | Executar v2 duas vezes; conferir uma raiz, uma UI e um FOV; contagem estável |
| 9. Unload completo | Cleanup idempotente testado localmente | Descarregar durante RMB/arraste/tween; confirmar ausência de UI, Highlights e binding |
| 10. Vazamentos/FPS/console | Contagem de escopos com doubles; FPS/console não medidos | MicroProfiler e Output com vários clientes e ciclos de toggles/respawn |

Validar ainda: troca de CurrentCamera, Scriptable/VR, viewport pequeno/touch, Drawing opcional e StreamingEnabled.
O Aim com RMB atua somente com mouse; a UI possui controles de toque.
Limites de renderização de Highlights e custo com muitos jogadores dependem do engine/dispositivo; não foi atribuído resultado de FPS.

Não foram realizados testes dos módulos antigos preservados; os relatórios anteriores do repositório se referem à versão demonstrativa.
