local Config = require("../src/v2/config")
local Cleanup = require("../src/v2/cleanup")
local Aim = require("../src/v2/aim")
local Tracker = require("../src/v2/tracker")

local count = 0
local function test(name, callback)
    callback()
    count += 1
    print("PASS " .. name)
end

test("defaults e limites dos sliders", function()
    local c = Config.new()
    assert(c:Get("SmoothSpeed") == 6 and c:Get("FOVRadius") == 100)
    assert(c:Set("SmoothSpeed", 90) and c:Get("SmoothSpeed") == 30)
    assert(c:Set("FOVRadius", 0) and c:Get("FOVRadius") == 30)
    assert(c:Set("FOVRadius", 999) and c:Get("FOVRadius") == 400)
end)

test("rejeita NaN, infinito, tipos e opções inválidos sem alterar estado", function()
    local c = Config.new()
    assert(not c:Set("SmoothSpeed", 0/0))
    assert(not c:Set("SmoothSpeed", math.huge))
    assert(not c:Set("AimEnabled", 1))
    assert(not c:Set("TargetPart", "Torso"))
    assert(not c:Set("Unknown", true))
    assert(c:Get("SmoothSpeed") == 6 and c:Get("TargetPart") == "Head")
end)

test("hex normalizado e reset não compartilha estado entre instâncias", function()
    local a, b = Config.new(), Config.new()
    assert(a:Set("FOVColor", "#abc123"))
    assert(a:Get("FOVColor") == "#ABC123")
    assert(not a:Set("FOVColor", "red"))
    assert(a:Set("AimEnabled", true))
    a:Reset()
    assert(not a:Get("AimEnabled") and b:Get("FOVColor") == "#42ADFF")
    assert(a:Get("FOVColor") == b:Get("FOVColor"))
end)

test("observadores notificam mudanças, desconectam e não recebem duplicatas", function()
    local c = Config.new()
    local calls = 0
    local disconnect = c:Subscribe(function(key, value)
        assert(key == "AimEnabled" and value == true)
        calls += 1
    end)
    c:Set("AimEnabled", true)
    c:Set("AimEnabled", true)
    disconnect()
    c:Set("AimEnabled", false)
    assert(calls == 1)
end)

test("cleanup é idempotente, libera escopos e continua após falha", function()
    local root = Cleanup.new()
    local total = 0
    local child = root:Scope("player")
    child:Add(function() total += 1 end)
    root:Remove("player")
    child:Destroy()
    assert(total == 1 and next(root.Items) == nil)
    root:Add(function() total += 10 end)
    root:Add(function() error("falha esperada de teardown") end)
    root:Add(function() total += 100 end)
    root:Destroy()
    root:Destroy()
    root:Add(function() total += 1000 end)
    assert(total == 1111 and next(root.Items) == nil)
    assert(root:ConnectionCount() == 0)
end)

test("substituição de escopo descarta a geração antiga", function()
    local root = Cleanup.new()
    local generations = 0
    root:Scope("character"):Add(function() generations += 1 end)
    root:Scope("character"):Add(function() generations += 10 end)
    assert(generations == 1)
    root:Destroy()
    assert(generations == 11)
end)

test("suavização tem o mesmo resultado em 30, 60 e 144 FPS", function()
    for _, fps in ipairs({30, 60, 144}) do
        local remaining = 1
        for _ = 1, fps do remaining *= 1 - Aim.alpha(6, 1/fps) end
        assert(math.abs(remaining - math.exp(-6)) < 1e-12)
    end
    assert(Aim.alpha(6, 0) == 0)
end)

test("FOV inclui a borda e rejeita fora da tela ou atrás da câmera", function()
    assert(Aim.screenDistance(80, 60, 1, true, 0, 0, 100) == 10000)
    assert(Aim.screenDistance(101, 0, 1, true, 0, 0, 100) == nil)
    assert(Aim.screenDistance(0, 0, -1, true, 0, 0, 100) == nil)
    assert(Aim.screenDistance(0, 0, 1, false, 0, 0, 100) == nil)
end)

test("neutros não viram aliados só por compartilhar TeamColor", function()
    local team = {}
    local a = {Neutral = false, Team = team}
    local b = {Neutral = false, Team = team}
    assert(Tracker.sameTeam(a, b))
    b.Neutral = true
    assert(not Tracker.sameTeam(a, b))
    b.Neutral, b.Team = false, {}
    assert(not Tracker.sameTeam(a, b))
    a.Team, b.Team = nil, nil
    assert(not Tracker.sameTeam(a, b))
end)

test("seleção Head não faz fallback silencioso para Root quando Head está ausente", function()
    local config = Config.new()
    local localPlayer, remotePlayer = {}, {}
    local record = {Player = remotePlayer, Root = {Position = {}, IsDescendantOf = function() return true end}, Character = {}}
    local controller = setmetatable({Context = {Config = config,
        Services = {Players = {LocalPlayer = localPlayer}},
        Tracker = {IsAlive = function() return true end, IsTeammate = function() return false end}}}, Aim)
    local result = controller:_candidate(record, {WorldToViewportPoint = function() error("Head ausente não deve projetar Root") end})
    assert(result == nil)
end)

print(string.format("%d testes locais passaram; isto não é um playtest Roblox.", count))
