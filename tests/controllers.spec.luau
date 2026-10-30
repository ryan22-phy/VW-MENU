local Config = require("../src/v2/config")
local Cleanup = require("../src/v2/cleanup")
local Tracker = require("../src/v2/tracker")
local Aim = require("../src/v2/aim")
local ESP = require("../src/v2/esp")
local Signal = require("./signal")
local count = 0
local function test(name, callback)
    callback(); count += 1; print("PASS " .. name)
end

local function observable(object)
    object.Signals = {}
    function object:GetPropertyChangedSignal(key)
        if not self.Signals[key] then self.Signals[key] = Signal() end
        return self.Signals[key]
    end
    return object
end

local function playerFixture()
    local player = observable({CharacterAdded = Signal(), CharacterRemoving = Signal(), Neutral = true})
    local players = {LocalPlayer = player, PlayerAdded = Signal(), PlayerRemoving = Signal()}
    function players:GetPlayers() return {player} end
    return player, players
end

local function characterFixture()
    local model = {ChildAdded = Signal(), ChildRemoved = Signal(), AncestryChanged = Signal(), Children = {}, InWorkspace = true}
    function model:FindFirstChild(key) return self.Children[key] end
    function model:FindFirstChildOfClass(className)
        for _, child in pairs(self.Children) do if child:IsA(className) then return child end end
    end
    function model:IsDescendantOf() return self.InWorkspace end
    local humanoid = observable({Health = 100, MaxHealth = 100, HealthChanged = Signal()})
    function humanoid:IsA(className) return className == "Humanoid" end
    local function part(name)
        local value = {Name = name}
        function value:IsA(className) return className == "BasePart" end
        function value:IsDescendantOf(parent) return parent == model end
        return value
    end
    model.Children.Humanoid = humanoid
    model.Children.HumanoidRootPart = part("HumanoidRootPart")
    model.Children.Head = part("Head")
    return model, humanoid
end

test("tracker ignora Highlight e outros filhos que não mudam suas referências", function()
    local player, players = playerFixture()
    player.Character = characterFixture()
    local cleanup = Cleanup.new()
    local tracker = Tracker.new({Players = players, Workspace = {}}, cleanup)
    local changes = 0
    tracker:Subscribe(function() changes += 1 end)
    player.Character.ChildAdded:Fire({Name = "VWMenu_Highlight", IsA = function() return false end})
    assert(changes == 0, "Criar Highlight não pode reentrar na criação do ESP")
    cleanup:Destroy()
end)

test("tracker troca gerações, ignora remoção antiga e libera conexões de respawn", function()
    local player, players = playerFixture()
    local cleanup = Cleanup.new()
    local tracker = Tracker.new({Players = players, Workspace = {}}, cleanup)
    local initial = cleanup:ConnectionCount()
    local old = characterFixture()
    player.Character = old; player.CharacterAdded:Fire(old)
    assert(tracker:IsAlive(tracker.Records[player]))
    local active = cleanup:ConnectionCount()
    for _ = 1, 20 do
        local current = characterFixture()
        player.Character = current; player.CharacterAdded:Fire(current)
        player.CharacterRemoving:Fire(old)
        assert(tracker.Records[player].Character == current)
        assert(cleanup:ConnectionCount() == active)
        old = current
    end
    player.CharacterRemoving:Fire(old)
    assert(cleanup:ConnectionCount() == initial and not tracker:IsAlive(tracker.Records[player]))
    players.PlayerRemoving:Fire(player)
    assert(tracker.Records[player] == nil and cleanup:ConnectionCount() == 2)
    cleanup:Destroy()
    assert(cleanup:ConnectionCount() == 0)
end)

test("tracker aceita partes atrasadas e invalida morto ou streamed out", function()
    local player, players = playerFixture()
    local model, humanoid = characterFixture()
    local root = model.Children.HumanoidRootPart
    model.Children.HumanoidRootPart = nil
    player.Character = model
    local cleanup = Cleanup.new()
    local tracker = Tracker.new({Players = players, Workspace = {}}, cleanup)
    local record = tracker.Records[player]
    assert(not tracker:IsAlive(record))
    model.Children.HumanoidRootPart = root; model.ChildAdded:Fire(root)
    assert(tracker:IsAlive(record))
    humanoid.Health = 0; humanoid.HealthChanged:Fire(0)
    assert(not tracker:IsAlive(record))
    humanoid.Health = 100; model.InWorkspace = false
    assert(not tracker:IsAlive(record))
    cleanup:Destroy()
end)

