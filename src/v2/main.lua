local Config = require(script.Parent.config)
local Cleanup = require(script.Parent.cleanup)
local PlayerTracker = require(script.Parent.tracker)
local AimController = require(script.Parent.aim)
local ESPController = require(script.Parent.esp)
local UI = require(script.Parent.ui)

local Main = {}

local function services()
    local result = {}
    for _, name in ipairs({"Players", "RunService", "UserInputService", "TweenService", "GuiService", "VRService", "HttpService", "Workspace"}) do
        result[name] = game:GetService(name)
    end
    return result
end

local function shutdownPrevious(playerGui)
    for _, previous in ipairs(playerGui:GetChildren()) do
        local owned = previous:GetAttribute("Owner") == "VWMenu"
        local known = previous.Name == "VWMenuRuntime_v2" or previous.Name == "VWMenu_Client_v1"
        if owned and known then
            local shutdown = previous:FindFirstChild("VWMenu_Shutdown")
            assert(shutdown and shutdown:IsA("BindableFunction"), "VW MENU anterior sem endpoint de limpeza; inicialização cancelada")
            local ok, problem = pcall(function() return shutdown:Invoke() end)
            assert(ok and previous.Parent == nil, "Não foi possível limpar a instância anterior: " .. tostring(problem))
        end
    end
end

local function controls(ui, config, app)
    ui:AddTab("AIM", "AIM", "Habilite e segure RMB. A mira usa o centro da tela.", "01")
    ui:AddTab("ESP", "ESP", "Overlays locais para o ambiente de teste autorizado.", "02")
    ui:AddTab("VISUAL", "VISUAL", "Cores em #RRGGBB; a amostra exibe a cor escolhida.", "03")
    ui:AddTab("SETTINGS", "SETTINGS", "Estado da sessão e descarregamento completo.", "04")
    local bindings = {}
    local function add(tab, kind, key, title, description, options)
        local definition = {Id = tab .. "_" .. key, Title = title, Description = description, Value = config:Get(key)}
        local range = Config.Ranges[key]
        if range then definition.Min, definition.Max, definition.Step = range[1], range[2], range[3] end
        definition.Options = options
        definition.OnChanged = function(value)
            local accepted, problem = config:Set(key, value)
            if not accepted then warn("[VW MENU] " .. tostring(problem)) end
        end
        local handle = ui["Add" .. kind](ui, tab, definition)
        table.insert(bindings, {Key = key, Handle = handle})
    end
    add("AIM", "Toggle", "AimEnabled", "Aim Assist", "Atua somente enquanto MouseButton2 estiver pressionado.")
    add("AIM", "Slider", "SmoothSpeed", "Smooth Speed", "1 a 30. Maior valor aproxima a câmera mais rápido.")
    add("AIM", "Slider", "FOVRadius", "FOV Radius", "Raio em pixels: 30 a 400.")
    add("AIM", "Toggle", "ShowFOV", "Show FOV", "Círculo visível mesmo com Aim Assist desativado.")
    add("AIM", "Toggle", "WallCheck", "Wall Check", "Exige linha de visão até a parte selecionada.")
    add("AIM", "Toggle", "TeamCheck", "Team Check", "Ignora aliados. Jogadores neutros não são aliados.")
    add("AIM", "Toggle", "TargetLock", "Target Lock", "Conserva o alvo enquanto vivo, visível e no FOV.")
    add("AIM", "Dropdown", "TargetPart", "Target Part", "A parte precisa existir; sem troca silenciosa.", {"Head", "HumanoidRootPart"})

    add("ESP", "Toggle", "ESPEnabled", "ESP", "Liga ou remove todos os overlays.")
    for _, item in ipairs({
        {"Highlight", "Highlight", "Contorno e preenchimento do personagem."},
        {"Boxes", "Boxes", "Caixa 3D acompanha os limites do modelo."},
        {"NameTags", "Name Tags", "Nome de exibição e usuário."},
        {"ShowHealth", "Show Health", "Vida atual / máxima, independente do nome."},
        {"ShowDistance", "Show Distance", "Distância em studs, independente do nome."},
        {"TeamColors", "Team Colors", "Usa TeamColor; desative para Friend/Enemy."},
        {"ShowTeammates", "Show Teammates", "Exibe também personagens da sua equipe."},
    }) do add("ESP", "Toggle", item[1], item[2], item[3]) end
    add("ESP", "Color", "FriendColor", "Friend Color", "Usada no modo Team / Relation sem Team Colors.")
    add("ESP", "Color", "EnemyColor", "Enemy Color", "Também se aplica a jogadores neutros.")
    add("ESP", "Slider", "HighlightTransparency", "Highlight Transparency", "0 = opaco; 1 = preenchimento invisível.")

    add("VISUAL", "Toggle", "ShowFOV", "Show FOV", "Sincronizado com o mesmo controle na aba AIM.")
    add("VISUAL", "Color", "FOVColor", "FOV Color", "Amostra e círculo atualizados ao confirmar a cor.")
    add("VISUAL", "Slider", "FOVThickness", "FOV Thickness", "Espessura em pixels.")
    add("VISUAL", "Slider", "FOVTransparency", "FOV Transparency", "0 = opaco; 1 = invisível, em ambos os renderizadores.")
    for _, component in ipairs({"Name", "Box", "Highlight"}) do
        add("VISUAL", "Dropdown", component .. "ColorMode", component .. " Color Mode", "Custom aplica a cor abaixo; Team / Relation usa a aba ESP.", {"Team / Relation", "Custom"})
        add("VISUAL", "Color", component .. "Color", component .. " Color", "Ative Custom para aplicar esta cor ao overlay.")
    end
    add("SETTINGS", "Toggle", "ReducedMotion", "Reduce Motion", "Aplica novas transições do menu sem animação.")
    ui:AddButton("SETTINGS", {Id = "Reset", Title = "Reset Defaults", ButtonText = "Restaurar", Description = "Desliga AIM/ESP e restaura todas as configurações.", OnActivated = function() config:Reset() end})
    ui:AddButton("SETTINGS", {Id = "Unload", Title = "Unload", ButtonText = "Descarregar VW MENU", Description = "Remove UI, FOV, overlays, eventos e render binding.", OnActivated = function() app:Destroy() end})
    local setStatus = ui:AddStatus("SETTINGS", {Id = "Status", Title = "Runtime Status"})
    local function synchronize()
        ui:SetReducedMotion(config:Get("ReducedMotion"))
        for _, binding in ipairs(bindings) do binding.Handle:Set(config:Get(binding.Key), false) end
    end
    app.Cleanup:Add(config:Subscribe(synchronize))
    synchronize()
    return setStatus
