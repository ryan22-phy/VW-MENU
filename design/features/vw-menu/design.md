# VW MENU

Status: brief fornecido pelo usuário; implementação direta desse escopo.

Aplicar ../../DESIGN.md. Main contém demonstração de toggle e teste de notificação; Player contém slider demonstrativo; Visual contém dropdown demonstrativo e redução de movimento real; Teleport contém destino demonstrativo e botão que apenas informa a seleção; Settings contém escala real, reset e encerramento. Não existem fluxos de compra, inventário, rede, permissões de gameplay ou chave.

Ao falhar um callback, exibir notificação de erro e sincronizar o controle ao estado aceito. Dropdown fecha após seleção. Ao encerrar, destruir UI, eventos, timers e escopos; ao apenas ocultar, manter Ctrl e botão touch. Em reexecução, emitir encerramento da instância anterior antes da substituição. O estado inicial é aberto mesmo que a execução anterior tenha sido ocultada.
