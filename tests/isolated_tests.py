#!/usr/bin/env python3
"""Run isolated logic tests with an explicitly supplied official Luau CLI.

Usage: python isolated_tests.py --luau PATH_TO_LUAU_EXE
These Instance, tween and timer stubs do not test Roblox rendering, input,
replication, real signals, scheduling, memory usage or device compatibility.
Font uses an audited whitelist; other enums/property assignments are generic.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile


STUBS = r'''
local methods = {}
local function newInstance(className)
    local object = { _kind = "Instance", _className = className,
        _children = {}, _attributes = {}, _properties = { Name = className } }
    return setmetatable(object, {
        __index = function(self, key) return methods[key] or self._properties[key] end,
        __newindex = function(self, key, value)
            if key == "Parent" then
                local old = self._properties.Parent
                if old then
                    local index = table.find(old._children, self)
                    if index then table.remove(old._children, index) end
                end
                self._properties.Parent = value
                if value then table.insert(value._children, self) end
            else self._properties[key] = value end
        end,
    })
end
function methods:IsA(className) return self._className == className end
function methods:GetChildren() return table.clone(self._children) end
function methods:SetAttribute(key, value) self._attributes[key] = value end
function methods:GetAttribute(key) return self._attributes[key] end
function methods:Destroy()
    self._properties.Destroyed = true
    for _, child in ipairs(table.clone(self._children)) do child:Destroy() end
    self.Parent = nil
end
local Instance = {}
function Instance.new(className)
    local object = newInstance(className)
    if className == "BindableEvent" then
        object.Event = { Connect = function(_, callback)
            local connection = { _kind = "RBXScriptConnection", Connected = true }
            function connection:Disconnect() self.Connected = false end
            return connection
        end }
    end
    return object
end
local function typeof(value)
    return if type(value) == "table" and value._kind then value._kind else type(value)
end
local function warn(message) print("Protected error expected by test:", message) end
local function enumGroup(name)
    return setmetatable({}, { __index = function(self, key)
        local value = name .. "." .. key; rawset(self, key, value); return value
    end })
end
local Enum = {}
for _, name in ipairs({ "AutomaticSize", "TextXAlignment", "TextYAlignment",
    "SortOrder", "HorizontalAlignment", "EasingStyle", "EasingDirection" }) do
    Enum[name] = enumGroup(name)
end
-- Audited Font names used by this project. The initial generic enum stub
-- accepted an invalid GothamSemibold constant; reject unknown fonts explicitly.
Enum.Font = setmetatable({ Gotham="Font.Gotham", GothamMedium="Font.GothamMedium",
    GothamBold="Font.GothamBold", GothamBlack="Font.GothamBlack" }, {
    __index = function(_, key) error("Unsupported Enum.Font: " .. tostring(key)) end,
})
local Color3 = { fromRGB = function(r,g,b) return { R=r/255, G=g/255, B=b/255 } end }
local Vector2 = { new = function(x,y) return { X=x, Y=y } end }
local UDim = { new = function(scale,offset) return { Scale=scale, Offset=offset } end }
local UDim2 = { new = function(xs,xo,ys,yo)
    return { X={Scale=xs,Offset=xo}, Y={Scale=ys,Offset=yo} }
end }
local TweenInfo = { new = function(...) return {...} end }
local TweenService = {}
function TweenService:Create(target, info, properties)
    local tween = { Cancelled=false, Destroyed=false }
    function tween:Play() for key,value in pairs(properties) do target[key]=value end end
    function tween:Cancel() self.Cancelled=true end
    function tween:Destroy() self.Destroyed=true end
    return tween
end
local game = { GetService = function(_,name)
    assert(name == "TweenService", "Unsupported service stub: " .. name)
    return TweenService
end }
local scheduled = {}
local task = { delay = function(seconds, callback)
    table.insert(scheduled, { Seconds=seconds, Callback=callback })
end }
local moduleMap = {}
local modules = { WaitForChild = function(_,name) return name end,
    CleanupManager="CleanupManager", SettingsManager="SettingsManager",
    NotificationManager="NotificationManager", FeatureController="FeatureController" }
local script = { Parent = modules }
local function require(name) assert(moduleMap[name], "Unknown module: " .. tostring(name)); return moduleMap[name] end
'''

NOTIFICATION_TESTS = r'''
local notificationChecks = 0
local function check(condition, message)
    notificationChecks += 1; assert(condition, message)
end
local gui = Instance.new("ScreenGui")
local owner = moduleMap.CleanupManager.new()
local notifications = moduleMap.NotificationManager.new(gui, owner)
local evicted = notifications:Push("Um", "Primeira mensagem")
notifications:Push("Dois", "Segunda mensagem")
notifications:Push("Tres", "Terceira mensagem")
notifications:Push("Quatro", "Quarta mensagem")
check(#notifications._entries == 3, "Toasts must retain at most three entries")
check(evicted.Destroyed, "Oldest toast should be destroyed on overflow")
scheduled[1].Callback()
check(#notifications._entries == 3, "An evicted toast timer must be harmless")
scheduled[2].Callback()
check(#notifications._entries == 2, "An expired toast must remove its live entry")
for index = 3, #scheduled do scheduled[index].Callback() end
table.clear(scheduled)
check(#notifications._entries == 0, "Expired toasts must not remain retained")
for index = 1, 80 do notifications:Push("Teste", "Ciclo " .. index, 1) end
check(#notifications._entries == 3, "Repeated pushes must keep the entry bound")
check(#owner._items == 1, "Toast pushes must not grow owner cleanup registrations")
owner:Destroy()
owner:Destroy()
check(#notifications._entries == 0, "Destroy must release all toast entries")
check(#gui:GetChildren() == 0, "Destroy must remove the owned notification stack")
check(notifications:Push("Encerrado", "Nao deve criar toast") == nil, "Destroyed manager must reject pushes")
for _, timer in ipairs(scheduled) do timer.Callback() end
check(#gui:GetChildren() == 0, "Delayed callbacks after destroy must be harmless")
table.clear(scheduled)
local durationOwner = moduleMap.CleanupManager.new()
local durationNotices = moduleMap.NotificationManager.new(gui, durationOwner)
durationNotices:Push("Duracao", "Padrao", 0/0)
check(scheduled[#scheduled].Seconds == 4, "NaN duration must use the default")
durationNotices:Push("Duracao", "Minimo", -10)
check(scheduled[#scheduled].Seconds == 1, "Negative duration must clamp to one second")
durationNotices:Push("Duracao", "Maximo", 1000)
check(scheduled[#scheduled].Seconds == 15, "Large duration must clamp to fifteen seconds")
durationOwner:Destroy()
gui:Destroy()
print(string.format("VW MENU notifications: %d assertions passed (isolated stubs).", notificationChecks))
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parent.parent
    parts = [STUBS]
    for name in ("CleanupManager", "SettingsManager", "NotificationManager", "FeatureController"):
        source = (project / "src" / f"{name}.lua").read_text(encoding="utf-8")
        parts += [f'\nmoduleMap["{name}"] = (function()\n', source, "\nend)()\n"]
    for spec in ("Support", "FeatureController"):
        source = (project / "tests" / f"{spec}.spec.lua").read_text(encoding="utf-8")
        parts += ["\nlocal run = (function()\n", source, "\nend)()\n",
                  'local result = run(modules, Instance.new("Player"))\n',
                  'if type(result) == "string" then print(result) end\n']
    parts.append(NOTIFICATION_TESTS)
    with tempfile.TemporaryDirectory(prefix="vw-menu-isolated-") as temporary:
        bundled = Path(temporary) / "isolated_runner.luau"
        bundled.write_text("".join(parts), encoding="utf-8")
        result = subprocess.run([str(args.luau.resolve()), str(bundled)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True, encoding="utf-8")
    report = (
        "VW MENU — isolated logic tests\n"
        f"Runtime: {args.luau.resolve()} (caller-supplied Luau CLI)\n"
        "Environment: local Instance/Folder/attribute/connection, tween and timer stubs.\n"
        "Not a Roblox Studio run. Rendering, input, scheduling, replication, device compatibility\n"
        "and actual memory usage were not validated. Expected protected errors are deliberate.\n"
        "Font uses an audited whitelist; other enum/property stubs do not validate all Roblox APIs.\n"
        "A previous generic Font stub accepted GothamSemibold, an invalid Roblox enum; regression added.\n"
        "Notification timers are guarded, not cancelled in the scheduler; closures live for at most 15s.\n"
        "No original Lumin Hub code is loaded or executed.\n"
        f"Exit code: {result.returncode}\n\n{result.stdout}{result.stderr}"
    )
    (project / "tests" / "support-results.txt").write_text(report, encoding="utf-8")
    print(report)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