local function aimFixture()
    local config = Config.new()
    config:Set("WallCheck", false)
    local localPlayer = {Neutral = false, Team = {}}
    local records = {}
    local tracker = {Records = records}
    function tracker:IsAlive(record) return record.Alive end
    function tracker:IsTeammate(player) return Tracker.sameTeam(localPlayer, player) end
    local center = setmetatable({X = 0, Y = 0}, {__div = function(self) return self end})
    local camera = {ViewportSize = center}
    function camera:WorldToViewportPoint(position) return position, true end
    local controller = setmetatable({Context = {Config = config, Tracker = tracker, Services = {Players = {LocalPlayer = localPlayer}}}}, Aim)
    local function record(x, team)
        local result = {Alive = true, Character = {}, Player = {Neutral = false, Team = team or {}}}
        result.Head = {Position = {X = x, Y = 0, Z = 1}, IsDescendantOf = function() return true end}
        records[result.Player] = result
        return result
    end
    return controller, camera, record, localPlayer
end

test("aim escolhe o mais próximo do centro e ignora mortos e aliados", function()
    local controller, camera, record, localPlayer = aimFixture()
    local near, far = record(10), record(50)
    record(1, localPlayer.Team)
    local dead = record(2); dead.Alive = false
    assert(controller:_select(camera) == near)
    near.Alive = false
    assert(controller:_select(camera) == far)
end)

test("target lock conserva alvo elegível e readquire ao sair do FOV", function()
    local controller, camera, record = aimFixture()
    local near, far = record(10), record(50)
    controller.Context.Config:Set("TargetLock", true)
    controller.Target = far
    assert(controller:_select(camera) == far)
    far.Head.Position.X = 110
    assert(controller:_select(camera) == near)
    near.Alive = false
    assert(controller:_select(camera) == nil)
end)

test("wall check rejeita obstáculo e reutiliza o mesmo RaycastParams", function()
    local controller, camera, record = aimFixture()
    local target = record(10)
    controller.Context.Config:Set("WallCheck", true)
    local vector = setmetatable({}, {__sub = function() return "direction" end})
    target.Head.Position = vector
    camera.CFrame = {Position = vector}
    local params = {}; controller.Params = params
    local blocked = true
    controller.Context.Services.Workspace = {Raycast = function(_, origin, direction, actualParams)
        assert(origin == vector and direction == "direction" and actualParams == params)
        return {Instance = {IsDescendantOf = function(_, model) return not blocked and model == target.Character end}}
    end}
    assert(not controller:_visible(target, target.Head, camera))
    blocked = false
    assert(controller:_visible(target, target.Head, camera))
    controller.Context.Config:Set("WallCheck", false)
    assert(controller:_visible(target, target.Head, camera))
end)

test("ESP aplica master, aliados e precedência das cores reais", function()
    local config = Config.new()
    local localPlayer = {Neutral = false, Team = {}}
    local record = {Alive = true, Player = {Neutral = false, Team = localPlayer.Team, TeamColor = {Color = "team"}}}
    local tracker = {IsAlive = function(_, r) return r.Alive end, IsTeammate = function(_, p) return Tracker.sameTeam(localPlayer, p) end}
    local esp = setmetatable({Context = {Config = config, Tracker = tracker, Services = {Players = {LocalPlayer = localPlayer}}},
        Palette = {FriendColor = "friend", EnemyColor = "enemy", NameColor = "custom"}}, ESP)
    assert(not esp:_eligible(record))
    config:Set("ESPEnabled", true)
    assert(esp:_eligible(record) and esp:_color(record, "Name") == "team")
    config:Set("TeamColors", false)
    assert(esp:_color(record, "Name") == "friend")
    config:Set("ShowTeammates", false)
    assert(not esp:_eligible(record))
    record.Player.Neutral = true
    assert(esp:_eligible(record) and esp:_color(record, "Name") == "enemy")
    config:Set("NameColorMode", "Custom")
    assert(esp:_color(record, "Name") == "custom")
    record.Alive = false
    assert(not esp:_eligible(record))
end)

print(string.format("%d testes de controladores passaram com doubles de API; sem runtime Roblox.", count))
