-- Entry point for a LocalScript in an experience you own or may test.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIController = require(script.Parent.UIController)
local FeatureRegistry = require(script.Parent.FeatureRegistry)
local FeatureController = require(script.Parent.FeatureController)
local SettingsManager = require(script.Parent.SettingsManager)
local NotificationManager = require(script.Parent.NotificationManager)
local CleanupManager = require(script.Parent.CleanupManager)

local Main = {}

function Main.Start()
    assert(RunService:IsClient(), "VW MENU must run in a LocalScript on the client")
    local player = Players.LocalPlayer
    assert(player, "LocalPlayer is not available")
    local playerGui = player:WaitForChild("PlayerGui")

    -- BindableFunction provides a synchronous, client-local shutdown handshake.
    -- A matching name alone never authorizes deleting another developer's GUI.
    for _, previous in ipairs(playerGui:GetChildren()) do
        if previous:IsA("ScreenGui") and previous.Name == "VWMenu_Client_v1"
            and previous:GetAttribute("Owner") == "VWMenu" then
            local shutdown = previous:FindFirstChild("VWMenu_Shutdown")
            if shutdown and shutdown:IsA("BindableFunction") then
                local ok, problem = pcall(function() shutdown:Invoke() end)
                if not ok then warn("[VW MENU] Previous shutdown: " .. tostring(problem)) end
            end
            previous:Destroy()
        end
    end

    local cleanup = CleanupManager.new()
    local app = { Cleanup = cleanup, Destroyed = false }
    cleanup:Add(function() app.Destroyed = true end)
    local ok, result = pcall(function()
        local settings = SettingsManager.new(player)
        local ui = UIController.new(playerGui, cleanup)
        ui:SetReducedMotion(settings:Get("reducedMotion"))
        ui:SetScale(settings:Get("uiScale"))
        local gui = ui:GetGui()
        gui:SetAttribute("Owner", "VWMenu")
        gui:SetAttribute("Version", 1)
        local notify = NotificationManager.new(gui, cleanup)
        local handles = {}
        local definitions = FeatureRegistry.Create()
        local context = { UI = ui, Settings = settings, Notify = notify }
        local controller = FeatureController.new(settings, notify, cleanup, context)
        app.UI, app.Settings, app.Features = ui, settings, controller
        app.Controls = handles
        app.Destroy = function() cleanup:Destroy() end
        context.Destroy = app.Destroy

        local shutdown = Instance.new("BindableFunction")
        shutdown.Name = "VWMenu_Shutdown"
        shutdown.OnInvoke = function()
            app.Destroy()
            return true
        end
        shutdown.Parent = gui
        cleanup:Add(shutdown)
        cleanup:Add(gui.Destroying:Connect(app.Destroy))

        for _, tab in ipairs(FeatureRegistry.Tabs) do
            ui:AddTab(tab.Id, tab.Title, tab.Description, tab.Icon)
        end

        for _, definition in ipairs(definitions) do controller:Register(definition) end

        local function synchronize()
            for _, definition in ipairs(definitions) do
                if definition.Key then
                    local accepted = controller:Set(definition.Id, settings:Get(definition.Key))
                    local handle = handles[definition.Id]
                    if handle then handle:Set(controller:Get(definition.Id), false) end
                    if not accepted then warn("[VW MENU] Cannot initialize " .. definition.Id) end
                end
            end
        end

        context.Reset = function()
            settings:Reset()
            synchronize()
            ui:SelectTab(settings:Get("selectedTab"))
            notify:Push("Preferencias restauradas", "Os controles voltaram aos valores iniciais.")
        end
        app.Reset = context.Reset

        for _, definition in ipairs(definitions) do
            local config = {
                Id = definition.Id,
                Title = definition.Title,
                Description = definition.Description,
                Value = definition.Key and settings:Get(definition.Key),
                Min = definition.Min,
                Max = definition.Max,
                Step = definition.Step,
                Options = definition.Options,
            }
            config.OnChanged = function(value)
                local accepted, problem = controller:Set(definition.Id, value)
                if not accepted then
                    handles[definition.Id]:Set(controller:Get(definition.Id), false)
                    if controller:GetState(definition.Id) ~= "error" then
                        notify:Push("Valor rejeitado", tostring(problem))
                    end
                end
            end
            config.OnActivated = function() controller:Activate(definition.Id) end
            local method = ui["Add" .. definition.Kind]
            assert(method, "Unknown control kind: " .. tostring(definition.Kind))
            handles[definition.Id] = method(ui, definition.Tab, config)
        end

        ui.OnTabChanged = function(id) settings:Set("selectedTab", id) end
        synchronize()
        ui:SelectTab(settings:Get("selectedTab"))
        ui:SetOpen(true)
        gui:SetAttribute("Ready", true)
        notify:Push("VW MENU", "Ctrl abre ou fecha. No celular, use o botao VW.", 4)
        return app
    end)
    if not ok then
        cleanup:Destroy()
        error("[VW MENU] Initialization failed: " .. tostring(result), 0)
    end
    return result
end

return Main