end

function Main.start()
    local s = services()
    assert(s.RunService:IsClient(), "Execute VW MENU em um LocalScript no cliente")
    local player = s.Players.LocalPlayer
    assert(player, "LocalPlayer não está disponível")
    local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    assert(playerGui, "PlayerGui não está disponível")
    shutdownPrevious(playerGui)

    local cleanup = Cleanup.new()
    local app = {Cleanup = cleanup, Unloaded = false}
    function app:Destroy()
        if self.Unloaded then return end
        self.Unloaded = true
        cleanup:Destroy()
    end
    local ok, result = pcall(function()
        -- Direct ScreenGui children survive PlayerGui respawn reset; a Folder does not.
        local root = Instance.new("ScreenGui")
        root.Name = "VWMenuRuntime_v2"
        root.ResetOnSpawn, root.IgnoreGuiInset = false, true
        root:SetAttribute("Owner", "VWMenu")
        root:SetAttribute("Version", 2)
        root.Parent = playerGui
        cleanup:Add(root)
        cleanup:Add(root.Destroying:Connect(function() app:Destroy() end))
        local shutdown = Instance.new("BindableFunction")
        shutdown.Name = "VWMenu_Shutdown"
        shutdown.OnInvoke = function() app:Destroy(); return true end
        shutdown.Parent = root
        if script and script:IsA("LocalScript") then cleanup:Add(script.Destroying:Connect(function() app:Destroy() end)) end

        local config = cleanup:Add(Config.new())
        local tracker = PlayerTracker.new(s, cleanup:Scope("tracker"))
        local id = s.HttpService:GenerateGUID(false)
        local function context(name)
            return {Services = s, Root = root, Config = config, Tracker = tracker, Id = id, Cleanup = cleanup:Scope(name)}
        end
        app.Config, app.Tracker = config, tracker
        app.Aim = AimController.new(context("aim"))
        app.ESP = ESPController.new(context("esp"))
        app.UI = UI.new(playerGui, cleanup:Scope("ui"))
        cleanup:Add(app.UI:GetGui().Destroying:Connect(function() app:Destroy() end))
        local setStatus = controls(app.UI, config, app)
        local elapsed = 0
        local function status()
            local aim, esp = app.Aim, app.ESP
            local aimState = "desligado"
            if config:Get("AimEnabled") then
                aimState = aim.Bound and (aim.Target and aim.Target.Player.Name or "sem alvo no FOV") or "aguarde RMB / câmera elegível"
            end
            local lastError = aim.LastError or esp.LastError or config.LastError or cleanup.LastError
            setStatus(string.format("AIM: %s\nESP: %s | overlays: %d\nFOV: %s | %s\nConexões gerenciadas: %d\nRender binding: %s\nErro interno: %s",
                aimState, config:Get("ESPEnabled") and "ligado" or "desligado", esp.Count,
                aim.FOVBackend, config:Get("ShowFOV") and "visível" or "oculto",
                cleanup:ConnectionCount(), aim.Bound and "ativo" or "inativo", lastError and string.sub(lastError, 1, 90) or "nenhum registrado"))
        end
        cleanup:Add(s.RunService.Heartbeat:Connect(function(deltaTime)
            elapsed += deltaTime
            if elapsed >= 0.5 then
                elapsed %= 0.5
                if app.UI:IsOpen() and app.UI._selectedTab == "SETTINGS" then status() end
            end
        end))
        status()
        root:SetAttribute("Ready", true)
        return app
    end)
    if not ok then app:Destroy(); error("[VW MENU] Falha na inicialização: " .. tostring(result), 0) end
    return result
end

return Main
