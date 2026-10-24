# Verificação no Roblox Studio — pendente

Use Play local numa experiência autorizada e selecione o contexto **Client**. Observe o Output. Não execute os arquivos de evidência.

1. Inicialização: janela aberta, 5 abas, controles legíveis, zero erro no Output. Não deve haver chamada HTTP nem tela de key.
2. Ctrl: pressionar e soltar LeftControl e RightControl; segurar; pressionar ambos; soltar; repetir. Cada ciclo de pressão alterna uma vez. Com um TextBox focado no jogo, não alternar. Perder/recuperar foco do app não deve travar o latch.
3. Ocultar: clicar X; Ctrl/launcher reabre. Durante cliques rápidos de abrir/fechar, visibilidade final deve corresponder ao último comando. Enter/Espaço não podem acionar controle oculto.
4. Navegação: visitar todas as abas, Tab/Shift+Tab, Enter/Espaço, slider por setas. Dropdown abre e fecha ao selecionar, Escape fecha, foco não fica em item oculto. Verifique se entradas CoreGui processadas interferem na navegação.
5. Componentes: toggle altera estado; slider respeita mínimo/máximo/passo; dropdown mantém seleção; botão gera toast. As demos não devem alterar personagem ou posição.
6. Preferências: mudar escala e movimento; restaurar; reinicializar o script, confirmar valores preservados na mesma sessão e painel aberto. Entrar em outra sessão não deve ser tratado como persistência garantida.
7. Rerun: executar `require(game.Players.LocalPlayer.PlayerScripts.VWMenu.Main).Start()` duas vezes na instalação modular. Deve existir somente uma ScreenGui com ownership VWMenu; um Ctrl deve gerar uma única alternância. Gui com o mesmo nome e outro ownership deve sobreviver.
8. Encerrar: botão encerra; nenhum Ctrl deve disparar callbacks antigos. Reiniciar reconstrói uma instância. Destruir a ScreenGui externamente também deve limpar o controlador.
9. Mobile: em Device Emulator testar 360×780, 390×844, 768×1024 e landscape 844×390, além de telas desktop. Verificar safe areas, texto, alcance de Settings na lateral rolável, arraste sem sair dos limites, toque no slider sem rolagem conflitante e launcher acessível. Não há captura ou teste real desses tamanhos nesta entrega.
10. Desempenho: com Developer Console/MicroProfiler, comparar antes/depois de 20 inicializações/encerramentos e 100 notificações. Aguardar até 15 s após a última notificação para os timers guardados terminarem. Checar crescimento de memória/conexões e erros; não basta contar instâncias para provar ausência de vazamento.

Specs de lógica podem ser importados como ModuleScripts e executados no cliente: `require(SupportSpec)(pastaDosModulos, game.Players.LocalPlayer)` e `require(FeatureControllerSpec)(pastaDosModulos)`. O segundo usa um Player sintético para isolamento, não testa comportamento de um jogador conectado. As specs restauram os valores válidos da configuração usada quando concluem normalmente; execute em ambiente de teste.

Se adicionar remotes ou gameplay, acrescente validação de servidor e testes de abuso/múltiplos clientes. O pacote atual não tem ações de servidor; seus testes locais não validam multiplayer.
