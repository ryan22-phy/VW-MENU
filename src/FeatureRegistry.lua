-- Independent controls. Demo entries do not affect the character or the game.
local FeatureRegistry = {}

FeatureRegistry.Tabs = {
    { Id = "Main", Title = "Main", Description = "Controles do painel e demonstracoes.", Icon = "01" },
    { Id = "Player", Title = "Player", Description = "Componentes preparados para integracao autorizada.", Icon = "02" },
    { Id = "Visual", Title = "Visual", Description = "Preferencias visuais e exemplos de selecao.", Icon = "03" },
    { Id = "Teleport", Title = "Teleport", Description = "Demonstracao de destinos. Nenhum teleporte e executado.", Icon = "04" },
    { Id = "Settings", Title = "Settings", Description = "Ajustes locais. Salvos somente nesta sessao.", Icon = "05" },
}

function FeatureRegistry.Create()
    return {
        { Id = "demoEnabled", Tab = "Main", Kind = "Toggle", Key = "demoEnabled",
            Title = "Demo: toggle", Description = "Altera apenas o estado deste componente.",
        },
        { Id = "notify", Tab = "Main", Kind = "Button", Title = "Testar notificacao",
            Description = "Exibe uma mensagem local do VW MENU.",
            Run = function(context) context.Notify:Push("VW MENU", "Painel independente pronto para suas integracoes.") end,
        },
        { Id = "demoValue", Tab = "Player", Kind = "Slider", Key = "demoValue",
            Title = "Demo: valor", Description = "Valor de exemplo; nao altera velocidade ou personagem.",
            Min = 0, Max = 100, Step = 1,
        },
        { Id = "demoChoice", Tab = "Visual", Kind = "Dropdown", Key = "demoChoice",
            Title = "Demo: perfil", Description = "Selecao de exemplo para um callback futuro.",
            Options = { "Equilibrado", "Rapido", "Preciso" },
        },
        { Id = "reducedMotion", Tab = "Visual", Kind = "Toggle", Key = "reducedMotion",
            Title = "Reduzir movimento", Description = "Aplica imediatamente as transicoes do painel.",
            Apply = function(value, _, context) context.UI:SetReducedMotion(value) end,
        },
        { Id = "demoDestination", Tab = "Teleport", Kind = "Dropdown", Key = "demoDestination",
            Title = "Demo: destino", Description = "Nomes ficticios para testar o dropdown.",
            Options = { "Laboratorio", "Praca", "Oficina" },
        },
        { Id = "inspectDestination", Tab = "Teleport", Kind = "Button",
            Title = "Demo: confirmar", Description = "Mostra a selecao; nao movimenta o jogador.",
            Run = function(context)
                context.Notify:Push("Destino de demonstracao", context.Settings:Get("demoDestination") .. " selecionado. Nenhum teleporte foi executado.")
            end,
        },
        { Id = "uiScale", Tab = "Settings", Kind = "Slider", Key = "uiScale",
            Title = "Escala do painel", Description = "80% a 110%, limitada ao espaco disponivel.",
            Min = 0.8, Max = 1.1, Step = 0.05,
            Apply = function(value, _, context) context.UI:SetScale(value) end,
        },
        { Id = "reset", Tab = "Settings", Kind = "Button", Title = "Restaurar preferencias",
            Description = "Restaura valores e componentes desta sessao.",
            Run = function(context) context.Reset() end,
        },
        { Id = "destroy", Tab = "Settings", Kind = "Button", Title = "Encerrar VW MENU",
            Description = "Remove o painel e todos os seus eventos. Execute novamente para abrir.",
            Run = function(context) context.Destroy() end,
        },
    }
end

return FeatureRegistry
