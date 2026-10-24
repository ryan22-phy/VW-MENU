# VW MENU — brief de implementação

Fonte de requisitos: pedido explícito do usuário nesta conversa. Este documento transcreve esse brief; não registra uma aprovação adicional de escolhas não apresentadas.

Interface nativa Luau, cliente Roblox, sem bibliotecas externas ou autenticação. Paleta: #090D14, #101D32, #17365A, #58B9FF, #80CEFF, #E7F1FA. Janela de referência 610 × 390, cabeçalho com título VW MENU e CONTROL PANEL, lateral 155, abas Main/Player/Visual/Teleport/Settings. Fonte Gotham, divisórias discretas, raios pequenos, animação 0,18 s.

Desktop: cabeçalho arrastável, Ctrl esquerdo/direito alterna, foco de TextBox bloqueia atalho. Mouse/teclado nos componentes. Touch: botão VW de reabertura sempre disponível, controles acionáveis por toque, escala ajustada ao espaço útil, conteúdo rolável. A orientação e o tamanho real precisam de validação em dispositivo.

Estados: aberto inicialmente, fechado mantendo atalho, aba selecionada, toggle ligado/desligado, slider com valor, dropdown expandido/selecionado, notificações e erros de callback. Componentes de gameplay são demonstrações identificadas e não alteram o personagem. Configurações visuais são reais. Persistência local apenas durante a sessão.

Decisões de engenharia: módulos com responsabilidades solicitadas e empacotamento determinístico em arquivo único. Uma instância de UI por cliente, limpeza por proprietário, sem remotes ou autoridade de servidor. Nenhuma afirmação de semelhança visual ao original sem capturas ou fonte.
