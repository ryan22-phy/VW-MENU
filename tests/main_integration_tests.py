#!/usr/bin/env python3
"""Exercise Main wiring with real logic modules and explicit UI/notice adapters.

This is an isolated Luau CLI integration test, not Roblox Studio or UI testing.
Usage: python main_integration_tests.py --luau PATH_TO_LUAU_EXE
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

from isolated_tests import STUBS


ADAPTERS = r'''
-- Extend the local isolated-test doubles with synchronous lifecycle signals.
local allSignals = {}
local function signal()
    local result = { Connections = {} }
    function result:Connect(callback)
        local connection = { _kind = "RBXScriptConnection", Connected = true, Callback = callback }
        function connection:Disconnect() self.Connected = false end
        table.insert(self.Connections, connection)
        return connection
    end
    function result:Fire(...)
        for _, connection in ipairs(table.clone(self.Connections)) do
            if connection.Connected then connection.Callback(...) end
        end
    end
    table.insert(allSignals, result)
    return result
end
local function liveConnections()
    local count = 0
    for _, item in ipairs(allSignals) do
        for _, connection in ipairs(item.Connections) do
            if connection.Connected then count += 1 end
        end
    end
    return count
end
local previousNew = Instance.new
function Instance.new(className)
    local item = previousNew(className)
    item.Destroying = signal()
    if className == "BindableEvent" then item.Event = signal() end
    return item
end
function methods:FindFirstChild(name)
    for _, child in ipairs(self:GetChildren()) do
        if child.Name == name then return child end
    end
    return nil
end
function methods:WaitForChild(name)
    return assert(self:FindFirstChild(name), "Missing child in integration stub: " .. name)
end
local invokedShutdowns = 0
function methods:Invoke(...)
    assert(self:IsA("BindableFunction"), "Invoke requires BindableFunction")
    if self.Name == "VWMenu_Shutdown" then invokedShutdowns += 1 end
    return assert(self.OnInvoke, "No OnInvoke callback")(...)
end
function methods:Destroy()
    if self.Destroyed or self.DestroyingNow then return end
    self.DestroyingNow = true
    self.Destroying:Fire()
    for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    self.Parent = nil
    self.Destroyed = true
    self.DestroyingNow = false
end

local player = Instance.new("Player")
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = player
local Players = { LocalPlayer = player }
local RunService = { Client = true }
function RunService:IsClient() return self.Client end
local baseGetService = game.GetService
function game:GetService(name)
    if name == "Players" then return Players end
    if name == "RunService" then return RunService end
    return baseGetService(self, name)
end
for _, name in ipairs({ "Main", "UIController", "FeatureRegistry" }) do modules[name] = name end

local syntheticInput = signal()
local failNextUICreation = false
local UIAdapter = {}
function UIAdapter.new(parent, cleanup)
    local gui = Instance.new("ScreenGui")
    gui.Name = "VWMenu_Client_v1"
    gui.Parent = parent
    cleanup:Add(gui)
    cleanup:Add(syntheticInput:Connect(function() end))
    if failNextUICreation then
        failNextUICreation = false
        error("Deliberate UI adapter initialization failure")
    end
    local self = { Gui = gui, Tabs = {}, Controls = {}, Open = false }
    function self:GetGui() return self.Gui end
    function self:SetOpen(value) self.Open = value end
    function self:IsOpen() return self.Open end
    function self:SetReducedMotion(value) self.ReducedMotion = value end
    function self:SetScale(value) self.Scale = value end
    function self:AddTab(id, title, description, icon)
        self.Tabs[id] = { Title = title, Description = description, Icon = icon }
    end
    function self:SelectTab(id)
        assert(self.Tabs[id], "Unknown adapter tab")
        self.SelectedTab = id
        if self.OnTabChanged then self.OnTabChanged(id) end
    end
    local function addControl(ui, tab, config, kind)
        assert(ui.Tabs[tab], "Control requires an existing tab")
        local handle = { Value = config.Value, Config = config, Kind = kind }
        function handle:Get() return self.Value end
        function handle:Set(value, fireCallback)
            self.Value = value
            if fireCallback and config.OnChanged then config.OnChanged(value) end
        end
        function handle:UserChange(value)
            self.Value = value
            assert(config.OnChanged, "Missing changed callback")(value)
        end
        function handle:Activate()
            assert(config.OnActivated, "Missing activated callback")()
        end
        ui.Controls[config.Id] = handle
        return handle
    end
    for _, kind in ipairs({ "Toggle", "Slider", "Button", "Dropdown" }) do
        self["Add" .. kind] = function(ui, tab, config) return addControl(ui, tab, config, kind) end
    end
    return self
end
moduleMap.UIController = UIAdapter
local noticeManagers = {}
local NoticeAdapter = {}
function NoticeAdapter.new(_, cleanup)
    local self = { Entries = {}, Destroyed = false }
    function self:Push(title, message, duration)
        assert(not self.Destroyed, "Push after adapter destruction")
        table.insert(self.Entries, { Title = title, Message = message, Duration = duration })
    end
    cleanup:Add(function() self.Destroyed = true end)
    table.insert(noticeManagers, self)
    return self
end
moduleMap.NotificationManager = NoticeAdapter
'''


TESTS = r'''
local checks = 0
local function check(condition, message)
    checks += 1
    assert(condition, "Main integration assertion: " .. message)
end
local function count(tableValue)
    local total = 0; for _ in pairs(tableValue) do total += 1 end; return total
end
local function ownedGuiCount()
    local total = 0
    for _, child in ipairs(playerGui:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == "VWMenu_Client_v1" and child:GetAttribute("Owner") == "VWMenu" then total += 1 end
    end
    return total
end

local foreign = Instance.new("ScreenGui")
foreign.Name = "VWMenu_Client_v1"
foreign:SetAttribute("Owner", "AnotherDeveloper")
foreign.Parent = playerGui
local foreignFolder = Instance.new("Folder")
foreignFolder.Name = "VWMenu_Settings_v1"
foreignFolder:SetAttribute("Owner", "AnotherDeveloper")
foreignFolder:SetAttribute("Version", 1)
foreignFolder:SetAttribute("demoValue", 91)
foreignFolder.Parent = player

local persisted = moduleMap.SettingsManager.new(player)
check(persisted:Set("reducedMotion", true), "seed reduced motion")
check(persisted:Set("uiScale", 1.1), "seed scale")
check(persisted:Set("demoEnabled", true), "seed toggle")
check(persisted:Set("demoValue", 75), "seed numeric value")
check(persisted:Set("demoChoice", "Preciso"), "seed choice")
check(persisted:Set("demoDestination", "Oficina"), "seed destination")
check(persisted:Set("selectedTab", "Visual"), "seed tab")

local app = moduleMap.Main.Start()
local notices = noticeManagers[#noticeManagers]
check(app.UI:IsOpen(), "Start explicitly opens the panel")
check(count(app.UI.Tabs) == 5, "five tabs registered")
for _, id in ipairs({ "Main", "Player", "Visual", "Teleport", "Settings" }) do
    check(app.UI.Tabs[id] ~= nil, "expected tab: " .. id)
end
check(count(app.Controls) == 10, "all ten controls created")
check(app.UI.ReducedMotion == true and app.UI.Scale == 1.1, "persisted UI preferences applied")
check(app.UI.SelectedTab == "Visual", "persisted selected tab applied")
check(app.Controls.demoValue:Get() == 75 and app.Controls.demoEnabled:Get() == true, "persisted control values applied")
check(app.Controls.demoChoice:Get() == "Preciso" and app.Controls.demoDestination:Get() == "Oficina", "persisted dropdowns applied")
check(app.UI.Gui:GetAttribute("Owner") == "VWMenu" and app.UI.Gui:GetAttribute("Version") == 1, "GUI ownership is tagged")
check(app.UI.Gui:GetAttribute("Ready") == true, "Ready marks successful initialization")
check(ownedGuiCount() == 1 and liveConnections() == 2, "one owned GUI and two instrumented owned connections")
check(foreign.Parent == playerGui and not foreign.Destroyed, "same-name foreign GUI survives Start")
check(foreignFolder:GetAttribute("demoValue") == 91, "same-name foreign settings remain untouched")
check(player.Character == nil, "test has no character")

app.Controls.demoEnabled:UserChange(false)
app.Controls.demoValue:UserChange(42)
app.Controls.demoChoice:UserChange("Rapido")
app.Controls.demoDestination:UserChange("Praca")
check(app.Settings:Get("demoEnabled") == false and app.Features:Get("demoValue") == 42, "demo callbacks reach real settings/controller")
check(app.Settings:Get("demoChoice") == "Rapido" and app.Features:Get("demoDestination") == "Praca", "dropdown callbacks reach real settings/controller")
check(player.Character == nil, "demo callbacks require no character")
local noticeCount = #notices.Entries
app.Controls.notify:Activate()
app.Controls.inspectDestination:Activate()
check(#notices.Entries == noticeCount + 2, "notification and destination buttons call the notification adapter")
check(string.find(notices.Entries[#notices.Entries].Message, "Praca", 1, true) ~= nil, "destination confirmation uses the chosen setting")
app.Controls.reducedMotion:UserChange(false)
app.Controls.uiScale:UserChange(0.85)
app.UI:SelectTab("Settings")
check(app.UI.ReducedMotion == false and app.UI.Scale == 0.85, "visual callbacks apply immediately")
check(app.Settings:Get("selectedTab") == "Settings", "tab callback persists selection")

local invalid = {
    { "demoEnabled", "yes" }, { "demoValue", 0/0 }, { "demoValue", math.huge },
    { "demoValue", 42.5 }, { "demoChoice", "Unknown" },
    { "demoDestination", "Unknown" }, { "uiScale", 7 }, { "reducedMotion", 1 },
}
for _, entry in ipairs(invalid) do
    local id, value = entry[1], entry[2]
    local before = app.Features:Get(id)
    local oldCount = #notices.Entries
    app.Controls[id]:UserChange(value)
    check(app.Features:Get(id) == before and app.Controls[id]:Get() == before, "invalid callback is reverted: " .. id)
    check(#notices.Entries == oldCount + 1, "rejected callback is reported: " .. id)
end
check(app.UI.Scale == 0.85 and app.UI.ReducedMotion == false, "invalid callbacks do not apply UI changes")

app.Controls.reset:Activate()
check(app.Controls.demoEnabled:Get() == false and app.Controls.demoValue:Get() == 50, "reset synchronizes numeric and boolean controls")
check(app.Controls.demoChoice:Get() == "Equilibrado" and app.Controls.demoDestination:Get() == "Laboratorio", "reset synchronizes dropdown controls")
check(app.UI.Scale == 1 and app.UI.ReducedMotion == false and app.UI.SelectedTab == "Main", "reset reapplies visual settings and tab")
check(app.Features:GetState("reset") == "ready", "reset button finishes successfully")

app.Controls.demoValue:UserChange(64)
app.UI:SelectTab("Player")
local firstGui = app.UI.Gui
local second = moduleMap.Main.Start()
check(invokedShutdowns == 1, "rerun invokes the old synchronous shutdown handshake")
check(app.Destroyed and firstGui.Destroyed, "rerun destroys the previous app and GUI")
check(app.Features:GetState("demoValue") == "destroyed" and notices.Destroyed, "rerun shuts down real feature scopes and notice adapter")
check(ownedGuiCount() == 1 and liveConnections() == 2, "rerun leaves one owned GUI and no accumulated connections")
check(second.Controls.demoValue:Get() == 64 and second.UI.SelectedTab == "Player", "rerun reuses only valid session settings")
check(foreign.Parent == playerGui and not foreign.Destroyed, "rerun preserves the same-name foreign GUI")

second.UI.Gui:Destroy()
check(second.Destroyed and ownedGuiCount() == 0, "external GUI.Destroy triggers app cleanup")
check(liveConnections() == 0, "external GUI destruction disconnects all instrumented connections")
check(second.Features:GetState("demoValue") == "destroyed", "external GUI destruction terminates feature scopes")
local repeatOk = pcall(function() second.Destroy(); second.Destroy(); second.Cleanup:Destroy() end)
check(repeatOk and liveConnections() == 0, "app and root cleanup are idempotent")

local third = moduleMap.Main.Start()
third.Controls.destroy:Activate()
check(third.Destroyed and ownedGuiCount() == 0, "Encerrar button destroys its own app")
check(third.Features:GetState("destroy") == "destroyed" and liveConnections() == 0, "Encerrar remains terminal after its callback returns")
check(third.Features:Activate("notify") == false and third.Features:Set("demoValue", 50) == false, "closed feature controller rejects later actions")

local storage = persisted:GetStorageFolder()
storage:SetAttribute("uiScale", 0/0)
storage:SetAttribute("demoValue", math.huge)
storage:SetAttribute("demoChoice", false)
storage:SetAttribute("selectedTab", "Missing")
local fourth = moduleMap.Main.Start()
check(fourth.UI.Scale == 1 and fourth.Controls.demoValue:Get() == 50, "corrupted numeric attributes use validated defaults")
check(fourth.Controls.demoChoice:Get() == "Equilibrado" and fourth.UI.SelectedTab == "Main", "corrupted choices and tabs use validated defaults")
fourth.Destroy()

failNextUICreation = true
local failed, problem = pcall(moduleMap.Main.Start)
check(not failed and string.find(tostring(problem), "Initialization failed", 1, true) ~= nil, "initialization failure is surfaced")
check(ownedGuiCount() == 0 and liveConnections() == 0, "failed initialization releases the partial GUI and connection")
check(foreign.Parent == playerGui and not foreign.Destroyed, "failed initialization still preserves foreign ownership")
RunService.Client = false
check(not pcall(moduleMap.Main.Start), "server context is rejected")
RunService.Client = true
Players.LocalPlayer = nil
check(not pcall(moduleMap.Main.Start), "missing LocalPlayer is rejected")
Players.LocalPlayer = player
check(ownedGuiCount() == 0 and liveConnections() == 0, "precondition failures create no owned resources")
check(foreignFolder.Parent == player and foreignFolder:GetAttribute("demoValue") == 91, "foreign settings survive all lifecycle scenarios")
player:Destroy()
print(string.format("VW MENU Main integration: %d assertions passed (explicit adapters and local signal stubs).", checks))
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    parts = [STUBS, ADAPTERS]
    for name in ("CleanupManager", "SettingsManager", "FeatureRegistry", "FeatureController", "Main"):
        source = (project / "src" / f"{name}.lua").read_text(encoding="utf-8")
        parts += [f'\nmoduleMap["{name}"] = (function()\n', source, "\nend)()\n"]
    parts.append(TESTS)
    with tempfile.TemporaryDirectory(prefix="vw-menu-main-integration-") as temporary:
        bundled = Path(temporary) / "main_integration_runner.luau"
        bundled.write_text("".join(parts), encoding="utf-8")
        result = subprocess.run([str(args.luau.resolve()), str(bundled)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True, encoding="utf-8")
    report = (
        "VW MENU — Main integration tests with explicit local adapters\n"
        f"Runtime: {args.luau.resolve()} (caller-supplied official Luau CLI)\n"
        "Real modules: Main, FeatureRegistry, FeatureController, SettingsManager, CleanupManager.\n"
        "Replaced modules: UIController and NotificationManager; neither renders or processes input.\n"
        "Environment: local Instances, attributes, synchronous Destroying/BindableFunction and signals.\n"
        "Connection assertions cover adapter and Main ownership, not real Roblox event delivery.\n"
        "Not a Roblox Studio run; rendering, input, scheduling, replication, device compatibility\n"
        "and actual memory usage were not validated. No original Lumin Hub code was executed.\n"
        f"Exit code: {result.returncode}\n\n{result.stdout}{result.stderr}"
    )
    (project / "tests" / "main-integration-results.txt").write_text(report, encoding="utf-8")
    print(report)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
